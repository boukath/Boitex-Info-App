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

// 🗓️ NEW HELPER: Extracts the most accurate date from a document
const getDocDate = (snap: any): Date => {
if (!snap) return new Date();
  const d = snap.data ? snap.data() : snap;
  if (!d) return new Date();
  if (d.date && typeof d.date.toDate === 'function') return d.date.toDate();
  if (d.createdAt && typeof d.createdAt.toDate === 'function') return d.createdAt.toDate();
  if (d.timestamp && typeof d.timestamp.toDate === 'function') return d.timestamp.toDate();
  return snap.createTime ? snap.createTime.toDate() : new Date();
};

// ✅ SPECIFIC HELPER FOR INTERVENTIONS (Smart Filtering)
async function getInterventionStats(db: admin.firestore.Firestore) {
  try {
    const colRef = db.collection("interventions");

    const activeStatuses = [
      'Nouvelle Demande',
      'Nouveau',
      'En cours',
      'Terminé',
      'En attente',
      'Clôturé'
    ];

    const totalSnap = await colRef.where("status", "in", activeStatuses).count().get();
    const successSnap = await colRef.where("status", "in", ["Terminé", "Clôturé"]).count().get();

    return { total: totalSnap.data().count, success: successSnap.data().count };
  } catch (e) {
    console.error("⚠️ Error counting Interventions:", e);
    return { total: 0, success: 0 };
  }
}

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
    const lowStockSnap = await db.collection("produits")
      .where("quantiteEnStock", "<", 5)
      .count()
      .get();

    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    const historySnapshot = await db.collectionGroup("stock_history")
      .where("timestamp", ">=", admin.firestore.Timestamp.fromDate(thirtyDaysAgo))
      .orderBy("timestamp", "desc")
      .get();

    let incomingTotal = 0;
    let outgoingTotal = 0;
    const dailyMap: Record<string, { in: number, out: number }> = {};

    historySnapshot.docs.forEach((doc) => {
      const data = doc.data();
      const change = data.change || 0;

      if (change > 0) incomingTotal += change;
      else outgoingTotal += Math.abs(change);

      if (data.timestamp) {
        const dateKey = data.timestamp.toDate().toISOString().split('T')[0];
        if (!dailyMap[dateKey]) dailyMap[dateKey] = { in: 0, out: 0 };

        if (change > 0) dailyMap[dateKey].in += change;
        else dailyMap[dateKey].out += Math.abs(change);
      }
    });

    return {
      lowStock: lowStockSnap.data().count,
      incoming: incomingTotal,
      outgoing: outgoingTotal,
      dailyHistory: dailyMap
    };

  } catch (e) {
    console.error("⚠️ Error in Logistics Stats:", e);
    return { lowStock: 0, incoming: 0, outgoing: 0, dailyHistory: {} };
  }
}

// ==================================================================
// 3️⃣ TECHNICIAN LEADERBOARD (UPDATED FOR SUBCOLLECTIONS)
// ==================================================================
async function updateTechnicianCounters(
  change: functions.Change<DocumentSnapshot>,
  techFieldNames: string[],
  successStatus: string | string[],
  totalPoints: number,
  category: string,
  explicitTechList?: string[] // 👈 NEW: Allow passing explicit authors for SAV
) {
  const db = admin.firestore();
  const before = change.before.exists ? change.before.data() : null;
  const after = change.after.exists ? change.after.data() : null;

  const isSuccess = (status: string) => {
    if (Array.isArray(successStatus)) return successStatus.includes(status);
    return status === successStatus;
  };

  const getNames = (data: any): string[] => {
    if (!data) return [];
    if (!isSuccess(data.status)) return [];

    let rawList: string[] = [];

    // 👈 Check explicit list first (Used for SAV journal entries)
    if (explicitTechList && explicitTechList.length > 0) {
      rawList = explicitTechList;
    } else {
      for (const field of techFieldNames) {
        if (data[field] && Array.isArray(data[field]) && data[field].length > 0) {
          rawList = data[field];
          break;
        } else if (typeof data[field] === 'string' && data[field].trim() !== '') {
          rawList = [data[field]];
          break;
        }
      }
    }

    return rawList
      .map(raw => TECHNICIAN_MAP[raw] || raw)
      .filter(name => VALID_NAMES.includes(name));
  };

  const techsBefore = getNames(before);
  const techsAfter = getNames(after);

  let pointsBefore = 0;
  if (techsBefore.length > 0) {
    pointsBefore = category === "Mission" ? 1 : (totalPoints / techsBefore.length);
  }

  let pointsAfter = 0;
  if (techsAfter.length > 0) {
    pointsAfter = category === "Mission" ? 1 : (totalPoints / techsAfter.length);
  }

  const allInvolved = Array.from(new Set([...techsBefore, ...techsAfter]));
  if (allInvolved.length === 0) return;

  const targetSnap = change.after.exists ? change.after : change.before;
  const docDate = getDocDate(targetSnap);
  const monthKey = `${docDate.getFullYear()}-${String(docDate.getMonth() + 1).padStart(2, '0')}`;

  const batch = db.batch();
  const countersRef = db.collection("analytics_dashboard").doc("technician_performance").collection("counters");
  const monthlyCountersRef = db.collection("analytics_dashboard").doc(`monthly_${monthKey}`).collection("counters");

  allInvolved.forEach(techName => {
    let scoreChange = 0;
    let countChange = 0;

    if (techsBefore.includes(techName)) scoreChange -= pointsBefore;
    if (techsAfter.includes(techName)) scoreChange += pointsAfter;

    if (!techsBefore.includes(techName) && techsAfter.includes(techName)) countChange = 1;
    if (techsBefore.includes(techName) && !techsAfter.includes(techName)) countChange = -1;

    scoreChange = Math.round(scoreChange * 100) / 100;

    if (scoreChange !== 0 || countChange !== 0) {
      const updateData: any = { name: techName };

      if (scoreChange !== 0) updateData.score = admin.firestore.FieldValue.increment(scoreChange);

      if (countChange !== 0) {
        updateData.count = admin.firestore.FieldValue.increment(countChange);
        updateData[`breakdown.${category}`] = admin.firestore.FieldValue.increment(countChange);
      }

      batch.set(countersRef.doc(techName), updateData, { merge: true });
      batch.set(monthlyCountersRef.doc(techName), updateData, { merge: true });
    }
  });

  await batch.commit();
  await refreshTopTechnicians(db);
}

