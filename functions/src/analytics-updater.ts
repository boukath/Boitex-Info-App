// functions/src/analytics-updater.ts

import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import { DocumentSnapshot } from "firebase-admin/firestore";

// ==================================================================
// 1️⃣ CONFIGURATION: APPROVED USERS ONLY 🛡️
// ==================================================================

// Map UIDs to Correct Names
const TECHNICIAN_MAP: { [key: string]: string } = {
"NXI8zvpqLugmGZdW7AYv1LNPpes1": "Athmane",
"1JnrYOkNiefx46sU737stkVpDmo2": "Lounes",
"FPsETJNuR6ZY7ToRWXnWnq2flh32": "Fares",
"fQmfpMbiwKg106SdVxympvgC9P32": "Abderrahmane",
"tK1puz2hIXWjeeuXRcjqKK7bJqE3": "Billel"
};

// Create a list of valid names for filtering
const VALID_NAMES = Object.values(TECHNICIAN_MAP); // ["Athmane", "Lounes", ...]

// ==================================================================
// 2️⃣ HELPERS
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

    // 2. Count SUCCESS
    // ✅ "Terminé" = Tech done, "Clôturé" = Billed. Both count as Success.
    const successSnap = await colRef.where("status", "in", ["Terminé", "Clôturé"]).count().get();

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
// 3️⃣ TECHNICIAN LEADERBOARD (UPDATED FOR STATIC USERS 🛡️)
// ==================================================================
async function updateTechnicianCounters(
  change: functions.Change<DocumentSnapshot>,
  techFieldName: string,
  successStatus: string | string[], // 👈 CHANGED: Now accepts Array OR String
  points: number,
  category: string
) {
  const db = admin.firestore();
  const before = change.before.exists ? change.before.data() : null;
  const after = change.after.exists ? change.after.data() : null;

  // Helper: Checks if status matches provided string or array
  const isSuccess = (status: string) => {
    if (Array.isArray(successStatus)) {
      return successStatus.includes(status);
    }
    return status === successStatus;
  };

  // Helper to extract AND NORMALIZE names safely
  const getNames = (data: any): string[] => {
    if (!data) return [];
    if (!isSuccess(data.status)) return [];

    const val = data[techFieldName];
    let rawList: string[] = [];

    if (Array.isArray(val)) rawList = val;
    else if (typeof val === 'string' && val.trim() !== '') rawList = [val];

    // 🛡️ NORMALIZE: Map UIDs to Names immediately
    return rawList
      .map(raw => TECHNICIAN_MAP[raw] || raw) // Convert ID to Name if possible
      .filter(name => VALID_NAMES.includes(name)); // STRICT FILTER: Only allow approved list
  };

  const techsBefore = getNames(before);
  const techsAfter = getNames(after);

  const toIncrement = techsAfter.filter(t => !techsBefore.includes(t));
  const toDecrement = techsBefore.filter(t => !techsAfter.includes(t));

  if (toIncrement.length === 0 && toDecrement.length === 0) return;

  const batch = db.batch();
  const countersRef = db.collection("analytics_dashboard").doc("technician_performance").collection("counters");

  // 1. Increment
  toIncrement.forEach(techName => {
    if (!techName) return;
    const docRef = countersRef.doc(techName);
    batch.set(docRef, {
      name: techName,
      count: admin.firestore.FieldValue.increment(1),
      score: admin.firestore.FieldValue.increment(points),
      [`breakdown.${category}`]: admin.firestore.FieldValue.increment(1)
    }, { merge: true });
  });

  // 2. Decrement
  toDecrement.forEach(techName => {
    if (!techName) return;
    const docRef = countersRef.doc(techName);
    batch.set(docRef, {
      count: admin.firestore.FieldValue.increment(-1),
      score: admin.firestore.FieldValue.increment(-points),
      [`breakdown.${category}`]: admin.firestore.FieldValue.increment(-1)
    }, { merge: true });
  });

  await batch.commit();
  await refreshTopTechnicians(db);
}

