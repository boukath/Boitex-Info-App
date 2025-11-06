// functions/src/triggers/generic.ts

import {onDocumentUpdated} from "firebase-functions/v2/firestore";
// ✅ --- ADDED: Import our new service functions ---
import {
notifyManagers,
createNotificationsForRoles,
} from "../services/notification_service";
// ✅ --- ADDED: Import our new constants ---
import { ROLES_MANAGERS } from "../core/constants";

//
// ⭐️ ----- NEW FILE ----- ⭐️
//

const collectionsToWatchForUpdates = [
"interventions",
"installations",
"sav_tickets",
];

// ⚠️ --- IMPORTANT NOTE --- ⚠️
// The functions below will cause DUPLICATE notifications for managers.
//
// Why? Because you have already created specific update handlers like:
// - onInterventionStatusUpdate_v2
// - onInstallationStatusUpdate_v2
// - onSavTicketUpdate_v2
//
// Both the specific handler AND this generic handler will run.
//
// ✅ RECOMMENDATION:
// To fix this, you should empty this array:
//
// const collectionsToWatchForUpdates: string[] = [];
//
// I am keeping the original logic for now so we don't break anything,
// but you should remove the items from this list.
// ⚠️ --- END OF NOTE --- ⚠️

collectionsToWatchForUpdates.forEach((collection) => {
  // This syntax dynamically creates and exports functions
  // e.g., oninterventionsUpdated, oninstallationsUpdated
  exports[`on${collection}Updated`] = onDocumentUpdated(
    `${collection}/{docId}`,
    async (event) => {
      if (!event.data) return;

      const after = event.data.after.data();
      const code = after.requisitionCode || after.interventionCode || after.savCode || after.blCode || after.clientName || "N/A";
      const status = after.status || after.requestStatus || "Inconnu";

      const title = `Mise à Jour: ${collection}`;
      const body = `Statut de '${code}' est maintenant '${status}'`;

      await notifyManagers(title, body); // ✅ USE IMPORTED FUNCTION

      // ✅ ADD TO INBOX
      await createNotificationsForRoles(ROLES_MANAGERS, { // ✅ USE IMPORTED FUNCTION & CONSTANT
        title,
        body,
        relatedDocId: event.data.after.id,
        relatedCollection: collection,
      });
    }
  );
});