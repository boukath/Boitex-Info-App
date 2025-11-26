// functions/src/index.ts

import {onDocumentCreated, onDocumentUpdated} from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";
import {setGlobalOptions} from "firebase-functions/v2";
import * as functions from "firebase-functions";
import B2 from "backblaze-b2";
import cors from "cors";
import axios from "axios"; // ✅ ADDED
import {defineSecret} from "firebase-functions/params";
import {onRequest, onCall, HttpsError} from "firebase-functions/v2/https"; // ✅ MODIFIED
import {onSchedule} from "firebase-functions/v2/scheduler";

import {
onInterventionAnalytics,
onInstallationAnalytics,
onLivraisonAnalytics,
onMissionAnalytics,
onSavAnalytics,
onStockHistoryAnalytics,
onProductAnalytics,
onProductStockChanged
} from "./analytics-updater";

export {
onInterventionAnalytics,
onInstallationAnalytics,
onLivraisonAnalytics,
onMissionAnalytics,
onSavAnalytics,
onStockHistoryAnalytics,
onProductAnalytics,
onProductStockChanged
};

export { onInstallationTermine, getInstallationPdf } from "./installation-handlers";
export { createLivraisonFromInstallation } from "./installation-delivery-handler";
export { onInterventionTermine } from "./intervention-handlers";
export { onSavTicketCreated } from "./sav-handlers";
export { onSavTicketReturned } from "./sav-return-handlers";
export { downloadSavPdf } from "./callable-handlers";
export * from "./callable-handlers";
const backblazeKeyId = defineSecret("BACKBLAZE_KEY_ID");
const backblazeAppKey = defineSecret("BACKBLAZE_APP_KEY");
const backblazeBucketId = defineSecret("BACKBLAZE_BUCKET_ID");
const groqApiKey = defineSecret("GROQ_API_KEY"); // ✅ ADDED

admin.initializeApp();
setGlobalOptions({region: "europe-west1"});

const MANAGERS_TOPIC = "manager_notifications";
const TECH_ST_TOPIC = "technician_st_alerts";
const TECH_IT_TOPIC = "technician_it_alerts"; // ✅ --- ADDED ---

// ✅ NEW TOPIC CONSTANT
const GLOBAL_ANNOUNCEMENTS_TOPIC = "GLOBAL_ANNOUNCEMENTS";

// ------------------------------------------------------------------
// START: NEW NOTIFICATION INBOX CONSTANTS
// ------------------------------------------------------------------

// --- Role Lists (from user_roles.dart) ---
// Used to find users for the notification inbox
const ROLES_MANAGERS = [
  "Admin",
  "PDG",
  "Responsable Administratif",
  "Responsable Commercial",
  "Responsable Technique",
  "Responsable IT",
  "Chef de Projet",
];
const ROLES_TECH_ST = ["Technicien ST"];
const ROLES_TECH_IT = ["Technicien IT"];

// ------------------------------------------------------------------
// END: NEW NOTIFICATION INBOX CONSTANTS
// ------------------------------------------------------------------

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

const notifyServiceTechnique = async (title: string, body: string) => {
  const message = {
    notification: {title, body},
    topic: TECH_ST_TOPIC,
  };

  try {
    await admin.messaging().send(message);
    console.log(`✅ Sent Service Technique notification: ${title}`);
  } catch (error) {
    console.error("❌ Error sending ST notification:", error);
  }
};

// ✅ --- ADDED FUNCTION ---
const notifyServiceIT = async (title: string, body: string) => {
  const message = {
    notification: {title, body},
    topic: TECH_IT_TOPIC,
  };

  try {
    await admin.messaging().send(message);
    console.log(`✅ Sent Service IT notification: ${title}`);
  } catch (error) {
    console.error("❌ Error sending SIT notification:", error);
  }
};
// ✅ --- END OF ADDED FUNCTION ---

// ------------------------------------------------------------------
// START: DAILY ACTIVITY FEED (JOURNAL DE BORD) HELPER
// ------------------------------------------------------------------

/**
 * Creates a new log entry in the 'activity_log' collection.
 */
const createActivityLog = (data: { [key: string]: any }) => {
  // We don't await this, let it run in the background
  admin.firestore().collection("activity_log").add({
    ...data,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  }).then(() => {
    console.log(`✅ Activity log created: ${data.taskType} - ${data.details}`);
  }).catch((err) => {
    console.error("❌ Error creating activity log:", err);
  });
};

// ------------------------------------------------------------------
// END: DAILY ACTIVITY FEED (JOURNAL DE BORD) HELPER
// ------------------------------------------------------------------

// ------------------------------------------------------------------
// START: NEW NOTIFICATION INBOX HELPERS
// ------------------------------------------------------------------

/**
 * Creates a new notification document in the 'user_notifications' collection.
 */
const createUserNotification = (data: {
  userId: string;
  title: string;
  body: string;
  isRead?: boolean;
  relatedDocId?: string;
  relatedCollection?: string;
}) => {
  // We don't await this, let it run in the background
  admin.firestore().collection("user_notifications").add({
    ...data,
    isRead: data.isRead || false,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  }).then(() => {
    console.log(`✅ User notification created for: ${data.userId}`);
  }).catch((err) => {
    console.error("❌ Error creating user notification:", err);
  });
};