async function refreshTopTechnicians(db: admin.firestore.Firestore) {
  const topSnaps = await db.collection("analytics_dashboard")
    .doc("technician_performance")
    .collection("counters")
    .orderBy("score", "desc")
    .get();

  const topTechsMap: {
    [key: string]: {
      score: number,
      count: number,
      badge: string,
      breakdown: { [key: string]: number }
    }
  } = {};

  topSnaps.forEach(doc => {
    const data = doc.data();

    if (data.score > 0 && VALID_NAMES.includes(data.name)) {

      const total = data.count || 1;
      const breakdown = data.breakdown || {};

      let assignedBadge = "Polyvalent";
      const installCount = breakdown['Installation'] || 0;
      const savCount = breakdown['SAV'] || 0;
      const logistiqueCount = breakdown['Livraison'] || 0;
      const interventionCount = breakdown['Intervention'] || 0;
      const missionCount = breakdown['Mission'] || 0;

      if (installCount > (total * 0.5)) assignedBadge = "Installateur";
      else if (savCount > (total * 0.5)) assignedBadge = "Expert SAV";
      else if (logistiqueCount > (total * 0.5)) assignedBadge = "Logistique";
      else if (interventionCount > (total * 0.5)) assignedBadge = "Technicien";
      else if (missionCount > (total * 0.5)) assignedBadge = "Mission";

      topTechsMap[data.name] = {
        score: data.score,
        count: data.count || 1,
        badge: assignedBadge,
        breakdown: breakdown
      };
    }
  });

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
    const [
      interventionStats,
      installationStats,
      livraisonStats,
      missionStats,
      savStats,
      logisticsStats
    ] = await Promise.all([
      getInterventionStats(db),
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
        "movements_out": logisticsStats.outgoing,
        "daily_history": logisticsStats.dailyHistory
      },
      livraisons_pending: livraisonStats.total - livraisonStats.success,
      last_updated: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

  } catch (error) {
    console.error("❌ Critical Error in updateGlobalDashboard:", error);
  }
}

// ==================================================================
// 5️⃣ TRIGGERS
// ==================================================================

export const onInterventionAnalytics = functions.region("europe-west1").firestore.document("interventions/{id}").onWrite(async (change) => {
  await updateGlobalDashboard();
  await updateTechnicianCounters(change, ["assignedTechnicians", "assignedTechniciansIds"], ["Terminé", "Clôturé"], 2, "Intervention");
});

export const onInstallationAnalytics = functions.region("europe-west1").firestore.document("installations/{id}").onWrite(async (change) => {
  await updateGlobalDashboard();
  await updateTechnicianCounters(change, ["assignedTechnicianNames", "assignedTechnicians"], "Terminée", 3, "Installation");
});

export const onMissionAnalytics = functions.region("europe-west1").firestore.document("missions/{id}").onWrite(async (change) => {
  await updateGlobalDashboard();
  await updateTechnicianCounters(change, ["assignedTechniciansNames", "assignedTechniciansIds"], "Terminée", 1, "Mission");
});

