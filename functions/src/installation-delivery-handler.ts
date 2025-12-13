// functions/src/installation-delivery-handler.ts

import {onDocumentCreated} from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";

// ✅ THE AUTOMATION LOGIC
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

    // Only proceed if there are products to deliver
    // We check 'orderedProducts' because that's where the "Plan" is stored
    const orderedProducts = installData.orderedProducts;
    if (!orderedProducts || !Array.isArray(orderedProducts) || orderedProducts.length === 0) {
      logger.log(`ℹ️ No products in Installation ${installationId}. Skipping Livraison creation.`);
      return;
    }

    logger.log(`🚀 New Installation detected (${installData.installationCode}). Generating Livraison...`);

    const db = admin.firestore();
    const livraisonsRef = db.collection("livraisons");

    // 2. Generate a Linked Code (e.g., BL-INST-5/2025)
    const blCode = `BL-${installData.installationCode || "DRAFT"}`;

    // 3. Map the Data (Transformation)
    const products = orderedProducts.map((p: any) => ({
      productId: p.productId || "",
      productName: p.productName || "Produit Inconnu",
      partNumber: p.reference || p.partNumber || "N/A",
      marque: p.marque || p.brand || "Non spécifiée",
      quantity: p.quantity || 1,

      // New fields for UI support
      imageUrl: p.image || p.imageUrl || null,
      category: p.category || "Autre",

      // Logistics fields
      serialNumbers: [],
      status: "À Préparer"
    }));

    // 4. Create the Delivery Document
    await db.runTransaction(async (t) => {
      const newDocRef = livraisonsRef.doc(); // Auto-ID

      t.set(newDocRef, {
        // Identity
        bonLivraisonCode: blCode,
        linkedInstallationId: installationId,
        serviceType: installData.serviceType || "Service Technique",

        // Client Info
        clientName: installData.clientName || "N/A",
        clientId: installData.clientId || null,
        contactName: installData.contactName || "",
        contactPhone: installData.clientPhone || "",

        // Destination
        storeName: installData.storeName || "N/A",
        storeId: installData.storeId || null,
        deliveryAddress: installData.storeLocation || "",

        // Content
        products: products,
        notes: `Généré automatiquement pour l'installation ${installData.installationCode}`,

        // Status & Meta
        status: "À Préparer",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        createdBy: "System (Auto)",
        createdById: "SYSTEM",

        // Defaults for UI compatibility
        deliveryMethod: "Livraison Interne",
        technicianId: null,
        technicianName: null,
      });

      // Link Back (Technician can see delivery status)
      t.update(snapshot.ref, {
        linkedLivraisonId: newDocRef.id,
        linkedLivraisonCode: blCode
      });
    });

    logger.log(`✅ Livraison ${blCode} created successfully with ${products.length} items.`);
  }
);