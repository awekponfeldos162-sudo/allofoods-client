/**
 * allofoods — auto_withdrawal_service.js
 * Gestion du wallet restaurant : retrait automatique + retrait manuel
 *
 * Retrait auto  : déclenché quand wallet_balance >= 50 000 FCFA
 * Retrait manuel: déclenché par le restaurant via Cloud Function callable
 * Seuil minimum : 10 000 FCFA pour un retrait manuel
 */

const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging }             = require("firebase-admin/messaging");
const { HttpsError }               = require("firebase-functions/v2/https");
const https                        = require("https");

const db  = getFirestore();
const fcm = getMessaging();

// ── Constantes financières ─────────────────────────────
const MIN_WITHDRAWAL  = 10000;   // FCFA seuil retrait manuel
const AUTO_WITHDRAWAL = 50000;   // FCFA seuil retrait automatique
const COMMISSION_RATE = 0.05;    // 5% déduit du restaurant (com1)

// ── Config FedaPay ─────────────────────────────────────
const FEDAPAY_SECRET  = process.env.FEDAPAY_SECRET_KEY ?? "";
const FEDAPAY_SANDBOX = process.env.FEDAPAY_SANDBOX !== "false";
const FEDAPAY_BASE    = FEDAPAY_SANDBOX
  ? "sandbox-api.fedapay.com"
  : "api.fedapay.com";

// ══════════════════════════════════════════════════════

/**
 * Appelé quand wallet_balance >= 50 000 FCFA (fire-and-forget depuis le webhook)
 * @param {string} restaurantId
 * @param {number} balance  — solde actuel du wallet
 */
async function declencherAutoRetrait(restaurantId, balance) {
  const restSnap = await db.collection("restaurants").doc(restaurantId).get();
  if (!restSnap.exists) return;
  const rest = restSnap.data();

  // Vérification numéro MoMo
  if (!rest.momo_number) {
    console.warn(`[AutoRetrait] Numéro MoMo manquant pour ${restaurantId}`);
    await db.collection("alerts").add({
      type:          "auto_payout_no_momo",
      restaurant_id: restaurantId,
      balance,
      created_at:    FieldValue.serverTimestamp(),
    });
    return;
  }

  // Double-vérification du solde actuel (évite les doublons si appelé plusieurs fois)
  const freshSnap = await db.collection("restaurants").doc(restaurantId).get();
  const freshBalance = freshSnap.data()?.wallet_balance ?? 0;
  if (freshBalance < AUTO_WITHDRAWAL) {
    console.log(`[AutoRetrait] Solde insuffisant (${freshBalance}) — abandon`);
    return;
  }

  try {
    // ── 1. Créer le payout FedaPay ─────────────────────
    const payoutResult = await _fedaPayRequest("POST", "/v1/payouts", {
      amount:   freshBalance,
      currency: { iso: "XOF" },
      mode:     rest.momo_network || "mtn",
      customer: {
        firstname:    rest.name || "Restaurant",
        phone_number: { number: rest.momo_number, country: "BJ" },
      },
      metadata: {
        restaurant_id: restaurantId,
        type:          "auto_withdrawal",
      },
    });

    const payoutId = payoutResult?.payout?.id ?? payoutResult?.id;
    if (!payoutId) throw new Error(`FedaPay: pas d'ID — ${JSON.stringify(payoutResult)}`);

    // ── 2. Déclencher l'envoi immédiat ──────────────────
    await _fedaPayRequest("PUT", `/v1/payouts/${payoutId}/send_now`, {});

    console.log(`[AutoRetrait] ✅ ${freshBalance} FCFA → ${rest.momo_number} (id=${payoutId})`);

    // ── 3. Mise à jour Firestore atomique ───────────────
    const batch = db.batch();

    batch.update(db.collection("restaurants").doc(restaurantId), {
      wallet_balance:    0,
      wallet_updated_at: FieldValue.serverTimestamp(),
      total_withdrawn:   FieldValue.increment(freshBalance),
      last_auto_payout:  FieldValue.serverTimestamp(),
    });

    const txRef = db.collection("wallet_transactions").doc();
    batch.set(txRef, {
      restaurant_id:     restaurantId,
      type:              "auto_withdrawal",
      amount:            freshBalance,
      network:           rest.momo_network || "mtn",
      momo_number:       rest.momo_number,
      fedapay_payout_id: payoutId,
      status:            "completed",
      description:       `Retrait auto — seuil ${AUTO_WITHDRAWAL.toLocaleString()} FCFA atteint`,
      created_at:        FieldValue.serverTimestamp(),
    });

    await batch.commit();

    // ── 4. Notification FCM restaurant ─────────────────
    if (rest.fcmToken) {
      const network = rest.momo_network === "mtn" ? "MTN MoMo" : "Moov Money";
      await fcm.send({
        token: rest.fcmToken,
        notification: {
          title: "💸 Virement automatique !",
          body:  `${freshBalance.toLocaleString()} FCFA envoyés sur ${network} ${rest.momo_number}`,
        },
        data: { type: "auto_withdrawal", amount: String(freshBalance) },
        android: { priority: "high", notification: { sound: "default", channelId: "allofoods_orders" } },
      }).catch(e => console.error("[AutoRetrait] FCM error:", e));
    }

  } catch (e) {
    console.error(`[AutoRetrait] ❌ Échec pour ${restaurantId}:`, e);

    // Log l'échec
    await db.collection("wallet_transactions").add({
      restaurant_id: restaurantId,
      type:          "auto_withdrawal",
      amount:        freshBalance,
      status:        "failed",
      error:         String(e.message ?? e),
      created_at:    FieldValue.serverTimestamp(),
    });

    await db.collection("alerts").add({
      type:          "auto_payout_failed",
      restaurant_id: restaurantId,
      balance:       freshBalance,
      error:         String(e.message ?? e),
      created_at:    FieldValue.serverTimestamp(),
    });
  }
}

