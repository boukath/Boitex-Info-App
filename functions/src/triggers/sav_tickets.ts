// functions/src/triggers/sav_tickets.ts

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
export const onSavTicketCreated_v2 = onDocumentCreated("sav_tickets/{ticketId}", async (event) => {
const snapshot = event.data;
if (!snapshot) {
    console.log("No data associated with the event");
    return;
  }

  const data = snapshot.data();
  const title = `Nouveau Ticket SAV: ${data.savCode}`;
  const body = `Client: ${data.clientName} - Produit: ${data.productName}`;

  // --- ADDED: Activity Log ---
  createActivityLog({ // ✅ USE IMPORTED FUNCTION
    service: "technique",
    taskType: "SAV",
    taskTitle: data.clientName || "Nouveau Ticket SAV",
    storeName: data.storeName || "",
    storeLocation: data.storeLocation || "",
    displayName: data.createdByName || "Inconnu",
    createdByName: data.createdByName || "Inconnu",
    details: `Créée par ${data.createdByName || "Inconnu"} | Produit: ${data.productName || "N/A"}`,
    status: data.status || "Nouveau",
    relatedDocId: snapshot.id,
    relatedCollection: "sav_tickets",
  });
  // --- End of Log ---

  // --- Notification Data ---
  const notificationData = {
    title,
    body,
    relatedDocId: snapshot.id,
    relatedCollection: "sav_tickets",
  };

  await notifyManagers(title, body); // ✅ USE IMPORTED FUNCTION
  // ✅ ADD TO INBOX
  await createNotificationsForRoles(ROLES_MANAGERS, notificationData); // ✅ USE IMPORTED FUNCTION & CONSTANT

  await notifyServiceTechnique(title, body); // ✅ USE IMPORTED FUNCTION
  // ✅ ADD TO INBOX
  await createNotificationsForRoles(ROLES_TECH_ST, notificationData); // ✅ USE IMPORTED FUNCTION & CONSTANT
});

//
// ⭐️ ----- NEW FILE ----- ⭐️
//
export const onSavTicketUpdate_v2 = onDocumentUpdated(
  "sav_tickets/{ticketId}",
  async (event) => {
    if (!event.data) return;

    const before = event.data.before.data();
    const after = event.data.after.data();

    if (before.status !== after.status) {
      const title = `Mise à Jour SAV: ${after.savCode}`;
      const body = `Nouveau statut: ${after.status}`;

      // --- ADDED: Activity Log ---
      createActivityLog({ // ✅ USE IMPORTED FUNCTION
        service: "technique",
        taskType: "SAV",
        taskTitle: after.clientName || "Ticket SAV",
        storeName: after.storeName || "",
        storeLocation: after.storeLocation || "",
        displayName: after.createdByName || "Inconnu",
        createdByName: after.createdByName || "Inconnu",
        details: `Statut changé: '${before.status}' -> '${after.status}'`,
        status: after.status,
        relatedDocId: event.data.after.id,
        relatedCollection: "sav_tickets",
      });
      // --- End of Log ---

      // --- Notification Data ---
      const notificationData = {
        title,
        body,
        relatedDocId: event.data.after.id,
        relatedCollection: "sav_tickets",
      };

      await notifyManagers(title, body); // ✅ USE IMPORTED FUNCTION
      // ✅ ADD TO INBOX
      await createNotificationsForRoles(ROLES_MANAGERS, notificationData); // ✅ USE IMPORTED FUNCTION & CONSTANT

      if (["En attente de pièce", "Terminé"].includes(after.status)) {
        await notifyServiceTechnique(title, body); // ✅ USE IMPORTED FUNCTION
        // ✅ ADD TO INBOX
        await createNotificationsForRoles(ROLES_TECH_ST, notificationData); // ✅ USE IMPORTED FUNCTION & CONSTANT
      }
    }
  }
);