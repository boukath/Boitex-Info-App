import {onDocumentCreated, onDocumentUpdated} from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";
import {onSchedule} from "firebase-functions/v2/scheduler";

// ------------------------------------------------------------------
// CONSTANTS & CONFIGURATION
// ------------------------------------------------------------------

// ✅ RESTORED: The compiler will accept this now because we use it below.
const GLOBAL_ANNOUNCEMENTS_TOPIC = "GLOBAL_ANNOUNCEMENTS";

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
 */
const createNotificationsForRoles = async (
  roles: string[],
  notificationData: {
    title: string;
    body: string;
    relatedDocId?: string;
    relatedCollection?: string;
  },
  category?: string
) => {
  let users = await getUsersForRoles(roles);
  if (users.length === 0) return;

  // ✅ FILTER: Remove users who turned this category OFF
  if (category) {
    users = users.filter((u) => {
      // If setting exists and is FALSE, we skip.
      if (u.notificationSettings && u.notificationSettings[category] === false) {
        return false;
      }
      return true;
    });
  }

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
  category?: string
) => {
  let users = await getUsersForAllUsers();
  if (users.length === 0) return;

  if (category) {
    users = users.filter((u) => {
      if (u.notificationSettings && u.notificationSettings[category] === false) {
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
  category?: string
) => {
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

  const title = `Nouvelle Intervention: ${data.interventionCode}`;
  const body = `Client: ${data.clientName} - Magasin: ${data.storeName}`;
  const logService = data.serviceType === "Service IT" ? "it" : "technique";

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

  const notificationData = { title, body, relatedDocId: snapshot.id, relatedCollection: "interventions" };

  await createNotificationsForRoles(ROLES_MANAGERS, notificationData, "interventions");

  if (data.serviceType === "Service IT") {
    await createNotificationsForRoles(ROLES_TECH_IT, notificationData, "interventions");
  } else {
    await createNotificationsForRoles(ROLES_TECH_ST, notificationData, "interventions");
  }
});

export const onInterventionStatusUpdate_v2 = onDocumentUpdated("interventions/{interventionId}", async (event) => {
  if (!event.data) return;
  const before = event.data.before.data();
  const after = event.data.after.data();

  if (before.status === after.status) return;

  const logService = after.serviceType === "Service IT" ? "it" : "technique";

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

  const title = `Mise à Jour Intervention: ${after.interventionCode || "N/A"}`;
  const body = `Statut: '${before.status}' -> '${after.status}'`;
  const notificationData = { title, body, relatedDocId: event.data.after.id, relatedCollection: "interventions" };

  await createNotificationsForRoles(ROLES_MANAGERS, notificationData, "interventions");
  if (logService === "it") {
    await createNotificationsForRoles(ROLES_TECH_IT, notificationData, "interventions");
  } else {
    await createNotificationsForRoles(ROLES_TECH_ST, notificationData, "interventions");
  }
});

// 2. SAV TICKETS
export const onSavTicketCreated_v2 = onDocumentCreated("sav_tickets/{ticketId}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) return;
  const data = snapshot.data();

  const title = `Nouveau Ticket SAV: ${data.savCode}`;
  const body = `Client: ${data.clientName} - Produit: ${data.productName}`;

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

  await createNotificationsForRoles(ROLES_MANAGERS, notificationData, "sav_tickets");
  await createNotificationsForRoles(ROLES_TECH_ST, notificationData, "sav_tickets");
});

export const onSavTicketUpdate_v2 = onDocumentUpdated("sav_tickets/{ticketId}", async (event) => {
  if (!event.data) return;
  const before = event.data.before.data();
  const after = event.data.after.data();

  if (before.status === after.status) return;

  const title = `Mise à Jour SAV: ${after.savCode}`;
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

  await createNotificationsForRoles(ROLES_MANAGERS, notificationData, "sav_tickets");
  if (["En attente de pièce", "Terminé"].includes(after.status)) {
    await createNotificationsForRoles(ROLES_TECH_ST, notificationData, "sav_tickets");
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

  await createNotificationsForRoles(ROLES_MANAGERS, notificationData, "sav_tickets");
});

export const onReplacementRequestUpdate_v2 = onDocumentUpdated("replacement_requests/{requestId}", async (event) => {
  if (!event.data) return;
  const before = event.data.before.data();
  const after = event.data.after.data();

  const beforeStatus = before.requestStatus;
  const afterStatus = after.requestStatus;
  const requestCode = after.replacementRequestCode;

  if (beforeStatus !== "Approuvé" && afterStatus === "Approuvé") {
    const title = `Remplacement Approuvé: ${requestCode}`;
    const body = `Préparez la pièce pour ${after.clientName} | Produit: ${after.productName}`;
    const notificationData = { title, body, relatedDocId: event.data.after.id, relatedCollection: "replacement_requests" };

    await createNotificationsForRoles(ROLES_TECH_ST, notificationData, "sav_tickets");
    await createNotificationsForRoles(ROLES_MANAGERS, notificationData, "sav_tickets");
  }

  if (beforeStatus !== afterStatus) {
    const title = "Mise à Jour: Demande de Remplacement";
    const body = `Le statut pour ${after.replacementRequestCode || "N/A"} est maintenant: ${afterStatus}.`;
    await createNotificationsForRoles(ROLES_MANAGERS, { title, body, relatedDocId: event.data.after.id, relatedCollection: "replacement_requests" }, "sav_tickets");
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

  const title = `Nouvelle Demande d'Achat: ${requisitionCode}`;
  const body = `Demandée par: ${requestedBy} - ${itemCount} article(s)`;

  await createNotificationsForRoles(ROLES_MANAGERS, { title, body, relatedDocId: snapshot.id, relatedCollection: "requisitions" }, "requisitions");
});

export const onRequisitionStatusUpdate_v2 = onDocumentUpdated("requisitions/{requisitionId}", async (event) => {
  if (!event.data) return;
  const before = event.data.before.data();
  const after = event.data.after.data();

  if (before.status === after.status) return;

  const title = `Mise à Jour: ${after.requisitionCode || "N/A"}`;
  const body = `Statut: ${after.status || "Inconnu"} - Demandé par: ${after.requestedBy}`;

  await createNotificationsForRoles(ROLES_MANAGERS, { title, body, relatedDocId: event.data.after.id, relatedCollection: "requisitions" }, "requisitions");
});

// 5. PROJECTS
export const onProjectCreated_v2 = onDocumentCreated("projects/{projectId}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) return;
  const data = snapshot.data();

  const title = `Nouveau Projet: ${data.projectName || "Nouveau Projet"}`;
  const body = `Client: ${data.clientName || "N/A"}`;

  await createNotificationsForRoles(ROLES_MANAGERS, { title, body, relatedDocId: snapshot.id, relatedCollection: "projects" }, "projects");
});

export const onProjectStatusUpdate_v2 = onDocumentUpdated("projects/{projectId}", async (event) => {
  if (!event.data) return;
  const before = event.data.before.data();
  const after = event.data.after.data();

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
    }, "projects");
  }

  // Status Change Logic
  if (before.status !== after.status) {
    const title = `Mise à Jour Projet: ${after.projectName}`;
    const body = `Client: ${after.clientName} - Statut: ${after.status}`;
    await createNotificationsForRoles(ROLES_MANAGERS, { title, body, relatedDocId: event.data.after.id, relatedCollection: "projects" }, "projects");
  }
});