/**
 * Fetches all user UIDs that match a list of roles.
 * Roles must match the 'role' field in the 'users' collection (e.g., "Responsable Administratif")
 */
const getUidsForRoles = async (roles: string[]): Promise<string[]> => {
  if (roles.length === 0) {
    return [];
  }

  const uids: string[] = [];
  try {
    // Query users collection where 'role' is in the provided list
    const usersSnapshot = await admin.firestore()
      .collection("users")
      .where("role", "in", roles)
      .get();

    if (!usersSnapshot.empty) {
      for (const doc of usersSnapshot.docs) {
        uids.push(doc.id); // doc.id is the user UID
      }
    }
    return uids;
  } catch (error) {
    console.error("❌ Error fetching UIDs for roles:", error);
    return [];
  }
};

/**
 * Fetches UIDs for given roles and creates a notification
 * document for each user.
 */
const createNotificationsForRoles = async (
  roles: string[],
  notificationData: {
    title: string;
    body: string;
    relatedDocId?: string;
    relatedCollection?: string;
  }
) => {
  const uids = await getUidsForRoles(roles);
  if (uids.length === 0) {
    console.log("No users found for roles, no inbox notifications created.");
    return;
  }

  const {title, body, relatedDocId, relatedCollection} = notificationData;

  // Create a notification for each user
  const promises = uids.map((uid) => {
    return createUserNotification({
      userId: uid,
      title,
      body,
      relatedDocId,
      relatedCollection,
    });
  });

  await Promise.all(promises);
  console.log(`✅ Created ${uids.length} inbox notifications.`);
};

/**
 * Fetches all user UIDs.
 */
const getUidsForAllUsers = async (): Promise<string[]> => {
  const uids: string[] = [];
  try {
    const usersSnapshot = await admin.firestore().collection("users").get();
    if (!usersSnapshot.empty) {
      for (const doc of usersSnapshot.docs) {
        uids.push(doc.id); // doc.id is the user UID
      }
    }
    return uids;
  } catch (error) {
    console.error("❌ Error fetching all UIDs:", error);
    return [];
  }
};

/**
 * Creates a notification document for ALL users.
 */
const createNotificationsForAllUsers = async (
  notificationData: {
    title: string;
    body: string;
    relatedDocId?: string;
    relatedCollection?: string;
  }
) => {
  const uids = await getUidsForAllUsers();
  if (uids.length === 0) {
    console.log("No users found, no global inbox notifications created.");
    return;
  }

  const {title, body, relatedDocId, relatedCollection} = notificationData;

  // Create a notification for each user
  const promises = uids.map((uid) => {
    return createUserNotification({
      userId: uid,
      title,
      body,
      relatedDocId,
      relatedCollection,
    });
  });

  await Promise.all(promises);
  console.log(`✅ Created ${uids.length} inbox notifications for global announcement.`);
};

/**
 * Converts FCM topic names (with underscores) back to
 * Firestore role names (with spaces).
 */
const convertTopicsToRoles = (topics: string[]): string[] => {
  return topics.map((topic) => topic.replace(/_/g, " "));
};

// ------------------------------------------------------------------
// END: NEW NOTIFICATION INBOX HELPERS
// ------------------------------------------------------------------


//
// ⭐️ ----- MODIFIED FUNCTION ----- ⭐️
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
  createActivityLog({
    service: logService,
    taskType: "Intervention",
    taskTitle: data.clientName || "Nouvelle Intervention",
    storeName: data.storeName || "", // ✅ ADDED
    storeLocation: data.storeLocation || "", // ✅ ADDED
    displayName: data.createdByName || "Inconnu", // ✅ FIXED (using createdByName)
    createdByName: data.createdByName || "Inconnu", // ✅ ADDED (for your request)
    details: `Créée par ${data.createdByName || "Inconnu"}`, // ✅ FIXED
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
  await notifyManagers(title, body);
  // ✅ ADD TO INBOX
  await createNotificationsForRoles(ROLES_MANAGERS, notificationData);

  // ✅ --- MODIFIED LOGIC ---
  // Only notify the correct service based on the intervention's serviceType
  if (data.serviceType === "Service IT") {
    await notifyServiceIT(title, body);
    // ✅ ADD TO INBOX
    await createNotificationsForRoles(ROLES_TECH_IT, notificationData);
  } else {
    // Default to Service Technique if not specified or is "Service Technique"
    await notifyServiceTechnique(title, body);
    // ✅ ADD TO INBOX
    await createNotificationsForRoles(ROLES_TECH_ST, notificationData);
  }
  // ✅ --- END OF MODIFIED LOGIC ---
});