// ══════════════════════════════════════════════════════
// RETRAIT MANUEL — Cloud Function callable
// Appelée par le restaurant depuis l'app
// ══════════════════════════════════════════════════════

/**
 * @param {object} request  — Firebase Functions v2 callable request
 *   request.auth           — contexte Firebase auth
 *   request.data           — { restaurantId: string }
 * @returns {Promise<{success, amount, payout_id}>}
 */
async function handleManualWithdrawal(request) {
  // Vérification authentification (v2 callable)
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Non connecté");
  }

  const { restaurantId } = request.data;
  if (!restaurantId) {
    throw new HttpsError("invalid-argument", "restaurantId manquant");
  }

  const restSnap = await db.collection("restaurants").doc(restaurantId).get();
  if (!restSnap.exists) {
    throw new HttpsError("not-found", "Restaurant introuvable");
  }

  const rest    = restSnap.data();
  const balance = rest.wallet_balance ?? 0;

  // Vérifications métier
  if (balance < MIN_WITHDRAWAL) {
    throw new HttpsError(
      "failed-precondition",
      `Minimum ${MIN_WITHDRAWAL.toLocaleString()} FCFA requis. Solde actuel : ${balance.toLocaleString()} FCFA`,
    );
  }

  if (!rest.momo_number) {
    throw new HttpsError("not-found", "Numéro MoMo non configuré dans votre profil");
  }

  // Vérifier la réserve allofoods
  const financesSnap = await db.collection("admin").doc("finances").get();
  const reserve = financesSnap.data()?.reserve_disponible ?? 0;
  if (reserve < balance) {
    throw new HttpsError(
      "resource-exhausted",
      `Réserve insuffisante (${reserve.toLocaleString("fr-FR")} FCFA dispo, ${balance.toLocaleString("fr-FR")} demandé). Réessayez plus tard.`,
    );
  }

  if (!FEDAPAY_SECRET) {
    throw new HttpsError("internal", "Configuration paiement manquante");
  }

  try {
    // ── 1. Créer le payout FedaPay ─────────────────────
    const payoutResult = await _fedaPayRequest("POST", "/v1/payouts", {
      amount:   balance,
      currency: { iso: "XOF" },
      mode:     rest.momo_network || "mtn",
      customer: {
        firstname:    rest.name || "Restaurant",
        phone_number: { number: rest.momo_number, country: "BJ" },
      },
      metadata: {
        restaurant_id: restaurantId,
        type:          "manual_withdrawal",
      },
    });

    const payoutId = payoutResult?.payout?.id ?? payoutResult?.id;
    if (!payoutId) throw new Error(`FedaPay: pas d'ID — ${JSON.stringify(payoutResult)}`);

    // ── 2. Déclencher l'envoi ───────────────────────────
    await _fedaPayRequest("PUT", `/v1/payouts/${payoutId}/send_now`, {});

    console.log(`[ManualRetrait] ✅ ${balance} FCFA → ${rest.momo_number} (id=${payoutId})`);

    // ── 3. Mise à jour Firestore atomique ───────────────
    const batch = db.batch();

    batch.update(db.collection("restaurants").doc(restaurantId), {
      wallet_balance:    0,
      wallet_updated_at: FieldValue.serverTimestamp(),
      total_withdrawn:   FieldValue.increment(balance),
      last_withdrawal:   FieldValue.serverTimestamp(),
    });

    const txRef = db.collection("wallet_transactions").doc();
    batch.set(txRef, {
      restaurant_id:     restaurantId,
      type:              "withdrawal",
      amount:            balance,
      network:           rest.momo_network || "mtn",
      momo_number:       rest.momo_number,
      fedapay_payout_id: payoutId,
      status:            "completed",
      description:       "Retrait manuel",
      created_at:        FieldValue.serverTimestamp(),
    });

    batch.set(db.collection("admin").doc("finances"), {
      reserve_disponible: FieldValue.increment(-balance),
      total_paye_jour:    FieldValue.increment(balance),
      last_updated:       FieldValue.serverTimestamp(),
    }, { merge: true });

    batch.set(db.collection("audit_logs").doc(), {
      type:         "retrait_manuel",
      restaurantId: restaurantId,
      amount:       balance,
      walletBefore: balance,
      walletAfter:  0,
      fedapayId:    payoutId,
      momoNumber:   rest.momo_number,
      createdAt:    FieldValue.serverTimestamp(),
    });

    await batch.commit();

    return { success: true, amount: balance, payout_id: payoutId };

  } catch (e) {
    console.error(`[ManualRetrait] ❌ Échec pour ${restaurantId}:`, e);

    await db.collection("wallet_transactions").add({
      restaurant_id: restaurantId,
      type:          "withdrawal",
      amount:        balance,
      status:        "failed",
      error:         String(e.message ?? e),
      created_at:    FieldValue.serverTimestamp(),
    });

    throw new HttpsError("internal", `Virement échoué : ${e.message ?? e}`);
  }
}

