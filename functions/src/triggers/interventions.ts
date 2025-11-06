// functions/src/triggers/interventions.ts

import {onDocumentCreated, onDocumentUpdated} from "firebase-functions/v2/firestore";
// ✅ --- ADDED: Import our new service functions ---
import {createActivityLog} from "../services/activity_log_service";
import {
notifyManagers,
notifyServiceIT,
notifyServiceTechnique,
createNotificationsForRoles,
} from "../services/notification_service";
// ✅ --- ADDED: Import our new constants ---
import {
ROLES_MANAGERS,
ROLES_TECH_IT,
ROLES_TECH_ST,
} from "../core/constants";

//
// ⭐️ ----- NEW FILE ----- ⭐️
//
export const onInterventionCreated_v2 = onDocumentCreated("interventions/{interventionId}", async (event) => {
const snapshot = event.data;
if (!snapshot) {
    console.log("No data associated with the event");
    return;
  }

  const data = snapshot.data();
  const title = `Nouvelle Intervention: ${data.interventionCode}`;
  const body = `Client: ${data.clientName} - Magasin: ${data.storeName}`;

  // ✅ --- FIX: Determine service based on intervention data ---
  const logService = data.serviceType === "Service IT" ? "it" : "technique";
  // ✅ --- END FIX ---

  // --- ADDED: Activity Log ---
  createActivityLog({ // ✅ USE IMPORTED FUNCTION
    service: logService,
    taskType: "Intervention",
    taskTitle: data.clientName || "Nouvelle Intervention",
    storeName: data.storeName || "",
    storeLocation: data.storeLocation || "",
    displayName: data.createdByName || "Inconnu",
    createdByName: data.createdByName || "Inconnu",
    details: `Créée par ${data.createdByName || "Inconnu"}`,
    status: data.status || "Nouveau",
    relatedDocId: snapshot.id,
    relatedCollection: "interventions",
  });
  // --- End of Log ---

  // --- Notification Data ---
  const notificationData = {
    title,
    body,
    relatedDocId: snapshot.id,
    relatedCollection: "interventions",
  };

  // Notify managers
  await notifyManagers(title, body); // ✅ USE IMPORTED FUNCTION
  // ✅ ADD TO INBOX
  await createNotificationsForRoles(ROLES_MANAGERS, notificationData); // ✅ USE IMPORTED FUNCTION & CONSTANT

  // ✅ --- MODIFIED LOGIC ---
  // Only notify the correct service based on the intervention's serviceType
  if (data.serviceType === "Service IT") {
    await notifyServiceIT(title, body); // ✅ USE IMPORTED FUNCTION
    // ✅ ADD TO INBOX
    await createNotificationsForRoles(ROLES_TECH_IT, notificationData); // ✅ USE IMPORTED FUNCTION & CONSTANT
  } else {
    // Default to Service Technique if not specified or is "Service Technique"
    await notifyServiceTechnique(title, body); // ✅ USE IMPORTED FUNCTION
    // ✅ ADD TO INBOX
    await createNotificationsForRoles(ROLES_TECH_ST, notificationData); // ✅ USE IMPORTED FUNCTION & CONSTANT
  }
  // ✅ --- END OF MODIFIED LOGIC ---
});

//
// ⭐️ ----- NEW FILE ----- ⭐️
//
export const onInterventionStatusUpdate_v2 = onDocumentUpdated("interventions/{interventionId}", async (event) => {
  if (!event.data) return;
  const before = event.data.before.data();
  const after = event.data.after.data();

  if (before.status === after.status) return null; // No change

  // ✅ --- FIX: Determine service based on intervention data ---
  const logService = after.serviceType === "Service IT" ? "it" : "technique";
  // ✅ --- END FIX ---

  // --- ADDED: Activity Log ---
  createActivityLog({ // ✅ USE IMPORTED FUNCTION
    service: logService,
    taskType: "Intervention",
    taskTitle: after.clientName || "Intervention",
    storeName: after.storeName || "",
    storeLocation: after.storeLocation || "",
    displayName: after.createdByName || "Inconnu",
    createdByName: after.createdByName || "Inconnu",
    details: `Statut changé: '${before.status}' -> '${after.status}'`,
    status: after.status,
    relatedDocId: event.data.after.id,
    relatedCollection: "interventions",
  });
  // --- End of Log ---

  // ✅ --- NEW: ADD INBOX NOTIFICATION FOR STATUS CHANGE ---
  // (Note: No push notification is sent here, only inbox)
  const title = `Mise à Jour Intervention: ${after.interventionCode || "N/A"}`;
  const body = `Statut: '${before.status}' -> '${after.status}'`;
  const notificationData = {
    title,
    body,
    relatedDocId: event.data.after.id,
    relatedCollection: "interventions",
  };

  // Notify roles that can see this intervention
  await createNotificationsForRoles(ROLES_MANAGERS, notificationData); // ✅ USE IMPORTED FUNCTION & CONSTANT
  if (logService === "it") {
    await createNotificationsForRoles(ROLES_TECH_IT, notificationData); // ✅ USE IMPORTED FUNCTION & CONSTANT
  } else {
    await createNotificationsForRoles(ROLES_TECH_ST, notificationData); // ✅ USE IMPORTED FUNCTION & CONSTANT
  }
  // ✅ --- END OF NEW LOGIC ---

  return null;
});