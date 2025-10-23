// functions/src/index.ts

import {onDocumentCreated, onDocumentUpdated} from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";
import {setGlobalOptions} from "firebase-functions/v2";
import * as functions from "firebase-functions";
import B2 from "backblaze-b2";
import cors from "cors";
import {defineSecret} from "firebase-functions/params";
import {onRequest} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";

const backblazeKeyId = defineSecret("BACKBLAZE_KEY_ID");
const backblazeAppKey = defineSecret("BACKBLAZE_APP_KEY");
const backblazeBucketId = defineSecret("BACKBLAZE_BUCKET_ID");

admin.initializeApp();
setGlobalOptions({region: "europe-west1"});

const MANAGERS_TOPIC = "manager_notifications";
const TECH_ST_TOPIC = "technician_st_alerts";

// ✅ NEW TOPIC CONSTANT
const GLOBAL_ANNOUNCEMENTS_TOPIC = "GLOBAL_ANNOUNCEMENTS";

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

// ✅ Notification for new requisition creation
export const onRequisitionCreated_v2 = onDocumentCreated(
  "requisitions/{requisitionId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      console.log("No data associated with the event");
      return;
    }

    const data = snapshot.data();
    const requisitionCode = data.requisitionCode || "N/A";
    const requestedBy = data.requestedBy || "Inconnu";
    const itemCount = (data.items as Array<Record<string, unknown>>)?.length || 0;

    const title = `Nouvelle Demande d'Achat: ${requisitionCode}`;
    const body = `Demandée par: ${requestedBy} - ${itemCount} article(s)`;

    const targetRoles = [
      "PDG",
      "Admin",
      "Responsable_Administratif",
      "Responsable_Commercial",
      "Responsable_Technique",
      "Responsable_IT",
      "Chef_de_Projet",
    ];

    const sendPromises = targetRoles.map(async (topic) => {
      const message = {
        notification: { title, body },
        topic: topic,
      };

      try {
        await admin.messaging().send(message);
        console.log(`✅ Sent requisition notification to: ${topic}`);
      } catch (error) {
        console.error(`❌ Error sending to ${topic}:`, error);
      }
    });

    await Promise.all(sendPromises);
  }
);

export const onRequisitionStatusUpdate_v2 = onDocumentUpdated(
  "requisitions/{requisitionId}",
  async (event) => {
    if (!event.data) return;

    const before = event.data.before.data();
    const after = event.data.after.data();

    if (before.status === after.status) return;

    const requisitionCode = after.requisitionCode || "N/A";
    const newStatus = after.status || "Inconnu";
    const requestedBy = after.requestedBy || "Inconnu";

    const title = `Mise à Jour: ${requisitionCode}`;
    const body = `Statut: ${newStatus} - Demandé par: ${requestedBy}`;

    await notifyManagers(title, body);
    console.log(`✅ Requisition status update notification sent for ${requisitionCode}`);
  }
);

// ✅ Notification for new project creation
export const onProjectCreated_v2 = onDocumentCreated(
  "projects/{projectId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      console.log("No data associated with the event");
      return;
    }

    const data = snapshot.data();
    const clientName = data.clientName || "N/A";
    const projectName = data.projectName || "Nouveau Projet";
    const startDate = data.startDate ? new Date(data.startDate.toDate()).toLocaleDateString("fr-FR") : "N/A";

    const title = `Nouveau Projet: ${projectName}`;
    const body = `Client: ${clientName} - Début: ${startDate}`;

    const targetRoles = [
      "PDG",
      "Admin",
      "Responsable_Administratif",
      "Responsable_Commercial",
      "Responsable_Technique",
      "Responsable_IT",
      "Chef_de_Projet",
    ];

    const sendPromises = targetRoles.map(async (topic) => {
      const message = {
        notification: { title, body },
        topic: topic,
      };

      try {
        await admin.messaging().send(message);
        console.log(`✅ Sent project notification to: ${topic}`);
      } catch (error) {
        console.error(`❌ Error sending to ${topic}:`, error);
      }
    });

    await Promise.all(sendPromises);
    console.log(`✅ Project creation notification sent for: ${projectName}`);
  }
);

// ✅ Notification when project status changes
export const onProjectStatusUpdate_v2 = onDocumentUpdated(
  "projects/{projectId}",
  async (event) => {
    if (!event.data) return;

    const before = event.data.before.data();
    const after = event.data.after.data();

    if (before.status === after.status) return;

    const projectName = after.projectName || "N/A";
    const clientName = after.clientName || "N/A";
    const newStatus = after.status || "Inconnu";

    const title = `Mise à Jour Projet: ${projectName}`;
    const body = `Client: ${clientName} - Statut: ${newStatus}`;

    await notifyManagers(title, body);
    console.log(`✅ Project status update notification sent for ${projectName}`);
  }
);

// ✅ NEW: Notification for new livraison creation
export const onLivraisonCreated_v2 = onDocumentCreated(
  "livraisons/{livraisonId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      console.log("No data associated with the event");
      return;
    }

    const data = snapshot.data();
    const bonLivraisonCode = data.bonLivraisonCode || "N/A";
    const clientName = data.clientName || "N/A";
    const serviceType = data.serviceType || "N/A";
    const deliveryMethod = data.deliveryMethod || "N/A";

    const title = `Nouvelle Livraison: ${bonLivraisonCode}`;
    const body = `Client: ${clientName} | Service: ${serviceType} | Méthode: ${deliveryMethod}`;

    // Send to all management roles + technicians
    const targetRoles = [
      "PDG",
      "Admin",
      "Responsable_Administratif",
      "Responsable_Commercial",
      "Responsable_Technique",
      "Responsable_IT",
      "Chef_de_Projet",
      "Technicien_ST", // ✅ Technicians need to know about deliveries
      "Technicien_IT",
    ];

    const sendPromises = targetRoles.map(async (topic) => {
      const message = {
        notification: { title, body },
        topic: topic,
      };

      try {
        await admin.messaging().send(message);
        console.log(`✅ Sent livraison notification to: ${topic}`);
      } catch (error) {
        console.error(`❌ Error sending to ${topic}:`, error);
      }
    });

    await Promise.all(sendPromises);
    console.log(`✅ Livraison creation notification sent for: ${bonLivraisonCode}`);
  }
);

