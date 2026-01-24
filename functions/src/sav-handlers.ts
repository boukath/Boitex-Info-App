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
* PURPOSE: Generates a 'Décharge' or 'Bon de Dépose' PDF and emails it.
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

    // ✅ CHECK TICKET TYPE
    const isRemoval = data.ticketType === 'removal';

    // ✅ Safety Check:
    // - If it's a standard SAV, we expect "Nouveau".
    // - If it's a Removal, the App sets it to "Terminé" immediately, so we MUST allow "Terminé" if type is removal.
    if (data.status !== "Nouveau" && !isRemoval) {
        logger.info(`Skipping ticket ${savCode} because status is not Nouveau (and not a Removal).`);
        return;
    }

    logger.info(`🆕 Processing Document (${isRemoval ? 'Dépose' : 'SAV'}) for Ticket: ${savCode}`);

    try {
      // --- 1. Generate the PDF ---
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

      // --- 3. Determine Recipient (Manager/Client) ---
      const managerEmail = data.storeManagerEmail;
      const recipient = (managerEmail && managerEmail.includes("@"))
        ? managerEmail
        : "commercial@boitexinfo.com";

      // --- 4. Determine Internal Team (CC) based on Service Type ---
      // Defaults to Service Technique if undefined
      const serviceType = data.serviceType || "Service Technique";
      let ccList: string[] = [];

      if (serviceType.toString().toUpperCase().includes("IT")) {
        // 💻 Service IT List
        ccList = [
          "karim-lehamine@boitexinfo.com",
          "commercial@boitexinfo.com"
        ];
        logger.info(`📧 Routing to IT Team: ${ccList.join(", ")}`);
      } else {
        // 🔧 Service Technique List (Default)
        ccList = [
          "khaled-mekideche@boitexinfo.com",
          "commercial@boitexinfo.com",
          "athmane-boukerdous@boitexinfo.com"
        ];
        logger.info(`📧 Routing to Technical Team: ${ccList.join(", ")}`);
      }

      // --- 5. Define Dynamic Email Content ---
      const emailSubject = isRemoval
        ? `[BON DE DÉPOSE] Confirmation de Dépose - ${data.productName} (${savCode})`
        : `[DÉCHARGE MATÉRIEL] Prise en charge SAV - ${data.productName} (${savCode})`;

      const emailTitle = isRemoval ? "Confirmation de Dépose Matériel" : "Confirmation de Prise en Charge SAV";

      const emailBodyIntro = isRemoval
        ? "L'équipement suivant a été <strong>désinstallé et laissé sur site</strong> à votre demande :"
        : "L'équipement suivant a été récupéré par nos techniciens pour reparation :";

      const problemLabel = isRemoval ? "Motif" : "Panne déclarée";

      const docName = isRemoval ? "Bon de Dépose" : "Décharge de Matériel";
      const fileName = isRemoval ? `Bon-Depose-${savCode}.pdf` : `Decharge-SAV-${savCode}.pdf`;

      // ✅ 5b. Build HTML for Items (Table vs Single List)
      let itemsHtml = "";
      const techString = data.pickupTechnicianNames ? data.pickupTechnicianNames.join(", ") : "Non spécifié";

      if (data.multiProducts && data.multiProducts.length > 0) {
        // 🅰️ BATCH MODE: HTML Table
        itemsHtml += `<table style="width: 100%; border-collapse: collapse; font-family: Arial, sans-serif; font-size: 13px; margin-top: 10px; margin-bottom: 20px;">`;
        // Header
        itemsHtml += `<thead style="background-color: #f2f2f2;"><tr>`;
        itemsHtml += `<th style="border: 1px solid #ddd; padding: 8px; text-align: left;">Produit</th>`;
        itemsHtml += `<th style="border: 1px solid #ddd; padding: 8px; text-align: left;">N° Série</th>`;
        itemsHtml += `<th style="border: 1px solid #ddd; padding: 8px; text-align: left;">${problemLabel}</th>`;
        itemsHtml += `</tr></thead>`;
        // Body
        itemsHtml += `<tbody>`;
        data.multiProducts.forEach((item: any) => {
          itemsHtml += `<tr>`;
          itemsHtml += `<td style="border: 1px solid #ddd; padding: 8px;">${item.productName || "N/A"}</td>`;
          itemsHtml += `<td style="border: 1px solid #ddd; padding: 8px;">${item.serialNumber || "N/A"}</td>`;
          itemsHtml += `<td style="border: 1px solid #ddd; padding: 8px;">${item.problemDescription || "N/A"}</td>`;
          itemsHtml += `</tr>`;
        });
        itemsHtml += `</tbody></table>`;

        // Add Technicians info below table for Batch
        itemsHtml += `<p style="margin-top: 0;"><strong>Technicien(s) :</strong> ${techString}</p>`;

      } else {
        // 🅱️ SINGLE MODE: Original <ul> List
        itemsHtml += `<ul>`;
        itemsHtml += `<li><strong>Produit :</strong> ${data.productName}</li>`;
        itemsHtml += `<li><strong>N° Série :</strong> ${data.serialNumber}</li>`;
        itemsHtml += `<li><strong>${problemLabel} :</strong> ${data.problemDescription}</li>`;
        itemsHtml += `<li><strong>Technicien(s) :</strong> ${techString}</li>`;
        itemsHtml += `</ul>`;
      }

      // --- 6. Construct Email ---
      const mailOptions = {
        from: `"Boitex SAV" <${smtpUser.value()}>`,
        to: recipient,
        cc: ccList,
        subject: emailSubject,
        html: `
          <div style="font-family: Arial, sans-serif; color: #333;">
            <h2 style="color: #0D47A1;">${emailTitle}</h2>
            <p>Bonjour ${data.storeManagerName},</p>

            <p>${emailBodyIntro}</p>

            ${itemsHtml}

            <p>Veuillez trouver ci-joint le document <strong>${docName}</strong> officiel (PDF).</p>

            <hr style="border: 0; border-top: 1px solid #eee;" />
            <p style="font-size: 12px; color: #666;">
              Ceci est un message automatique. Merci de ne pas y répondre directement.<br/>
              <strong>SARL Boitex Info</strong>
            </p>
          </div>
        `,
        attachments: [
          {
            filename: fileName,
            content: pdfBuffer,
            contentType: "application/pdf",
          },
        ],
      };

      // --- 7. Send ---
      await transporter.sendMail(mailOptions);
      logger.info(`✅ Email (${docName}) sent successfully to ${recipient} (CC: ${ccList.length}) for ${savCode}`);

    } catch (error) {
      logger.error(`❌ Error processing SAV Document for ${savCode}:`, error);
      // If you set retry: true, throwing here would trigger a retry
    }
  }
);