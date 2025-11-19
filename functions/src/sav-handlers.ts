// functions/src/sav-handlers.ts

import { onDocumentCreated } from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";
import * as nodemailer from "nodemailer";
import { defineSecret } from "firebase-functions/params";
import { generateSavDechargePdf } from "./sav-pdf-generator"; // ✅ Import the new generator

// --- 1. Define Secrets (Reusing existing SMTP config) ---
const smtpHost = defineSecret("SMTP_HOST");
const smtpPort = defineSecret("SMTP_PORT");
const smtpUser = defineSecret("SMTP_USER");
const smtpPassword = defineSecret("SMTP_PASSWORD");

/**
 * TRIGGER: Fires when a new document is created in 'sav_tickets'.
 * PURPOSE: Generates a 'Décharge' PDF and emails it to the manager.
 */
export const onSavTicketCreated = onDocumentCreated(
  {
    document: "sav_tickets/{ticketId}",
    secrets: [smtpHost, smtpPort, smtpUser, smtpPassword],
    region: "europe-west1",
    // Retry ensures if the email fails due to network, it tries again.
    // Set to false if you want to avoid risk of double emails.
    retry: false, 
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      logger.error("No data associated with the event");
      return;
    }

    const data = snapshot.data();
    const ticketId = event.params.ticketId;
    const savCode = data.savCode || ticketId;

    // ✅ Safety Check: Only process if it's actually a new ticket (Status "Nouveau")
    // Although onDocumentCreated implies it is new, redundancy is safe.
    if (data.status !== "Nouveau") {
        logger.info(`Skipping ticket ${savCode} because status is not Nouveau.`);
        return;
    }

    logger.info(`🆕 Processing Décharge for SAV Ticket: ${savCode}`);

    try {
      // --- 1. Generate the PDF ---
      // We use the specific "Décharge" generator we created in Step 1
      const pdfBuffer = await generateSavDechargePdf(data);
      
      // --- 2. Configure Email Transport ---
      const transporter = nodemailer.createTransport({
        host: smtpHost.value(),
        port: parseInt(smtpPort.value()),
        secure: true, // True for port 465
        auth: {
          user: smtpUser.value(),
          pass: smtpPassword.value(),
        },
      });

      // --- 3. Determine Recipient ---
      // If the manager put their email, use it. Otherwise, fallback to commercial.
      const managerEmail = data.storeManagerEmail;
      const recipient = (managerEmail && managerEmail.includes("@")) 
        ? managerEmail 
        : "commercial@boitexinfo.com";

      // --- 4. Construct Email ---
      const mailOptions = {
        from: `"Boitex SAV" <${smtpUser.value()}>`,
        to: recipient,
        cc: [
          "athmane-boukerdous@boitexinfo.com",
            ],
        subject: `[DÉCHARGE MATÉRIEL] Prise en charge SAV - ${data.productName} (${savCode})`,
        html: `
          <div style="font-family: Arial, sans-serif; color: #333;">
            <h2 style="color: #0D47A1;">Confirmation de Prise en Charge SAV</h2>
            <p>Bonjour ${data.storeManagerName},</p>
            
            <p>L'équipement suivant a été récupéré par nos services pour diagnostic :</p>
            
            <ul>
              <li><strong>Produit :</strong> ${data.productName}</li>
              <li><strong>N° Série :</strong> ${data.serialNumber}</li>
              <li><strong>Panne déclarée :</strong> ${data.problemDescription}</li>
              <li><strong>Technicien(s) :</strong> ${data.pickupTechnicianNames ? data.pickupTechnicianNames.join(", ") : "Non spécifié"}</li>
            </ul>

            <p>Veuillez trouver ci-joint la <strong>Décharge de Matériel</strong> officielle (PDF) valant preuve de dépôt.</p>
            
            <hr style="border: 0; border-top: 1px solid #eee;" />
            <p style="font-size: 12px; color: #666;">
              Ceci est un message automatique. Merci de ne pas y répondre directement.<br/>
              <strong>Boitex Info SARL</strong>
            </p>
          </div>
        `,
        attachments: [
          {
            filename: `Decharge-SAV-${savCode}.pdf`,
            content: pdfBuffer,
            contentType: "application/pdf",
          },
        ],
      };

      // --- 5. Send ---
      await transporter.sendMail(mailOptions);
      logger.info(`✅ Décharge email sent successfully to ${recipient} for ${savCode}`);

    } catch (error) {
      logger.error(`❌ Error processing SAV Décharge for ${savCode}:`, error);
      // If you set retry: true, throwing here would trigger a retry
    }
  }
);