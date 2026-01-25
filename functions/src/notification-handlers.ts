// functions/src/notification-handlers.ts
import {onDocumentCreated, onDocumentUpdated} from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";
import {onSchedule} from "firebase-functions/v2/scheduler";
// ✅ ADDED IMPORTS FOR WEB SUBSCRIPTION
import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";

// ------------------------------------------------------------------
// CONSTANTS & CONFIGURATION
// ------------------------------------------------------------------

// Role Lists (Synced with user_roles.dart)
const ROLES_MANAGERS = [
"Admin",
"PDG",
"Responsable Administratif",
"Responsable Commercial",
"Responsable Technique",
"Responsable IT",
"Chef de Projet",
];

// ✅ NEW: Separate list for Commercials (Sales Team)
const ROLES_COMMERCIAL = ["Commercial"];

const ROLES_TECH_ST = ["Technicien ST"];
const ROLES_TECH_IT = ["Technicien IT"];

// ------------------------------------------------------------------
// HELPER FUNCTIONS (NOTIFICATIONS & LOGS)
// ------------------------------------------------------------------

/**
* Creates a new log entry in the 'activity_log' collection.
*/
const createActivityLog = (data: { [key: string]: any }) => {
admin.firestore().collection("activity_log").add({
    ...data,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  }).then(() => {
    console.log(`✅ Activity log created: ${data.taskType} - ${data.details}`);
  }).catch((err) => {
    console.error("❌ Error creating activity log:", err);
  });
};

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
  admin.firestore().collection("user_notifications").add({
    ...data,
    isRead: data.isRead || false,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  }).catch((err) => {
    console.error("❌ Error creating user notification:", err);
  });
};

// ------------------------------------------------------------------
// SMART NOTIFICATION ENGINE (TOKENS ONLY) 🧠
// ------------------------------------------------------------------

interface UserData {
  uid: string;
  fcmTokenWeb?: string;
  fcmTokenMobile?: string;
  notificationSettings?: { [key: string]: boolean };
}

const getUsersForRoles = async (roles: string[]): Promise<UserData[]> => {
  if (roles.length === 0) return [];
  const users: UserData[] = [];
  try {
    // Note: 'in' queries support max 10 values
    // Safety check for Firestore 'in' limit
    if (roles.length > 10) {
        console.warn("⚠️ Warning: Roles list > 10, slicing to first 10 for query safety.");
        roles = roles.slice(0, 10);
    }

    const usersSnapshot = await admin.firestore()
      .collection("users")
      .where("role", "in", roles)
      .get();

    if (!usersSnapshot.empty) {
      for (const doc of usersSnapshot.docs) {
        const d = doc.data();
        users.push({
          uid: doc.id,
          fcmTokenWeb: d.fcmTokenWeb,
          fcmTokenMobile: d.fcmTokenMobile,
          notificationSettings: d.notificationSettings,
        });
      }
    }
    return users;
  } catch (error) {
    console.error("❌ Error fetching users for roles:", error);
    return [];
  }
};

/**
 * Sends notifications to a list of roles.
 * - Checks User Settings first 🛡️
 * - Sends to Inbox
 * - Sends Push to BOTH Mobile and Web tokens
 * - 🛡️ EXCLUDES specific User ID (The Sender)
 */
const createNotificationsForRoles = async (
  roles: string[],
  notificationData: {
    title: string;
    body: string;
    relatedDocId?: string;
    relatedCollection?: string;
  },
  category?: string,
  excludeUserId?: string // ⚡ NEW: Param to prevent self-notification
) => {
  let users = await getUsersForRoles(roles);
  if (users.length === 0) return;

  // ✅ FILTER: Remove users who turned this category OFF
  // ✅ FILTER: Remove the Actor (Sender)
  users = users.filter((u) => {
    // 1. Exclude Sender
    if (excludeUserId && u.uid === excludeUserId) {
        return false;
    }
    // 2. Check Settings
    if (category && u.notificationSettings && u.notificationSettings[category] === false) {
      return false;
    }
    return true;
  });

  const {title, body, relatedDocId, relatedCollection} = notificationData;
  const tokensToSend: string[] = [];

  // 1. Inbox Items & Token Collection
  const promises = users.map((user) => {
    // Collect tokens for this valid user
    if (user.fcmTokenWeb) tokensToSend.push(user.fcmTokenWeb);
    if (user.fcmTokenMobile) tokensToSend.push(user.fcmTokenMobile);

    return createUserNotification({
      userId: user.uid,
      title,
      body,
      relatedDocId,
      relatedCollection,
    });
  });

  // 2. Send Push (Multicast to Mobile + Web)
  if (tokensToSend.length > 0) {
    try {
      await admin.messaging().sendEachForMulticast({
        tokens: tokensToSend,
        notification: { title, body },
        // ✅ 1. UPDATE APPLIED: Added data payload for Deep Linking
        data: {
          relatedCollection: relatedCollection || "",
          relatedDocId: relatedDocId || "",
          click_action: "FLUTTER_NOTIFICATION_CLICK"
        }
      });
      console.log(`✅ Sent Push to ${tokensToSend.length} devices (Mobile+Web).`);
    } catch (error) {
      console.error("❌ Error sending Push:", error);
    }
  }

  await Promise.all(promises);
};

const getUsersForAllUsers = async (): Promise<UserData[]> => {
  const users: UserData[] = [];
  try {
    const usersSnapshot = await admin.firestore().collection("users").get();
    if (!usersSnapshot.empty) {
      for (const doc of usersSnapshot.docs) {
        const d = doc.data();
        users.push({
          uid: doc.id,
          fcmTokenWeb: d.fcmTokenWeb,
          fcmTokenMobile: d.fcmTokenMobile,
          notificationSettings: d.notificationSettings,
        });
      }
    }
    return users;
  } catch (error) {
    console.error("❌ Error fetching all users:", error);
    return [];
  }
};

