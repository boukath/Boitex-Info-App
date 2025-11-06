// functions/src/triggers/interventions.ts

import {onDocumentCreated, onDocumentUpdated} from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin"; // ✅ ADDED for Firestore updates
import * as functions from "firebase-functions"; // ✅ ADDED for logging

// --- Core Services ---
import {createActivityLog} from "../services/activity_log_service";
import {
notifyManagers,
notifyServiceIT,
notifyServiceTechnique,
createNotificationsForRoles,
} from "../services/notification_service";

// ✅ --- ADDED: Our 3 new automation services ---
import {generateInterventionPdf} from "../services/pdf_service";
import {uploadBufferToB2, b2Secrets} from "../services/b2_upload_service";
import {sendEmailWithAttachment, emailSecrets} from "../services/email_service";

// --- Constants ---
import {
ROLES_MANAGERS,
ROLES_TECH_IT,
ROLES_TECH_ST,
} from "../core/constants";

//
// ⭐️ ----- EXISTING FUNCTION (UNCHANGED) ----- ⭐️
//
export const onInterventionCreated_v2 = onDocumentCreated("interventions/{interventionId}", async (event) => {
const snapshot = event.data;
if (!snapshot) {
    console.log("No data associated with the event");
    return;
  }

  const data = snapshot.data();
  const title = `Nouvelle Intervention: ${data.interventionCode}`;
  const body = `Client: ${data.clientName} - Magasin: ${data.storeName}`;

  const logService = data.serviceType === "Service IT" ? "it" : "technique";

  createActivityLog({
    service: logService,
    taskType: "Intervention",
    taskTitle: data.clientName || "Nouvelle Intervention",
    storeName: data.storeName || "",
    storeLocation: data.storeLocation || "",
    displayName: data.createdByName || "Inconnu",
    createdByName: data.createdByName || "Inconnu",
    details: `Créée par ${data.createdByName || "Inconnu"}`,
    status: data.status || "Nouveau",
    relatedDocId: snapshot.id,
    relatedCollection: "interventions",
  });

  const notificationData = {
    title,
    body,
    relatedDocId: snapshot.id,
    relatedCollection: "interventions",
  };

  await notifyManagers(title, body);
  await createNotificationsForRoles(ROLES_MANAGERS, notificationData);

  if (data.serviceType === "Service IT") {
    await notifyServiceIT(title, body);
    await createNotificationsForRoles(ROLES_TECH_IT, notificationData);
  } else {
    await notifyServiceTechnique(title, body);
    await createNotificationsForRoles(ROLES_TECH_ST, notificationData);
  }
});

//
// ⭐️ ----- EXISTING FUNCTION (UNCHANGED) ----- ⭐️
//
export const onInterventionStatusUpdate_v2 = onDocumentUpdated("interventions/{interventionId}", async (event) => {
  if (!event.data) return;
  const before = event.data.before.data();
  const after = event.data.after.data();

  if (before.status === after.status) return null; // No change

  const logService = after.serviceType === "Service IT" ? "it" : "technique";

  createActivityLog({
    service: logService,
    taskType: "Intervention",
    taskTitle: after.clientName || "Intervention",
    storeName: after.storeName || "",
    storeLocation: after.storeLocation || "",
    displayName: after.createdByName || "Inconnu",
    createdByName: after.createdByName || "Inconnu",
    details: `Statut changé: '${before.status}' -> '${after.status}'`,
    status: after.status,
    relatedDocId: event.data.after.id,
    relatedCollection: "interventions",
  });

  const title = `Mise à Jour Intervention: ${after.interventionCode || "N/A"}`;
  const body = `Statut: '${before.status}' -> '${after.status}'`;
  const notificationData = {
    title,
    body,
    relatedDocId: event.data.after.id,
    relatedCollection: "interventions",
  };

  await createNotificationsForRoles(ROLES_MANAGERS, notificationData);
  if (logService === "it") {
    await createNotificationsForRoles(ROLES_TECH_IT, notificationData);
  } else {
    await createNotificationsForRoles(ROLES_TECH_ST, notificationData);
  }

  return null;
});


//
// ⭐️ ----- NEW AUTOMATION FUNCTION ----- ⭐️
//
export const onInterventionCompletedSendEmail_v2 = onDocumentUpdated(
  // 1. Define function trigger and secrets
  {
    document: "interventions/{interventionId}",
    // This function needs access to ALL email and B2 secrets
    secrets: [...emailSecrets, ...b2Secrets],
  },
  async (event) => {
    if (!event.data) return null;

    const before = event.data.before.data();
    const after = event.data.after.data();
    const docId = event.data.after.id;

    // 2. CHECK 1: Only run if status just changed to "Terminé"
    if (before.status === "Terminé" || after.status !== "Terminé") {
      // Not the right time to run, so exit
      return null;
    }

    functions.logger.info(`Starting PDF/Email process for intervention: ${docId}`);

    // 3. CHECK 2: Validate required data
    const clientEmail = after.managerEmail;
    const signatureUrl = after.clientSignatureUrl;
    const interventionCode = after.interventionCode || docId;

    if (!clientEmail) {
      functions.logger.warn(`Intervention ${docId} is 'Terminé' but has no 'managerEmail'. Skipping email.`);
      return null;
    }

    if (!signatureUrl) {
      functions.logger.warn(`Intervention ${docId} is 'Terminé' but has no 'clientSignatureUrl'. PDF will lack signature.`);
      // We continue, but log the warning.
    }

    try {
      // 4. STEP A: Generate the PDF in memory
      functions.logger.log(`Generating PDF for ${interventionCode}...`);
      const pdfBuffer = await generateInterventionPdf(after);

      // 5. STEP B: Upload the PDF to Backblaze
      const fileName = `interventions_reports/${interventionCode}_${docId}.pdf`;
      functions.logger.log(`Uploading PDF to B2 as ${fileName}...`);
      const publicPdfUrl = await uploadBufferToB2(pdfBuffer, fileName);

      // 6. STEP C (Bonus): Save the new PDF URL back to the document
      await admin.firestore().collection("interventions").doc(docId).update({
        pdfUrl: publicPdfUrl,
        pdfGeneratedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      functions.logger.log(`Saved PDF URL ${publicPdfUrl} back to document ${docId}.`);

      // 7. STEP D: Send the email with the PDF attached
      const subject = `Rapport d'Intervention Terminé: ${interventionCode}`;
      const htmlBody = `
        <p>Bonjour,</p>
        <p>Veuillez trouver ci-joint le rapport d'intervention pour :</p>
        <ul>
          <li><strong>Client:</strong> ${after.clientName || "N/A"}</li>
          <li><strong>Magasin:</strong> ${after.storeName || "N/A"}</li>
          <li><strong>Code:</strong> ${interventionCode}</li>
        </ul>
        <p>Merci de votre confiance.</p>
        <p><strong>Service Technique - Boitex Info</strong></p>
      `;

      functions.logger.log(`Sending email to ${clientEmail}...`);
      await sendEmailWithAttachment(
        clientEmail,
        subject,
        htmlBody,
        pdfBuffer, // Attach the buffer directly
        `${interventionCode}.pdf` // The filename the client will see
      );

      functions.logger.info(`✅ Successfully processed intervention ${docId}.`);
      return null;

    } catch (error) {
      functions.logger.error(`❌ FAILED to process intervention ${docId}:`, error);
      // Optional: Update the doc with an error status
      await admin.firestore().collection("interventions").doc(docId).update({
        pdfGenerationError: error ? (error as Error).message : "Unknown error",
      });
      return null;
    }
  }
);