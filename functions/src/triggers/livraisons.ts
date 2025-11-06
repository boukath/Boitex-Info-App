// functions/src/triggers/livraisons.ts

import {onDocumentCreated, onDocumentUpdated} from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin"; // ✅ We need this for admin.messaging()
// ✅ --- ADDED: Import our new service functions ---
import {createActivityLog} from "../services/activity_log_service";
import {
notifyManagers,
notifyServiceTechnique,
createNotificationsForRoles,
} from "../services/notification_service";
// ✅ --- ADDED: Import our new constants ---
import {
ROLES_MANAGERS,
ROLES_TECH_ST,
ROLES_TECH_IT,
TOPICS_MANAGERS_AND_ADMINS, // ✅ USE THE NEW TOPIC LIST
} from "../core/constants";

//
// ⭐️ ----- NEW FILE ----- ⭐️
//
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

    // --- ADDED: Activity Log ---
    createActivityLog({ // ✅ USE IMPORTED FUNCTION
      service: "technique", // Assuming tech service handles this
      taskType: "Livraison",
      taskTitle: data.clientName || "Nouvelle Livraison",
      storeName: data.storeName || "",
      storeLocation: data.storeLocation || "",
      displayName: data.createdByName || "Inconnu",
      createdByName: data.createdByName || "Inconnu",
      details: `Créée par ${data.createdByName || "Inconnu"} | BL: ${bonLivraisonCode}`,
      status: data.status || "Nouveau",
      relatedDocId: snapshot.id,
      relatedCollection: "livraisons",
    });
    // --- End of Log ---

    // ✅ --- FIX: Use the constant list + the two extra topics ---
    const targetTopics = [
      ...TOPICS_MANAGERS_AND_ADMINS,
      "Technicien_ST", // Specific to this function
      "Technicien_IT", // Specific to this function
    ];
    // ✅ --- END FIX ---

    const sendPromises = targetTopics.map(async (topic) => { // ✅ Use targetTopics
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

    // ✅ ADD TO INBOX
    // ✅ --- FIX: Combine all target roles for the inbox ---
    const allTargetRoles = [
      ...ROLES_MANAGERS,
      ...ROLES_TECH_ST,
      ...ROLES_TECH_IT,
    ];
    await createNotificationsForRoles(allTargetRoles, { // ✅ USE IMPORTED FUNCTION & CONSTANTS
      title,
      body,
      relatedDocId: snapshot.id,
      relatedCollection: "livraisons",
    });

    console.log(`✅ Livraison creation notification sent for: ${bonLivraisonCode}`);
  }
);

//
// ⭐️ ----- NEW FILE ----- ⭐️
//
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

    // --- ADDED: Activity Log ---
    createActivityLog({ // ✅ USE IMPORTED FUNCTION
      service: "technique",
      taskType: "Livraison",
      taskTitle: after.clientName || "Livraison",
      storeName: after.storeName || "",
      storeLocation: after.storeLocation || "",
      displayName: after.createdByName || "Inconnu",
      createdByName: after.createdByName || "Inconnu",
      details: `Statut changé: '${before.status}' -> '${after.status}'`,
      status: after.status,
      relatedDocId: event.data.after.id,
      relatedCollection: "livraisons",
    });
    // --- End of Log ---

    // --- Notification Data ---
    const notificationData = {
      title,
      body,
      relatedDocId: event.data.after.id,
      relatedCollection: "livraisons",
    };

    // Notify managers and relevant technicians
    await notifyManagers(title, body); // ✅ USE IMPORTED FUNCTION
    // ✅ ADD TO INBOX
    await createNotificationsForRoles(ROLES_MANAGERS, notificationData); // ✅ USE IMPORTED FUNCTION & CONSTANT

    await notifyServiceTechnique(title, body); // ✅ USE IMPORTED FUNCTION
    // ✅ ADD TO INBOX
    await createNotificationsForRoles(ROLES_TECH_ST, notificationData); // ✅ USE IMPORTED FUNCTION & CONSTANT


    console.log(`✅ Livraison status update notification sent for ${bonLivraisonCode}`);
  }
);