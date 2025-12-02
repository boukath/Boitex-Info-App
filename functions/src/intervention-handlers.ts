// functions/src/intervention-handlers.ts

import {onDocumentUpdated} from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";
import * as nodemailer from "nodemailer";
import * as admin from "firebase-admin"; // ✅ ADDED: Required for database writes
import {defineSecret} from "firebase-functions/params";
import { HttpsError } from "firebase-functions/v2/https";

// ✅ --- NEW ---
// Import our new PDF generator function
import { generateInterventionPdf } from "./pdf-generator";
// ✅ --- END NEW ---

// --- 1. Define the secrets we just set ---
const smtpHost = defineSecret("SMTP_HOST");
const smtpPort = defineSecret("SMTP_PORT");
const smtpUser = defineSecret("SMTP_USER");
const smtpPassword = defineSecret("SMTP_PASSWORD");

// --- CONFIGURATION CONSTANTS (ADDED FOR SERVICE IT) ---
const SERVICE_IT = "Service IT";

const CC_LIST_TECH = [
"athmane-boukerdous@boitexinfo.com",
"commercial@boitexinfo.com",
"khaled-mekideche@boitexinfo.com"
];

const CC_LIST_IT = [
"commercial@boitexinfo.com",
"karim-lehamine@boitexinfo.com"
];

/**
* Validates if a string is a plausible email address.
* @param {string} email The email string to test.
* @return {boolean} True if it looks like an email, false otherwise.
*/
function isValidEmail(email: string): boolean {
  if (!email || typeof email !== "string") {
    return false;
  }
  // A simple regex for email validation.
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
}

// ✅ ---------------------------------------------------------
// ✅ NEW: Inventory Synchronization Logic
// ✅ ---------------------------------------------------------
const syncInterventionToInventory = async (interventionId: string, data: any) => {
  const db = admin.firestore();
  const clientId = data.clientId;
  const storeId = data.storeId;
  const systems = data.systems; // The list from your App

  // 1. Basic Validation
  if (!clientId || !storeId || !systems || !Array.isArray(systems) || systems.length === 0) {
    logger.log(`ℹ️ Inventory Sync: Skipping ${interventionId} (No systems data or missing IDs).`);
    return;
  }

  logger.log(`🔄 Starting Inventory Sync for Store: ${storeId} | Found ${systems.length} product groups.`);

  // Reference to the store's equipment collection
  const inventoryRef = db
    .collection("clients")
    .doc(clientId)
    .collection("stores")
    .doc(storeId)
    .collection("materiel_installe");

  const batch = db.batch();
  let opCount = 0;

  // 2. Loop through each Product Group
  for (const item of systems) {
    // Get the list of serials.
    let serials: string[] = item.serialNumbers || [];

    // Loop through every serial number provided
    for (const sn of serials) {
      // Skip empty serial numbers
      if (!sn || sn.trim() === "") continue;

      // 3. Check if this specific asset (S/N) already exists in this store
      const snapshot = await inventoryRef.where("serialNumber", "==", sn).limit(1).get();

      let assetRef;
      let assetData;

      if (!snapshot.empty) {
        // 🟢 CASE A: UPDATE (Maintenance)
        // The asset is already there. We just update its heartbeat.
        const doc = snapshot.docs[0];
        assetRef = doc.ref;

        assetData = {
          lastInterventionId: interventionId,
          lastInterventionDate: admin.firestore.FieldValue.serverTimestamp(),
          status: "Opérationnel", // Confirmed working during intervention

          // ✅ FIXED: Update brand and category if changed
          name: item.name || doc.data().name,
          marque: item.marque || doc.data().marque,
          reference: item.reference || doc.data().reference,
          categorie: item.category || doc.data().categorie,
          imageUrl: item.image || doc.data().imageUrl,
        };
        batch.update(assetRef, assetData);
      } else {
        // 🔵 CASE B: INSERT (New Installation or Discovery)
        // This S/N was not in the database. Create it.
        assetRef = inventoryRef.doc();

        assetData = {
          // Standard Fields
          name: item.name || "Équipement Inconnu",
          // ✅ FIXED: Saving brand and category on creation
          marque: item.marque || "Non spécifiée",
          reference: item.reference || "N/A",
          serialNumber: sn,
          categorie: item.category || "Autre",

          // Lifecycle Fields
          installDate: admin.firestore.FieldValue.serverTimestamp(),
          status: "Installé",
          imageUrl: item.image || null,

          // Traceability
          source: "Intervention Audit",
          firstSeenInterventionId: interventionId,
          lastInterventionId: interventionId,
          lastInterventionDate: admin.firestore.FieldValue.serverTimestamp(),
        };
        batch.set(assetRef, assetData);
      }
      opCount++;
    }
  }

  // 4. Commit the changes
  if (opCount > 0) {
    await batch.commit();
    logger.log(`✅ Inventory Sync Complete: ${opCount} assets processed for Store ${storeId}.`);
  } else {
    logger.log("ℹ️ Inventory Sync: No valid serial numbers found to sync.");
  }
};
// ✅ ---------------------------------------------------------
// ✅ END NEW LOGIC
// ✅ ---------------------------------------------------------