// ══════════════════════════════════════════════════════
// HELPER — Requête HTTPS vers FedaPay
// ══════════════════════════════════════════════════════
function _fedaPayRequest(method, path, body) {
  return new Promise((resolve, reject) => {
    const payload = JSON.stringify(body);
    const opts = {
      hostname: FEDAPAY_BASE,
      path,
      method,
      headers: {
        "Content-Type":   "application/json",
        "Authorization":  `Bearer ${FEDAPAY_SECRET}`,
        "Content-Length": Buffer.byteLength(payload),
      },
    };

    const req = https.request(opts, (res) => {
      let data = "";
      res.on("data",  chunk => { data += chunk; });
      res.on("end", () => {
        try {
          const parsed = JSON.parse(data);
          if (res.statusCode >= 200 && res.statusCode < 300) {
            resolve(parsed);
          } else {
            reject(new Error(`FedaPay ${method} ${path} → HTTP ${res.statusCode}: ${data}`));
          }
        } catch {
          reject(new Error(`FedaPay parse error: ${data}`));
        }
      });
    });

    req.on("error", reject);
    req.write(payload);
    req.end();
  });
}

module.exports = { declencherAutoRetrait, handleManualWithdrawal, COMMISSION_RATE, MIN_WITHDRAWAL, AUTO_WITHDRAWAL, _fedaPayRequest };