// 6. MISSIONS (NEW)
export const onMissionCreated_v2 = onDocumentCreated("missions/{missionId}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) return;
  const data = snapshot.data();

  const title = `Nouvelle Mission: ${data.missionCode || "N/A"}`;
  const body = `${data.title} - ${data.destinations?.length || 0} Destination(s)`;

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
  await createNotificationsForRoles(ROLES_MANAGERS, notificationData, "missions");

  // Notify Assigned Technicians
  const assignedIds = data.assignedTechniciansIds as string[];
  if (assignedIds && assignedIds.length > 0) {
    await createNotificationsForUsers(assignedIds, notificationData, "missions");
  }
});

// 7. INSTALLATIONS
export const onInstallationCreated_v2 = onDocumentCreated("installations/{installationId}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) return;
  const data = snapshot.data();

  const title = `Nouvelle Installation: ${data.installationCode || "N/A"}`;
  const body = `Client: ${data.clientName} - Magasin: ${data.storeName}`;

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

  await createNotificationsForRoles(ROLES_MANAGERS, notificationData, "installations");
  await createNotificationsForRoles(ROLES_TECH_ST, notificationData, "installations");
});

export const onInstallationStatusUpdate_v2 = onDocumentUpdated("installations/{installationId}", async (event) => {
  if (!event.data) return;
  const before = event.data.before.data();
  const after = event.data.after.data();

  if (before.status === after.status) return;

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

  const title = `Mise à Jour Installation: ${after.installationCode || "N/A"}`;
  const body = `Client: ${after.clientName} - Statut: ${after.status}`;
  const notificationData = { title, body, relatedDocId: event.data.after.id, relatedCollection: "installations" };

  await createNotificationsForRoles(ROLES_MANAGERS, notificationData, "installations");
  await createNotificationsForRoles(ROLES_TECH_ST, notificationData, "installations");
});

