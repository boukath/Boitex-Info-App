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
    let serials = item.serialNumbers || [];

    // If no serials are tracked, we might still want to add the item (Generic)
    // For now, assuming we stick to serial-based tracking as per previous logic.
    if (serials.length === 0) continue;

    // Loop through Serials
    for (const serial of serials) {
      if (!serial) continue; // Skip empty serials

      // Check if this serial already exists in this store
      // NOTE: In a real app, serials should be unique globally or checked more rigorously.
      const snapshot = await inventoryRef.where("serialNumber", "==", serial).get();

      if (snapshot.empty) {
        // 🟢 CREATE NEW
        const newDocRef = inventoryRef.doc();
        batch.set(newDocRef, {
          // Core Data
          productId: item.id || null,
          nom: item.name || "Produit Inconnu",
          serialNumber: serial,

          // ✅ FIXED: Added missing fields here
          marque: item.marque || "N/A",
          reference: item.reference || "N/A",
          category: item.category || "N/A",
          image: item.image || null,

          status: "Installé",

          // Source Info
          installDate: admin.firestore.FieldValue.serverTimestamp(),
          source: "Installation Report",
          firstSeenInstallationId: installationId,
          lastInterventionDate: admin.firestore.FieldValue.serverTimestamp(),
        });
      } else {
        // 🔵 UPDATE EXISTING
        // We also update the details here in case they were N/A before!
        batch.update(snapshot.docs[0].ref, {
          lastInterventionDate: admin.firestore.FieldValue.serverTimestamp(),
          status: "Installé",
          lastInstallationId: installationId,

          // ✅ FIXED: Update details on re-sync
          productId: item.id || null,
          nom: item.name || snapshot.docs[0].data().nom, // Keep existing name if preferred, or overwrite
          marque: item.marque || snapshot.docs[0].data().marque,
          reference: item.reference || snapshot.docs[0].data().reference,
          category: item.category || snapshot.docs[0].data().category,
          image: item.image || snapshot.docs[0].data().image,
        });
      }
      opCount++;
    }
  }

  // Commit
  if (opCount > 0) {
    await batch.commit();
    logger.log(`✅ Installation Sync Complete: ${opCount} assets added/updated in Store ${storeId}.`);
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
      const installationId = event.params.installationId;
      await syncInstallationToInventory(installationId, after);
    }
  }
);