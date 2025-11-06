// functions/src/triggers/installations.ts

import {onDocumentCreated, onDocumentUpdated} from "firebase-functions/v2/firestore";
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
} from "../core/constants";

//
// ⭐️ ----- NEW FILE ----- ⭐️
//
export const onInstallationCreated_v2 = onDocumentCreated(
"installations/{installationId}",
async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      console.log("No data associated with the event");
      return;
    }
    const data = snapshot.data();
    const title = `Nouvelle Installation: ${data.installationCode || "N/A"}`;
    const body = `Client: ${data.clientName} - Magasin: ${data.storeName}`;

    // --- ADDED: Activity Log ---
    createActivityLog({ // ✅ USE IMPORTED FUNCTION
      service: "technique",
      taskType: "Installation",
      taskTitle: data.clientName || "Nouvelle Installation",
      storeName: data.storeName || "",
      storeLocation: data.storeLocation || "",
      displayName: data.createdByName || "Inconnu",
      createdByName: data.createdByName || "Inconnu",
      details: `Créée par ${data.createdByName || "Inconnu"}`,
      status: data.status || "Nouveau",
      relatedDocId: snapshot.id,
      relatedCollection: "installations",
    });
    // --- End of Log ---

    // --- Notification Data ---
    const notificationData = {
      title,
      body,
      relatedDocId: snapshot.id,
      relatedCollection: "installations",
    };

    await notifyManagers(title, body); // ✅ USE IMPORTED FUNCTION
    // ✅ ADD TO INBOX
    await createNotificationsForRoles(ROLES_MANAGERS, notificationData); // ✅ USE IMPORTED FUNCTION & CONSTANT

    await notifyServiceTechnique(title, body); // ✅ USE IMPORTED FUNCTION
    // ✅ ADD TO INBOX
    await createNotificationsForRoles(ROLES_TECH_ST, notificationData); // ✅ USE IMPORTED FUNCTION & CONSTANT
  }
);

//
// ⭐️ ----- NEW FILE ----- ⭐️
//
export const onInstallationStatusUpdate_v2 = onDocumentUpdated(
  "installations/{installationId}",
  async (event) => {
    if (!event.data) return;
    const before = event.data.before.data();
    const after = event.data.after.data();

    if (before.status === after.status) return null; // No change

    // --- ADDED: Activity Log ---
    createActivityLog({ // ✅ USE IMPORTED FUNCTION
      service: "technique",
      taskType: "Installation",
      taskTitle: after.clientName || "Installation",
      storeName: after.storeName || "",
      storeLocation: after.storeLocation || "",
      displayName: after.createdByName || "Inconnu",
      createdByName: after.createdByName || "Inconnu",
      details: `Statut changé: '${before.status}' -> '${after.status}'`,
      status: after.status,
      relatedDocId: event.data.after.id,
      relatedCollection: "installations",
    });
    // --- End of Log ---

    // Also send a notification for the status change
    const title = `Mise à Jour Installation: ${after.installationCode || "N/A"}`;
    const body = `Client: ${after.clientName} - Statut: ${after.status}`;

    // --- Notification Data ---
    const notificationData = {
      title,
      body,
      relatedDocId: event.data.after.id,
      relatedCollection: "installations",
    };

    await notifyManagers(title, body); // ✅ USE IMPORTED FUNCTION
    // ✅ ADD TO INBOX
    await createNotificationsForRoles(ROLES_MANAGERS, notificationData); // ✅ USE IMPORTED FUNCTION & CONSTANT

    await notifyServiceTechnique(title, body); // ✅ USE IMPORTED FUNCTION
    // ✅ ADD TO INBOX
    await createNotificationsForRoles(ROLES_TECH_ST, notificationData); // ✅ USE IMPORTED FUNCTION & CONSTANT

    return null;
  }
);