// functions/src/installation-handlers.ts

import {onDocumentUpdated} from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";

// ✅ 1. THE SYNC LOGIC (Adapted for Installations)
// This reads the "systems" array you just saved in the App and upserts it to Inventory.
const syncInstallationToInventory = async (installationId: string, data: any) => {
const db = admin.firestore();
const clientId = data.clientId;
const storeId = data.storeId;
const systems = data.systems;

// Basic Validation
if (!clientId || !storeId || !systems || !Array.isArray(systems) || systems.length === 0) {
    logger.log(`ℹ️ Inventory Sync: Skipping Installation ${installationId} (No systems data).`);
    return;
  }

  logger.log(`🔄 Starting Installation Inventory Sync: ${storeId} | ${systems.length} product groups.`);

  // Reference to the store's equipment collection
  const inventoryRef = db
    .collection("clients")
    .doc(clientId)
    .collection("stores")
    .doc(storeId)
    .collection("materiel_installe");

  const batch = db.batch();
  let opCount = 0;

  // Loop through each Product Group (e.g., "Camera x5")
  for (const item of systems) {
    let serials: string[] = item.serialNumbers || [];

    // Loop through each Serial Number
    for (const sn of serials) {
      if (!sn || sn.trim() === "") continue;

      // Check if asset already exists (rare for new installs, but possible)
      const snapshot = await inventoryRef.where("serialNumber", "==", sn).limit(1).get();

      if (snapshot.empty) {
        // 🟢 INSERT NEW ASSET
        const newRef = inventoryRef.doc();
        batch.set(newRef, {
          // Core Data
          name: item.name || "Équipement Inconnu",
          marque: item.marque || "Non spécifiée",
          reference: item.reference || "N/A",
          categorie: item.category || "Autre",
          serialNumber: sn,
          imageUrl: item.image || null,

          // Status
          status: "Installé",
          installDate: admin.firestore.FieldValue.serverTimestamp(),

          // Traceability
          source: "Installation Report",
          firstSeenInstallationId: installationId,
          lastInterventionDate: admin.firestore.FieldValue.serverTimestamp(),
        });
      } else {
        // 🔵 UPDATE EXISTING (Just in case)
        batch.update(snapshot.docs[0].ref, {
          lastInterventionDate: admin.firestore.FieldValue.serverTimestamp(),
          status: "Installé",
          lastInstallationId: installationId,
        });
      }
      opCount++;
    }
  }

  // Commit
  if (opCount > 0) {
    await batch.commit();
    logger.log(`✅ Installation Sync Complete: ${opCount} assets added to Store ${storeId}.`);
  } else {
    logger.log("ℹ️ Installation Sync: No valid serial numbers found to sync.");
  }
};

// ✅ 2. THE TRIGGER
// Listens for changes to 'installations/{id}'
export const onInstallationTermine = onDocumentUpdated(
  {
    document: "installations/{installationId}",
    region: "europe-west1",
  },
  async (event) => {
    if (!event.data) return;

    const before = event.data.before.data();
    const after = event.data.after.data();

    // Only run if status CHANGED to "Terminée"
    // This prevents it from running on every little edit
    if (before?.status !== "Terminée" && after?.status === "Terminée") {
        logger.log(`🚀 Installation ${event.params.installationId} marked as Terminée. Triggering Sync...`);
        await syncInstallationToInventory(event.params.installationId, after);
    }
  }
);