// 🔄 UPDATED FUNCTION: Includes breakdown in the summary
async function refreshTopTechnicians(db: admin.firestore.Firestore) {
  // 🟢 FIX 1: REMOVE .limit(5). Fetch ALL counters to bypass "Weird User" clutter.
  const topSnaps = await db.collection("analytics_dashboard")
    .doc("technician_performance")
    .collection("counters")
    .orderBy("score", "desc")
    .get();

  // Updated Interface to include Badge AND Breakdown
  const topTechsMap: {
    [key: string]: {
      score: number,
      count: number,
      badge: string,
      breakdown: { [key: string]: number } // 👈 NEW: Detailed Breakdown
    }
  } = {};

  let count = 0;

  topSnaps.forEach(doc => {
    const data = doc.data();

    // 🟢 FIX 2: Filter STRICTLY by VALID_NAMES
    // We only process if they are in our approved list.
    if (data.score > 0 && VALID_NAMES.includes(data.name)) {

      // 🏅 BADGE LOGIC (The Brain)
      const total = data.count || 1;
      const breakdown = data.breakdown || {};

      let assignedBadge = "Polyvalent"; // Default = Generalist
      const installCount = breakdown['Installation'] || 0;
      const savCount = breakdown['SAV'] || 0;
      const logistiqueCount = breakdown['Livraison'] || 0;

      // Logic: If > 50% of work is in one category, assign that badge
      if (installCount > (total * 0.5)) assignedBadge = "Installateur";
      else if (savCount > (total * 0.5)) assignedBadge = "Expert SAV";
      else if (logistiqueCount > (total * 0.5)) assignedBadge = "Logistique";

      topTechsMap[data.name] = {
        score: data.score,
        count: data.count || 1,
        badge: assignedBadge,
        breakdown: breakdown // 👈 Send the breakdown to the app
      };
      count++;
    }
  });

  // 🟢 FIX 3: Use .update() instead of .set() to avoid total overwrite if needed,
  // but here .set() is cleaner to ensure old keys are gone from the Overview.
  await db.collection("analytics_dashboard").doc("stats_overview").set({
    top_technicians: topTechsMap
  }, { merge: true });
}

// ==================================================================
// 4️⃣ MASTER UPDATE FUNCTION
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
      logisticsStats
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
        "daily_history": logisticsStats.dailyHistory
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
// 5️⃣ TRIGGERS (FIXED)
// ==================================================================

// 🔧 Interventions: 3 Points
export const onInterventionAnalytics = functions.region("europe-west1").firestore.document("interventions/{id}").onWrite(async (change) => {
  await updateGlobalDashboard();
  // 🟢 FIX: We now accept BOTH statuses. Moving from "Terminé" to "Clôturé" will NOT remove points.
  await updateTechnicianCounters(change, "assignedTechnicians", ["Terminé", "Clôturé"], 3, "Intervention");
});

// 🛠️ Installations: 10 Points
export const onInstallationAnalytics = functions.region("europe-west1").firestore.document("installations/{id}").onWrite(async (change) => {
  await updateGlobalDashboard();
  // 🟢 Field: "assignedTechnicianNames"
  await updateTechnicianCounters(change, "assignedTechnicianNames", "Terminée", 10, "Installation");
});

// 🚩 Missions: 5 Points
export const onMissionAnalytics = functions.region("europe-west1").firestore.document("missions/{id}").onWrite(async (change) => {
  await updateGlobalDashboard();
  // 🟢 Field: "assignedTechniciansNames"
  await updateTechnicianCounters(change, "assignedTechniciansNames", "Terminée", 5, "Mission");
});

// 🚑 SAV: 5 Points (Kept same)
export const onSavAnalytics = functions.region("europe-west1").firestore.document("sav_tickets/{id}").onWrite(async (change) => {
  await updateGlobalDashboard();
  await updateTechnicianCounters(change, "pickupTechnicianNames", "Retourné", 5, "SAV");
});

// 🚚 Livraisons: 2 Points (Kept same)
export const onLivraisonAnalytics = functions.region("europe-west1").firestore.document("livraisons/{id}").onWrite(async (change) => {
  await updateGlobalDashboard();
  await updateTechnicianCounters(change, "livreurName", "Livré", 2, "Livraison");
});

// ✅ THE MISSING FUNCTION - Now with strict region
export const onStockHistoryAnalytics = functions.region("europe-west1").firestore.document("produits/{productId}/stock_history/{historyId}")
  .onWrite(() => updateGlobalDashboard());

export const onProductAnalytics = functions.region("europe-west1").firestore.document("produits/{id}").onWrite(() => updateGlobalDashboard());


// ==================================================================
// 6️⃣ NEW: AUTO-GENERATE HISTORY ON STOCK CHANGE
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

// ==================================================================
// 7️⃣ MANUAL RECALCULATION (THE "RESET" BUTTON) 🔄
// ==================================================================

// Helper class for the aggregation
interface TechStats {
  score: number;
  count: number;
  breakdown: { [key: string]: number };
}