// 8. LIVRAISONS
export const onLivraisonCreated_v2 = onDocumentCreated("livraisons/{livraisonId}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) return;
  const data = snapshot.data();

  const title = `Nouvelle Livraison: ${data.bonLivraisonCode || "N/A"}`;
  const body = `Client: ${data.clientName} | Service: ${data.serviceType}`;

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

  await createNotificationsForRoles([...ROLES_MANAGERS, ...ROLES_TECH_ST, ...ROLES_TECH_IT], notificationData, "livraisons");
});

export const onLivraisonStatusUpdate_v2 = onDocumentUpdated("livraisons/{livraisonId}", async (event) => {
  if (!event.data) return;
  const before = event.data.before.data();
  const after = event.data.after.data();

  if (before.status === after.status) return;

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

  const title = `Mise à Jour Livraison: ${after.bonLivraisonCode || "N/A"}`;
  const body = `Client: ${after.clientName} - Statut: ${after.status}`;
  const notificationData = { title, body, relatedDocId: event.data.after.id, relatedCollection: "livraisons" };

  await createNotificationsForRoles(ROLES_MANAGERS, notificationData, "livraisons");
  await createNotificationsForRoles(ROLES_TECH_ST, notificationData, "livraisons");
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

  await createNotificationsForRoles(ROLES_TECH_IT, { title, body, relatedDocId: snapshot.id, relatedCollection: "support_tickets" }, "interventions");
});

export const onSupportTicketUpdated_v2 = onDocumentUpdated("support_tickets/{ticketId}", async (event) => {
  if (!event.data) return;
  const before = event.data.before.data();
  const after = event.data.after.data();

  if (before.status === after.status) return;

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
  }, "interventions");
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

  await createNotificationsForRoles(ROLES_TECH_IT, { title, body, relatedDocId: snapshot.id, relatedCollection: "maintenance_it" }, "interventions");
});

export const onMaintenanceTaskUpdated_v2 = onDocumentUpdated("maintenance_it/{taskId}", async (event) => {
  if (!event.data) return;
  const before = event.data.before.data();
  const after = event.data.after.data();

  if (before.status === after.status) return;

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
  }, "interventions");
});

// 10. ANNOUNCEMENTS
export const onNewAnnouncementMessage = onDocumentCreated("channels/{channelId}/messages/{messageId}", async (event) => {
  const message = event.data?.data();
  const params = event.params;
  if (!message) return;

  const messageText: string = message.text || "Nouveau message";
  const senderName: string = message.senderName || "Boitex Info";
  let channelName = "Annonces";

  try {
    const channelDoc = await admin.firestore().collection("channels").doc(params.channelId).get();
    if (channelDoc.exists) channelName = channelDoc.data()?.name || channelName;
  } catch (_) {}

  const bodyText = messageText.length > 100 ? `${messageText.substring(0, 97)}...` : messageText;
  const title = `Nouveau message dans #${channelName}`;
  const body = `${senderName}: ${bodyText}`;

  // ✅ RESTORED: Topic logic is BACK and USED here!
  // This satisfies the compiler and your requirement.
  try {
    await admin.messaging().send({ notification: { title, body }, topic: GLOBAL_ANNOUNCEMENTS_TOPIC });
  } catch (_) {}

  await createNotificationsForAllUsers({ title, body, relatedDocId: params.channelId, relatedCollection: "channels" });
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