//
// ⭐️ ----- MODIFIED FUNCTION ----- ⭐️
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
  createActivityLog({
    service: logService,
    taskType: "Intervention",
    taskTitle: after.clientName || "Intervention",
    storeName: after.storeName || "", // ✅ ADDED
    storeLocation: after.storeLocation || "", // ✅ ADDED
    displayName: after.createdByName || "Inconnu", // ✅ FIXED
    createdByName: after.createdByName || "Inconnu", // ✅ ADDED
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
  await createNotificationsForRoles(ROLES_MANAGERS, notificationData);
  if (logService === "it") {
    await createNotificationsForRoles(ROLES_TECH_IT, notificationData);
  } else {
    await createNotificationsForRoles(ROLES_TECH_ST, notificationData);
  }
  // ✅ --- END OF NEW LOGIC ---

  return null;
});


//
// ⭐️ ----- MODIFIED FUNCTION ----- ⭐️
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
  createActivityLog({
    service: "technique",
    taskType: "SAV",
    taskTitle: data.clientName || "Nouveau Ticket SAV",
    storeName: data.storeName || "", // ✅ ADDED
    storeLocation: data.storeLocation || "", // ✅ ADDED
    displayName: data.createdByName || "Inconnu", // ✅ FIXED
    createdByName: data.createdByName || "Inconnu", // ✅ ADDED
    details: `Créée par ${data.createdByName || "Inconnu"} | Produit: ${data.productName || "N/A"}`, // ✅ FIXED
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

  await notifyManagers(title, body);
  // ✅ ADD TO INBOX
  await createNotificationsForRoles(ROLES_MANAGERS, notificationData);

  await notifyServiceTechnique(title, body);
  // ✅ ADD TO INBOX
  await createNotificationsForRoles(ROLES_TECH_ST, notificationData);
});

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

  await notifyManagers(title, body);
  // ✅ ADD TO INBOX
  await createNotificationsForRoles(ROLES_MANAGERS, notificationData);
});

// ✅ Notification for new requisition creation
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

    // Role list for topics
    const targetRoles = [
      "PDG",
      "Admin",
      "Responsable_Administratif",
      "Responsable_Commercial",
      "Responsable_Technique",
      "Responsable_IT",
      "Chef_de_Projet",
    ];

    const sendPromises = targetRoles.map(async (topic) => {
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

    // ✅ ADD TO INBOX
    // Use the ROLES_MANAGERS constant which has the correct role names
    await createNotificationsForRoles(ROLES_MANAGERS, {
      title,
      body,
      relatedDocId: snapshot.id,
      relatedCollection: "requisitions",
    });
  }
);

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

    await notifyManagers(title, body);
    // ✅ ADD TO INBOX
    await createNotificationsForRoles(ROLES_MANAGERS, {
      title,
      body,
      relatedDocId: event.data.after.id,
      relatedCollection: "requisitions",
    });

    console.log(`✅ Requisition status update notification sent for ${requisitionCode}`);
  }
);

// ✅ Notification for new project creation
export const onProjectCreated_v2 = onDocumentCreated(
  "projects/{projectId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      console.log("No data associated with the event");
      return;
    }

    const data = snapshot.data();
    const clientName = data.clientName || "N/A";
    const projectName = data.projectName || "Nouveau Projet";
    const startDate = data.startDate ? new Date(data.startDate.toDate()).toLocaleDateString("fr-FR") : "N/A";

    const title = `Nouveau Projet: ${projectName}`;
    const body = `Client: ${clientName} - Début: ${startDate}`;

    // Role list for topics
    const targetRoles = [
      "PDG",
      "Admin",
      "Responsable_Administratif",
      "Responsable_Commercial",
      "Responsable_Technique",
      "Responsable_IT",
      "Chef_de_Projet",
    ];

    const sendPromises = targetRoles.map(async (topic) => {
      const message = {
        notification: { title, body },
        topic: topic,
      };

      try {
        await admin.messaging().send(message);
        console.log(`✅ Sent project notification to: ${topic}`);
      } catch (error) {
        console.error(`❌ Error sending to ${topic}:`, error);
      }
    });

    await Promise.all(sendPromises);

    // ✅ ADD TO INBOX
    await createNotificationsForRoles(ROLES_MANAGERS, {
      title,
      body,
      relatedDocId: snapshot.id,
      relatedCollection: "projects",
    });

    console.log(`✅ Project creation notification sent for: ${projectName}`);
  }
);

