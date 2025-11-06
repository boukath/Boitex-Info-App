// functions/src/triggers/support_tickets_it.ts

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
* Logs when a new IT support ticket is created.
* Assumes a collection named 'support_tickets'.
*/
//
// ⭐️ ----- NEW FILE ----- ⭐️
//
export const onSupportTicketCreated_v2 = onDocumentCreated(
"support_tickets/{ticketId}",
async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;
    const data = snapshot.data();

    createActivityLog({ // ✅ USE IMPORTED FUNCTION
      service: "it",
      taskType: "Support IT", // ⭐️ Matches app query
      taskTitle: data.clientName || "Support IT",
      storeName: data.storeName || "",
      storeLocation: data.storeLocation || "",
      displayName: data.createdByName || "Inconnu",
      createdByName: data.createdByName || "Inconnu",
      details: `Nouveau ticket: ${data.subject || "N/A"}`,
      status: data.status || "Nouveau",
      relatedDocId: snapshot.id,
      relatedCollection: "support_tickets",
    });

    // ✅ --- ADD NOTIFICATION FOR IT TEAM ---
    const title = `Nouveau Ticket Support: ${data.clientName || ""}`;
    const body = data.subject || "Nouveau ticket de support IT";
    await notifyServiceIT(title, body); // ✅ USE IMPORTED FUNCTION

    // ✅ ADD TO INBOX
    await createNotificationsForRoles(ROLES_TECH_IT, { // ✅ USE IMPORTED FUNCTION & CONSTANT
      title,
      body,
      relatedDocId: snapshot.id,
      relatedCollection: "support_tickets",
    });
    // ✅ --- END OF NOTIFICATION ---
  }
);

/**
 * Logs when an IT support ticket's status changes.
 * Assumes a collection named 'support_tickets'.
 */
//
// ⭐️ ----- NEW FILE ----- ⭐️
//
export const onSupportTicketUpdated_v2 = onDocumentUpdated(
  "support_tickets/{ticketId}",
  async (event) => {
    if (!event.data) return;
    const before = event.data.before.data();
    const after = event.data.after.data();

    if (before.status === after.status) return; // No change

    createActivityLog({ // ✅ USE IMPORTED FUNCTION
      service: "it",
      taskType: "Support IT", // ⭐️ Matches app query
      taskTitle: after.clientName || "Support IT",
      storeName: after.storeName || "",
      storeLocation: after.storeLocation || "",
      displayName: after.createdByName || "Inconnu",
      createdByName: after.createdByName || "Inconnu",
      details: `Statut changé: '${before.status}' -> '${after.status}'`,
      status: after.status,
      relatedDocId: event.data.after.id,
      relatedCollection: "support_tickets",
    });

    // ✅ --- NEW: ADD INBOX NOTIFICATION FOR STATUS CHANGE ---
    await createNotificationsForRoles(ROLES_TECH_IT, { // ✅ USE IMPORTED FUNCTION & CONSTANT
      title: `Mise à Jour Support: ${after.clientName || "N/A"}`,
      body: `Statut: '${before.status}' -> '${after.status}'`,
      relatedDocId: event.data.after.id,
      relatedCollection: "support_tickets",
    });
    // ✅ --- END OF NEW LOGIC ---
  }
);