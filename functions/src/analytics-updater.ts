// functions/src/analytics-updater.ts

import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import { DocumentSnapshot } from "firebase-admin/firestore";

// ==================================================================
// 1️⃣ HELPERS
// ==================================================================

// ✅ SPECIFIC HELPER FOR INTERVENTIONS (Smart Filtering)
async function getInterventionStats(db: admin.firestore.Firestore) {
  try {
    const colRef = db.collection("interventions");

    // Only count these valid active statuses for the Total
    const activeStatuses = [
      'Nouvelle Demande',
      'Nouveau',
      'En cours',
      'Terminé',
      'En attente',
      'Clôturé'
    ];

    // 1. Count TOTAL (Active only)
    const totalSnap = await colRef.where("status", "in", activeStatuses).count().get();

    // 2. Count SUCCESS (Strictly "Clôturé")
    const successSnap = await colRef.where("status", "==", "Clôturé").count().get();

    return { total: totalSnap.data().count, success: successSnap.data().count };
  } catch (e) {
    console.error("⚠️ Error counting Interventions:", e);
    return { total: 0, success: 0 };
  }
}

// Generic helper for other collections
async function getCollectionStats(db: admin.firestore.Firestore, collectionName: string, successStatus: string) {
  try {
    const colRef = db.collection(collectionName);
    const totalSnap = await colRef.count().get();
    const successSnap = await colRef.where("status", "==", successStatus).count().get();
    return { total: totalSnap.data().count, success: successSnap.data().count };
  } catch (e) {
    console.error(`⚠️ Error counting ${collectionName}:`, e);
    return { total: 0, success: 0 };
  }
}

// ✅ LOGISTICS STATS (Advanced Time-Series Version)
async function getLogisticsStats(db: admin.firestore.Firestore) {
  try {
    // A. Low Stock (< 5)
    const lowStockSnap = await db.collection("produits")
      .where("quantiteEnStock", "<", 5)
      .count()
      .get();

    // B. Advanced Flow Calculation (Time-Series)
    // ✅ MODIFIED: Use Date-based filtering (Last 30 Days)
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    const historySnapshot = await db.collectionGroup("stock_history")
      .where("timestamp", ">=", admin.firestore.Timestamp.fromDate(thirtyDaysAgo))
      .orderBy("timestamp", "desc") // ✅ Gets everything from the last 30 days
      .get();

    let incomingTotal = 0;
    let outgoingTotal = 0;
    const dailyMap: Record<string, { in: number, out: number }> = {};

    historySnapshot.docs.forEach((doc) => {
      const data = doc.data();
      const change = data.change || 0;

      // 1. Calculate Totals
      if (change > 0) incomingTotal += change;
      else outgoingTotal += Math.abs(change);

      // 2. Group by Date (YYYY-MM-DD) for the Chart
      if (data.timestamp) {
        // Safe conversion of Firestore Timestamp to YYYY-MM-DD string
        const dateKey = data.timestamp.toDate().toISOString().split('T')[0];

        if (!dailyMap[dateKey]) {
          dailyMap[dateKey] = { in: 0, out: 0 };
        }

        if (change > 0) {
          dailyMap[dateKey].in += change;
        } else {
          // Store positive number for chart visualization
          dailyMap[dateKey].out += Math.abs(change);
        }
      }
    });

    return {
      lowStock: lowStockSnap.data().count,
      incoming: incomingTotal,
      outgoing: outgoingTotal,
      dailyHistory: dailyMap // ✅ The missing piece for your chart
    };

  } catch (e) {
    console.error("⚠️ Error in Logistics Stats:", e);
    return { lowStock: 0, incoming: 0, outgoing: 0, dailyHistory: {} };
  }
}

