/**
 * allofoods — admin_payout_script.js
 * Firebase Cloud Functions (Node.js)
 * Rôle : Gestion de la paie mensuelle des livreurs
 * 
 * 3 fonctions :
 * 1. monthlyPayoutAuto   → Automatique le dernier jour du mois
 * 2. unlockOneDriver     → Admin débloque un livreur manuellement
 * 3. unlockAllDrivers    → Admin débloque tous les livreurs d'un coup
 */

const { onRequest } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

const db  = getFirestore();
const fcm = getMessaging();

const ADMIN_SECRET = process.env.ADMIN_SECRET ?? "allofoods_admin_2026";

// ══════════════════════════════════════════════════════
// 1. PAIEMENT AUTO — Dernier jour du mois à 23h00
// Cotonou = UTC+1 → 22h00 UTC
// ══════════════════════════════════════════════════════
exports.monthlyPayoutAuto = onSchedule(
  { schedule: "0 22 28-31 * *", timeZone: "Africa/Porto-Novo" },
  async () => {
    // Vérifier que c'est bien le dernier jour
    const today    = new Date();
    const tomorrow = new Date(today);
    tomorrow.setDate(today.getDate() + 1);

    if (tomorrow.getMonth() === today.getMonth()) {
      console.log("[payout] Pas le dernier jour du mois — skip");
      return;
    }

    console.log(`[payout] Début paiement mensuel — ${_currentMonth()}`);
    await _processAllDrivers("auto");
  }
);

// ══════════════════════════════════════════════════════
// 2. DÉBLOQUER UN LIVREUR — Action admin manuelle
// POST /unlockOneDriver?driverId=XXX&adminKey=SECRET
// ══════════════════════════════════════════════════════
exports.unlockOneDriver = onRequest(
  { cors: true, region: "europe-west1" },
  async (req, res) => {
    if (!_checkAdminKey(req, res)) return;

    const driverId = req.query.driverId ?? req.body.driverId;
    if (!driverId) {
      res.status(400).json({ error: "driverId requis" });
      return;
    }

    try {
      const result = await _unlockDriver(driverId);
      if (result.skipped) {
        res.status(200).json({ message: "Aucun gain à débloquer", driverId });
        return;
      }
      res.status(200).json({
        success:        true,
        driverId,
        unlockedAmount: result.amount,
        month:          result.month,
        message:        `${result.amount} FCFA débloqués pour le livreur`,
      });
    } catch (err) {
      console.error("[unlockOneDriver] Erreur:", err);
      res.status(500).json({ error: String(err) });
    }
  }
);

// ══════════════════════════════════════════════════════
// 3. DÉBLOQUER TOUS LES LIVREURS — Action admin
// POST /unlockAllDrivers?adminKey=SECRET
// ══════════════════════════════════════════════════════
exports.unlockAllDrivers = onRequest(
  { cors: true, region: "europe-west1" },
  async (req, res) => {
    if (!_checkAdminKey(req, res)) return;

    try {
      const report = await _processAllDrivers("manual");
      res.status(200).json({
        success:       true,
        processed:     report.processed,
        skipped:       report.skipped,
        totalUnlocked: report.totalUnlocked,
        month:         report.month,
        message:       `${report.processed} livreurs payés — ${report.totalUnlocked} FCFA au total`,
      });
    } catch (err) {
      console.error("[unlockAllDrivers] Erreur:", err);
      res.status(500).json({ error: String(err) });
    }
  }
);

// ══════════════════════════════════════════════════════
// 4. VOIR LES GAINS D'UN LIVREUR — GET /driverBalance
// GET /driverBalance?driverId=XXX&adminKey=SECRET
// ══════════════════════════════════════════════════════
exports.driverBalance = onRequest(
  { cors: true, region: "europe-west1" },
  async (req, res) => {
    if (!_checkAdminKey(req, res)) return;

    const driverId = req.query.driverId;
    if (!driverId) {
      res.status(400).json({ error: "driverId requis" });
      return;
    }

    try {
      const doc = await db.collection("users").doc(driverId).get();
      if (!doc.exists) {
        res.status(404).json({ error: "Livreur introuvable" });
        return;
      }

      const data = doc.data();
      const currentMonth = _currentMonth();

      // Historique des mois précédents
      const historySnap = await db.collection("users").doc(driverId)
        .collection("monthly_earnings")
        .orderBy("month", "desc")
        .limit(6)
        .get();

      const history = historySnap.docs.map(d => d.data());

      res.status(200).json({
        driverId,
        name:                        data.name,
        currentMonth,
        monthly_accumulated_earnings: data.monthly_accumulated_earnings ?? 0,
        withdrawable_balance:          data.withdrawable_balance          ?? 0,
        total_earnings:               data.total_earnings                ?? 0,
        totalDeliveries:              data.stats?.totalDeliveries         ?? 0,
        lastUnlockedMonth:            data.lastUnlockedMonth              ?? "—",
        history,
      });
    } catch (err) {
      res.status(500).json({ error: String(err) });
    }
  }
);

