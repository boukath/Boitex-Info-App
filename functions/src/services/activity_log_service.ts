// functions/src/services/activity_log_service.ts

import * as admin from "firebase-admin";

/**
* Creates a new log entry in the 'activity_log' collection.
*/
export const createActivityLog = (data: { [key: string]: any }) => {
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