//
// ⭐️ ----- MODIFIED FUNCTION ----- ⭐️
//
export const onProjectStatusUpdate_v2 = onDocumentUpdated(
  "projects/{projectId}",
  async (event) => {
    if (!event.data) return;

    const before = event.data.before.data();
    const after = event.data.after.data();

    // ✅ --- NEW IT EVALUATION LOGIC ---
    if (!before.it_evaluation && after.it_evaluation) {
      createActivityLog({
        service: "it",
        taskType: "Evaluation IT", // ⭐️ This matches the app's query
        taskTitle: after.clientName || "Évaluation IT",
        storeName: after.storeName || "magasin", // ✅ ADDED
        storeLocation: after.storeLocation || "", // ✅ ADDED
        displayName: after.createdByName || "Inconnu", // ✅ FIXED
        createdByName: after.createdByName || "Inconnu", // ✅ ADDED
        details: `Terminée pour ${after.storeName || "magasin"}`,
        status: after.status, // Current project status
        relatedDocId: event.data.after.id,
        relatedCollection: "projects",
      });

      // ✅ ADD TO INBOX for IT team
      await createNotificationsForRoles(ROLES_TECH_IT, {
        title: "Évaluation IT Terminée",
        body: `Client: ${after.clientName || "N/A"} - Magasin: ${after.storeName || "N/A"}`,
        relatedDocId: event.data.after.id,
        relatedCollection: "projects",
      });
    }
    // ✅ --- END NEW LOGIC ---

    // --- Original Status Change Logic ---
    if (before.status === after.status) {
      // If only IT eval changed, we don't need the status notification
      return;
    }

    const projectName = after.projectName || "N/A";
    const clientName = after.clientName || "N/A";
    const newStatus = after.status || "Inconnu";

    const title = `Mise à Jour Projet: ${projectName}`;
    const body = `Client: ${clientName} - Statut: ${newStatus}`;

    await notifyManagers(title, body);
    // ✅ ADD TO INBOX
    await createNotificationsForRoles(ROLES_MANAGERS, {
      title,
      body,
      relatedDocId: event.data.after.id,
      relatedCollection: "projects",
    });

    console.log(`✅ Project status update notification sent for ${projectName}`);
  }
);
//
// ⭐️ ----- END OF MODIFIED FUNCTION ----- ⭐️
//


//
// ⭐️ ----- MODIFIED FUNCTION ----- ⭐️
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
    createActivityLog({
      service: "technique",
      taskType: "Installation",
      taskTitle: data.clientName || "Nouvelle Installation",
      storeName: data.storeName || "", // ✅ ADDED
      storeLocation: data.storeLocation || "", // ✅ ADDED
      displayName: data.createdByName || "Inconnu", // ✅ FIXED
      createdByName: data.createdByName || "Inconnu", // ✅ ADDED
      details: `Créée par ${data.createdByName || "Inconnu"}`, // ✅ FIXED
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

    await notifyManagers(title, body);
    // ✅ ADD TO INBOX
    await createNotificationsForRoles(ROLES_MANAGERS, notificationData);

    await notifyServiceTechnique(title, body);
    // ✅ ADD TO INBOX
    await createNotificationsForRoles(ROLES_TECH_ST, notificationData);
  }
);

//
// ⭐️ ----- MODIFIED FUNCTION ----- ⭐️
//
export const onInstallationStatusUpdate_v2 = onDocumentUpdated(
  "installations/{installationId}",
  async (event) => {
    if (!event.data) return;
    const before = event.data.before.data();
    const after = event.data.after.data();

    if (before.status === after.status) return null; // No change

    // --- ADDED: Activity Log ---
    createActivityLog({
      service: "technique",
      taskType: "Installation",
      taskTitle: after.clientName || "Installation",
      storeName: after.storeName || "", // ✅ ADDED
      storeLocation: after.storeLocation || "", // ✅ ADDED
      displayName: after.createdByName || "Inconnu", // ✅ FIXED
      createdByName: after.createdByName || "Inconnu", // ✅ ADDED
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

    await notifyManagers(title, body);
    // ✅ ADD TO INBOX
    await createNotificationsForRoles(ROLES_MANAGERS, notificationData);

    await notifyServiceTechnique(title, body);
    // ✅ ADD TO INBOX
    await createNotificationsForRoles(ROLES_TECH_ST, notificationData);

    return null;
  }
);


//
// ⭐️ ----- MODIFIED FUNCTION ----- ⭐️
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
    createActivityLog({
      service: "technique", // Assuming tech service handles this
      taskType: "Livraison",
      taskTitle: data.clientName || "Nouvelle Livraison",
      storeName: data.storeName || "", // ✅ ADDED
      storeLocation: data.storeLocation || "", // ✅ ADDED
      displayName: data.createdByName || "Inconnu", // ✅ FIXED
      createdByName: data.createdByName || "Inconnu", // ✅ ADDED
      details: `Créée par ${data.createdByName || "Inconnu"} | BL: ${bonLivraisonCode}`, // ✅ FIXED
      status: data.status || "Nouveau",
      relatedDocId: snapshot.id,
      relatedCollection: "livraisons",
    });
    // --- End of Log ---

    // Send to all management roles + technicians (topics)
    const targetRoles = [
      "PDG",
      "Admin",
      "Responsable_Administratif",
      "Responsable_Commercial",
      "Responsable_Technique",
      "Responsable_IT",
      "Chef_de_Projet",
      "Technicien_ST", // ✅ Technicians need to know about deliveries
      "Technicien_IT",
    ];

    const sendPromises = targetRoles.map(async (topic) => {
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
    // Combine all target roles for the inbox
    const allTargetRoles = [
      ...ROLES_MANAGERS,
      ...ROLES_TECH_ST,
      ...ROLES_TECH_IT,
    ];
    await createNotificationsForRoles(allTargetRoles, {
      title,
      body,
      relatedDocId: snapshot.id,
      relatedCollection: "livraisons",
    });

    console.log(`✅ Livraison creation notification sent for: ${bonLivraisonCode}`);
  }
);

//
// ⭐️ ----- MODIFIED FUNCTION ----- ⭐️
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
    createActivityLog({
      service: "technique",
      taskType: "Livraison",
      taskTitle: after.clientName || "Livraison",
      storeName: after.storeName || "", // ✅ ADDED
      storeLocation: after.storeLocation || "", // ✅ ADDED
      displayName: after.createdByName || "Inconnu", // ✅ FIXED
      createdByName: after.createdByName || "Inconnu", // ✅ ADDED
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
    await notifyManagers(title, body);
    // ✅ ADD TO INBOX
    await createNotificationsForRoles(ROLES_MANAGERS, notificationData);

    await notifyServiceTechnique(title, body);
    // ✅ ADD TO INBOX
    await createNotificationsForRoles(ROLES_TECH_ST, notificationData);


    console.log(`✅ Livraison status update notification sent for ${bonLivraisonCode}`);
  }
);

//
// ⭐️ ----- MODIFIED FUNCTION ----- ⭐️
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
      createActivityLog({
        service: "technique",
        taskType: "SAV",
        taskTitle: after.clientName || "Ticket SAV",
        storeName: after.storeName || "", // ✅ ADDED
        storeLocation: after.storeLocation || "", // ✅ ADDED
        displayName: after.createdByName || "Inconnu", // ✅ FIXED
        createdByName: after.createdByName || "Inconnu", // ✅ ADDED
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

      await notifyManagers(title, body);
      // ✅ ADD TO INBOX
      await createNotificationsForRoles(ROLES_MANAGERS, notificationData);

      if (["En attente de pièce", "Terminé"].includes(after.status)) {
        await notifyServiceTechnique(title, body);
        // ✅ ADD TO INBOX
        await createNotificationsForRoles(ROLES_TECH_ST, notificationData);
      }
    }
  }
);

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

      await notifyServiceTechnique(title, body);
      // ✅ ADD TO INBOX
      await createNotificationsForRoles(ROLES_TECH_ST, notificationData);

      await notifyManagers(title, body);
      // ✅ ADD TO INBOX
      await createNotificationsForRoles(ROLES_MANAGERS, notificationData);


      console.log(`✅ Replacement approval notification sent for ${requestCode}`);
    }

    if (beforeStatus !== afterStatus) {
      const title = "Mise à Jour: Demande de Remplacement";
      const body = `Le statut pour ${after.replacementRequestCode || "N/A"} est maintenant: ${afterStatus}.`;

      await notifyManagers(title, body);
      // ✅ ADD TO INBOX
      await createNotificationsForRoles(ROLES_MANAGERS, {
        title,
        body,
        relatedDocId: event.data.after.id,
        relatedCollection: "replacement_requests",
      });
    }
  }
);

