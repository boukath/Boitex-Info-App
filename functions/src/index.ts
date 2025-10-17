// functions/src/index.ts
import {onDocumentCreated, onDocumentUpdated} from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";
import {setGlobalOptions} from "firebase-functions/v2";
import * as functions from "firebase-functions";
import B2 from "backblaze-b2";
import cors from "cors";
// ✅ ADDED: Imports for v2 secrets and onRequest
import {defineSecret} from "firebase-functions/params";
import {onRequest} from "firebase-functions/v2/https";

// ✅ NEW: Define the secrets your function will use
const backblazeKeyId = defineSecret("BACKBLAZE_KEY_ID");
const backblazeAppKey = defineSecret("BACKBLAZE_APP_KEY");
const backblazeBucketId = defineSecret("BACKBLAZE_BUCKET_ID");

// Initialize Firebase Admin SDK
admin.initializeApp();

// Set the region for all functions
setGlobalOptions({region: "europe-west1"});

// --- START OF YOUR EXISTING NOTIFICATION CODE (UNCHANGED) ---

const MANAGERS_TOPIC = "manager_notifications";
const TECH_ST_TOPIC = "technician_st_alerts";
// const TECH_IT_TOPIC = "technician_it_alerts";

const notifyManagers = async (title: string, body: string) => {
  const message = {
    notification: {title, body},
    topic: MANAGERS_TOPIC,
  };
  try {
    await admin.messaging().send(message);
    console.log(`✅ Sent manager notification: ${title}`);
  } catch (error) {
    console.error("❌ Error sending manager notification:", error);
  }
};

const notifyServiceTechnique = async (title: string, body: string) => {
  const message = {
    notification: {title, body},
    topic: TECH_ST_TOPIC,
  };
  try {
    await admin.messaging().send(message);
    console.log(`✅ Sent Service Technique notification: ${title}`);
  } catch (error) {
    console.error("❌ Error sending ST notification:", error);
  }
};

// RENAMED
export const onInterventionCreated_v2 = onDocumentCreated("interventions/{interventionId}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) {
    console.log("No data associated with the event");
    return;
  }
  const data = snapshot.data();
  const title = `Nouvelle Intervention: ${data.interventionCode}`;
  const body = `Client: ${data.clientName} - Magasin: ${data.storeName}`;

  await notifyManagers(title, body);
  await notifyServiceTechnique(title, body);
});

// RENAMED
export const onSavTicketCreated_v2 = onDocumentCreated("sav_tickets/{ticketId}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) {
    console.log("No data associated with the event");
    return;
  }
  const data = snapshot.data();
  const title = `Nouveau Ticket SAV: ${data.savCode}`;
  const body = `Client: ${data.clientName} - Produit: ${data.productName}`;

  await notifyManagers(title, body);
  await notifyServiceTechnique(title, body);
});

// RENAMED
export const onReplacementRequestCreated_v2 = onDocumentCreated("replacement_requests/{requestId}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) {
    console.log("No data associated with the event");
    return;
  }
  const data = snapshot.data();
  const title = `Nouvelle Demande de Remplacement: ${data.replacementRequestCode}`;
  const body = `Demandé par: ${data.technicianName} pour ${data.clientName}`;

  await notifyManagers(title, body);
});

// RENAMED
export const onSavTicketUpdate_v2 = onDocumentUpdated(
  "sav_tickets/{ticketId}",
  async (event) => {
    if (!event.data) return;
    const before = event.data.before.data();
    const after = event.data.after.data();

    if (before.status !== after.status) {
      const title = `Mise à Jour SAV: ${after.savCode}`;
      const body = `Nouveau statut: ${after.status}`;
      await notifyManagers(title, body);
      if (["En attente de pièce", "Terminé"].includes(after.status)) {
        await notifyServiceTechnique(title, body);
      }
    }
  }
);

// RENAMED
export const onReplacementRequestUpdate_v2 = onDocumentUpdated(
  "replacement_requests/{requestId}",
  async (event) => {
    if (!event.data) return;

    const before = event.data.before.data();
    const after = event.data.after.data();

    const beforeStatus = before.requestStatus;
    const afterStatus = after.requestStatus;
    const requestCode = after.replacementRequestCode;

    if (beforeStatus !== "Approuvé" && afterStatus === "Approuvé") {
      const clientName = after.clientName || "N/A";
      const productName = after.productName || "N/A";
      const title = `Remplacement Approuvé: ${requestCode}`;
      const body = `Préparez la pièce pour ${clientName} | Produit: ${productName}`;

      await notifyServiceTechnique(title, body);
      await notifyManagers(title, body);
      console.log(`✅ Replacement approval notification sent for ${requestCode}`);
    }

    if (beforeStatus !== afterStatus) {
      await notifyManagers(
        "Mise à Jour: Demande de Remplacement",
        `Le statut pour ${after.replacementRequestCode || "N/A"} est maintenant: ${afterStatus}.`
      );
    }
  }
);

const collectionsToWatchForUpdates = [
  "interventions",
  "installations",
  "livraisons",
  "projects",
  "sav_tickets",
  "requisitions",
];

collectionsToWatchForUpdates.forEach((collection) => {
  exports[`on${collection}Updated`] = onDocumentUpdated(
    `${collection}/{docId}`,
    async (event) => {
      if (!event.data) return;

      const after = event.data.after.data();
      const code = after.requisitionCode || after.interventionCode || after.savCode || after.blCode || after.clientName || "N/A";
      const status = after.status || after.requestStatus || "Inconnu";

      const title = `Mise à Jour: ${collection}`;
      const body = `Statut de '${code}' est maintenant '${status}'`;
      await notifyManagers(title, body);
    }
  );
});

// --- END OF YOUR EXISTING NOTIFICATION CODE ---


// --- ✅ BACKBLAZE B2 FUNCTION (CORRECTED SYNTAX) ---

const corsHandler = cors({origin: true});

// ✅ MODIFIED: Using the correct v2 syntax for onRequest with secrets
export const getB2UploadUrl = onRequest(
  { secrets: [backblazeKeyId, backblazeAppKey, backblazeBucketId] },
  (request, response) => {
    corsHandler(request, response, async () => {
      try {
        const b2 = new B2({
          applicationKeyId: backblazeKeyId.value(),
          applicationKey: backblazeAppKey.value(),
        });

        const authResponse = await b2.authorize();
        const { downloadUrl } = authResponse.data;
        const bucketId = backblazeBucketId.value();
        const uploadUrlResponse = await b2.getUploadUrl({ bucketId: bucketId });
        const bucketName = "boitex-info-app";
        const downloadUrlPrefix = `${downloadUrl}/file/${bucketName}/`;

        functions.logger.info("Successfully generated B2 upload URL.");
        response.status(200).send({
          uploadUrl: uploadUrlResponse.data.uploadUrl,
          authorizationToken: uploadUrlResponse.data.authorizationToken,
          downloadUrlPrefix: downloadUrlPrefix,
        });
      } catch (error) {
        functions.logger.error("Error getting B2 upload URL:", error);
        response.status(500).send({
          error: "Failed to get an upload URL from Backblaze B2.",
        });
      }
    });
  }
);