// 🚑 SAV (UPDATED: Gives points to the Repair Tech from journal_entries)
export const onSavAnalytics = functions.region("europe-west1").firestore.document("sav_tickets/{id}").onWrite(async (change, context) => {
  await updateGlobalDashboard();

  const db = admin.firestore();
  const savId = context.params.id;
  let repairTechs: string[] = [];

  try {
    const journalSnap = await db.collection(`sav_tickets/${savId}/journal_entries`)
      .where("newStatus", "==", "Terminé")
      .get();

    if (!journalSnap.empty) {
      const authors = new Set<string>();
      journalSnap.docs.forEach(doc => {
        const data = doc.data();
        if (data.authorName) authors.add(data.authorName);
        else if (data.authorId) authors.add(data.authorId);
      });
      repairTechs = Array.from(authors);
    }
  } catch (error) {
    console.error(`Error fetching journal entries for SAV ${savId}:`, error);
  }

  await updateTechnicianCounters(change, [], "Retourné", 2, "SAV", repairTechs);
});

export const onLivraisonAnalytics = functions.region("europe-west1").firestore.document("livraisons/{id}").onWrite(async (change) => {
  await updateGlobalDashboard();
  await updateTechnicianCounters(change, ["livreurName", "livreurId"], "Livré", 2, "Livraison");
});

export const onStockHistoryAnalytics = functions.region("europe-west1").firestore.document("produits/{productId}/stock_history/{historyId}")
  .onWrite(() => updateGlobalDashboard());

export const onProductAnalytics = functions.region("europe-west1").firestore.document("produits/{id}").onWrite(() => updateGlobalDashboard());


// ==================================================================
// 6️⃣ NEW: AUTO-GENERATE HISTORY ON STOCK CHANGE
// ==================================================================
export const onProductStockChanged = functions.region("europe-west1").firestore.document("produits/{productId}").onUpdate(async (change, context) => {
  const before = change.before.data();
  const after = change.after.data();

  const oldQty = before.quantiteEnStock || 0;
  const newQty = after.quantiteEnStock || 0;

  if (oldQty === newQty) return null;

  const diff = newQty - oldQty;
  const productId = context.params.productId;

  let userName = "Système";
  if (after.lastModifiedBy && typeof after.lastModifiedBy === 'string' && after.lastModifiedBy.trim() !== '') {
    userName = after.lastModifiedBy;
  }

  const productName = after.nom || "Produit Inconnu";

  try {
    await admin.firestore().collection(`produits/${productId}/stock_history`).add({
      change: diff,
      previousStock: oldQty,
      newStock: newQty,
      reason: "Mise à jour manuelle",
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      user: userName,
      productName: productName,
      type: diff > 0 ? "Entrée" : "Sortie"
    });
  } catch (error) {
    console.error("❌ Failed to create history record:", error);
  }

  return null;
});

// ==================================================================
// 7️⃣ MANUAL RECALCULATION (THE "RESET" BUTTON) 🔄
// ==================================================================

interface TechStats {
  score: number;
  count: number;
  breakdown: { [key: string]: number };
}