// ==================================================================
// 2️⃣ TECHNICIAN LEADERBOARD
// ==================================================================
async function updateTechnicianCounters(
  change: functions.Change<DocumentSnapshot>,
  techFieldName: string,
  successStatus: string
) {
  const db = admin.firestore();
  const before = change.before.exists ? change.before.data() : null;
  const after = change.after.exists ? change.after.data() : null;

  const techsBefore: string[] = (before && before.status === successStatus)
    ? (Array.isArray(before[techFieldName]) ? before[techFieldName] : (before[techFieldName] ? [before[techFieldName]] : []))
    : [];

  const techsAfter: string[] = (after && after.status === successStatus)
    ? (Array.isArray(after[techFieldName]) ? after[techFieldName] : (after[techFieldName] ? [after[techFieldName]] : []))
    : [];

  const toIncrement = techsAfter.filter(t => !techsBefore.includes(t));
  const toDecrement = techsBefore.filter(t => !techsAfter.includes(t));

  if (toIncrement.length === 0 && toDecrement.length === 0) return;

  const batch = db.batch();
  const countersRef = db.collection("analytics_dashboard").doc("technician_performance").collection("counters");

  toIncrement.forEach(techName => {
    if (!techName) return;
    const docRef = countersRef.doc(techName);
    batch.set(docRef, { count: admin.firestore.FieldValue.increment(1), name: techName }, { merge: true });
  });

  toDecrement.forEach(techName => {
    if (!techName) return;
    const docRef = countersRef.doc(techName);
    batch.set(docRef, { count: admin.firestore.FieldValue.increment(-1) }, { merge: true });
  });

  await batch.commit();
  await refreshTopTechnicians(db);
}

async function refreshTopTechnicians(db: admin.firestore.Firestore) {
  const topSnaps = await db.collection("analytics_dashboard")
    .doc("technician_performance")
    .collection("counters")
    .orderBy("count", "desc")
    .limit(5)
    .get();

  const topTechsMap: { [key: string]: number } = {};
  topSnaps.forEach(doc => {
    const data = doc.data();
    if (data.count > 0) topTechsMap[data.name] = data.count;
  });

  await db.collection("analytics_dashboard").doc("stats_overview").set({ top_technicians: topTechsMap }, { merge: true });
}

