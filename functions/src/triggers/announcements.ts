// functions/src/triggers/announcements.ts

import {onDocumentCreated} from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
// ✅ --- ADDED: Import our new service functions ---
import {createNotificationsForAllUsers} from "../services/notification_service";
// ✅ --- ADDED: Import our new constants ---
import {TOPIC_GLOBAL_ANNOUNCEMENTS} from "../core/constants";

/**
* Sends a notification to ALL users when a new message
* is posted in any announcement channel.
*/
//
// ⭐️ ----- NEW FILE ----- ⭐️
//
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
      topic: TOPIC_GLOBAL_ANNOUNCEMENTS, // ✅ USE CONSTANT
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
    await createNotificationsForAllUsers({ // ✅ USE IMPORTED FUNCTION
      title: payload.notification.title,
      body: payload.notification.body,
      relatedDocId: params.channelId, // The channel ID
      relatedCollection: "channels", // To know to navigate to the channel
    });
  });