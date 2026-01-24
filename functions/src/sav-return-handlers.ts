// functions/src/sav-return-handlers.ts

import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";
import * as nodemailer from "nodemailer";
import { defineSecret } from "firebase-functions/params";
import { generateSavReturnPdf } from "./sav-return-pdf-generator"; // ✅ Import from the NEW file

// Reuse Secrets
const smtpHost = defineSecret("SMTP_HOST");
const smtpPort = defineSecret("SMTP_PORT");
const smtpUser = defineSecret("SMTP_USER");
const smtpPassword = defineSecret("SMTP_PASSWORD");

/**
 * TRIGGER: Fires ONLY when status changes to "Retourné".
 */
export const onSavTicketReturned = onDocumentUpdated(
  {
    document: "sav_tickets/{ticketId}",
    secrets: [smtpHost, smtpPort, smtpUser, smtpPassword],
    region: "europe-west1",
    retry: false,
  },
  async (event) => {
    if (!event.data) return;
    const before = event.data.before.data();
    const after = event.data.after.data();
    const ticketId = event.params.ticketId;
    const savCode = after.savCode || ticketId;

    // ✅ Trigger ONLY if status changed TO "Retourné"
    if (after.status !== "Retourné" || before.status === "Retourné") {
      return;
    }

    logger.info(`🔄 Ticket SAV ${savCode} marked as 'Retourné'. Processing Return PDF...`);

    try {
      // 1. Generate PDF using the NEW generator
      const pdfBuffer = await generateSavReturnPdf(after);

      // 2. Setup Email
      const transporter = nodemailer.createTransport({
        host: smtpHost.value(),
        port: parseInt(smtpPort.value()),
        secure: true,
        auth: {
          user: smtpUser.value(),
          pass: smtpPassword.value(),
        },
      });

      const recipient = after.storeManagerEmail || "commercial@boitexinfo.com";
      const returnDate = new Date().toLocaleDateString("fr-FR");

      const mailOptions = {
        from: `"Boitex Info SAV" <${smtpUser.value()}>`,
        to: recipient,
        cc: [
          "khaled-mekideche@boitexinfo.com",
          "commercial@boitexinfo.com",
          "athmane-boukerdous@boitexinfo.com"
            ],
        subject: `[BON DE RESTITUTION] Retour SAV - ${after.productName} (${savCode})`,
        html: `
          <div style="font-family: Arial, sans-serif; color: #333;">
            <h2 style="color: #0D47A1;">Restitution de Matériel SAV</h2>
            <p>Bonjour ${after.storeManagerName || "Client"},</p>
            
            <p>Nous vous confirmons la restitution de votre matériel ce jour (${returnDate}).</p>
            
            <div style="background-color: #f8f9fa; padding: 15px; border-radius: 5px; margin: 20px 0;">
              <strong>Détails de l'intervention :</strong><br/>
              Produit : ${after.productName}<br/>
              S/N : ${after.serialNumber}<br/>
              <br/>
              <em>"${after.technicianReport || 'Maintenance standard effectuée.'}"</em>
            </div>

            <p>Veuillez trouver ci-joint le <strong>Bon de Restitution</strong> officiel.</p>
            
            <hr style="border: 0; border-top: 1px solid #eee;" />
            <p style="font-size: 12px; color: #666;">
              Boitex Info SARL
            </p>
          </div>
        `,
        attachments: [
          {
            filename: `Restitution-${savCode}.pdf`,
            content: pdfBuffer,
            contentType: "application/pdf",
          },
        ],
      };

      // 3. Send
      await transporter.sendMail(mailOptions);
      logger.info(`✅ Return email sent to ${recipient} for ${savCode}`);

    } catch (error) {
      logger.error(`❌ Error processing Return PDF for ${savCode}:`, error);
    }
  }
);