const createNotificationsForAllUsers = async (
  notificationData: {
    title: string;
    body: string;
    relatedDocId?: string;
    relatedCollection?: string;
  },
  category?: string,
  excludeUserId?: string // ⚡ NEW: Param to prevent self-notification
) => {
  let users = await getUsersForAllUsers();
  if (users.length === 0) return;

  if (category || excludeUserId) {
    users = users.filter((u) => {
      // 1. Exclude Sender
      if (excludeUserId && u.uid === excludeUserId) {
        return false;
      }
      // 2. Check Settings
      if (category && u.notificationSettings && u.notificationSettings[category] === false) {
        return false;
      }
      return true;
    });
  }

  const {title, body, relatedDocId, relatedCollection} = notificationData;
  const tokensToSend: string[] = [];

  const promises = users.map((user) => {
    if (user.fcmTokenWeb) tokensToSend.push(user.fcmTokenWeb);
    if (user.fcmTokenMobile) tokensToSend.push(user.fcmTokenMobile);

    return createUserNotification({
      userId: user.uid,
      title,
      body,
      relatedDocId,
      relatedCollection,
    });
  });

  if (tokensToSend.length > 0) {
    try {
      await admin.messaging().sendEachForMulticast({
        tokens: tokensToSend,
        notification: { title, body },
        // ✅ 2. UPDATE APPLIED: Added data payload for Deep Linking
        data: {
          relatedCollection: relatedCollection || "",
          relatedDocId: relatedDocId || "",
          click_action: "FLUTTER_NOTIFICATION_CLICK"
        }
      });
    } catch (error) {
      console.error("❌ Error sending Global Push:", error);
    }
  }

  await Promise.all(promises);
};

const convertTopicsToRoles = (topics: string[]): string[] => {
  return topics.map((topic) => topic.replace(/_/g, " "));
};

const createNotificationsForUsers = async (
  uids: string[],
  notificationData: {
    title: string;
    body: string;
    relatedDocId?: string;
    relatedCollection?: string;
  },
  category?: string,
  excludeUserId?: string // ⚡ NEW: Param to prevent self-notification
) => {
  if (uids.length === 0) return;

  // 1. Filter out the sender immediately
  if (excludeUserId) {
    uids = uids.filter(id => id !== excludeUserId);
  }
  if (uids.length === 0) return;

  const {title, body, relatedDocId, relatedCollection} = notificationData;
  const tokensToSend: string[] = [];

  const userFetchPromises = uids.map(uid => admin.firestore().collection("users").doc(uid).get());
  const userSnapshots = await Promise.all(userFetchPromises);

  const inboxPromises = userSnapshots.map(doc => {
    if (!doc.exists) return Promise.resolve();
    const data = doc.data();

    // ✅ FILTER
    if (category && data?.notificationSettings?.[category] === false) {
      return Promise.resolve();
    }

    if (data?.fcmTokenMobile) tokensToSend.push(data.fcmTokenMobile);
    if (data?.fcmTokenWeb) tokensToSend.push(data.fcmTokenWeb);

    return createUserNotification({
      userId: doc.id,
      title,
      body,
      relatedDocId,
      relatedCollection,
    });
  });

  await Promise.all(inboxPromises);

  if (tokensToSend.length > 0) {
    try {
      await admin.messaging().sendEachForMulticast({
        tokens: tokensToSend,
        notification: { title, body },
        // ✅ 3. UPDATE APPLIED: Added data payload for Deep Linking
        data: {
          relatedCollection: relatedCollection || "",
          relatedDocId: relatedDocId || "",
          click_action: "FLUTTER_NOTIFICATION_CLICK"
        }
      });
    } catch (error) {
      console.error("❌ Error sending targeted push:", error);
    }
  }
};

// ------------------------------------------------------------------
// FIRESTORE TRIGGERS
// ------------------------------------------------------------------

