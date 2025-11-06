// functions/src/triggers/replacement_requests.ts

import {onDocumentCreated, onDocumentUpdated} from "firebase-functions/v2/firestore";
// ✅ --- ADDED: Import our new service functions ---
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
export const onReplacementRequestCreated_v2 = onDocumentCreated("replacement_requests/{requestId}", async (event) => {
const snapshot = event.data;
if (!snapshot) {
    console.log("No data associated with the event");
    return;
  }

  const data = snapshot.data();
  const title = `Nouvelle Demande de Remplacement: ${data.replacementRequestCode}`;
  const body = `Demandé par: ${data.technicianName} pour ${data.clientName}`;

  // --- Notification Data ---
  const notificationData = {
    title,
    body,
    relatedDocId: snapshot.id,
    relatedCollection: "replacement_requests",
  };

  await notifyManagers(title, body); // ✅ USE IMPORTED FUNCTION
  // ✅ ADD TO INBOX
  await createNotificationsForRoles(ROLES_MANAGERS, notificationData); // ✅ USE IMPORTED FUNCTION & CONSTANT
});

//
// ⭐️ ----- NEW FILE ----- ⭐️
//
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

      // --- Notification Data ---
      const notificationData = {
        title,
        body,
        relatedDocId: event.data.after.id,
        relatedCollection: "replacement_requests",
      };

      await notifyServiceTechnique(title, body); // ✅ USE IMPORTED FUNCTION
      // ✅ ADD TO INBOX
      await createNotificationsForRoles(ROLES_TECH_ST, notificationData); // ✅ USE IMPORTED FUNCTION & CONSTANT

      await notifyManagers(title, body); // ✅ USE IMPORTED FUNCTION
      // ✅ ADD TO INBOX
      await createNotificationsForRoles(ROLES_MANAGERS, notificationData); // ✅ USE IMPORTED FUNCTION & CONSTANT


      console.log(`✅ Replacement approval notification sent for ${requestCode}`);
    }

    if (beforeStatus !== afterStatus) {
      const title = "Mise à Jour: Demande de Remplacement";
      const body = `Le statut pour ${after.replacementRequestCode || "N/A"} est maintenant: ${afterStatus}.`;

      await notifyManagers(title, body); // ✅ USE IMPORTED FUNCTION
      // ✅ ADD TO INBOX
      await createNotificationsForRoles(ROLES_MANAGERS, { // ✅ USE IMPORTED FUNCTION & CONSTANT
        title,
        body,
        relatedDocId: event.data.after.id,
        relatedCollection: "replacement_requests",
      });
    }
  }
);