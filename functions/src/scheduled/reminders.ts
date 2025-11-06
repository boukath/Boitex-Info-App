// functions/src/scheduled/reminders.ts

import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import {onSchedule} from "firebase-functions/v2/scheduler";
// ✅ --- ADDED: Import our new service functions ---
import {
createNotificationsForRoles,
convertTopicsToRoles,
} from "../services/notification_service";

//
// ⭐️ ----- NEW FILE ----- ⭐️
//
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
    const rolesWithSpaces = convertTopicsToRoles(targetRoles); // ✅ USE IMPORTED FUNCTION
    await createNotificationsForRoles(rolesWithSpaces, { // ✅ USE IMPORTED FUNCTION
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