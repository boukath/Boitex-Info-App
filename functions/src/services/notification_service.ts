// functions/src/services/notification_service.ts

import * as admin from "firebase-admin";
// ✅ --- ADDED: Import all our new constants
import * as constants from "../core/constants";

// ------------------------------------------------------------------
// START: PUSH NOTIFICATION HELPERS
// ------------------------------------------------------------------

export const notifyManagers = async (title: string, body: string) => {
const message = {
notification: {title, body},
topic: constants.TOPIC_MANAGERS, // ✅ USE CONSTANT
};

try {
await admin.messaging().send(message);
    console.log(`✅ Sent manager notification: ${title}`);
  } catch (error) {
    console.error("❌ Error sending manager notification:", error);
  }
};

export const notifyServiceTechnique = async (title: string, body: string) => {
  const message = {
    notification: {title, body},
    topic: constants.TOPIC_TECH_ST, // ✅ USE CONSTANT
  };

  try {
    await admin.messaging().send(message);
    console.log(`✅ Sent Service Technique notification: ${title}`);
  } catch (error) {
    console.error("❌ Error sending ST notification:", error);
  }
};

export const notifyServiceIT = async (title: string, body: string) => {
  const message = {
    notification: {title, body},
    topic: constants.TOPIC_TECH_IT, // ✅ USE CONSTANT
  };

  try {
    await admin.messaging().send(message);
    console.log(`✅ Sent Service IT notification: ${title}`);
  } catch (error) {
    console.error("❌ Error sending SIT notification:", error);
  }
};

// ------------------------------------------------------------------
// START: INBOX NOTIFICATION HELPERS
// ------------------------------------------------------------------

/**
 * Creates a new notification document in the 'user_notifications' collection.
 */
export const createUserNotification = (data: {
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
export const getUidsForRoles = async (roles: string[]): Promise<string[]> => {
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
export const createNotificationsForRoles = async (
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
    // ✅ This function now calls the *local* createUserNotification
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
export const getUidsForAllUsers = async (): Promise<string[]> => {
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
export const createNotificationsForAllUsers = async (
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
    // ✅ This function now calls the *local* createUserNotification
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
export const convertTopicsToRoles = (topics: string[]): string[] => {
  return topics.map((topic) => topic.replace(/_/g, " "));
};