export const recalculateTechnicianStats = functions
  .runWith({ timeoutSeconds: 540, memory: '1GB' }) // Allow long execution for heavy data
  .region("europe-west1")
  .https.onCall(async (data, context) => {

    const db = admin.firestore();
    const statsMap: { [name: string]: TechStats } = {};

    console.log("🔄 STARTING FULL RECALCULATION (CLEAN MODE)...");

    // 🕵️‍♀️ STEP 0: CLEANUP OLD GARBAGE FIRST 🧹
    // We fetch ALL existing counters and delete the ones that are NOT in our valid list.
    try {
      const countersRef = db.collection("analytics_dashboard").doc("technician_performance").collection("counters");
      const existingSnaps = await countersRef.get();
      const deleteBatch = db.batch();
      let deleteCount = 0;

      existingSnaps.forEach(doc => {
        if (!VALID_NAMES.includes(doc.id)) {
          deleteBatch.delete(doc.ref);
          deleteCount++;
        }
      });

      if (deleteCount > 0) {
        await deleteBatch.commit();
        console.log(`🧹 Cleaned up ${deleteCount} invalid/old users.`);
      }
    } catch (e) {
      console.warn("⚠️ Cleanup warning (non-fatal):", e);
    }

    // Helper to process a list of names/ids
    const processNames = (rawInput: any, points: number, category: string) => {
      let inputList: string[] = [];
      if (Array.isArray(rawInput)) inputList = rawInput;
      else if (typeof rawInput === 'string' && rawInput.trim() !== '') inputList = [rawInput];

      inputList.forEach(raw => {
        if (!raw) return;

        // 🧠 RESOLVE NAME: Check if 'raw' is a UID in our map
        let finalName = TECHNICIAN_MAP[raw] || raw; // Convert ID to Name if possible

        finalName = String(finalName).trim(); // Safety string conversion

        // 🛑 STRICT FILTER: ONLY ALLOW OUR 5 TECHNICIANS
        if (!VALID_NAMES.includes(finalName)) {
          // console.log(`Skipping unknown user: ${finalName} (Raw: ${raw})`);
          return;
        }

        if (!statsMap[finalName]) {
          statsMap[finalName] = { score: 0, count: 0, breakdown: {} };
        }
        statsMap[finalName].score += points;
        statsMap[finalName].count += 1;
        statsMap[finalName].breakdown[category] = (statsMap[finalName].breakdown[category] || 0) + 1;
      });
    };

    try {
      // 1️⃣ INTERVENTIONS (+3 pts)
      const interventionsSnap = await db.collection('interventions')
        .where('status', 'in', ['Terminé', 'Clôturé'])
        .get();

      interventionsSnap.docs.forEach(doc => {
        processNames(doc.data().assignedTechnicians, 3, "Intervention");
      });
      console.log(`✅ Processed ${interventionsSnap.size} Interventions`);

      // 2️⃣ INSTALLATIONS (+10 pts)
      const installationsSnap = await db.collection('installations')
        .where('status', '==', 'Terminée')
        .get();

      installationsSnap.docs.forEach(doc => {
        const d = doc.data();
        const targets = (d.assignedTechnicianNames && d.assignedTechnicianNames.length > 0)
                        ? d.assignedTechnicianNames
                        : d.assignedTechnicians;
        processNames(targets, 10, "Installation");
      });
      console.log(`✅ Processed ${installationsSnap.size} Installations`);

      // 3️⃣ MISSIONS (+5 pts)
      const missionsSnap = await db.collection('missions')
        .where('status', '==', 'Terminée')
        .get();

      missionsSnap.docs.forEach(doc => {
        const d = doc.data();
        const targets = (d.assignedTechniciansNames && d.assignedTechniciansNames.length > 0)
                        ? d.assignedTechniciansNames
                        : d.assignedTechniciansIds;
        processNames(targets, 5, "Mission");
      });
      console.log(`✅ Processed ${missionsSnap.size} Missions`);

      // 4️⃣ SAV (+5 pts)
      const savSnap = await db.collection('sav_tickets')
        .where('status', '==', 'Retourné')
        .get();

      savSnap.docs.forEach(doc => {
        processNames(doc.data().pickupTechnicianNames, 5, "SAV");
      });
      console.log(`✅ Processed ${savSnap.size} SAV Tickets`);

      // 5️⃣ LIVRAISONS (+2 pts)
      const livraisonsSnap = await db.collection('livraisons')
        .where('status', '==', 'Livré')
        .get();

      livraisonsSnap.docs.forEach(doc => {
        processNames(doc.data().livreurName, 2, "Livraison");
      });
      console.log(`✅ Processed ${livraisonsSnap.size} Livraisons`);

      // 6️⃣ WRITE RESULTS TO FIRESTORE
      const batch = db.batch();
      const countersRef = db.collection("analytics_dashboard").doc("technician_performance").collection("counters");

      const entries = Object.entries(statsMap);
      let batchCount = 0;

      for (const [name, stats] of entries) {
        const docRef = countersRef.doc(name);
        batch.set(docRef, {
          name: name,
          score: stats.score,
          count: stats.count,
          breakdown: stats.breakdown
        });

        batchCount++;
        if (batchCount >= 450) {
          await batch.commit();
          batchCount = 0;
        }
      }

      if (batchCount > 0) await batch.commit();

      // 7️⃣ UPDATE SUMMARY DOC
      await refreshTopTechnicians(db);

      console.log("🚀 LEADERBOARD RECALIBRATED SUCCESSFULLY!");
      return { success: true, message: `Updated ${entries.length} technicians (Strict Mode).` };

    } catch (e: any) {
      console.error("❌ Recalculation Failed:", e);
      throw new functions.https.HttpsError('internal', `Failed: ${e.message}`);
    }
  });