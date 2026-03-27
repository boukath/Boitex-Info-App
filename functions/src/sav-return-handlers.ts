// functions/src/sav-return-handlers.ts

import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";
import * as nodemailer from "nodemailer";
import { defineSecret } from "firebase-functions/params";
import { generateSavReturnPdf } from "./sav-return-pdf-generator";
// ✅ Import the dynamic email settings helper
import { getEmailSettings } from "./email-utils";

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
      // 1. Generate PDF using the NEW generator (which now includes the timeline)
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

      // ✅ NEW: Fetch Dynamic SAV Settings
      const emailSettings = await getEmailSettings();

      // ✅ SMART ROUTING
      const serviceType = after.serviceType || "Service Technique";
      let ccList: string[] = [];
      let fromDisplayName = "Boitex Info SAV";

      if (serviceType.toString().toUpperCase().includes("IT")) {
        ccList = emailSettings.sav_cc_it;
        fromDisplayName = "Boitex Info SAV IT";
      } else {
        ccList = emailSettings.sav_cc_tech;
      }

      // Safe fallbacks in case of grouped/multi-product tickets
      const displayProduct = after.productName || "Multiples équipements";
      const displaySn = after.serialNumber || "-";
      const displayReport = after.technicianReport || "Intervention technique terminée et matériel vérifié.";

      const mailOptions = {
        from: `"${fromDisplayName}" <${smtpUser.value()}>`,
        to: recipient,
        cc: ccList, // ✅ Dynamic List
        subject: `[BON DE RESTITUTION] Retour SAV - ${displayProduct} (${savCode})`,
        html: `
          <div style="font-family: Arial, sans-serif; color: #333; max-width: 600px; margin: 0 auto;">
            <h2 style="color: #0D47A1;">Restitution de Matériel SAV</h2>
            <p>Bonjour ${after.storeManagerName || "Client"},</p>

            <p>Nous vous confirmons la restitution de votre matériel ce jour (<strong>${returnDate}</strong>).</p>

            <div style="background-color: #f8f9fa; padding: 15px; border-radius: 5px; margin: 20px 0; border: 1px solid #E2E8F0;">
              <strong style="color: #0F172A;">Détails de l'intervention :</strong><br/><br/>
              <strong>Produit :</strong> ${displayProduct}<br/>
              <strong>N° Série :</strong> ${displaySn}<br/>
              <br/>
              <em>"${displayReport}"</em>
            </div>

            <p>Veuillez trouver ci-joint le <strong>Bon de Restitution</strong> officiel.</p>

            <div style="background-color: #E0F2FE; color: #0284C7; padding: 12px; border-radius: 6px; font-size: 13px; margin: 20px 0; border-left: 4px solid #0284C7;">
              📄 <strong>Note importante :</strong> Le document joint inclut désormais le journal détaillé de la réparation, précisant les <strong>pièces remplacées</strong> et les étapes de l'intervention.
            </div>

            <hr style="border: 0; border-top: 1px solid #eee; margin-top: 30px;" />
            <p style="font-size: 12px; color: #666; text-align: center;">
              Ceci est un message automatique, merci de ne pas y répondre directement.<br/>
              <strong>Boitex Info SARL</strong>
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
      logger.info(`✅ Return email sent to ${recipient} (CC: ${ccList.length}) for ${savCode}`);

    } catch (error) {
      logger.error(`❌ Error processing Return PDF for ${savCode}:`, error);
    }
  }
);