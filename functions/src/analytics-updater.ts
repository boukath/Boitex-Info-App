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

    // Define the exact list of statuses that count as "Valid Work"
    // This excludes "Annulé" or "Brouillon" from the Total.
    const activeStatuses = [
      'Nouvelle Demande',
      'Nouveau',
      'En cours',
      'Terminé',
      'En attente',
      'Clôturé'
    ];

    // 1. Count TOTAL (Only active statuses)
    const totalSnap = await colRef.where("status", "in", activeStatuses).count().get();

    // 2. Count SUCCESS (Only "Clôturé" per your new rule)
    const successSnap = await colRef.where("status", "==", "Clôturé").count().get();

    return { total: totalSnap.data().count, success: successSnap.data().count };
  } catch (e) {
    console.error("⚠️ Error counting Interventions:", e);
    return { total: 0, success: 0 };
  }
}

// Generic helper for other collections (Installations, etc.)
async function getCollectionStats(db: admin.firestore.Firestore, collectionName: string, successStatus: string) {
  try {
    const colRef = db.collection(collectionName);
    const totalSnap = await colRef.count().get(); // Counts ALL docs
    const successSnap = await colRef.where("status", "==", successStatus).count().get();
    return { total: totalSnap.data().count, success: successSnap.data().count };
  } catch (e) {
    console.error(`⚠️ Error counting ${collectionName}:`, e);
    return { total: 0, success: 0 };
  }
}

// Calculate Logistics Stats
async function getLogisticsStats(db: admin.firestore.Firestore) {
  try {
    const lowStockSnap = await db.collection("produits")
      .where("quantity", "<", 5)
      .count()
      .get();

    const historyQuery = db.collectionGroup("stock_history");
    const incomingSnap = await historyQuery.where("change", ">", 0).count().get();
    const outgoingSnap = await historyQuery.where("change", "<", 0).count().get();

    return {
      lowStock: lowStockSnap.data().count,
      incoming: incomingSnap.data().count,
      outgoing: outgoingSnap.data().count
    };
  } catch (e) {
    console.error("⚠️ Error in Logistics Stats:", e);
    return { lowStock: 0, incoming: 0, outgoing: 0 };
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
    console.log("🔄 Starting Dashboard Update (Smart Intervention Logic)...");

    // Run Aggregations
    const [
      interventionStats, // ✅ Uses new Specific Logic
      installationStats,
      livraisonStats,
      missionStats,
      savStats,
      logisticsStats
    ] = await Promise.all([
      getInterventionStats(db), // ✅ Call the new helper
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
      // Detailed breakdown
      category_performance: {
        "Interventions": { "total": interventionStats.total, "success": interventionStats.success },
        "Installations": { "total": installationStats.total, "success": installationStats.success },
        "Livraisons": { "total": livraisonStats.total, "success": livraisonStats.success },
        "Missions": { "total": missionStats.total, "success": missionStats.success },
        "SAV": { "total": savStats.total, "success": savStats.success },
      },
      stock_health: {
        "low_stock": logisticsStats.lowStock,
        "movements_in": logisticsStats.incoming,
        "movements_out": logisticsStats.outgoing
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
// 🚀 TRIGGERS
// ==================================================================

export const onInterventionAnalytics = functions.firestore.document("interventions/{id}").onWrite(async (change) => {
  // Note: We still track Tech Performance based on "Clôturé"
  await updateGlobalDashboard(); await updateTechnicianCounters(change, "assignedTechnicians", "Clôturé");
});
export const onInstallationAnalytics = functions.firestore.document("installations/{id}").onWrite(async (change) => {
  await updateGlobalDashboard(); await updateTechnicianCounters(change, "assignedTechnicians", "Terminée");
});
export const onSavAnalytics = functions.firestore.document("sav_tickets/{id}").onWrite(async (change) => {
  await updateGlobalDashboard(); await updateTechnicianCounters(change, "pickupTechnicianNames", "Retourné");
});
export const onLivraisonAnalytics = functions.firestore.document("livraisons/{id}").onWrite(() => updateGlobalDashboard());
export const onMissionAnalytics = functions.firestore.document("missions/{id}").onWrite(() => updateGlobalDashboard());

export const onStockHistoryAnalytics = functions.firestore.document("produits/{productId}/stock_history/{historyId}")
  .onWrite(() => updateGlobalDashboard());

export const onProductAnalytics = functions.firestore.document("produits/{id}").onWrite(() => updateGlobalDashboard());