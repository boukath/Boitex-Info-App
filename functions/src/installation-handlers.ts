// functions/src/installation-handlers.ts

import {onDocumentUpdated} from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";
import * as nodemailer from "nodemailer"; // ✅ Added for Email
import {defineSecret} from "firebase-functions/params"; // ✅ Added for Secrets
// ✅ MODIFIED: Added 'onCall' to the imports so we can use it for the new function
import {onCall, HttpsError} from "firebase-functions/v2/https";

// ✅ Import the specific PDF generator for Installations
import { generateInstallationPdf } from "./installation-pdf-generator";

// ✅ Define Secrets
const smtpHost = defineSecret("SMTP_HOST");
const smtpPort = defineSecret("SMTP_PORT");
const smtpUser = defineSecret("SMTP_USER");
const smtpPassword = defineSecret("SMTP_PASSWORD");

/**
* Helper: Validate email format
* (Added to support the fallback logic)
*/
function isValidEmail(email: string): boolean {
  if (!email || typeof email !== "string") return false;
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
}

// ✅ 1. THE SYNC LOGIC (Adapted for Installations)
// This reads the "systems" array you just saved in the App and upserts it to Inventory.
const syncInstallationToInventory = async (installationId: string, data: any) => {
  const db = admin.firestore();
  const clientId = data.clientId;
  const storeId = data.storeId;
  const systems = data.systems;

  // Basic Validation
  if (!clientId || !storeId || !systems || !Array.isArray(systems) || systems.length === 0) {
    logger.log(`ℹ️ Inventory Sync: Skipping Installation ${installationId} (No systems data).`);
    return;
  }

  logger.log(`🔄 Starting Installation Inventory Sync: ${storeId} | ${systems.length} product groups.`);

  // Reference to the store's equipment collection
  const inventoryRef = db
    .collection("clients")
    .doc(clientId)
    .collection("stores")
    .doc(storeId)
    .collection("materiel_installe");

  const batch = db.batch();
  let opCount = 0;

  // Loop through each Product Group (e.g., "Camera x5")
  for (const item of systems) {
    let serials = item.serialNumbers || [];

    // If no serials are tracked, we might still want to add the item (Generic)
    // For now, assuming we stick to serial-based tracking as per previous logic.
    if (serials.length === 0) continue;

    // Loop through Serials
    for (const serial of serials) {
      if (!serial) continue; // Skip empty serials

      // Check if this serial already exists in this store
      // NOTE: In a real app, serials should be unique globally or checked more rigorously.
      const snapshot = await inventoryRef.where("serialNumber", "==", serial).get();

      if (snapshot.empty) {
        // 🟢 CREATE NEW
        const newDocRef = inventoryRef.doc();
        batch.set(newDocRef, {
          // Core Data
          productId: item.id || null,
          nom: item.name || "Produit Inconnu",
          serialNumber: serial,

          // ✅ FIXED: Added missing fields here
          marque: item.marque || "N/A",
          reference: item.reference || "N/A",
          category: item.category || "N/A",
          image: item.image || null,

          status: "Installé",

          // Source Info
          installDate: admin.firestore.FieldValue.serverTimestamp(),
          source: "Installation Report",
          firstSeenInstallationId: installationId,
          lastInterventionDate: admin.firestore.FieldValue.serverTimestamp(),
        });
      } else {
        // 🔵 UPDATE EXISTING
        // We also update the details here in case they were N/A before!
        batch.update(snapshot.docs[0].ref, {
          lastInterventionDate: admin.firestore.FieldValue.serverTimestamp(),
          status: "Installé",
          lastInstallationId: installationId,

          // ✅ FIXED: Update details on re-sync
          productId: item.id || null,
          nom: item.name || snapshot.docs[0].data().nom, // Keep existing name if preferred, or overwrite
          marque: item.marque || snapshot.docs[0].data().marque,
          reference: item.reference || snapshot.docs[0].data().reference,
          category: item.category || snapshot.docs[0].data().category,
          image: item.image || snapshot.docs[0].data().image,
        });
      }
      opCount++;
    }
  }

  // Commit
  if (opCount > 0) {
    await batch.commit();
    logger.log(`✅ Installation Sync Complete: ${opCount} assets added/updated in Store ${storeId}.`);
  } else {
    logger.log("ℹ️ Installation Sync: No valid serial numbers found to sync.");
  }
};