// --- 2. Create the function trigger ---
export const onInterventionTermine = onDocumentUpdated(
  {
    document: "interventions/{interventionId}",
    region: "europe-west1", // Matching your project's region
    secrets: [smtpHost, smtpPort, smtpUser, smtpPassword],
  },
  async (event) => {
    // --- 3. Get the data before and after the change ---
    if (!event.data) {
      logger.log("No data found in event, exiting.");
      return;
    }

    const beforeData = event.data.before.data();
    const afterData = event.data.after.data();

    // --- 4. Get specific data fields ---
    const statusBefore = beforeData?.status;
    const statusAfter = afterData?.status;
    const interventionCode = afterData?.interventionCode || "N/A";
    const serviceType = afterData?.serviceType || "Service Technique"; // Check Service Type

    logger.log(`Processing update for intervention: ${interventionCode} | Service: ${serviceType}`);

    // --- 5. Status Check Logic ---
    // We only proceed if the status was *not* "Terminé" before
    // AND it *is* "Terminé" now.
    if (statusBefore === "Terminé" && statusAfter === "Terminé") {
      logger.log("Status was already 'Terminé', no email needed.");
      return;
    }

    if (statusAfter !== "Terminé") {
      logger.log(`Status changed to '${statusAfter}', not 'Terminé'. No email needed.`);
      return;
    }

    logger.log("Status changed to 'Terminé'. Starting post-completion tasks...");

    // ✅ ---------------------------------------------------------
    // ✅ INTEGRATION: Call Inventory Sync
    // ✅ ---------------------------------------------------------
    try {
      await syncInterventionToInventory(event.params.interventionId, afterData);
    } catch (error) {
      // Log error but DO NOT stop execution. We still want to send the email.
      logger.error("❌ Error syncing inventory:", error);
    }
    // ✅ ---------------------------------------------------------

    logger.log("Preparing to send email...");

    // --- 6. Email Validation Logic ---
    const managerEmail = afterData?.managerEmail;

    if (!isValidEmail(managerEmail)) {
      logger.warn(
        `Invalid or missing managerEmail: '${managerEmail}'. Cannot send email.`
      );
      return;
    }

    logger.log(`Valid recipient email found: ${managerEmail}`);

    // --- 7. Configure Nodemailer (SMTP Transporter) ---
    const transporter = nodemailer.createTransport({
      host: smtpHost.value(),
      port: parseInt(smtpPort.value(), 10),
      secure: parseInt(smtpPort.value(), 10) === 465,
      auth: {
        user: smtpUser.value(),
        pass: smtpPassword.value(),
      },
    });

    // --- 7.5. DETERMINE IDENTITY (IT vs TECHNIQUE) ---
    let fromDisplayName = "Boitex Info Service Technique";
    let ccList = CC_LIST_TECH;
    let pdfSubjectPrefix = "Rapport Intervention";

    if (serviceType === SERVICE_IT) {
      fromDisplayName = "Boitex Info Service IT";
      ccList = CC_LIST_IT;
      pdfSubjectPrefix = "Rapport Intervention IT";
    }

    // --- 8. Define Email Content ---
    const subject = `${pdfSubjectPrefix}: ${interventionCode} - ${afterData?.clientName || "Client"}`;
    const body = `
      <p>Bonjour,</p>

      <p>L'intervention <strong>${interventionCode}</strong>
      concernant le client <strong>${afterData?.clientName || "N/A"}</strong>
      au magasin <strong>${afterData?.storeName || "N/A"}</strong>
      est maintenant terminée.</p>

      <p>Vous trouverez ci-joint le rapport d'intervention au format PDF.</p>

      <p><strong>Diagnostique:</strong><br/>
      ${afterData?.diagnostic || "Non spécifié"}</p>

      <p><strong>Travaux Effectués:</strong><br/>
      ${afterData?.workDone || "Non spécifié"}</p>

      <p>Cordialement,<br/>
      ${fromDisplayName}</p>
    `;

    // --- 9. Send the Email ---
    try {
      // ✅ --- NEW ---
      // Generate the PDF buffer *before* sending the email
      logger.log("Generating PDF report in memory...");
      const pdfBuffer = await generateInterventionPdf(afterData);
      logger.log("✅ PDF report generated successfully.");
      // ✅ --- END NEW ---

      // ✅ --- MODIFIED ---
      // Add the 'attachments' array to the mail options
      const mailOptions = {
        from: `"${fromDisplayName}" <${smtpUser.value()}>`,
        to: managerEmail,
        cc: ccList, // Dynamic list
        subject: subject,
        html: body,
        attachments: [
          {
            filename: `${pdfSubjectPrefix.replace(/\s/g, "_")}-${interventionCode}.pdf`,
            content: pdfBuffer,
            contentType: "application/pdf",
          },
        ],
      };
      // ✅ --- END MODIFIED ---

      await transporter.sendMail(mailOptions);
      // ✅ Updated log message to reflect the CC
      logger.log(`✅ Email sent as "${fromDisplayName}" to ${managerEmail} (CC count: ${ccList.length})`);
      return;

    } catch (error) {
      logger.error(`❌ Failed to send email to ${managerEmail}:`, error);
      throw new HttpsError(
        "internal",
        "Failed to generate PDF or send email.",
        error
      );
    }
  }
);