// ------------------------------------------------------------------
// START: NEW IT ACTIVITY LOGS
// ------------------------------------------------------------------

/**
 * Logs when a new IT support ticket is created.
 * Assumes a collection named 'support_tickets'.
 */
//
// ⭐️ ----- MODIFIED FUNCTION ----- ⭐️
//
export const onSupportTicketCreated_v2 = onDocumentCreated(
  "support_tickets/{ticketId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;
    const data = snapshot.data();

    createActivityLog({
      service: "it",
      taskType: "Support IT", // ⭐️ Matches app query
      taskTitle: data.clientName || "Support IT",
      storeName: data.storeName || "", // ✅ ADDED
      storeLocation: data.storeLocation || "", // ✅ ADDED
      displayName: data.createdByName || "Inconnu", // ✅ FIXED
      createdByName: data.createdByName || "Inconnu", // ✅ ADDED
      details: `Nouveau ticket: ${data.subject || "N/A"}`, // ✅ FIXED
      status: data.status || "Nouveau",
      relatedDocId: snapshot.id,
      relatedCollection: "support_tickets",
    });

    // ✅ --- ADD NOTIFICATION FOR IT TEAM ---
    const title = `Nouveau Ticket Support: ${data.clientName || ""}`;
    const body = data.subject || "Nouveau ticket de support IT";
    await notifyServiceIT(title, body);

    // ✅ ADD TO INBOX
    await createNotificationsForRoles(ROLES_TECH_IT, {
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
// ⭐️ ----- MODIFIED FUNCTION ----- ⭐️
//
export const onSupportTicketUpdated_v2 = onDocumentUpdated(
  "support_tickets/{ticketId}",
  async (event) => {
    if (!event.data) return;
    const before = event.data.before.data();
    const after = event.data.after.data();

    if (before.status === after.status) return; // No change

    createActivityLog({
      service: "it",
      taskType: "Support IT", // ⭐️ Matches app query
      taskTitle: after.clientName || "Support IT",
      storeName: after.storeName || "", // ✅ ADDED
      storeLocation: after.storeLocation || "", // ✅ ADDED
      displayName: after.createdByName || "Inconnu", // ✅ FIXED
      createdByName: after.createdByName || "Inconnu", // ✅ ADDED
      details: `Statut changé: '${before.status}' -> '${after.status}'`,
      status: after.status,
      relatedDocId: event.data.after.id,
      relatedCollection: "support_tickets",
    });

    // ✅ --- NEW: ADD INBOX NOTIFICATION FOR STATUS CHANGE ---
    await createNotificationsForRoles(ROLES_TECH_IT, {
      title: `Mise à Jour Support: ${after.clientName || "N/A"}`,
      body: `Statut: '${before.status}' -> '${after.status}'`,
      relatedDocId: event.data.after.id,
      relatedCollection: "support_tickets",
    });
    // ✅ --- END OF NEW LOGIC ---
  }
);

/**
 * Logs when a new IT maintenance task is created.
 * Assumes a collection named 'maintenance_it'.
 */
//
// ⭐️ ----- MODIFIED FUNCTION ----- ⭐️
//
export const onMaintenanceTaskCreated_v2 = onDocumentCreated(
  "maintenance_it/{taskId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;
    const data = snapshot.data();

    createActivityLog({
      service: "it",
      taskType: "Maintenance IT", // ⭐️ Matches app query
      taskTitle: data.taskName || "Maintenance IT",
      storeName: data.storeName || "", // ✅ ADDED
      storeLocation: data.storeLocation || "", // ✅ ADDED
      displayName: data.createdByName || "Inconnu", // ✅ FIXED
      createdByName: data.createdByName || "Inconnu", // ✅ ADDED
      details: `Nouvelle tâche: ${data.description || "N/A"}`, // ✅ FIXED
      status: data.status || "Nouveau",
      relatedDocId: snapshot.id,
      relatedCollection: "maintenance_it",
    });

    // ✅ --- ADD NOTIFICATION FOR IT TEAM ---
    const title = `Maintenance IT: ${data.taskName || "Nouvelle Tâche"}`;
    const body = data.description || "Une nouvelle tâche de maintenance a été créée.";
    await notifyServiceIT(title, body);

    // ✅ ADD TO INBOX
    await createNotificationsForRoles(ROLES_TECH_IT, {
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
// ⭐️ ----- MODIFIED FUNCTION ----- ⭐️
//
export const onMaintenanceTaskUpdated_v2 = onDocumentUpdated(
  "maintenance_it/{taskId}",
  async (event) => {
    if (!event.data) return;
    const before = event.data.before.data();
    const after = event.data.after.data();

    if (before.status === after.status) return; // No change

    createActivityLog({
      service: "it",
      taskType: "Maintenance IT", // ⭐️ Matches app query
      taskTitle: after.taskName || "Maintenance IT",
      storeName: after.storeName || "", // ✅ ADDED
      storeLocation: after.storeLocation || "", // ✅ ADDED
      displayName: after.createdByName || "Inconnu", // ✅ FIXED
      createdByName: after.createdByName || "Inconnu", // ✅ ADDED
      details: `Statut changé: '${before.status}' -> '${after.status}'`,
      status: after.status,
      relatedDocId: event.data.after.id,
      relatedCollection: "maintenance_it",
    });

    // ✅ --- NEW: ADD INBOX NOTIFICATION FOR STATUS CHANGE ---
    await createNotificationsForRoles(ROLES_TECH_IT, {
      title: `Mise à Jour Maintenance: ${after.taskName || "N/A"}`,
      body: `Statut: '${before.status}' -> '${after.status}'`,
      relatedDocId: event.data.after.id,
      relatedCollection: "maintenance_it",
    });
    // ✅ --- END OF NEW LOGIC ---
  }
);

// ------------------------------------------------------------------
// END: NEW IT ACTIVITY LOGS
// ------------------------------------------------------------------


// ✅
// ✅ NEWLY ADDED FUNCTION (FROM YOUR FILE - UNTOUCHED)
// ✅
/**
 * Sends a notification to ALL users when a new message
 * is posted in any announcement channel.
 */
export const onNewAnnouncementMessage = onDocumentCreated(
  // This path listens to the "messages" subcollection of ANY doc in "channels"
  "channels/{channelId}/messages/{messageId}",
  async (event): Promise<void> => {
    // Get the data for the new message that was just created
    const message = event.data?.data();
    const params = event.params; // Contains wildcards like {channelId}

    if (!message) {
      functions.logger.log("No message data found, exiting function.");
      return;
    }

    // 1. Get message details
    const messageText: string = message.text || "Nouveau message";
    const senderName: string = message.senderName || "Boitex Info";

    // 2. Get the channel name from the parent channel document
    let channelName = "Annonces"; // A sensible default
    try {
      // Go up one level to get the channel's main document
      const channelDoc = await admin.firestore()
        .collection("channels")
        .doc(params.channelId) // Use the wildcard value from the path
        .get();

      if (channelDoc.exists) {
        channelName = channelDoc.data()?.name || channelName;
      }
    } catch (error) {
      functions.logger.error(
        `Error fetching channel name for id ${params.channelId}:`,
        error
      );
    }

    // 3. Construct the notification payload
    // Truncate the message body if it's too long for a notification
    const bodyText = messageText.length > 100 ?
      `${messageText.substring(0, 97)}...` :
      messageText;

    const payload = {
      notification: {
        title: `Nouveau message dans #${channelName}`,
        body: `${senderName}: ${bodyText}`,
      },
      // Send to the global topic that all users are subscribed to
      topic: GLOBAL_ANNOUNCEMENTS_TOPIC,
    };

    // 4. Send the notification
    try {
      await admin.messaging().send(payload);
      functions.logger.log(
        `✅ Sent announcement notification for channel: #${channelName}`
      );
    } catch (error) {
      functions.logger.error("❌ Error sending announcement notification:", error);
    }

    // ✅ 5. ADD TO INBOX for all users
    await createNotificationsForAllUsers({
      title: payload.notification.title,
      body: payload.notification.body,
      relatedDocId: params.channelId, // The channel ID
      relatedCollection: "channels", // To know to navigate to the channel
    });
  });
// ✅
// ✅ END OF NEW FUNCTION (FROM YOUR FILE - UNTOUCHED)
// ✅

const collectionsToWatchForUpdates = [
  "interventions",
  "installations",
  "sav_tickets",
];

// NOTE: This generic handler is still here, but our specific handlers
// (like onInterventionStatusUpdate_v2) will run *in addition* to this.
// This is fine, but you may want to remove "interventions", "installations",
// and "sav_tickets" from this list to avoid duplicate manager notifications.
collectionsToWatchForUpdates.forEach((collection) => {
  exports[`on${collection}Updated`] = onDocumentUpdated(
    `${collection}/{docId}`,
    async (event) => {
      if (!event.data) return;

      const after = event.data.after.data();
      const code = after.requisitionCode || after.interventionCode || after.savCode || after.blCode || after.clientName || "N/A";
      const status = after.status || after.requestStatus || "Inconnu";

      const title = `Mise à Jour: ${collection}`;
      const body = `Statut de '${code}' est maintenant '${status}'`;

      await notifyManagers(title, body);

      // ✅ ADD TO INBOX
      // Note: This might create duplicate inbox items for updates
      // that are already handled by specific functions above
      // (onInterventionStatusUpdate_v2, onInstallationStatusUpdate_v2, etc.)
      // This is OK for now, but you might want to remove items from
      // 'collectionsToWatchForUpdates' to prevent this.
      await createNotificationsForRoles(ROLES_MANAGERS, {
        title,
        body,
        relatedDocId: event.data.after.id,
        relatedCollection: collection,
      });
    }
  );
});

// ------------------------------------------------------------------
// ✅ START: AI FUNCTION (GROQ) - (CONTEXT-AWARE V3)
// ------------------------------------------------------------------

// Define the Groq API endpoint
const GROQ_API_URL = "https://api.groq.com/openai/v1/chat/completions";

/**
 * Generates formal text from raw notes based on a given context.
 * (e.g., 'problem_report', 'diagnostic', 'workDone')
 */
export const generateReportFromNotes = onCall(
  {secrets: [groqApiKey]},
  async (request) => {
    // ✅ 1. Get both rawNotes and context from the app
    const rawNotes = request.data.rawNotes as string;
    const context = request.data.context as string | undefined; // 'problem_report', 'diagnostic', 'workDone'

    if (!rawNotes || rawNotes.trim().length === 0) {
      functions.logger.error("No rawNotes provided.");
      throw new HttpsError("invalid-argument", "The function must be called with 'rawNotes'.");
    }

    // Use a fast model available on Groq
    const modelId = "llama-3.1-8b-instant";

    // ✅ 2. Select the correct prompt based on the context
    let systemPrompt = "";

    // ✅ THIS IS THE "TRAINING" YOU REQUESTED.
    // We give it business context.
    const businessContext = `
      **CONTEXTE IMPORTANT:**
      - "Boitex Info" est une société spécialisée dans les systèmes de sécurité pour **magasins (retail)**.
      - Le terme "antivol" ou "anti vol" fait référence à des **systèmes de sécurité pour magasins** (portiques antivol, anti-vol à l'étalage, antivol textile).
      - **NE PAS** l'associer à des voitures ou des véhicules.
    `;

    switch (context) {
      case 'diagnostic':
        systemPrompt = `Tu es un technicien expert pour Boitex Info.
        ${businessContext}
        **TA TÂCHE:** Convertir les notes/mots-clés suivants en un **diagnostic technique** clair et professionnel. Reste factuel et précis. Ne parle pas de la solution.`;
        break;
      case 'workDone':
        systemPrompt = `Tu es un technicien expert pour Boitex Info.
        ${businessContext}
        **TA TÂCHE:** Convertir les notes/mots-clés suivants en un rapport formel des **travaux effectués**. Liste les actions de manière claire. Ne parle pas du diagnostic.`;
        break;
      case 'problem_report':
      default: // This is the original prompt from add_intervention_page
        systemPrompt = `Tu es un assistant expert pour Boitex Info.
        ${businessContext}
        **TA TÂCHE:** Ton unique objectif est de convertir les notes/mots-clés suivants en une **description de problème** claire et professionnelle en Français, telle que rapportée par un client de magasin. Ne crée PAS de section "Diagnostic" ou "Solution". Rédige simplement la plainte du client en utilisant le bon contexte.`;
        break;
    }

    // 3. Use the standard OpenAI "messages" format
    const messages = [
      {
        role: "system",
        content: systemPrompt, // Use the selected prompt
      },
      {
        role: "user",
        content: rawNotes,
      },
    ];

    try {
      functions.logger.info(`Calling Groq API (${modelId}) for context: ${context}`);

      const response = await axios.post(
        GROQ_API_URL,
        {
          model: modelId,
          messages: messages,
          max_tokens: 300,
          stream: false,
        },
        {
          headers: {
            "Authorization": `Bearer ${groqApiKey.value()}`,
            "Content-Type": "application/json",
          },
        }
      );

      if (!response.data || !response.data.choices || response.data.choices.length === 0) {
        functions.logger.error("Invalid response from Groq API", response.data);
        throw new Error("Invalid response from Groq API");
      }

      const formalReport = response.data.choices[0].message.content.trim();

      functions.logger.info(`Successfully generated report: ${formalReport}`);
      return formalReport; // Send the clean text back to the app

    } catch (error) {
      // We must check the type of 'error' before accessing properties.
      if (axios.isAxiosError(error)) {
        functions.logger.error("Error calling Groq API (Axios):", error.response?.data || error.message);
      } else if (error instanceof Error) {
        functions.logger.error("Error calling Groq API (General):", error.message);
      } else {
        functions.logger.error("Error calling Groq API (Unknown):", error);
      }

      throw new HttpsError("internal", "Failed to generate AI report.");
    }
  }
);
// ------------------------------------------------------------------
// ✅ END: MODIFIED AI FUNCTION (GROQ)
// ------------------------------------------------------------------


const corsHandler = cors({origin: true});

export const getB2UploadUrl = onRequest(
  { secrets: [backblazeKeyId, backblazeAppKey, backblazeBucketId] },
  (request, response) => {
    corsHandler(request, response, async () => {
      try {
        const b2 = new B2({
          applicationKeyId: backblazeKeyId.value(),
          applicationKey: backblazeAppKey.value(),
        });

        const authResponse = await b2.authorize();
        const { downloadUrl } = authResponse.data;
        const bucketId = backblazeBucketId.value();

        const uploadUrlResponse = await b2.getUploadUrl({ bucketId: bucketId });
        const bucketName = "BoitexInfo";
        const downloadUrlPrefix = `${downloadUrl}/file/${bucketName}/`;

        functions.logger.info("Successfully generated B2 upload URL.");

        response.status(200).send({
          uploadUrl: uploadUrlResponse.data.uploadUrl,
          authorizationToken: uploadUrlResponse.data.authorizationToken,
          downloadUrlPrefix: downloadUrlPrefix,
        });
      } catch (error) {
        functions.logger.error("Error getting B2 upload URL:", error);
        response.status(500).send({
          error: "Failed to get an upload URL from Backblaze B2.",
        });
      }
    });
  }
);

export const checkAndSendReminders = onSchedule("every 5 minutes", async (event) => {
  const now = admin.firestore.Timestamp.now();
  const db = admin.firestore();
  const messaging = admin.messaging();

  const query = db.collection("reminders")
    .where("status", "==", "pending")
    .where("dueAt", "<=", now);

  const remindersSnapshot = await query.get();

  if (remindersSnapshot.empty) {
    functions.logger.info("No pending reminders found.");
    return;
  }

  const promises: Promise<unknown>[] = [];

  for (const doc of remindersSnapshot.docs) {
    const reminder = doc.data();
    const title = reminder.title;
    // These are topic names (e.g., "Responsable_Administratif")
    const targetRoles = reminder.targetRoles as string[];

    if (!title || !targetRoles || targetRoles.length === 0) {
      functions.logger.warn("Skipping malformed reminder:", doc.id);
      promises.push(doc.ref.update({ status: "error_malformed" }));
      continue;
    }

    functions.logger.info(`Processing reminder: ${title}, for roles: ${targetRoles.join(", ")}`);

    const sendPromises = targetRoles.map(async (topic) => {
      try {
        functions.logger.info(`Sending to topic: ${topic}`);
        const message = {
          notification: {
            title: "🔔 Rappel",
            body: title,
          },
          topic: topic,
        };

        await messaging.send(message);
        functions.logger.info(`✅ Successfully sent to topic: ${topic}`);
      } catch (error) {
        functions.logger.error(`❌ Error sending to topic ${topic}:`, error);
      }
    });

    await Promise.all(sendPromises);

    // ✅ ADD TO INBOX
    // Convert topic names ("Responsable_Administratif")
    // to role names ("Responsable Administratif")
    const rolesWithSpaces = convertTopicsToRoles(targetRoles);
    await createNotificationsForRoles(rolesWithSpaces, {
      title: "🔔 Rappel", // Match the push notification title
      body: title,
      relatedCollection: "reminders",
      relatedDocId: doc.id,
    });

    promises.push(doc.ref.update({
      status: "sent",
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
    }));
  }

  await Promise.all(promises);
  functions.logger.info(`Processed ${remindersSnapshot.size} reminders.`);
});
