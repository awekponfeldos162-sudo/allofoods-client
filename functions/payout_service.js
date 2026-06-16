/**
 * allofoods — payout_service.js
 * Transfert automatique vers le restaurant via FedaPay Disbursement
 *
 * Appelé par fedapayWebhook après confirmation du paiement client.
 * POST https://api.fedapay.com/v1/payouts → restaurant MoMo number
 */

const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const https = require("https");

const db  = getFirestore();
const fcm = getMessaging();

// ── Clé secrète FedaPay (production) ──────────────
const FEDAPAY_SECRET = process.env.FEDAPAY_SECRET_KEY ?? "";
const FEDAPAY_SANDBOX = process.env.FEDAPAY_SANDBOX !== "false";
const FEDAPAY_BASE    = FEDAPAY_SANDBOX
  ? "sandbox-api.fedapay.com"
  : "api.fedapay.com";

// ══════════════════════════════════════════════════════
// TRANSFERT VERS RESTAURANT — fonction principale
// ══════════════════════════════════════════════════════

/**
 * @param {string} orderId
 * @param {string} restaurantId
 * @param {number} amount  — montant à transférer en FCFA
 * @param {string} restaurantName
 * @returns {Promise<{success: boolean, payoutId?: string, error?: string}>}
 */
async function payoutRestaurant({ orderId, restaurantId, amount, restaurantName }) {
  if (!amount || amount <= 0) {
    console.warn(`[payout] Montant invalide pour commande ${orderId} — skip`);
    return { success: false, error: "invalid_amount" };
  }

  if (!FEDAPAY_SECRET) {
    console.error("[payout] FEDAPAY_SECRET_KEY manquant — payout impossible");
    await _logFailure(orderId, restaurantId, amount, "missing_secret_key");
    return { success: false, error: "missing_secret_key" };
  }

  // ── Récupérer le numéro MoMo du restaurant ─────
  const restSnap = await db.collection("restaurants").doc(restaurantId).get();
  if (!restSnap.exists) {
    await _logFailure(orderId, restaurantId, amount, "restaurant_not_found");
    return { success: false, error: "restaurant_not_found" };
  }

  const restData = restSnap.data();
  const paymentNumber = restData.payment_number ?? restData.momoNumber ?? "";
  const operatorCode  = restData.payment_operator ?? "mtn"; // "mtn" | "moov"
  const ownerName     = restData.ownerName ?? restaurantName ?? "Restaurant";

  if (!paymentNumber) {
    console.warn(`[payout] Pas de numéro MoMo pour ${restaurantId} — payout reporté`);
    await _updateOrderStatus(orderId, "transfer_pending_number", {
      payoutNote: "Numéro MoMo du restaurant manquant",
    });
    await _logFailure(orderId, restaurantId, amount, "missing_payment_number");
    return { success: false, error: "missing_payment_number" };
  }

  // ── Formater le numéro ─────────────────────────
  const phone = paymentNumber.startsWith("229")
    ? paymentNumber
    : `229${paymentNumber}`;

  try {
    // ── 1. Créer le payout FedaPay ─────────────────
    const payoutBody = {
      amount,
      currency: { iso: "XOF" },
      mode: operatorCode,
      customer: {
        firstname: ownerName,
        phone_number: { number: phone, country: "BJ" },
      },
      metadata: {
        order_id:      orderId,
        restaurant_id: restaurantId,
        type:          "restaurant_payout",
      },
    };

    const createResult = await _fedaPayRequest("POST", "/v1/payouts", payoutBody);
    const payoutId = createResult?.payout?.id ?? createResult?.id;

    if (!payoutId) {
      throw new Error(`FedaPay payout create: pas d'ID — ${JSON.stringify(createResult)}`);
    }

    console.log(`[payout] Payout créé id=${payoutId} — envoi pour commande ${orderId}`);

    // ── 2. Déclencher l'envoi ──────────────────────
    await _fedaPayRequest("PUT", `/v1/payouts/${payoutId}/send_now`, {});

    console.log(`[payout] Payout envoyé id=${payoutId} — ${amount} FCFA → ${phone}`);

    // ── 3. Mettre à jour Firestore ─────────────────
    await _updateOrderStatus(orderId, "transferred", {
      payoutId,
      payoutAmount:  amount,
      payoutPhone:   phone,
      payoutOperator: operatorCode,
      transferredAt: FieldValue.serverTimestamp(),
    });

    await _logSuccess(orderId, restaurantId, amount, payoutId, phone);

    // ── 4. Notifier le restaurant ──────────────────
    const fcmToken = restData.fcmToken;
    if (fcmToken) {
      await fcm.send({
        token: fcmToken,
        notification: {
          title: "💸 Virement reçu !",
          body:  `${amount} FCFA ont été transférés sur votre ${operatorCode === "mtn" ? "MTN MoMo" : "Moov Money"}.`,
        },
        data: { type: "payout_received", orderId, amount: String(amount) },
        android: { priority: "high", notification: { sound: "default", channelId: "orders" } },
      }).catch(e => console.error("[payout] FCM error:", e));
    }

    return { success: true, payoutId };

  } catch (err) {
    console.error(`[payout] Erreur pour commande ${orderId}:`, err);

    await _updateOrderStatus(orderId, "transfer_failed", {
      payoutError:    String(err.message ?? err),
      transferFailedAt: FieldValue.serverTimestamp(),
    });

    await _logFailure(orderId, restaurantId, amount, String(err.message ?? err));

    // ── Alerter l'admin ────────────────────────────
    await db.collection("alerts").add({
      type:      "payout_failed",
      orderId,
      restaurantId,
      amount,
      error:     String(err.message ?? err),
      createdAt: FieldValue.serverTimestamp(),
    });

    return { success: false, error: String(err.message ?? err) };
  }
}

// ══════════════════════════════════════════════════════
// HELPERS
// ══════════════════════════════════════════════════════

function _fedaPayRequest(method, path, body) {
  return new Promise((resolve, reject) => {
    const payload = JSON.stringify(body);
    const opts = {
      hostname: FEDAPAY_BASE,
      path,
      method,
      headers: {
        "Content-Type":  "application/json",
        "Authorization": `Bearer ${FEDAPAY_SECRET}`,
        "Content-Length": Buffer.byteLength(payload),
      },
    };

    const req = https.request(opts, (res) => {
      let data = "";
      res.on("data", (chunk) => { data += chunk; });
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

async function _updateOrderStatus(orderId, status, extra = {}) {
  await db.collection("orders").doc(orderId).update({
    payoutStatus: status,
    ...extra,
  });
}

async function _logSuccess(orderId, restaurantId, amount, payoutId, phone) {
  await db.collection("payout_logs").add({
    orderId,
    restaurantId,
    amount,
    payoutId,
    phone,
    status:    "success",
    createdAt: FieldValue.serverTimestamp(),
  });
}

async function _logFailure(orderId, restaurantId, amount, reason) {
  await db.collection("payout_logs").add({
    orderId,
    restaurantId,
    amount,
    reason,
    status:    "failed",
    createdAt: FieldValue.serverTimestamp(),
  });
}

module.exports = { payoutRestaurant };
