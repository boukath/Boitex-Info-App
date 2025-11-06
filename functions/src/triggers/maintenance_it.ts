// functions/src/triggers/maintenance_it.ts

import {onDocumentCreated, onDocumentUpdated} from "firebase-functions/v2/firestore";
// ✅ --- ADDED: Import our new service functions ---
import {createActivityLog} from "../services/activity_log_service";
import {
notifyServiceIT,
createNotificationsForRoles,
} from "../services/notification_service";
// ✅ --- ADDED: Import our new constants ---
import { ROLES_TECH_IT } from "../core/constants";

/**
* Logs when a new IT maintenance task is created.
* Assumes a collection named 'maintenance_it'.
*/
//
// ⭐️ ----- NEW FILE ----- ⭐️
//
export const onMaintenanceTaskCreated_v2 = onDocumentCreated(
"maintenance_it/{taskId}",
async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;
    const data = snapshot.data();

    createActivityLog({ // ✅ USE IMPORTED FUNCTION
      service: "it",
      taskType: "Maintenance IT", // ⭐️ Matches app query
      taskTitle: data.taskName || "Maintenance IT",
      storeName: data.storeName || "",
      storeLocation: data.storeLocation || "",
      displayName: data.createdByName || "Inconnu",
      createdByName: data.createdByName || "Inconnu",
      details: `Nouvelle tâche: ${data.description || "N/A"}`,
      status: data.status || "Nouveau",
      relatedDocId: snapshot.id,
      relatedCollection: "maintenance_it",
    });

    // ✅ --- ADD NOTIFICATION FOR IT TEAM ---
    const title = `Maintenance IT: ${data.taskName || "Nouvelle Tâche"}`;
    const body = data.description || "Une nouvelle tâche de maintenance a été créée.";
    await notifyServiceIT(title, body); // ✅ USE IMPORTED FUNCTION

    // ✅ ADD TO INBOX
    await createNotificationsForRoles(ROLES_TECH_IT, { // ✅ USE IMPORTED FUNCTION & CONSTANT
      title,
      body,
      relatedDocId: snapshot.id,
      relatedCollection: "maintenance_it",
    });
    // ✅ --- END OF NOTIFICATION ---
  }
);

/**
 * Logs when an IT maintenance task's status changes.
 * Assumes a collection named 'maintenance_it'.
 */
//
// ⭐️ ----- NEW FILE ----- ⭐️
//
export const onMaintenanceTaskUpdated_v2 = onDocumentUpdated(
  "maintenance_it/{taskId}",
  async (event) => {
    if (!event.data) return;
    const before = event.data.before.data();
    const after = event.data.after.data();

    if (before.status === after.status) return; // No change

    createActivityLog({ // ✅ USE IMPORTED FUNCTION
      service: "it",
      taskType: "Maintenance IT", // ⭐️ Matches app query
      taskTitle: after.taskName || "Maintenance IT",
      storeName: after.storeName || "",
      storeLocation: after.storeLocation || "",
      displayName: after.createdByName || "Inconnu",
      createdByName: after.createdByName || "Inconnu",
      details: `Statut changé: '${before.status}' -> '${after.status}'`,
      status: after.status,
      relatedDocId: event.data.after.id,
      relatedCollection: "maintenance_it",
    });

    // ✅ --- NEW: ADD INBOX NOTIFICATION FOR STATUS CHANGE ---
    await createNotificationsForRoles(ROLES_TECH_IT, { // ✅ USE IMPORTED FUNCTION & CONSTANT
      title: `Mise à Jour Maintenance: ${after.taskName || "N/A"}`,
      body: `Statut: '${before.status}' -> '${after.status}'`,
      relatedDocId: event.data.after.id,
      relatedCollection: "maintenance_it",
    });
    // ✅ --- END OF NEW LOGIC ---
  }
);