// 1. INTERVENTIONS
export const onInterventionCreated_v2 = onDocumentCreated("interventions/{interventionId}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) return;
  const data = snapshot.data();

  // ✅ CHANGED: Use Store Name
  const storeName = data.storeName || "Magasin Inconnu";
  const title = `Nouvelle Intervention : ${storeName}`;
  const body = `Client: ${data.clientName} - Magasin: ${data.storeName}`;
  const logService = data.serviceType === "Service IT" ? "it" : "technique";

  // ⚡ FIX: Added check for 'createdByUid' because your Flutter app uses that name
  const actorId = data.createdByUid || data.createdBy;

  createActivityLog({
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

  // --------------------------------------------------------
  // ✅ LOGIC UPDATE: Handle Portal Requests ("En Attente Validation")
  // --------------------------------------------------------
  if (data.status === "En Attente Validation") {
    console.log(`🔒 Portal Request detected (${snapshot.id}). Notifying Managers ONLY.`);

    // Custom Message for Validation
    const requestTitle = `Demande de Validation : ${storeName}`;
    const requestBody = `Nouvelle demande client pour ${data.clientName}. Validation requise.`;

    // 1. Notify Managers ONLY
    await createNotificationsForRoles(
      ROLES_MANAGERS,
      {
        title: requestTitle,
        body: requestBody,
        relatedDocId: snapshot.id,
        // 🚨 IMPORTANT: Route to "portal_requests" so App opens Validation Page, NOT details page.
        relatedCollection: "portal_requests"
      },
      "interventions",
      actorId
    );

    // 2. 🛑 EXIT: Do NOT notify Technicians yet.
    // They will be notified via onInterventionStatusUpdate when a Manager approves it.
    return;
  }

  // --------------------------------------------------------
  // ✅ STANDARD FLOW (Admin/Manager created directly)
  // --------------------------------------------------------
  const notificationData = { title, body, relatedDocId: snapshot.id, relatedCollection: "interventions" };

  await createNotificationsForRoles(ROLES_MANAGERS, notificationData, "interventions", actorId);

  if (data.serviceType === "Service IT") {
    await createNotificationsForRoles(ROLES_TECH_IT, notificationData, "interventions", actorId);
  } else {
    await createNotificationsForRoles(ROLES_TECH_ST, notificationData, "interventions", actorId);
  }
});

export const onInterventionStatusUpdate_v2 = onDocumentUpdated("interventions/{interventionId}", async (event) => {
  if (!event.data) return;
  const before = event.data.before.data();
  const after = event.data.after.data();

  if (before.status === after.status) return;

  const logService = after.serviceType === "Service IT" ? "it" : "technique";

  // ✅ UPDATE: Try to find an actor from various common fields
  const actorId = after.modifiedBy || after.updatedBy || after.lastModifiedBy;

  createActivityLog({
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

  // ✅ CHANGED: Use Store Name
  const storeName = after.storeName || "Magasin Inconnu";
  const title = `Mise à Jour Intervention : ${storeName}`;
  const body = `Statut: '${before.status}' -> '${after.status}'`;
  const notificationData = { title, body, relatedDocId: event.data.after.id, relatedCollection: "interventions" };

  // ✅ FIX: Pass actorId (will only work if App saves it)
  await createNotificationsForRoles(ROLES_MANAGERS, notificationData, "interventions", actorId);
  if (logService === "it") {
    await createNotificationsForRoles(ROLES_TECH_IT, notificationData, "interventions", actorId);
  } else {
    await createNotificationsForRoles(ROLES_TECH_ST, notificationData, "interventions", actorId);
  }
});

// 2. SAV TICKETS
export const onSavTicketCreated_v2 = onDocumentCreated("sav_tickets/{ticketId}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) return;
  const data = snapshot.data();

  // ✅ CHANGED: Use Store Name
  const storeName = data.storeName || "Magasin Inconnu";
  const title = `Nouveau Ticket SAV : ${storeName}`;
  const body = `Client: ${data.clientName} - Produit: ${data.productName}`;

  // ⚡ FIX: Check both field names
  const actorId = data.createdByUid || data.createdBy;

  createActivityLog({
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

  const notificationData = { title, body, relatedDocId: snapshot.id, relatedCollection: "sav_tickets" };

  await createNotificationsForRoles(ROLES_MANAGERS, notificationData, "sav_tickets", actorId);
  await createNotificationsForRoles(ROLES_TECH_ST, notificationData, "sav_tickets", actorId);
});

export const onSavTicketUpdate_v2 = onDocumentUpdated("sav_tickets/{ticketId}", async (event) => {
  if (!event.data) return;
  const before = event.data.before.data();
  const after = event.data.after.data();

  if (before.status === after.status) return;

  // ✅ UPDATE: Try to find an actor from various common fields
  const actorId = after.modifiedBy || after.updatedBy || after.lastModifiedBy;

  // ✅ CHANGED: Use Store Name
  const storeName = after.storeName || "Magasin Inconnu";
  const title = `Mise à Jour SAV : ${storeName}`;
  const body = `Nouveau statut: ${after.status}`;

  createActivityLog({
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

  const notificationData = { title, body, relatedDocId: event.data.after.id, relatedCollection: "sav_tickets" };

  // ✅ FIX: Pass actorId
  await createNotificationsForRoles(ROLES_MANAGERS, notificationData, "sav_tickets", actorId);
  if (["En attente de pièce", "Terminé"].includes(after.status)) {
    await createNotificationsForRoles(ROLES_TECH_ST, notificationData, "sav_tickets", actorId);
  }
});

// 3. REPLACEMENT REQUESTS
export const onReplacementRequestCreated_v2 = onDocumentCreated("replacement_requests/{requestId}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) return;
  const data = snapshot.data();

  const title = `Nouvelle Demande de Remplacement: ${data.replacementRequestCode}`;
  const body = `Demandé par: ${data.technicianName} pour ${data.clientName}`;
  const notificationData = { title, body, relatedDocId: snapshot.id, relatedCollection: "replacement_requests" };

  // ⚡ FIX: Check both field names
  const actorId = data.createdByUid || data.createdBy;

  await createNotificationsForRoles(ROLES_MANAGERS, notificationData, "sav_tickets", actorId);
});

export const onReplacementRequestUpdate_v2 = onDocumentUpdated("replacement_requests/{requestId}", async (event) => {
  if (!event.data) return;
  const before = event.data.before.data();
  const after = event.data.after.data();

  const beforeStatus = before.requestStatus;
  const afterStatus = after.requestStatus;
  const requestCode = after.replacementRequestCode;

  // ⚡ FIX: Check updated fields
  const actorId = after.modifiedBy || after.updatedBy;

  if (beforeStatus !== "Approuvé" && afterStatus === "Approuvé") {
    const title = `Remplacement Approuvé: ${requestCode}`;
    const body = `Préparez la pièce pour ${after.clientName} | Produit: ${after.productName}`;
    const notificationData = { title, body, relatedDocId: event.data.after.id, relatedCollection: "replacement_requests" };

    await createNotificationsForRoles(ROLES_TECH_ST, notificationData, "sav_tickets", actorId);
    await createNotificationsForRoles(ROLES_MANAGERS, notificationData, "sav_tickets", actorId);
  }

  if (beforeStatus !== afterStatus) {
    const title = "Mise à Jour: Demande de Remplacement";
    const body = `Le statut pour ${after.replacementRequestCode || "N/A"} est maintenant: ${afterStatus}.`;
    await createNotificationsForRoles(ROLES_MANAGERS, { title, body, relatedDocId: event.data.after.id, relatedCollection: "replacement_requests" }, "sav_tickets", actorId);
  }
});

// 4. REQUISITIONS
export const onRequisitionCreated_v2 = onDocumentCreated("requisitions/{requisitionId}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) return;
  const data = snapshot.data();

  const requisitionCode = data.requisitionCode || "N/A";
  const requestedBy = data.requestedBy || "Inconnu";
  const itemCount = (data.items as Array<Record<string, unknown>>)?.length || 0;

  // ⚡ FIX: Check both field names
  const actorId = data.createdByUid || data.createdBy;

  const title = `Nouvelle Demande d'Achat: ${requisitionCode}`;
  const body = `Demandée par: ${requestedBy} - ${itemCount} article(s)`;

  await createNotificationsForRoles(ROLES_MANAGERS, { title, body, relatedDocId: snapshot.id, relatedCollection: "requisitions" }, "requisitions", actorId);
});

export const onRequisitionStatusUpdate_v2 = onDocumentUpdated("requisitions/{requisitionId}", async (event) => {
  if (!event.data) return;
  const before = event.data.before.data();
  const after = event.data.after.data();

  if (before.status === after.status) return;

  const title = `Mise à Jour: ${after.requisitionCode || "N/A"}`;
  const body = `Statut: ${after.status || "Inconnu"} - Demandé par: ${after.requestedBy}`;
  const actorId = after.modifiedBy || after.updatedBy; // ✅ FIX

  await createNotificationsForRoles(ROLES_MANAGERS, { title, body, relatedDocId: event.data.after.id, relatedCollection: "requisitions" }, "requisitions", actorId);
});

// 5. PROJECTS
export const onProjectCreated_v2 = onDocumentCreated("projects/{projectId}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) return;
  const data = snapshot.data();

  const title = `Nouveau Projet: ${data.projectName || "Nouveau Projet"}`;
  const body = `Client: ${data.clientName || "N/A"}`;

  // ⚡ FIX: Check both field names
  const actorId = data.createdByUid || data.createdBy;

  await createNotificationsForRoles(ROLES_MANAGERS, { title, body, relatedDocId: snapshot.id, relatedCollection: "projects" }, "projects", actorId);
});

export const onProjectStatusUpdate_v2 = onDocumentUpdated("projects/{projectId}", async (event) => {
  if (!event.data) return;
  const before = event.data.before.data();
  const after = event.data.after.data();
  const actorId = after.modifiedBy || after.updatedBy; // ✅ FIX

  // IT Evaluation Logic
  if (!before.it_evaluation && after.it_evaluation) {
    createActivityLog({
      service: "it",
      taskType: "Evaluation IT",
      taskTitle: after.clientName || "Évaluation IT",
      storeName: after.storeName || "magasin",
      storeLocation: after.storeLocation || "",
      displayName: after.createdByName || "Inconnu",
      createdByName: after.createdByName || "Inconnu",
      details: `Terminée pour ${after.storeName || "magasin"}`,
      status: after.status,
      relatedDocId: event.data.after.id,
      relatedCollection: "projects",
    });

    await createNotificationsForRoles(ROLES_TECH_IT, {
      title: "Évaluation IT Terminée",
      body: `Client: ${after.clientName} - Magasin: ${after.storeName}`,
      relatedDocId: event.data.after.id,
      relatedCollection: "projects",
    }, "projects", actorId);
  }

  // Status Change Logic
  if (before.status !== after.status) {
    const title = `Mise à Jour Projet: ${after.projectName}`;
    const body = `Client: ${after.clientName} - Statut: ${after.status}`;
    await createNotificationsForRoles(ROLES_MANAGERS, { title, body, relatedDocId: event.data.after.id, relatedCollection: "projects" }, "projects", actorId);
  }
});

// 6. MISSIONS (NEW)
export const onMissionCreated_v2 = onDocumentCreated("missions/{missionId}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) return;
  const data = snapshot.data();

  const title = `Nouvelle Mission: ${data.missionCode || "N/A"}`;
  const body = `${data.title} - ${data.destinations?.length || 0} Destination(s)`;

  // ⚡ FIX: Check both field names
  const actorId = data.createdByUid || data.createdBy;

  createActivityLog({
    service: data.serviceType === "Service IT" ? "it" : "technique",
    taskType: "Mission",
    taskTitle: data.title || "Nouvelle Mission",
    displayName: data.createdBy || "Admin",
    details: `Mission créée pour ${data.assignedTechniciansNames?.join(", ") || "équipe"}`,
    status: data.status || "Planifiée",
    relatedDocId: snapshot.id,
    relatedCollection: "missions",
  });

  const notificationData = { title, body, relatedDocId: snapshot.id, relatedCollection: "missions" };

  // Notify Managers
  await createNotificationsForRoles(ROLES_MANAGERS, notificationData, "missions", actorId);

  // Notify Assigned Technicians
  const assignedIds = data.assignedTechniciansIds as string[];
  if (assignedIds && assignedIds.length > 0) {
    // Note: If the creator assigned themselves, we exclude them here too
    await createNotificationsForUsers(assignedIds, notificationData, "missions", actorId);
  }
});

// 7. INSTALLATIONS
export const onInstallationCreated_v2 = onDocumentCreated("installations/{installationId}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) return;
  const data = snapshot.data();

  // ✅ CHANGED: Use Store Name
  const storeName = data.storeName || "Magasin Inconnu";
  const title = `Nouvelle Installation : ${storeName}`;
  const body = `Client: ${data.clientName} - Magasin: ${data.storeName}`;

  // ⚡ FIX: Check both field names
  const actorId = data.createdByUid || data.createdBy;

  createActivityLog({
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

  const notificationData = { title, body, relatedDocId: snapshot.id, relatedCollection: "installations" };

  await createNotificationsForRoles(ROLES_MANAGERS, notificationData, "installations", actorId);
  await createNotificationsForRoles(ROLES_TECH_ST, notificationData, "installations", actorId);
});

export const onInstallationStatusUpdate_v2 = onDocumentUpdated("installations/{installationId}", async (event) => {
  if (!event.data) return;
  const before = event.data.before.data();
  const after = event.data.after.data();

  if (before.status === after.status) return;

  const actorId = after.modifiedBy || after.updatedBy; // ✅ FIX

  createActivityLog({
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

  // ✅ CHANGED: Use Store Name
  const storeName = after.storeName || "Magasin Inconnu";
  const title = `Mise à Jour Installation : ${storeName}`;
  const body = `Client: ${after.clientName} - Statut: ${after.status}`;
  const notificationData = { title, body, relatedDocId: event.data.after.id, relatedCollection: "installations" };

  await createNotificationsForRoles(ROLES_MANAGERS, notificationData, "installations", actorId);
  await createNotificationsForRoles(ROLES_TECH_ST, notificationData, "installations", actorId);
});

// ✅ NEW: Installation Log Notification
// Triggers specifically when a document is added to the "daily_logs" sub-collection
export const onInstallationLogCreated = onDocumentCreated("installations/{installationId}/daily_logs/{logId}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) return;
  const data = snapshot.data();
  const params = event.params;

  const technicianId = data.technicianId;
  // If no description, fallback to generic
  const description = data.description || "Mise à jour du journal";

  // 1. Fetch Technician Name from Users Collection
  // We use the ID stored in the log to get the accurate display name from the users collection
  let technicianName = data.technicianName || "Technicien"; // Fallback to log data if user fetch fails
  if (technicianId) {
    try {
      const userDoc = await admin.firestore().collection("users").doc(technicianId).get();
      if (userDoc.exists) {
        technicianName = userDoc.data()?.displayName || technicianName;
      }
    } catch (e) {
      console.error("Error fetching technician name", e);
    }
  }

  // 2. Fetch Parent Installation Data
  // We need the Store Name and Location for the notification Title
  let storeName = "Magasin";
  let storeLocation = "";

  try {
    const installationDoc = await admin.firestore().collection("installations").doc(params.installationId).get();
    if (installationDoc.exists) {
      const instData = installationDoc.data();
      storeName = instData?.storeName || storeName;
      storeLocation = instData?.storeLocation ? ` ${instData.storeLocation}` : "";
    }
  } catch (e) {
    console.error("Error fetching installation data", e);
  }

  // 3. Prepare Notification
  const title = `Update Installation ${storeName}${storeLocation}`;
  const body = `${technicianName} : ${description}`;

  const notificationData = {
    title,
    body,
    relatedDocId: params.installationId, // Link to the Installation, not the log itself, so app opens details
    relatedCollection: "installations"
  };

  // 4. Send Notifications
  // Exclude the sender (technicianId) from receiving their own notification
  await createNotificationsForRoles(ROLES_MANAGERS, notificationData, "installations", technicianId);
  await createNotificationsForRoles(ROLES_TECH_ST, notificationData, "installations", technicianId);
});

// 8. LIVRAISONS
export const onLivraisonCreated_v2 = onDocumentCreated("livraisons/{livraisonId}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) return;
  const data = snapshot.data();

  // ✅ CHANGED: Use Store Name
  const storeName = data.storeName || "Magasin Inconnu";
  const title = `Nouvelle Livraison : ${storeName}`;
  const body = `Client: ${data.clientName} | Service: ${data.serviceType}`;

  // ⚡ FIX: Check both field names
  const actorId = data.createdByUid || data.createdBy;

  createActivityLog({
    service: "technique",
    taskType: "Livraison",
    taskTitle: data.clientName || "Nouvelle Livraison",
    storeName: data.storeName || "",
    storeLocation: data.storeLocation || "",
    displayName: data.createdByName || "Inconnu",
    createdByName: data.createdByName || "Inconnu",
    details: `Créée par ${data.createdByName || "Inconnu"} | BL: ${data.bonLivraisonCode}`,
    status: data.status || "Nouveau",
    relatedDocId: snapshot.id,
    relatedCollection: "livraisons",
  });

  const notificationData = { title, body, relatedDocId: snapshot.id, relatedCollection: "livraisons" };

  await createNotificationsForRoles([...ROLES_MANAGERS, ...ROLES_TECH_ST, ...ROLES_TECH_IT], notificationData, "livraisons", actorId);
});

export const onLivraisonStatusUpdate_v2 = onDocumentUpdated("livraisons/{livraisonId}", async (event) => {
  if (!event.data) return;
  const before = event.data.before.data();
  const after = event.data.after.data();

  if (before.status === after.status) return;

  const actorId = after.modifiedBy || after.updatedBy; // ✅ FIX

  createActivityLog({
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

  // ✅ CHANGED: Use Store Name
  const storeName = after.storeName || "Magasin Inconnu";
  const title = `Mise à Jour Livraison : ${storeName}`;
  const body = `Client: ${after.clientName} - Statut: ${after.status}`;
  const notificationData = { title, body, relatedDocId: event.data.after.id, relatedCollection: "livraisons" };

  await createNotificationsForRoles(ROLES_MANAGERS, notificationData, "livraisons", actorId);
  await createNotificationsForRoles(ROLES_TECH_ST, notificationData, "livraisons", actorId);
});

// 9. IT SUPPORT & MAINTENANCE
export const onSupportTicketCreated_v2 = onDocumentCreated("support_tickets/{ticketId}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) return;
  const data = snapshot.data();

  createActivityLog({
    service: "it",
    taskType: "Support IT",
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

  const title = `Nouveau Ticket Support: ${data.clientName || ""}`;
  const body = data.subject || "Nouveau ticket de support IT";

  // ⚡ FIX: Check both field names
  const actorId = data.createdByUid || data.createdBy;

  await createNotificationsForRoles(ROLES_TECH_IT, { title, body, relatedDocId: snapshot.id, relatedCollection: "support_tickets" }, "interventions", actorId);
});

export const onSupportTicketUpdated_v2 = onDocumentUpdated("support_tickets/{ticketId}", async (event) => {
  if (!event.data) return;
  const before = event.data.before.data();
  const after = event.data.after.data();

  if (before.status === after.status) return;

  const actorId = after.modifiedBy || after.updatedBy; // ✅ FIX

  createActivityLog({
    service: "it",
    taskType: "Support IT",
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

  await createNotificationsForRoles(ROLES_TECH_IT, {
    title: `Mise à Jour Support: ${after.clientName || "N/A"}`,
    body: `Statut: '${before.status}' -> '${after.status}'`,
    relatedDocId: event.data.after.id,
    relatedCollection: "support_tickets",
  }, "interventions", actorId);
});

export const onMaintenanceTaskCreated_v2 = onDocumentCreated("maintenance_it/{taskId}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) return;
  const data = snapshot.data();

  createActivityLog({
    service: "it",
    taskType: "Maintenance IT",
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

  const title = `Maintenance IT: ${data.taskName || "Nouvelle Tâche"}`;
  const body = data.description || "Une nouvelle tâche de maintenance a été créée.";

  // ⚡ FIX: Check both field names
  const actorId = data.createdByUid || data.createdBy;

  await createNotificationsForRoles(ROLES_TECH_IT, { title, body, relatedDocId: snapshot.id, relatedCollection: "maintenance_it" }, "interventions", actorId);
});

export const onMaintenanceTaskUpdated_v2 = onDocumentUpdated("maintenance_it/{taskId}", async (event) => {
  if (!event.data) return;
  const before = event.data.before.data();
  const after = event.data.after.data();

  if (before.status === after.status) return;

  const actorId = after.modifiedBy || after.updatedBy; // ✅ FIX

  createActivityLog({
    service: "it",
    taskType: "Maintenance IT",
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

  await createNotificationsForRoles(ROLES_TECH_IT, {
    title: `Mise à Jour Maintenance: ${after.taskName || "N/A"}`,
    body: `Statut: '${before.status}' -> '${after.status}'`,
    relatedDocId: event.data.after.id,
    relatedCollection: "maintenance_it",
  }, "interventions", actorId);
});

// 10. ANNOUNCEMENTS
export const onNewAnnouncementMessage = onDocumentCreated("channels/{channelId}/messages/{messageId}", async (event) => {
  const message = event.data?.data();
  const params = event.params;
  if (!message) return;

  const messageText: string = message.text || "Nouveau message";
  const senderName: string = message.senderName || "Boitex Info";
  let channelName = "Annonces";
  const senderId = message.senderId; // ⚡ Capture Sender of Message

  try {
    const channelDoc = await admin.firestore().collection("channels").doc(params.channelId).get();
    if (channelDoc.exists) channelName = channelDoc.data()?.name || channelName;
  } catch (_) {}

  const bodyText = messageText.length > 100 ? `${messageText.substring(0, 97)}...` : messageText;
  const title = `Nouveau message dans #${channelName}`;
  const body = `${senderName}: ${bodyText}`;

  // ✅ UPDATED: Switched from Topic to Filterable User List to respect User Settings
  // We pass "announcements" as the category so the filtering logic applies.
  await createNotificationsForAllUsers(
    { title, body, relatedDocId: params.channelId, relatedCollection: "channels" },
    "announcements", // <--- This enables the filtering logic!
    senderId // <--- EXCLUDE SENDER
  );
});

// 15. COMMERCIAL PROSPECTS (NEW)
export const onProspectCreated = onDocumentCreated("prospects/{prospectId}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) return;
  const data = snapshot.data();

  const title = `Nouveau Prospect : ${data.companyName || "Inconnu"}`;
  const body = `📍 Situé à ${data.commune || "Alger"} - Ajouté par ${data.authorName || "Commercial"}`;

  // ⚡ FIX: Check both field names (Prospects usually use createdBy)
  const actorId = data.createdByUid || data.createdBy;

  createActivityLog({
    service: "commercial",
    taskType: "Prospect",
    taskTitle: data.companyName || "Nouveau Prospect",
    storeName: data.companyName || "",
    storeLocation: data.commune || "",
    displayName: data.authorName || "Commercial",
    createdByName: data.authorName || "Commercial",
    details: `Prospect ajouté à ${data.commune}`,
    status: data.status || "Nouveau",
    relatedDocId: snapshot.id,
    relatedCollection: "prospects",
  });

  const notificationData = { title, body, relatedDocId: snapshot.id, relatedCollection: "prospects" };

  // ✅ UPDATED: Include Commercials for gamification, BUT EXCLUDE SELF
  await createNotificationsForRoles([...ROLES_MANAGERS, ...ROLES_COMMERCIAL], notificationData, "commercial", actorId);
});

export const onProspectStatusUpdate = onDocumentUpdated("prospects/{prospectId}", async (event) => {
  if (!event.data) return;
  const before = event.data.before.data();
  const after = event.data.after.data();

  if (before.status === after.status) return;

  const title = `Pipeline Commercial 🚀`;
  const body = `${after.companyName} est maintenant "${after.status}"`;

  // ✅ UPDATE: Try to find an actor from various common fields
  const actorId = after.modifiedBy || after.updatedBy || after.lastModifiedBy;

  createActivityLog({
    service: "commercial",
    taskType: "Prospect",
    taskTitle: after.companyName || "Prospect",
    storeName: after.companyName || "",
    storeLocation: after.commune || "",
    displayName: after.authorName || "Commercial",
    createdByName: after.authorName || "Commercial",
    details: `Statut changé: ${before.status} -> ${after.status}`,
    status: after.status,
    relatedDocId: event.data.after.id,
    relatedCollection: "prospects",
  });

  const notificationData = { title, body, relatedDocId: event.data.after.id, relatedCollection: "prospects" };

  // ✅ FIX: Pass actorId (will only work if App saves it)
  await createNotificationsForRoles([...ROLES_MANAGERS, ...ROLES_COMMERCIAL], notificationData, "commercial", actorId);
});

// 11. REMINDERS (SCHEDULER)
export const checkAndSendReminders = onSchedule("every 5 minutes", async (event) => {
  const now = admin.firestore.Timestamp.now();
  const db = admin.firestore();
  const messaging = admin.messaging();

  const query = db.collection("reminders").where("status", "==", "pending").where("dueAt", "<=", now);
  const remindersSnapshot = await query.get();

  if (remindersSnapshot.empty) return;

  const promises: Promise<unknown>[] = [];

  for (const doc of remindersSnapshot.docs) {
    const reminder = doc.data();
    const title = reminder.title;
    const targetRoles = reminder.targetRoles as string[];

    if (!title || !targetRoles) {
      promises.push(doc.ref.update({ status: "error_malformed" }));
      continue;
    }

    // Send to Topics
    const sendPromises = targetRoles.map(async (topic) => {
      try { await messaging.send({ notification: { title: "🔔 Rappel", body: title }, topic: topic }); } catch (_) {}
    });
    await Promise.all(sendPromises);

    // Send to Inbox + Web
    const rolesWithSpaces = convertTopicsToRoles(targetRoles);
    await createNotificationsForRoles(rolesWithSpaces, {
      title: "🔔 Rappel",
      body: title,
      relatedCollection: "reminders",
      relatedDocId: doc.id,
    });

    promises.push(doc.ref.update({ status: "sent", sentAt: admin.firestore.FieldValue.serverTimestamp() }));
  }

  await Promise.all(promises);
});

// 12. GENERIC FALLBACK FOR OTHER COLLECTIONS
// ✅ FIX: Emptied this list to prevent duplicate notifications (Double Trigger Bug)
// Because "interventions", "installations", and "sav_tickets" already have specific listeners above.
// ❌ FIX TYPE: Added ': string[]' to prevent 'implicitly has type any[]' error.
const collectionsToWatchForUpdates: string[] = [];
export const genericUpdateTriggers = collectionsToWatchForUpdates.map(collection => {
  return onDocumentUpdated(`${collection}/{docId}`, async (event) => {
    if (!event.data) return;
    const after = event.data.after.data();
    const code = after.requisitionCode || after.interventionCode || after.savCode || after.blCode || after.clientName || "N/A";
    const status = after.status || after.requestStatus || "Inconnu";

    const title = `Mise à Jour: ${collection}`;
    const body = `Statut de '${code}' est maintenant '${status}'`;

    await createNotificationsForRoles(ROLES_MANAGERS, { title, body, relatedDocId: event.data.after.id, relatedCollection: collection }, "interventions");
  });
});

// ------------------------------------------------------------------
// WEB SUBSCRIPTION HANDLER
// ------------------------------------------------------------------

/**
 * Manually subscribes a Web FCM Token to a list of topics.
 * This is required because the Firebase JS SDK does not support
 * client-side topic subscription.
 */
export const subscribeToTopicsWeb = onCall(async (request) => {
  // 1. Validation
  const token = request.data.token;
  const topics = request.data.topics as string[];

  if (!token || typeof token !== "string") {
    throw new HttpsError("invalid-argument", "The function must be called with a valid 'token'.");
  }

  if (!topics || !Array.isArray(topics) || topics.length === 0) {
    throw new HttpsError("invalid-argument", "The function must be called with a list of 'topics'.");
  }

  // 2. Execution
  try {
    console.log(`🔌 Subscribing Web Token to ${topics.length} topics...`);

    // Create an array of promises to subscribe to all topics in parallel
    const promises = topics.map((topic) =>
      admin.messaging().subscribeToTopic(token, topic)
    );

    await Promise.all(promises);

    console.log(`✅ Successfully subscribed web user to: ${topics.join(", ")}`);
    return { success: true, subscribedTo: topics };

  } catch (error) {
    console.error("❌ Error subscribing web token to topics:", error);
    throw new HttpsError("internal", "Failed to subscribe web token to topics.");
  }
});

// ------------------------------------------------------------------
// MORNING BRIEFING SCHEDULER
// ------------------------------------------------------------------

export const sendMorningBriefing = onSchedule({
  schedule: "every 15 minutes", // ⚡ UPDATED: Check more often for better precision
  timeZone: "Africa/Algiers",
  retryCount: 0,
}, async (event) => {

  const db = admin.firestore();

  // 1. Fetch Configuration
  const settingsDoc = await db.collection("settings").doc("morning_briefing").get();
  if (!settingsDoc.exists) return;

  const settings = settingsDoc.data();
  if (!settings || !settings.enabled) return;

  // ----------------------------------------------------------------
  // 2. Precise Time Calculation (Force Algeria Time UTC+1)
  // ----------------------------------------------------------------
  const now = new Date();
  // Get UTC time in ms
  const utcMs = now.getTime() + (now.getTimezoneOffset() * 60000);
  // Add Algeria Offset (UTC + 1 hour)
  const algeriaOffsetHours = 1;
  const algeriaDate = new Date(utcMs + (3600000 * algeriaOffsetHours));

  const currentHour = algeriaDate.getHours();
  const currentMinute = algeriaDate.getMinutes();

  // Check Day
  const frenchDays = ['Dimanche', 'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi'];
  const currentDayName = frenchDays[algeriaDate.getDay()];

  if (!settings.days || !settings.days.includes(currentDayName)) {
    console.log(`Skipping: Today is ${currentDayName}, not in allowed days.`);
    return;
  }

  // ----------------------------------------------------------------
  // 3. ⚡ FIXED: Time Window Logic
  // ----------------------------------------------------------------
  const targetHour = settings.time.hour;
  const targetMinute = settings.time.minute;

  // Calculate difference in minutes
  const currentTotalMinutes = (currentHour * 60) + currentMinute;
  const targetTotalMinutes = (targetHour * 60) + targetMinute;

  const diff = Math.abs(currentTotalMinutes - targetTotalMinutes);

  console.log(`🕒 Time Check (Algeria): Current ${currentHour}:${currentMinute} vs Target ${targetHour}:${targetMinute} (Diff: ${diff}m)`);

  // We run every 15 mins.
  // We strictly check if we are within 7 minutes of the target.
  // This prevents 8:15 and 8:45 from triggering an 8:30 target.
  if (diff > 7) {
    console.log(`Skipping: Time mismatch.`);
    return;
  }

  console.log("🚀 Starting Morning Briefing Generation...");

  // ----------------------------------------------------------------
  // 4. Data Aggregation & Sending
  // ----------------------------------------------------------------
  try {
    // Note: I also fixed the '!=' query which can be problematic in Firestore
    const activeSavStatuses = ['Nouveau', 'En cours', 'En attente de pièce', 'Diagnostiqué'];

    const [
      interventionsSnap,
      savSnap,
      livraisonsSnap,
      billingSnap,
      requisitionsSnap
    ] = await Promise.all([
      db.collection('interventions').where('status', '==', 'Nouvelle Demande').count().get(),

      // Changed to 'in' query for better accuracy
      db.collection('sav_tickets').where('status', 'in', activeSavStatuses).count().get(),

      db.collection('livraisons').where('status', '==', 'À Préparer').count().get(),
      db.collection('interventions').where('status', '==', 'Terminé').count().get(),
      db.collection('requisitions').where('status', '==', "En attente d'approbation").count().get()
    ]);

    const counts = {
      pending_interventions: interventionsSnap.data().count,
      active_sav: savSnap.data().count,
      todays_livraisons: livraisonsSnap.data().count,
      pending_billing: billingSnap.data().count,
      pending_requisitions: requisitionsSnap.data().count,
    };

    // Dispatch (Per Role)
    const recipients = settings.roles || [];
    const contentVisibility = settings.content_visibility || {};

    const sendPromises = recipients.map(async (role: string) => {
      let bodyLines: string[] = [];

      // Helper to check visibility
      const canSee = (key: string) => {
        const allowedRoles = contentVisibility[key];
        return allowedRoles && allowedRoles.includes(role);
      };

      if (canSee('pending_interventions') && counts.pending_interventions > 0) {
        bodyLines.push(`🛠️ ${counts.pending_interventions} Nouvelles Interventions`);
      }
      if (canSee('active_sav') && counts.active_sav > 0) {
        bodyLines.push(`🎫 ${counts.active_sav} Tickets SAV actifs`);
      }
      if (canSee('todays_livraisons') && counts.todays_livraisons > 0) {
        bodyLines.push(`🚚 ${counts.todays_livraisons} Livraisons à préparer`);
      }
      if (canSee('pending_billing') && counts.pending_billing > 0) {
        bodyLines.push(`💰 ${counts.pending_billing} Dossiers à facturer`);
      }
      if (canSee('pending_requisitions') && counts.pending_requisitions > 0) {
        bodyLines.push(`🛒 ${counts.pending_requisitions} Achats à valider`);
      }

      if (bodyLines.length === 0) return;

      const messageBody = bodyLines.join("\n");
      // IMPORTANT: Ensure topic name matches what the app subscribes to!
      const topicName = `user_role_${role.replace(/\s+/g, '_')}`; // e.g., user_role_Admin

      await admin.messaging().send({
        topic: topicName,
        notification: {
          title: `📊 Briefing Matinal - ${currentDayName}`,
          body: messageBody,
        },
        data: {
          type: "morning_briefing",
          click_action: "FLUTTER_NOTIFICATION_CLICK"
        }
      });

      console.log(`✅ Sent briefing to ${role} (Topic: ${topicName})`);
    });

    await Promise.all(sendPromises);

  } catch (error) {
    logger.error("Error generating morning briefing:", error);
  }
});

// ------------------------------------------------------------------
// 13. AUTO-CLEANUP (Scheduled - Daily at 03:00 AM)
// ------------------------------------------------------------------
// Deletes notifications older than 7 days to keep the DB clean and the app fast.

export const cleanupOldNotifications = onSchedule({
  schedule: "every day 03:00", // Runs at 3 AM when traffic is low
  timeZone: "Africa/Algiers",
}, async (event) => {

  const db = admin.firestore();
  const now = new Date();
  // Calculate date: 7 days ago
  const sevenDaysAgo = new Date(now.getTime() - (7 * 24 * 60 * 60 * 1000));
  const threshold = admin.firestore.Timestamp.fromDate(sevenDaysAgo);

  console.log(`🧹 Starting cleanup of notifications older than: ${sevenDaysAgo.toISOString()}`);

  try {
    // Query for old docs
    // Note: Firestore batch delete limit is 500. We loop to handle more if needed.
    const snapshot = await db.collection("user_notifications")
      .where("timestamp", "<", threshold)
      .limit(400) // Safety limit per run
      .get();

    if (snapshot.empty) {
      console.log("✅ No old notifications to delete.");
      return;
    }

    const batch = db.batch();
    let count = 0;

    snapshot.docs.forEach((doc) => {
      batch.delete(doc.ref);
      count++;
    });

    await batch.commit();
    console.log(`🗑️ Successfully deleted ${count} old notifications.`);

  } catch (error) {
    logger.error("❌ Error running cleanup:", error);
  }
});

// ------------------------------------------------------------------
// 14. AUTO-NOTIFY ON APP UPDATE
// ------------------------------------------------------------------
// Triggers when 'settings/app_version' is updated (e.g. by your publish script)
export const notifyUsersOnAppVersionUpdate = onDocumentUpdated(
  "settings/app_version",
  async (event) => {
    // 1. Validation
    if (!event.data) return;
    const oldData = event.data.before.data();
    const newData = event.data.after.data();

    // 2. Check if version actually changed
    if (oldData.currentVersion === newData.currentVersion) {
      return; // It was just a minor edit, ignore.
    }

    const newVersion = newData.currentVersion;
    const releaseNotes = newData.releaseNotes || "Nouvelles fonctionnalités et corrections.";
    const isForced = newData.forceUpdate ? "obligatoire" : "disponible";

    console.log(`🚀 Detected new version: ${newVersion}. Sending notification...`);

    // 3. Prepare Notification
    const message: admin.messaging.Message = {
      topic: "GLOBAL_ANNOUNCEMENTS", // Sent to everyone
      notification: {
        title: `Mise à jour ${newVersion} disponible 🚀`,
        body: `Une nouvelle version est ${isForced}. ${releaseNotes}`,
      },
      data: {
        type: "app_update",
        version: newVersion,
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      android: {
        priority: "high",
        notification: {
          channelId: "high_importance_channel",
          priority: "max",
          defaultSound: true,
        },
      },
    };

    // 4. Send
    try {
      await admin.messaging().send(message);
      console.log("✅ Update notification sent successfully.");
    } catch (error) {
      console.error("❌ Failed to send update notification:", error);
    }
  }
);

// ------------------------------------------------------------------
// 16. WEEKLY MILEAGE REMINDER (FLEET) - ALGERIA SUNDAY
// ------------------------------------------------------------------
// Sends a reminder every Sunday at 10:00 AM (Algeria Time) to check vehicle mileage.

export const weeklyMileageReminder = onSchedule({
  schedule: "every sunday 10:00",
  timeZone: "Africa/Algiers",
}, async (event) => {
  console.log("🚗 Starting Weekly Mileage Reminder...");

  try {
    const message: admin.messaging.Message = {
      topic: "FLEET_REMINDERS", // ⚠️ Ensure users subscribe to this topic!
      notification: {
        title: "Relevé Kilométrique 🚗",
        body: "C'est Dimanche ! Merci de mettre à jour le kilométrage de nos véhicules.",
      },
      data: {
        click_action: "FLUTTER_NOTIFICATION_CLICK",
        screen: "/fleet", // Custom data to guide the app to the Fleet List
        relatedCollection: "vehicles"
      },
      android: {
        priority: "high",
        notification: {
          channelId: "high_importance_channel",
        },
      },
    };

    await admin.messaging().send(message);
    console.log("✅ Weekly mileage reminder sent to FLEET_REMINDERS topic.");
  } catch (error) {
    logger.error("❌ Error sending weekly mileage reminder:", error);
  }
});