// ✅ 2. THE TRIGGER
// Listens for changes to 'installations/{id}'
export const onInstallationTermine = onDocumentUpdated(
  {
    document: "installations/{installationId}",
    region: "europe-west1",
    secrets: [smtpHost, smtpPort, smtpUser, smtpPassword], // ✅ Added Secrets
  },
  async (event) => {
    if (!event.data) return;

    const before = event.data.before.data();
    const after = event.data.after.data();

    // Only run if status CHANGED to "Terminée"
    if (before?.status !== "Terminée" && after?.status === "Terminée") {
      const installationId = event.params.installationId;

      // --- 1. Run Inventory Sync (Preserved) ---
      // We wrap it in try/catch to ensure the email still sends even if sync hits a snag
      try {
        await syncInstallationToInventory(installationId, after);
      } catch (error) {
        logger.error("❌ Inventory sync failed, but continuing with email:", error);
      }

      // --- 2. Run Email & PDF Logic (Upgraded) ---
      logger.log(`🚀 Processing Completion for Installation: ${after.installationCode}`);

      // Prepare Recipients (with Fallback)
      // ✅ FIX: Use 'clientEmail' instead of 'managerEmail'
      let mainRecipient = after.clientEmail;
      if (!isValidEmail(mainRecipient)) {
         logger.warn(`⚠️ Invalid or missing client email. Defaulting to internal admin.`);
         mainRecipient = "athmane-boukerdous@boitexinfo.com";
      } else {
         logger.log(`📧 Sending to client: ${mainRecipient}`);
      }

      const ccList = [
          "athmane-boukerdous@boitexinfo.com",
      ];

      // Generate PDF
      logger.log("📄 Generating Installation PDF in memory...");
      let pdfBuffer: Buffer;
      try {
          pdfBuffer = await generateInstallationPdf(after);
      } catch (e) {
          logger.error("❌ PDF Generation Failed", e);
          return; // Stop if PDF fails to avoid sending broken emails
      }

      // Configure Transporter
      const transporter = nodemailer.createTransport({
        host: smtpHost.value(),
        port: parseInt(smtpPort.value(), 10),
        secure: parseInt(smtpPort.value(), 10) === 465,
        auth: { user: smtpUser.value(), pass: smtpPassword.value() },
      });

      const mailOptions = {
        from: `"Boitex Info Installation" <${smtpUser.value()}>`,
        to: mainRecipient,
        cc: ccList,
        subject: `Rapport d'Installation: ${after.installationCode || "N/A"}`,
        html: `
          <p>Bonjour,</p>
          <p>L'installation <strong>${after.installationCode || "N/A"}</strong>
          pour le client <strong>${after.clientName || "Client"}</strong>
          au magasin <strong>${after.storeName || "Magasin"}</strong>
          est maintenant terminée.</p>

          <p>Vous trouverez ci-joint le rapport détaillé incluant les numéros de série des équipements installés.</p>

          <p>Cordialement,<br>L'équipe Technique Boitex Info</p>
        `,
        attachments: [{
          filename: `Installation-${after.installationCode || "Rapport"}.pdf`,
          content: pdfBuffer,
          contentType: "application/pdf",
        }]
      };

      try {
          await transporter.sendMail(mailOptions);
          logger.log(`✅ Email successfully sent to ${mainRecipient} (CC: ${ccList.length})`);
      } catch (e) {
          logger.error("❌ Error sending email:", e);
          throw new HttpsError("internal", "Email sending failed");
      }
    }
  }
);

// ✅ 3. CALLABLE: Generate PDF on Demand
// This function is called by the App when clicking "Generer PDF", "WhatsApp", or "Email" buttons.
export const getInstallationPdf = onCall(
  { region: "europe-west1" },
  async (request) => {
    const installationId = request.data.installationId;
    if (!installationId) {
      throw new HttpsError("invalid-argument", "Missing installationId");
    }

    // 1. Fetch Data
    const doc = await admin.firestore().collection("installations").doc(installationId).get();
    if (!doc.exists) {
      throw new HttpsError("not-found", "Installation not found");
    }
    const data = doc.data();

    // 2. Generate PDF
    try {
      const pdfBuffer = await generateInstallationPdf(data);

      // 3. Return as Base64 string (so App can download and save it as a file)
      return {
        pdfBase64: pdfBuffer.toString("base64"),
        filename: `Installation-${data?.installationCode || "Rapport"}.pdf`
      };
    } catch (error) {
      logger.error("Error generating PDF on-demand:", error);
      throw new HttpsError("internal", "Could not generate PDF");
    }
  }
);