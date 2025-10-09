// functions/src/index.ts
import {onDocumentCreated, onDocumentUpdated} from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";
import {setGlobalOptions} from "firebase-functions/v2";

// Initialize Firebase Admin SDK
admin.initializeApp();

// Set the region for all functions
setGlobalOptions({region: "europe-west1"});

// Define the names of our notification topics
const MANAGERS_TOPIC = "manager_notifications";
const TECH_ST_TOPIC = "technician_st_alerts";
const TECH_IT_TOPIC = "technician_it_alerts";

// Helper function to send notifications to managers
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

// Helper function to send notifications to Service Technique
const notifyServiceTechnique = async (title: string, body: string) => {
  const message = {
    notification: {title, body},
    topic: TECH_ST_TOPIC,
  };
  try {
    await admin.messaging().send(message);
    console.log(`✅ Sent Service Technique notification: ${title}`);
  } catch (error) {
    console.error("❌ Error sending Service Technique notification:", error);
  }
};

// --- GENERIC FUNCTION FOR NEW TASKS ---
const collectionsToWatchForCreation = [
  "interventions",
  "installations",
  "livraisons",
];

collectionsToWatchForCreation.forEach((collection) => {
  exports[`on${collection}Created`] = onDocumentCreated(
    `${collection}/{docId}`,
    async (event) => {
      const snapshot = event.data;
      if (!snapshot) return;

      const data = snapshot.data();

      // Determine the correct topic based on serviceType
      const serviceType = data.serviceType;
      let targetTopic = "";

      if (serviceType === "Service Technique") {
        targetTopic = TECH_ST_TOPIC;
      } else if (serviceType === "Service IT") {
        targetTopic = TECH_IT_TOPIC;
      }

      // Get details
      const code = data.interventionCode || data.blCode || "N/A";
      const client = data.clientName || "N/A";
      const storeName = data.storeName || "N/A";
      const storeLocation = data.storeLocation || data.destinationName || "";

      // Choose emoji based on collection type
      let emoji = "📋";
      if (collection === "interventions") emoji = "🔧";
      if (collection === "installations") emoji = "⚙️";
      if (collection === "livraisons") emoji = "📦";

      // Build location string
      let locationInfo = "";
      if (storeName !== "N/A") {
        if (storeLocation) {
          locationInfo = ` | ${storeName} (${storeLocation})`;
        } else {
          locationInfo = ` | ${storeName}`;
        }
      }

      const title = `${emoji} Nouveau Ticket: ${collection.slice(0, -1)}`;
      const body = `${code} | ${client}${locationInfo}`;

      // Send to the relevant technician group
      if (targetTopic) {
        const message = {
          notification: {title, body},
          data: {
            docId: snapshot.id,
            collection: collection,
            type: "new_task",
          },
          topic: targetTopic,
        };

        try {
          await admin.messaging().send(message);
          console.log(`Sent notification to ${targetTopic}`);
        } catch (error) {
          console.error(`Error sending to ${targetTopic}:`, error);
        }
      }

      // Also notify managers
      await notifyManagers(title, body);
    }
  );
});

// --- SAV TICKETS ---
exports.onsav_ticketsCreated = onDocumentCreated(
  "sav_tickets/{docId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const data = snapshot.data();
    const savCode = data.savCode || "N/A";
    const clientName = data.clientName || "Client";
    const storeName = data.storeName || "";

    // Extract store name and location from storeName field
    let storeInfo = "";
    if (storeName) {
      storeInfo = ` | ${storeName}`;
    }

    const title = "🛠️ Nouveau Ticket SAV";
    const body = `${savCode} | ${clientName}${storeInfo}`;

    // Send to Service Technique
    await notifyServiceTechnique(title, body);

    // Also notify managers
    await notifyManagers(title, body);

    console.log(`✅ SAV notification sent for ${savCode}`);
  }
);

// --- SPECIFIC FUNCTION FOR MISSION ASSIGNMENTS ---
exports.onMissionUpdated = onDocumentUpdated("missions/{missionId}", async (event) => {
  if (!event.data) return;

  const before = event.data.before.data();
  const after = event.data.after.data();

  // Check if technicians were just assigned
  const beforeTechs = before.assignedTechniciansIds || [];
  const afterTechs = after.assignedTechniciansIds || [];

  if (beforeTechs.length === 0 && afterTechs.length > 0) {
    const title = "🎯 Nouvelle Mission Assignée";
    const body = `La mission "${after.title}" vous a été assignée.`;

    // Get the FCM tokens for all assigned technicians
    const usersSnapshot = await admin.firestore().collection("users")
      .where(admin.firestore.FieldPath.documentId(), "in", afterTechs).get();

    const tokens: string[] = [];
    usersSnapshot.forEach((doc) => {
      const token = doc.data().fcmToken;
      if (token) {
        tokens.push(token);
      }
    });

    // Send direct message to each token
    if (tokens.length > 0) {
      const messages = tokens.map((token) => ({
        notification: {title, body},
        data: {
          missionId: event.params.missionId,
          type: "mission_assigned",
        },
        token: token,
      }));

      try {
        const response = await admin.messaging().sendEach(messages);
        console.log(`Sent direct mission notification. Success: ${response.successCount}, Failure: ${response.failureCount}`);
      } catch (error) {
        console.error("Error sending direct message:", error);
      }
    }

    // Also notify managers of the update
    await notifyManagers(`Mission Mise à Jour: ${after.title}`, `Le statut est maintenant: ${after.status}`);
  }
});

// --- REPLACEMENT REQUESTS ---
exports.onreplacementRequestsUpdated = onDocumentUpdated(
  "replacementRequests/{requestId}",
  async (event) => {
    if (!event.data) return;

    const before = event.data.before.data();
    const after = event.data.after.data();

    const beforeStatus = before.requestStatus || "";
    const afterStatus = after.requestStatus || "";

    // Only notify when status changes to approved
    if (
      beforeStatus !== afterStatus &&
      (afterStatus === "Approuvé - Produit en stock" || afterStatus === "Approuvé - En attente de commande")
    ) {
      const requestCode = after.replacementRequestCode || "N/A";
      const productName = after.productName || "Produit";
      const clientName = after.clientName || "Client";

      const title = "✅ Remplacement Approuvé";
      const body = `${requestCode} | ${clientName} | Produit: ${productName}`;

      // Send to Service Technique
      await notifyServiceTechnique(title, body);

      // Also notify managers
      await notifyManagers(title, body);

      console.log(`✅ Replacement approval notification sent for ${requestCode}`);
    }

    // Keep existing manager notifications for all other updates
    if (beforeStatus !== afterStatus) {
      await notifyManagers(
        "Mise à Jour: Demande de Remplacement",
        `Le statut pour ${after.replacementRequestCode || "N/A"} est maintenant: ${afterStatus}.`
      );
    }
  }
);

// --- GENERIC FUNCTION TO NOTIFY MANAGERS OF ANY UPDATE ---
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
      const code = after.interventionCode || after.savCode || after.blCode || after.clientName || "N/A";
      const status = after.status || after.requestStatus || "Inconnu";

      // Notify managers about the status change
      await notifyManagers(
        `Mise à Jour: ${collection.slice(0, -1)}`,
        `Le statut pour ${code} est maintenant: ${status}.`
      );
    }
  );
});
