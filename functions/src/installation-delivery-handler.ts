// functions/src/installation-delivery-handler.ts

import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";

// ✅ 1. CREATE TRIGGER (Existing)
// Trigger: When a new Installation document is created
export const createLivraisonFromInstallation = onDocumentCreated(
{
document: "installations/{installationId}",
region: "europe-west1",
},
async (event) => {
    // 1. Safety Checks
    const snapshot = event.data;
    if (!snapshot) return;

    const installData = snapshot.data();
    const installationId = event.params.installationId;

    // Filter: Only include items that are NOT supplied by the client
    // We only want to deliver what we actually sell/stock.
    const allProducts = installData.orderedProducts || [];

    // ✅ CRITICAL FIX: Normalize products for Picking/Logistics Scanner
    // (Added .map to ensure serialNumbers and pickedQuantity exist)
    const productsToDeliver = allProducts
      .filter((p: any) => p.source !== 'client_supply')
      .map((p: any) => ({
        ...p, // Keep existing fields
        // Ensure Logistics fields exist for the app to work:
        serialNumbers: p.serialNumbers || [],
        pickedQuantity: p.pickedQuantity || 0,
        isBulk: p.isBulk || false,
        status: "pending"
      }));

    // If no products to deliver, we stop here.
    if (!productsToDeliver || productsToDeliver.length === 0) {
      logger.log(`ℹ️ No stock products in Installation ${installationId}. Skipping Livraison creation.`);
      return;
    }

    logger.log(`🚀 New Installation detected (${installData.installationCode}). Generating Livraison...`);

    const db = admin.firestore();
    const livraisonsRef = db.collection("livraisons");

    // Determine Service Type (Default to Technique)
    const serviceType = installData.serviceType || "Service Technique";

    // ✅ COUNTER LOGIC SETUP
    const currentYear = new Date().getFullYear();
    const counterRef = db.collection("counters").doc(`livraison_counter_${currentYear}`);

    await db.runTransaction(async (t) => {
      // A. Get the next sequence number (Atomic Increment)
      const counterDoc = await t.get(counterRef);
      let nextIndex = 1;

      if (counterDoc.exists) {
        const data = counterDoc.data();
        if (data && typeof data.lastIndex === 'number') {
          nextIndex = data.lastIndex + 1;
        }
      }

      // B. Generate the sequential code: BL-15/2026
      const blCode = `BL-${nextIndex}/${currentYear}`;

      // C. Update the counter immediately
      t.set(counterRef, { lastIndex: nextIndex }, { merge: true });

      // D. Create the Delivery Document
      const newDocRef = livraisonsRef.doc(); // Auto-ID

      t.set(newDocRef, {
        // Identity
        bonLivraisonCode: blCode,
        linkedInstallationId: installationId,
        serviceType: serviceType,

        // ✅ VISIBILITY FIX: Ensure correct roles can see this document
        accessGroups: [serviceType, "Logistique", "Admin"],

        // Client Info
        clientName: installData.clientName || "N/A",
        clientId: installData.clientId || null,
        contactName: installData.contactName || "",
        contactPhone: installData.clientPhone || "",

        // Destination
        storeName: installData.storeName || "N/A",
        storeId: installData.storeId || null,
        deliveryAddress: installData.storeLocation || "",

        // Content (Filtered & Normalized)
        products: productsToDeliver,

        // Logistics Defaults
        packages: [],
        totalWeight: 0,
        notes: `Généré automatiquement pour l'installation ${installData.installationCode}`,

        // ✅ STATUS FIX: Must match 'À Préparer' to show in the Flutter Tab
        status: "À Préparer",

        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        createdBy: "System (Auto)",
        createdById: "SYSTEM",

        // Defaults for UI compatibility
        deliveryMethod: "Livraison Interne",
        technicianId: null,
        technicianName: null,
      });

      // E. Link Back (Technician can see delivery status)
      t.update(snapshot.ref, {
        linkedLivraisonId: newDocRef.id,
        linkedLivraisonCode: blCode,
        deliveryStatus: "À Préparer"
      });
    });

    logger.log(`✅ Livraison created successfully.`);
  }
);

// ✅ 2. SYNC TRIGGER
// Trigger: When an Installation is EDITED (e.g., adding a forgotten product)
export const syncLivraisonOnInstallationUpdate = onDocumentUpdated(
  {
    document: "installations/{installationId}",
    region: "europe-west1",
  },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    const installationId = event.params.installationId;

    if (!before || !after) return;

    // 1. Check if products actually changed (Save money on unneeded runs)
    const oldProducts = JSON.stringify(before.orderedProducts);
    const newProducts = JSON.stringify(after.orderedProducts);

    if (oldProducts === newProducts) {
      return; // No product changes, ignore.
    }

    logger.log(`🔄 Product list changed for Installation ${installationId}. Attempting sync to Livraison...`);

    const db = admin.firestore();

    // 2. Find the linked Livraison
    // We query by linkedInstallationId to be safe
    const deliveryQuery = await db.collection("livraisons")
      .where("linkedInstallationId", "==", installationId)
      .limit(1)
      .get();

    if (deliveryQuery.empty) {
      logger.log(`⚠️ No linked Livraison found for ${installationId}. Skipping sync.`);
      return;
    }

    const deliveryDoc = deliveryQuery.docs[0];
    const deliveryData = deliveryDoc.data();

    // 3. SAFETY CHECK: Lock updates if shipping started
    const lockedStatuses = ["Expédiée", "Livrée", "Terminée", "Annulée"];
    if (lockedStatuses.includes(deliveryData.status)) {
      logger.warn(`⛔ Cannot sync products: Livraison ${deliveryData.bonLivraisonCode} is already '${deliveryData.status}'.`);
      return;
    }

    // 4. Prepare new list (Filtering out Client Supply items)
    const allNewProducts = after.orderedProducts || [];
    const productsToSync = allNewProducts
      .filter((p: any) => p.source !== 'client_supply')
      .map((p: any) => ({
        ...p,
        // Ensure fields exist for sync as well
        serialNumbers: p.serialNumbers || [],
        pickedQuantity: p.pickedQuantity || 0,
        isBulk: p.isBulk || false,
        status: "pending"
      }));

    // 5. Update the Delivery Note
    await deliveryDoc.ref.update({
      products: productsToSync,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      notes: (deliveryData.notes || "") + "\n[System] Liste produits mise à jour suite modif installation."
    });

    logger.log(`✅ Sync successful: Livraison ${deliveryData.bonLivraisonCode} updated with ${productsToSync.length} items.`);
  }
);