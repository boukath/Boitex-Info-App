// functions/src/triggers/requisitions.ts

import {onDocumentCreated, onDocumentUpdated} from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin"; // ✅ We need this for admin.messaging()
// ✅ --- ADDED: Import our new service functions ---
import {
notifyManagers,
createNotificationsForRoles,
} from "../services/notification_service";
// ✅ --- ADDED: Import our new constants ---
import {
ROLES_MANAGERS,
TOPICS_MANAGERS_AND_ADMINS, // ✅ USE THE NEW TOPIC LIST
} from "../core/constants";

//
// ⭐️ ----- NEW FILE ----- ⭐️
//
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

    // ✅ --- FIX: Use the constant list of topics ---
    const targetTopics = TOPICS_MANAGERS_AND_ADMINS;

    const sendPromises = targetTopics.map(async (topic) => { // ✅ Use targetTopics
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
    // ✅ --- END FIX ---

    // ✅ ADD TO INBOX
    // Use the ROLES_MANAGERS constant which has the correct role names
    await createNotificationsForRoles(ROLES_MANAGERS, { // ✅ USE IMPORTED FUNCTION & CONSTANT
      title,
      body,
      relatedDocId: snapshot.id,
      relatedCollection: "requisitions",
    });
  }
);

//
// ⭐️ ----- NEW FILE ----- ⭐️
//
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

    await notifyManagers(title, body); // ✅ USE IMPORTED FUNCTION
    // ✅ ADD TO INBOX
    await createNotificationsForRoles(ROLES_MANAGERS, { // ✅ USE IMPORTED FUNCTION & CONSTANT
      title,
      body,
      relatedDocId: event.data.after.id,
      relatedCollection: "requisitions",
    });

    console.log(`✅ Requisition status update notification sent for ${requisitionCode}`);
  }
);