// ✅ NEW: Notification when livraison status changes
export const onLivraisonStatusUpdate_v2 = onDocumentUpdated(
  "livraisons/{livraisonId}",
  async (event) => {
    if (!event.data) return;

    const before = event.data.before.data();
    const after = event.data.after.data();

    // Only notify if status actually changed
    if (before.status === after.status) return;

    const bonLivraisonCode = after.bonLivraisonCode || "N/A";
    const clientName = after.clientName || "N/A";
    const newStatus = after.status || "Inconnu";

    const title = `Mise à Jour Livraison: ${bonLivraisonCode}`;
    const body = `Client: ${clientName} - Statut: ${newStatus}`;

    // Notify managers and relevant technicians
    await notifyManagers(title, body);
    await notifyServiceTechnique(title, body);

    console.log(`✅ Livraison status update notification sent for ${bonLivraisonCode}`);
  }
);

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

// ✅
// ✅ NEWLY ADDED FUNCTION
// ✅
/**
 * Sends a notification to ALL users when a new message
 * is posted in any announcement channel.
 */
export const onNewAnnouncementMessage = onDocumentCreated(
  // This path listens to the "messages" subcollection of ANY doc in "channels"
  "channels/{channelId}/messages/{messageId}",
  async (event): Promise<void> => {
    // Get the data for the new message that was just created
    const message = event.data?.data();
    const params = event.params; // Contains wildcards like {channelId}

    if (!message) {
      functions.logger.log("No message data found, exiting function.");
      return;
    }

    // 1. Get message details
    const messageText: string = message.text || "Nouveau message";
    const senderName: string = message.senderName || "Boitex Info";

    // 2. Get the channel name from the parent channel document
    let channelName = "Annonces"; // A sensible default
    try {
      // Go up one level to get the channel's main document
      const channelDoc = await admin.firestore()
        .collection("channels")
        .doc(params.channelId) // Use the wildcard value from the path
        .get();

      if (channelDoc.exists) {
        channelName = channelDoc.data()?.name || channelName;
      }
    } catch (error) {
      functions.logger.error(
        `Error fetching channel name for id ${params.channelId}:`,
        error
      );
    }

    // 3. Construct the notification payload
    // Truncate the message body if it's too long for a notification
    const bodyText = messageText.length > 100 ?
      `${messageText.substring(0, 97)}...` :
      messageText;

    const payload = {
      notification: {
        title: `Nouveau message dans #${channelName}`,
        body: `${senderName}: ${bodyText}`,
      },
      // Send to the global topic that all users are subscribed to
      topic: GLOBAL_ANNOUNCEMENTS_TOPIC,
    };

    // 4. Send the notification
    try {
      await admin.messaging().send(payload);
      functions.logger.log(
        `✅ Sent announcement notification for channel: #${channelName}`
      );
    } catch (error) {
      functions.logger.error("❌ Error sending announcement notification:", error);
    }
  });
// ✅
// ✅ END OF NEW FUNCTION
// ✅

const collectionsToWatchForUpdates = [
  "interventions",
  "installations",
  "sav_tickets",
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

const corsHandler = cors({origin: true});

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

export const checkAndSendReminders = onSchedule("every 5 minutes", async (event) => {
  const now = admin.firestore.Timestamp.now();
  const db = admin.firestore();
  const messaging = admin.messaging();

  const query = db.collection("reminders")
    .where("status", "==", "pending")
    .where("dueAt", "<=", now);

  const remindersSnapshot = await query.get();

  if (remindersSnapshot.empty) {
    functions.logger.info("No pending reminders found.");
    return;
  }

  const promises: Promise<unknown>[] = [];

  for (const doc of remindersSnapshot.docs) {
    const reminder = doc.data();
    const title = reminder.title;
    const targetRoles = reminder.targetRoles as string[];

    if (!title || !targetRoles || targetRoles.length === 0) {
      functions.logger.warn("Skipping malformed reminder:", doc.id);
      promises.push(doc.ref.update({ status: "error_malformed" }));
      continue;
    }

    functions.logger.info(`Processing reminder: ${title}, for roles: ${targetRoles.join(", ")}`);

    const sendPromises = targetRoles.map(async (topic) => {
      try {
        functions.logger.info(`Sending to topic: ${topic}`);
        const message = {
          notification: {
            title: "🔔 Rappel",
            body: title,
          },
          topic: topic,
        };

        await messaging.send(message);
        functions.logger.info(`✅ Successfully sent to topic: ${topic}`);
      } catch (error) {
        functions.logger.error(`❌ Error sending to topic ${topic}:`, error);
      }
    });

    await Promise.all(sendPromises);

    promises.push(doc.ref.update({
      status: "sent",
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
    }));
  }

  await Promise.all(promises);
  functions.logger.info(`Processed ${remindersSnapshot.size} reminders.`);
});