// ══════════════════════════════════════════════════════
// LOGIQUE PRINCIPALE — Débloquer tous les livreurs
// ══════════════════════════════════════════════════════
async function _processAllDrivers(trigger) {
  const currentMonth = _currentMonth();
  const driversSnap  = await db.collection("users")
    .where("role", "==", "driver")
    .get();

  let processed    = 0;
  let skipped      = 0;
  let totalUnlocked = 0;

  const batch = db.batch();

  for (const driverDoc of driversSnap.docs) {
    const data        = driverDoc.data();
    const accumulated = data.monthly_accumulated_earnings ?? 0;

    if (accumulated <= 0) {
      skipped++;
      continue;
    }

    // Archiver les gains du mois
    const archiveRef = driverDoc.ref
      .collection("monthly_earnings").doc(currentMonth);
    batch.set(archiveRef, {
      month:       currentMonth,
      amount:      accumulated,
      trigger,
      unlockedAt:  FieldValue.serverTimestamp(),
    });

    // Transférer vers withdrawable_balance
    batch.update(driverDoc.ref, {
      withdrawable_balance:         FieldValue.increment(accumulated),
      monthly_accumulated_earnings: 0,           // Remise à zéro
      total_earnings:               FieldValue.increment(accumulated),
      lastUnlockedAt:               FieldValue.serverTimestamp(),
      lastUnlockedMonth:            currentMonth,
    });

    totalUnlocked += accumulated;
    processed++;
  }

  await batch.commit();

  // Rapport mensuel
  await db.collection("reports").doc(`payout_${currentMonth}`).set({
    type:          "monthly_driver_payout",
    month:         currentMonth,
    trigger,
    driversTotal:  driversSnap.size,
    processed,
    skipped,
    totalUnlocked,
    processedAt:   FieldValue.serverTimestamp(),
  });

  // Notifier les livreurs payés
  await _notifyDriversPaid(driversSnap.docs, currentMonth);

  console.log(`[payout] ${processed} livreurs payés | ${totalUnlocked} FCFA | ${skipped} skipped`);

  return { processed, skipped, totalUnlocked, month: currentMonth };
}

// ── Débloquer un seul livreur ──────────────────────────
async function _unlockDriver(driverId) {
  const ref  = db.collection("users").doc(driverId);
  const doc  = await ref.get();

  if (!doc.exists) throw new Error(`Livreur ${driverId} introuvable`);

  const data        = doc.data();
  const accumulated = data.monthly_accumulated_earnings ?? 0;
  const month       = _currentMonth();

  if (accumulated <= 0) return { skipped: true, amount: 0, month };

  // Archiver
  await ref.collection("monthly_earnings").doc(month).set({
    month,
    amount:     accumulated,
    trigger:    "manual_single",
    unlockedAt: FieldValue.serverTimestamp(),
  });

  // Débloquer
  await ref.update({
    withdrawable_balance:         FieldValue.increment(accumulated),
    monthly_accumulated_earnings: 0,
    total_earnings:               FieldValue.increment(accumulated),
    lastUnlockedAt:               FieldValue.serverTimestamp(),
    lastUnlockedMonth:            month,
  });

  // Notifier le livreur
  const fcmToken = data.fcmToken;
  if (fcmToken) {
    await fcm.send({
      token: fcmToken,
      notification: {
        title: "💰 Gains débloqués !",
        body:  `${accumulated} FCFA disponibles sur votre solde.`,
      },
      data: { type: "payout", amount: String(accumulated) },
    }).catch(console.error);
  }

  return { skipped: false, amount: accumulated, month };
}

// ── Notifier tous les livreurs payés ──────────────────
async function _notifyDriversPaid(drivers, month) {
  const notifications = drivers.map(async (driverDoc) => {
    const data        = driverDoc.data();
    const accumulated = data.monthly_accumulated_earnings ?? 0;
    if (accumulated <= 0) return;

    const fcmToken = data.fcmToken;
    if (!fcmToken) return;

    return fcm.send({
      token: fcmToken,
      notification: {
        title: "🎉 Paie du mois disponible !",
        body:  `Vos gains de ${month} (${accumulated} FCFA) sont maintenant disponibles.`,
      },
      data: { type: "monthly_payout", month },
    }).catch(console.error);
  });

  await Promise.allSettled(notifications);
}

// ══════════════════════════════════════════════════════
// UTILITAIRES
// ══════════════════════════════════════════════════════
function _checkAdminKey(req, res) {
  const key = req.query.adminKey ?? req.body.adminKey;
  if (key !== ADMIN_SECRET) {
    res.status(403).json({ error: "Accès refusé — clé admin invalide" });
    return false;
  }
  return true;
}

function _currentMonth() {
  const now = new Date();
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}`;
}