// ==================================================================
// 3️⃣ MASTER UPDATE FUNCTION
// ==================================================================
async function updateGlobalDashboard() {
  const db = admin.firestore();
  const statsDocRef = db.collection("analytics_dashboard").doc("stats_overview");

  try {
    console.log("🔄 Starting Dashboard Update...");

    const [
      interventionStats,
      installationStats,
      livraisonStats,
      missionStats,
      savStats,
      logisticsStats // ✅ Now contains dailyHistory
    ] = await Promise.all([
      getInterventionStats(db), // Smart Filter
      getCollectionStats(db, "installations", "Terminée"),
      getCollectionStats(db, "livraisons", "Livré"),
      getCollectionStats(db, "missions", "Terminée"),
      getCollectionStats(db, "sav_tickets", "Retourné"),
      getLogisticsStats(db)
    ]);

    const grandTotal = interventionStats.total + installationStats.total + livraisonStats.total + missionStats.total + savStats.total;
    const grandSuccess = interventionStats.success + installationStats.success + livraisonStats.success + missionStats.success + savStats.success;
    const globalSuccessRate = grandTotal > 0 ? parseFloat(((grandSuccess / grandTotal) * 100).toFixed(1)) : 0.0;

    await statsDocRef.set({
      total_interventions_month: grandTotal,
      success_rate: globalSuccessRate,
      interventions_by_type: {
        "Interventions": interventionStats.total,
        "Installations": installationStats.total,
        "Livraisons": livraisonStats.total,
        "Missions": missionStats.total,
        "SAV": savStats.total,
      },
      // Detailed Performance Map
      category_performance: {
        "Interventions": { "total": interventionStats.total, "success": interventionStats.success },
        "Installations": { "total": installationStats.total, "success": installationStats.success },
        "Livraisons": { "total": livraisonStats.total, "success": livraisonStats.success },
        "Missions": { "total": missionStats.total, "success": missionStats.success },
        "SAV": { "total": savStats.total, "success": savStats.success },
      },
      // ✅ LOGISTICS UPDATE
      stock_health: {
        "low_stock": logisticsStats.lowStock,
        "movements_in": logisticsStats.incoming,
        "movements_out": logisticsStats.outgoing,
        "daily_history": logisticsStats.dailyHistory // ✅ Saves the map for the Flutter Chart
      },
      livraisons_pending: livraisonStats.total - livraisonStats.success,
      last_updated: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    console.log("✅ Dashboard Updated Successfully!");

  } catch (error) {
    console.error("❌ Critical Error in updateGlobalDashboard:", error);
  }
}

// ==================================================================
// 🚀 TRIGGERS (Explicit region 'europe-west1' added)
// ==================================================================

export const onInterventionAnalytics = functions.region("europe-west1").firestore.document("interventions/{id}").onWrite(async (change) => {
  await updateGlobalDashboard(); await updateTechnicianCounters(change, "assignedTechnicians", "Clôturé");
});
export const onInstallationAnalytics = functions.region("europe-west1").firestore.document("installations/{id}").onWrite(async (change) => {
  await updateGlobalDashboard(); await updateTechnicianCounters(change, "assignedTechnicians", "Terminée");
});
export const onSavAnalytics = functions.region("europe-west1").firestore.document("sav_tickets/{id}").onWrite(async (change) => {
  await updateGlobalDashboard(); await updateTechnicianCounters(change, "pickupTechnicianNames", "Retourné");
});
export const onLivraisonAnalytics = functions.region("europe-west1").firestore.document("livraisons/{id}").onWrite(() => updateGlobalDashboard());
export const onMissionAnalytics = functions.region("europe-west1").firestore.document("missions/{id}").onWrite(() => updateGlobalDashboard());

// ✅ THE MISSING FUNCTION - Now with strict region
export const onStockHistoryAnalytics = functions.region("europe-west1").firestore.document("produits/{productId}/stock_history/{historyId}")
  .onWrite(() => updateGlobalDashboard());

export const onProductAnalytics = functions.region("europe-west1").firestore.document("produits/{id}").onWrite(() => updateGlobalDashboard());


// ==================================================================
// 4️⃣ NEW: AUTO-GENERATE HISTORY ON STOCK CHANGE
// ==================================================================
export const onProductStockChanged = functions.region("europe-west1").firestore.document("produits/{productId}").onUpdate(async (change, context) => {
  const before = change.before.data();
  const after = change.after.data();

  // 1. Check if quantity actually changed
  const oldQty = before.quantiteEnStock || 0;
  const newQty = after.quantiteEnStock || 0;

  if (oldQty === newQty) return null; // No change, do nothing

  // 2. Calculate difference
  const diff = newQty - oldQty;
  const productId = context.params.productId;

  // ✅ ROBUST USER DETECTION
  // We check 'lastModifiedBy' explicitly.
  // If it's missing, undefined, or null, ONLY THEN do we fallback.
  let userName = "Système";

  if (after.lastModifiedBy && typeof after.lastModifiedBy === 'string' && after.lastModifiedBy.trim() !== '') {
    userName = after.lastModifiedBy;
  }

  const productName = after.nom || "Produit Inconnu";

  console.log(`STK_UPDATE: ${productId} | Qty: ${oldQty}->${newQty} | User: '${userName}' (Raw field: '${after.lastModifiedBy}')`);

  // 3. Create the History Record
  try {
    await admin.firestore().collection(`produits/${productId}/stock_history`).add({
      change: diff,
      previousStock: oldQty,
      newStock: newQty,
      reason: "Mise à jour manuelle",
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      user: userName, // ✅ Uses the robustly detected name
      productName: productName,
      type: diff > 0 ? "Entrée" : "Sortie"
    });
    console.log("✅ History record created successfully.");
  } catch (error) {
    console.error("❌ Failed to create history record:", error);
  }

  return null;
});