export const recalculateTechnicianStats = functions
  .runWith({ timeoutSeconds: 540, memory: '1GB' })
  .region("europe-west1")
  .https.onCall(async (data, context) => {

    const db = admin.firestore();
    const allTimeStats: { [name: string]: TechStats } = {};
    const monthlyStats: { [monthKey: string]: { [name: string]: TechStats } } = {};

    console.log("🔄 STARTING FULL RECALCULATION...");

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
      }
    } catch (e) {
      console.warn("⚠️ Cleanup warning (non-fatal):", e);
    }

    const processDoc = (doc: any, techField: any, totalPoints: number, category: string) => {
      let inputList: string[] = [];
      if (Array.isArray(techField)) inputList = techField;
      else if (typeof techField === 'string' && techField.trim() !== '') inputList = [techField];

      const validTechs = inputList
        .map(raw => TECHNICIAN_MAP[raw] || raw)
        .map(name => String(name).trim())
        .filter(name => VALID_NAMES.includes(name));

      if (validTechs.length === 0) return;

      const docDate = getDocDate(doc);
      const monthKey = `${docDate.getFullYear()}-${String(docDate.getMonth() + 1).padStart(2, '0')}`;

      const pointsPerTech = category === "Mission" ? 1 : (totalPoints / validTechs.length);
      const addedScore = Math.round(pointsPerTech * 100) / 100;

      if (!monthlyStats[monthKey]) monthlyStats[monthKey] = {};

      validTechs.forEach(finalName => {
        if (!allTimeStats[finalName]) allTimeStats[finalName] = { score: 0, count: 0, breakdown: {} };
        allTimeStats[finalName].score += addedScore;
        allTimeStats[finalName].count += 1;
        allTimeStats[finalName].breakdown[category] = (allTimeStats[finalName].breakdown[category] || 0) + 1;

        if (!monthlyStats[monthKey][finalName]) monthlyStats[monthKey][finalName] = { score: 0, count: 0, breakdown: {} };
        monthlyStats[monthKey][finalName].score += addedScore;
        monthlyStats[monthKey][finalName].count += 1;
        monthlyStats[monthKey][finalName].breakdown[category] = (monthlyStats[monthKey][finalName].breakdown[category] || 0) + 1;
      });
    };

    try {
      // 1️⃣ INTERVENTIONS
      const interventionsSnap = await db.collection('interventions')
        .where('status', 'in', ['Terminé', 'Clôturé'])
        .get();

      interventionsSnap.docs.forEach(doc => {
        const d = doc.data();
        const targets = (d.assignedTechnicians && d.assignedTechnicians.length > 0)
                        ? d.assignedTechnicians
                        : d.assignedTechniciansIds;
        processDoc(doc, targets, 2, "Intervention");
      });

      // 2️⃣ INSTALLATIONS
      const installationsSnap = await db.collection('installations')
        .where('status', '==', 'Terminée')
        .get();

      installationsSnap.docs.forEach(doc => {
        const d = doc.data();
        const targets = (d.assignedTechnicianNames && d.assignedTechnicianNames.length > 0)
                        ? d.assignedTechnicianNames
                        : d.assignedTechnicians;
        processDoc(doc, targets, 3, "Installation");
      });

      // 3️⃣ MISSIONS
      const missionsSnap = await db.collection('missions')
        .where('status', '==', 'Terminée')
        .get();

      missionsSnap.docs.forEach(doc => {
        const d = doc.data();
        const targets = (d.assignedTechniciansNames && d.assignedTechniciansNames.length > 0)
                        ? d.assignedTechniciansNames
                        : d.assignedTechniciansIds;
        processDoc(doc, targets, 1, "Mission");
      });

      // 4️⃣ SAV (Using Journal Entries to find the repairing technician)
      const savSnap = await db.collection('sav_tickets')
        .where('status', '==', 'Retourné')
        .get();

      const savPromises = savSnap.docs.map(async (doc) => {
        let targets: string[] = [];

        const journalSnap = await db.collection(`sav_tickets/${doc.id}/journal_entries`)
          .where("newStatus", "==", "Terminé")
          .get();

        if (!journalSnap.empty) {
          const authors = new Set<string>();
          journalSnap.docs.forEach(jDoc => {
            const jd = jDoc.data();
            if (jd.authorName) authors.add(jd.authorName);
            else if (jd.authorId) authors.add(jd.authorId);
          });
          targets = Array.from(authors);
        }

        processDoc(doc, targets, 2, "SAV");
      });

      await Promise.all(savPromises);

      // 5️⃣ LIVRAISONS
      const livraisonsSnap = await db.collection('livraisons')
        .where('status', '==', 'Livré')
        .get();

      livraisonsSnap.docs.forEach(doc => {
        const d = doc.data();
        const targets = d.livreurName || d.livreurId;
        processDoc(doc, targets, 2, "Livraison");
      });

      // 6️⃣ WRITE RESULTS TO FIRESTORE
      const batch = db.batch();
      let batchCount = 0;

      const commitBatchIfNeeded = async () => {
        batchCount++;
        if (batchCount >= 450) { await batch.commit(); batchCount = 0; }
      };

      const countersRef = db.collection("analytics_dashboard").doc("technician_performance").collection("counters");

      for (const [name, stats] of Object.entries(allTimeStats)) {
        batch.set(countersRef.doc(name), { name: name, ...stats });
        await commitBatchIfNeeded();
      }

      for (const [mKey, mData] of Object.entries(monthlyStats)) {
        const mRef = db.collection("analytics_dashboard").doc(`monthly_${mKey}`).collection("counters");
        for (const [name, stats] of Object.entries(mData)) {
          batch.set(mRef.doc(name), { name: name, ...stats });
          await commitBatchIfNeeded();
        }
      }

      if (batchCount > 0) await batch.commit();

      // 7️⃣ UPDATE SUMMARY DOC
      await refreshTopTechnicians(db);

      console.log("🚀 LEADERBOARD RECALIBRATED SUCCESSFULLY!");
      return { success: true, message: `Recalculated All-Time and Monthly records across ${Object.keys(monthlyStats).length} months.` };

    } catch (e: any) {
      console.error("❌ Recalculation Failed:", e);
      throw new functions.https.HttpsError('internal', `Failed: ${e.message}`);
    }
  });