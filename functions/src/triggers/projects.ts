// functions/src/triggers/projects.ts

import {onDocumentCreated, onDocumentUpdated} from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin"; // ✅ We need this for admin.messaging()
// ✅ --- ADDED: Import our new service functions ---
import {createActivityLog} from "../services/activity_log_service";
import {
notifyManagers,
createNotificationsForRoles,
} from "../services/notification_service";
// ✅ --- ADDED: Import our new constants ---
import {
ROLES_MANAGERS,
ROLES_TECH_IT,
TOPICS_MANAGERS_AND_ADMINS, // ✅ USE THE NEW TOPIC LIST
} from "../core/constants";

//
// ⭐️ ----- NEW FILE ----- ⭐️
//
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

    // ✅ --- FIX: Use the constant list of topics ---
    const targetTopics = TOPICS_MANAGERS_AND_ADMINS;

    const sendPromises = targetTopics.map(async (topic) => { // ✅ Use targetTopics
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
    // ✅ --- END FIX ---

    // ✅ ADD TO INBOX
    await createNotificationsForRoles(ROLES_MANAGERS, { // ✅ USE IMPORTED FUNCTION & CONSTANT
      title,
      body,
      relatedDocId: snapshot.id,
      relatedCollection: "projects",
    });

    console.log(`✅ Project creation notification sent for: ${projectName}`);
  }
);

//
// ⭐️ ----- NEW FILE ----- ⭐️
//
export const onProjectStatusUpdate_v2 = onDocumentUpdated(
  "projects/{projectId}",
  async (event) => {
    if (!event.data) return;

    const before = event.data.before.data();
    const after = event.data.after.data();

    // ✅ --- NEW IT EVALUATION LOGIC ---
    if (!before.it_evaluation && after.it_evaluation) {
      createActivityLog({ // ✅ USE IMPORTED FUNCTION
        service: "it",
        taskType: "Evaluation IT", // ⭐️ This matches the app's query
        taskTitle: after.clientName || "Évaluation IT",
        storeName: after.storeName || "magasin",
        storeLocation: after.storeLocation || "",
        displayName: after.createdByName || "Inconnu",
        createdByName: after.createdByName || "Inconnu",
        details: `Terminée pour ${after.storeName || "magasin"}`,
        status: after.status, // Current project status
        relatedDocId: event.data.after.id,
        relatedCollection: "projects",
      });

      // ✅ ADD TO INBOX for IT team
      await createNotificationsForRoles(ROLES_TECH_IT, { // ✅ USE IMPORTED FUNCTION & CONSTANT
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

    await notifyManagers(title, body); // ✅ USE IMPORTED FUNCTION
    // ✅ ADD TO INBOX
    await createNotificationsForRoles(ROLES_MANAGERS, { // ✅ USE IMPORTED FUNCTION & CONSTANT
      title,
      body,
      relatedDocId: event.data.after.id,
      relatedCollection: "projects",
    });

    console.log(`✅ Project status update notification sent for ${projectName}`);
  }
);