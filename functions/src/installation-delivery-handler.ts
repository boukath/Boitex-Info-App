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

        // ⚠️ FIXED: Now checks for 'count' to match your Flutter App/Database
        if (data && typeof data.count === 'number') {
          nextIndex = data.count + 1;
        }
      }

      // B. Generate the sequential code: BL-15/2026
      const blCode = `BL-${nextIndex}/${currentYear}`;

      // C. Update the counter immediately
      // ⚠️ FIXED: Updates 'count' field so Flutter sees the new number too
      t.set(counterRef, { count: nextIndex }, { merge: true });

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

// ✅ 2. SMART SYNC TRIGGER
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
    const oldProductsRaw = JSON.stringify(before.orderedProducts);
    const newProductsRaw = JSON.stringify(after.orderedProducts);

    if (oldProductsRaw === newProductsRaw) {
      return; // No product changes, ignore.
    }

    logger.log(`🔄 Product list changed for Installation ${installationId}. Analyzing Sync Logic...`);

    const db = admin.firestore();

    // 2. Find the linked Livraison
    // Get the most recently created delivery linked to this installation
    const deliveryQuery = await db.collection("livraisons")
      .where("linkedInstallationId", "==", installationId)
      .orderBy("createdAt", "desc")
      .limit(1)
      .get();

    if (deliveryQuery.empty) {
      logger.log(`⚠️ No linked Livraison found for ${installationId}. Skipping sync.`);
      return;
    }

    const deliveryDoc = deliveryQuery.docs[0];
    const deliveryData = deliveryDoc.data();
    const currentStatus = deliveryData.status;

    // 3. Normalize New Products (from Installation)
    // We apply the same normalization rules as the Create Trigger
    const allNewProducts = after.orderedProducts || [];
    const normalizedNewProducts = allNewProducts
      .filter((p: any) => p.source !== 'client_supply')
      .map((p: any) => ({
        ...p,
        serialNumbers: p.serialNumbers || [],
        pickedQuantity: p.pickedQuantity || 0,
        isBulk: p.isBulk || false,
        status: "pending"
      }));

    // ==================================================================================
    // 🧠 LOGIC A: OPEN or ON THE ROAD -> EDIT & MERGE (Preserve Picking)
    // ==================================================================================
    const openStatuses = ["À Préparer", "En Cours de Livraison"];

    if (openStatuses.includes(currentStatus)) {
        logger.log(`📝 Livraison is '${currentStatus}'. Performing Smart Merge...`);

        // Get the existing state of the delivery (to save scanned serials)
        const oldDeliveryProducts = deliveryData.products || [];

        // MERGE LOGIC:
        // 1. Loop through the NEW list from installation.
        // 2. If item exists in OLD list, copy its 'pickedQuantity' and 'serialNumbers'.
        // 3. This ensures that if we add a product, we don't wipe the work the warehouse already did.
        const mergedProducts = normalizedNewProducts.map((newP: any) => {
            // Match by Product ID
            const existingP = oldDeliveryProducts.find((op: any) => op.productId === newP.productId);

            if (existingP) {
                return {
                    ...newP, // Update fields like Name, Description, Target Quantity
                    // ✅ PRESERVE PICKING DATA:
                    pickedQuantity: existingP.pickedQuantity || 0,
                    serialNumbers: existingP.serialNumbers || [],
                    // Preserve item status if it exists, else pending
                    status: existingP.status || "pending"
                };
            }
            // New item -> Defaults are already set by normalization
            return newP;
        });

        // Determine Status Update
        // Logic: If driver was "En Cours", force back to "À Préparer" so they notice the change.
        let statusUpdate = {};
        if (currentStatus === "En Cours de Livraison") {
            statusUpdate = { status: "À Préparer" };
            logger.log(`🚚 Status was 'En Cours', reverting to 'À Préparer' for safety.`);
        }

        // Apply Update
        await deliveryDoc.ref.update({
            products: mergedProducts,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            notes: (deliveryData.notes || "") + "\n[System] Liste mise à jour (Smart Sync).",
            ...statusUpdate
        });

        return;
    }

    // ==================================================================================
    // 🧠 LOGIC B: CLOSED -> COMPARE & CREATE COMPLEMENT (Change Order)
    // ==================================================================================
    const closedStatuses = ["Expédiée", "Livrée", "Terminée", "Annulée"];

    if (closedStatuses.includes(currentStatus)) {
        logger.log(`🔒 Livraison is '${currentStatus}'. Calculating Difference for Complementary Delivery...`);

        const oldDeliveryProducts = deliveryData.products || [];
        const productsToCreate: any[] = [];

        // Diff Calculation
        for (const newP of normalizedNewProducts) {
            const existingP = oldDeliveryProducts.find((op: any) => op.productId === newP.productId);

            if (!existingP) {
                // Completely new product -> Add full quantity
                productsToCreate.push(newP);
            } else {
                // Existing product -> Check for quantity increase
                const qtyDiff = (newP.quantity || 0) - (existingP.quantity || 0);
                if (qtyDiff > 0) {
                    productsToCreate.push({
                        ...newP,
                        quantity: qtyDiff, // Only the extra amount
                        pickedQuantity: 0,
                        serialNumbers: []
                    });
                }
            }
        }

        if (productsToCreate.length === 0) {
            logger.log(`✅ No quantity increase or new items detected. No Complementary Delivery needed.`);
            return;
        }

        logger.log(`🆕 Creating Complementary Delivery for ${productsToCreate.length} items...`);

        // Transaction to generate new BL Code and Create Doc
        const currentYear = new Date().getFullYear();
        const counterRef = db.collection("counters").doc(`livraison_counter_${currentYear}`);
        const livraisonsRef = db.collection("livraisons");

        await db.runTransaction(async (t) => {
            const counterDoc = await t.get(counterRef);
            let nextIndex = 1;
            if (counterDoc.exists) {
                const data = counterDoc.data();
                if (data && typeof data.count === 'number') {
                    nextIndex = data.count + 1;
                }
            }

            const standardBlCode = `BL-${nextIndex}/${currentYear}`;

            // Update Counter
            t.set(counterRef, { count: nextIndex }, { merge: true });

            // Create Doc
            const newDocRef = livraisonsRef.doc();

            t.set(newDocRef, {
                // Identity
                bonLivraisonCode: standardBlCode,
                linkedInstallationId: installationId,
                isComplementary: true, // Marker to distinguish
                originalLivraisonId: deliveryDoc.id,
                serviceType: deliveryData.serviceType || "Service Technique",
                accessGroups: deliveryData.accessGroups || ["Service Technique", "Logistique", "Admin"],

                // Client / Dest (Copy from latest installation data to be safe)
                clientName: after.clientName || deliveryData.clientName,
                clientId: after.clientId || deliveryData.clientId,
                contactName: after.contactName || deliveryData.contactName,
                contactPhone: after.clientPhone || deliveryData.contactPhone,

                storeName: after.storeName || deliveryData.storeName,
                storeId: after.storeId || deliveryData.storeId,
                deliveryAddress: after.storeLocation || deliveryData.deliveryAddress,

                // Content
                products: productsToCreate,

                // Meta
                status: "À Préparer",
                notes: `[Complément] Suite à modification de l'installation ${after.installationCode}. Reliquat de BL ${deliveryData.bonLivraisonCode}.`,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                createdBy: "System (Smart Sync)",
                createdById: "SYSTEM",

                deliveryMethod: deliveryData.deliveryMethod || "Livraison Interne",
            });
        });

        logger.log(`✅ Complementary Delivery Created.`);
    }
  }
);