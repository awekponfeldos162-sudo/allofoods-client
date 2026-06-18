/**
 * allofoods — Cloud Functions
 * Firebase Functions v2
 *
 * Fonctions :
 * 1. onNewOrder          → Notifie le restaurant quand une commande arrive
 * 2. onOrderStatusChange → Notifie le client quand le statut change
 * 3. onOrderReady        → Dispatch livreur proche du restaurant
 * 4. fedapayWebhook      → Valide le paiement FedaPay côté serveur
 * 5. onNewSupportTicket  → Notifie l'admin d'un nouveau ticket support
 * 6. scheduledCleanup    → Nettoyage automatique (chaque nuit à minuit)
 */

const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onRequest } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const crypto     = require("crypto");
const nodemailer = require("nodemailer");

initializeApp();
const db  = getFirestore();
const fcm = getMessaging();

// ── Mailer partagé (lazy, utilise les env vars au moment de l'appel) ──────────
function _createMailer() {
  const user = process.env.EMAIL_USER;
  const pass = process.env.EMAIL_PASS;
  if (!user || !pass) return null;
  return nodemailer.createTransport({ service: "gmail", auth: { user, pass } });
}

// ── Alerte email réserve basse ────────────────────────────────────────────────
async function _sendAlertReserveBasse(reserve, montantRequis) {
  const adminEmail = process.env.ADMIN_EMAIL;
  const mailer     = _createMailer();
  if (!mailer || !adminEmail) return;
  try {
    await mailer.sendMail({
      from:    `"allofoods Finance" <${process.env.EMAIL_USER}>`,
      to:      adminEmail,
      subject: "⚠️ allofoods — Réserve FedaPay insuffisante",
      html: `<div style="font-family:Arial,sans-serif;padding:24px;background:#fff8f0;border-left:4px solid #e65100">
        <h2 style="color:#e65100;margin:0 0 12px">⚠️ Réserve FedaPay basse</h2>
        <p>Réserve disponible : <strong>${Number(reserve).toLocaleString("fr-FR")} FCFA</strong></p>
        <p>Montant requis : <strong>${Number(montantRequis).toLocaleString("fr-FR")} FCFA</strong></p>
        <p>Rechargez votre compte FedaPay Business pour permettre les virements automatiques.</p>
        <p style="color:#999;font-size:11px;margin-top:16px">allofoods · Système automatique · Ne pas répondre</p>
      </div>`,
    });
  } catch (e) {
    console.warn("[sendAlertReserveBasse]", e.message);
  }
  await db.collection("alerts").add({
    type:           "reserve_basse",
    reserve,
    montantRequis,
    createdAt:      FieldValue.serverTimestamp(),
  }).catch(() => {});
}

// ── Reçu de paiement HTML envoyé au client ────────────────────────────────────
async function _sendPaymentReceipt({ clientEmail, clientName, orderId, txId,
  restaurantName, items, foodAmount, deliveryFee, serviceFee, totalAmount }) {
  const mailer = _createMailer();
  if (!mailer) {
    console.warn("[_sendPaymentReceipt] EMAIL_USER/EMAIL_PASS manquants dans .env");
    return;
  }

  const shortId = orderId.substring(0, 8).toUpperCase();
  const shortTx = txId ? String(txId).substring(0, 12) : "—";
  const date    = new Date().toLocaleString("fr-FR", { timeZone: "Africa/Porto-Novo" });

  // Générer les lignes articles
  const itemsRows = Array.isArray(items) && items.length > 0
    ? items.map(it => {
        const name  = it.name ?? it.itemName ?? "Article";
        const qty   = it.quantity ?? it.qty ?? 1;
        const price = it.price ?? it.unitPrice ?? 0;
        return `<tr>
          <td style="padding:8px 12px;border-bottom:1px solid #f0f0f0">${name}</td>
          <td style="padding:8px 12px;border-bottom:1px solid #f0f0f0;text-align:center">×${qty}</td>
          <td style="padding:8px 12px;border-bottom:1px solid #f0f0f0;text-align:right">${(price * qty).toLocaleString("fr-FR")} FCFA</td>
        </tr>`;
      }).join("")
    : `<tr><td colspan="3" style="padding:8px 12px;color:#999;text-align:center">—</td></tr>`;

  const html = `<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body style="margin:0;padding:20px;background:#f5f5f5;font-family:Arial,sans-serif">
<div style="max-width:580px;margin:0 auto;background:white;border-radius:16px;overflow:hidden;box-shadow:0 4px 20px rgba(0,0,0,0.08)">

  <!-- Header -->
  <div style="background:linear-gradient(135deg,#FF6600,#FF9800);padding:32px 24px;text-align:center">
    <div style="font-size:48px;margin-bottom:8px">✅</div>
    <h1 style="color:white;margin:0;font-size:24px;font-weight:bold">Paiement confirmé !</h1>
    <p style="color:rgba(255,255,255,0.9);margin:8px 0 0;font-size:14px">${date}</p>
  </div>

  <!-- Salutation -->
  <div style="padding:24px 24px 0">
    <p style="margin:0;font-size:15px;color:#333">Bonjour <strong>${clientName}</strong>,</p>
    <p style="margin:8px 0 0;color:#666;font-size:14px">
      Votre commande chez <strong>${restaurantName}</strong> a été payée avec succès.
      Voici votre reçu.
    </p>
  </div>

  <!-- Référence -->
  <div style="margin:16px 24px;background:#fff8f0;border:1px solid #FFD0A0;border-radius:10px;padding:14px 16px;display:flex;justify-content:space-between">
    <div>
      <p style="margin:0;font-size:11px;color:#FF6600;font-weight:bold;text-transform:uppercase">N° Commande</p>
      <p style="margin:4px 0 0;font-size:16px;font-weight:bold;color:#333">#${shortId}</p>
    </div>
    <div style="text-align:right">
      <p style="margin:0;font-size:11px;color:#FF6600;font-weight:bold;text-transform:uppercase">Réf. Transaction</p>
      <p style="margin:4px 0 0;font-size:14px;color:#666">${shortTx}</p>
    </div>
  </div>

  <!-- Articles -->
  <div style="padding:0 24px">
    <p style="margin:0 0 8px;font-weight:bold;color:#333;font-size:14px">🍽️ ${restaurantName}</p>
    <table style="width:100%;border-collapse:collapse;font-size:13px">
      <thead>
        <tr style="background:#f9f9f9">
          <th style="padding:8px 12px;text-align:left;color:#666;font-weight:600">Article</th>
          <th style="padding:8px 12px;text-align:center;color:#666;font-weight:600">Qté</th>
          <th style="padding:8px 12px;text-align:right;color:#666;font-weight:600">Prix</th>
        </tr>
      </thead>
      <tbody>${itemsRows}</tbody>
    </table>
  </div>

  <!-- Totaux -->
  <div style="margin:16px 24px;border-top:2px solid #f0f0f0;padding-top:12px;font-size:13px">
    <div style="display:flex;justify-content:space-between;padding:4px 0;color:#666">
      <span>Sous-total nourriture</span><span>${Number(foodAmount).toLocaleString("fr-FR")} FCFA</span>
    </div>
    <div style="display:flex;justify-content:space-between;padding:4px 0;color:#666">
      <span>Frais de livraison</span><span>${Number(deliveryFee).toLocaleString("fr-FR")} FCFA</span>
    </div>
    <div style="display:flex;justify-content:space-between;padding:4px 0;color:#FF6600">
      <span>Commission service (5%)</span><span>${Number(serviceFee).toLocaleString("fr-FR")} FCFA</span>
    </div>
    <div style="display:flex;justify-content:space-between;padding:10px 0;margin-top:8px;border-top:2px solid #FF6600;font-weight:bold;font-size:16px;color:#333">
      <span>TOTAL PAYÉ</span><span style="color:#FF6600">${Number(totalAmount).toLocaleString("fr-FR")} FCFA</span>
    </div>
  </div>

  <!-- Statut -->
  <div style="margin:0 24px 24px;background:#e8f5e9;border-radius:10px;padding:14px 16px;text-align:center">
    <p style="margin:0;color:#2e7d32;font-weight:bold;font-size:14px">🏍️ Votre livreur est en route !</p>
    <p style="margin:6px 0 0;color:#388e3c;font-size:12px">Vous recevrez une notification dès sa confirmation.</p>
  </div>

  <!-- Footer -->
  <div style="background:#f9f9f9;padding:16px 24px;text-align:center;border-top:1px solid #f0f0f0">
    <p style="margin:0;font-size:12px;color:#999">allofoods · Livraison rapide à Cotonou, Bénin</p>
    <p style="margin:4px 0 0;font-size:11px;color:#bbb">Ce reçu est généré automatiquement — ne pas répondre</p>
  </div>

</div>
</body>
</html>`;

  await mailer.sendMail({
    from:    `"allofoods" <${process.env.EMAIL_USER}>`,
    to:      clientEmail,
    subject: `✅ Reçu #${shortId} — ${Number(totalAmount).toLocaleString("fr-FR")} FCFA chez ${restaurantName}`,
    html,
  });

  console.log(`[_sendPaymentReceipt] Reçu envoyé à ${clientEmail} — commande #${shortId}`);
}

const payout = require('./admin_payout_script');
exports.unlockOneDriver   = payout.unlockOneDriver;
exports.unlockAllDrivers  = payout.unlockAllDrivers;
exports.driverBalance     = payout.driverBalance;
exports.monthlyPayoutAuto = payout.monthlyPayoutAuto;

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { declencherAutoRetrait, handleManualWithdrawal, COMMISSION_RATE, _fedaPayRequest } = require('./auto_withdrawal_service');
const https = require("https");

// ── Config FedaPay (partagée avec auto_withdrawal_service) ────────
const _FEDAPAY_SECRET  = process.env.FEDAPAY_SECRET_KEY ?? "";
const _FEDAPAY_SANDBOX = process.env.FEDAPAY_SANDBOX !== "false";
const _FEDAPAY_BASE    = _FEDAPAY_SANDBOX ? "sandbox-api.fedapay.com" : "api.fedapay.com";
const _FEDAPAY_CHECKOUT= _FEDAPAY_SANDBOX
  ? "https://sandbox-checkout.fedapay.com"
  : "https://checkout.fedapay.com";

// ── GET helper FedaPay (sans body) ────────────────────────────────
function _fedaPayGet(path) {
  return new Promise((resolve, reject) => {
    const opts = {
      hostname: _FEDAPAY_BASE,
      path,
      method: "GET",
      headers: {
        "Authorization": `Bearer ${_FEDAPAY_SECRET}`,
        "Content-Type":  "application/json",
      },
    };
    const req = https.request(opts, (res) => {
      let data = "";
      res.on("data",  chunk => { data += chunk; });
      res.on("end", () => {
        try {
          const parsed = JSON.parse(data);
          if (res.statusCode >= 200 && res.statusCode < 300) resolve(parsed);
          else reject(new Error(`FedaPay GET ${path} → HTTP ${res.statusCode}: ${data}`));
        } catch { reject(new Error(`FedaPay parse error: ${data}`)); }
      });
    });
    req.on("error", reject);
    req.end();
  });
}

// ══════════════════════════════════════════════════════════════════
// PAIEMENT CLIENT — Étape 1 : Créer la transaction FedaPay
// Callable : initFedaPayPayment({ orderId })
// Retourne : { transactionId, token, paymentUrl }
// ══════════════════════════════════════════════════════════════════
exports.initFedaPayPayment = onCall({ region: "europe-west1" }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Non connecté");

  const { orderId } = request.data ?? {};
  if (!orderId) throw new HttpsError("invalid-argument", "orderId requis");
  if (!_FEDAPAY_SECRET) throw new HttpsError("internal", "Configuration paiement manquante");

  // Lire le montant depuis Firestore (non falsifiable côté client)
  const orderSnap = await db.collection("orders").doc(orderId).get();
  if (!orderSnap.exists) throw new HttpsError("not-found", "Commande introuvable");

  const order          = orderSnap.data();
  const amount         = order.paidOnline ?? order.totalAmount ?? 0;
  const restaurantName = order.restaurantName ?? "Restaurant";
  const customerName   = order.customerName   ?? "Client";
  const customerEmail  = order.clientEmail    ?? request.auth.token.email ?? "client@allofoods.bj";

  if (amount <= 0) throw new HttpsError("failed-precondition", "Montant invalide");

  try {
    const result = await _fedaPayRequest("POST", "/v1/transactions", {
      description:  `allofoods — ${restaurantName}`,
      amount,
      currency:     { iso: "XOF" },
      callback_url: "https://allofoods-5d32b.web.app/payment/callback",
      customer:     { firstname: customerName, email: customerEmail },
      metadata:     { order_id: orderId },
    });

    const tx    = result?.v1_transaction ?? result;
    const txId  = tx?.id;
    const token = tx?.payment_token?.token ?? "";

    if (!txId) throw new Error(`FedaPay: pas d'ID — ${JSON.stringify(result)}`);

    const paymentUrl = token
      ? `${_FEDAPAY_CHECKOUT}/v1/checkout-button/transactions/${token}`
      : "";

    // Sauvegarder l'ID de transaction dans la commande
    await db.collection("orders").doc(orderId).update({
      fedaPayTransactionId: String(txId),
      fedaPayToken:         token,
      updatedAt:            FieldValue.serverTimestamp(),
    });

    console.log(`[initFedaPayPayment] Transaction ${txId} créée pour commande ${orderId}`);
    return { transactionId: String(txId), token, paymentUrl };

  } catch (e) {
    console.error("[initFedaPayPayment] Erreur:", e.message);
    throw new HttpsError("internal", `Erreur FedaPay : ${e.message}`);
  }
});

// ══════════════════════════════════════════════════════════════════
// PAIEMENT CLIENT — Étape 2 : Pousser le paiement sur le téléphone
// Callable : sendFedaPayMomo({ token, phoneNumber, operator })
// Déclenche le USSD push sur le téléphone du client (send_now)
// ══════════════════════════════════════════════════════════════════
exports.sendFedaPayMomo = onCall({ region: "europe-west1" }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Non connecté");

  const { token, phoneNumber, operator } = request.data ?? {};
  if (!token)       throw new HttpsError("invalid-argument", "Token manquant");
  if (!phoneNumber) throw new HttpsError("invalid-argument", "Numéro de téléphone manquant");
  if (!_FEDAPAY_SECRET) throw new HttpsError("internal", "Configuration paiement manquante");

  // Opérateurs non disponibles pour le push direct → fallback checkout WebView
  const supportedOperators = ["mtn_open", "moov", "celtis"];
  if (!supportedOperators.includes(operator)) {
    return { useCheckout: true, message: "Opérateur non disponible pour le push direct." };
  }

  try {
    await _fedaPayRequest("POST", `/v1/transactions/${token}/send_now`, {
      phone_number: { number: phoneNumber, country: "BJ" },
      method:       operator,
    });

    console.log(`[sendFedaPayMomo] USSD envoyé → ${phoneNumber} (${operator})`);
    return { success: true, message: "Notification USSD envoyée. Confirmez sur votre téléphone." };

  } catch (e) {
    console.error("[sendFedaPayMomo] Erreur:", e.message);

    // Si l'opérateur rejette le push → proposer le checkout WebView
    if (e.message?.includes("400") || e.message?.includes("422")) {
      return { useCheckout: true, message: "Push non disponible pour cet opérateur. Utilisation du checkout." };
    }
    throw new HttpsError("internal", `Erreur push MoMo : ${e.message}`);
  }
});

// ══════════════════════════════════════════════════════════════════
// PAIEMENT CLIENT — Étape 3 : Vérifier le statut du paiement
// Callable : checkFedaPayStatus({ transactionId })
// Retourne : { success, status, isPaid, isExpired, amount }
// ══════════════════════════════════════════════════════════════════
exports.checkFedaPayStatus = onCall({ region: "europe-west1" }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Non connecté");

  const { transactionId } = request.data ?? {};
  if (!transactionId) throw new HttpsError("invalid-argument", "transactionId requis");
  if (!_FEDAPAY_SECRET) throw new HttpsError("internal", "Configuration paiement manquante");

  try {
    const result = await _fedaPayGet(`/v1/transactions/${transactionId}`);
    const tx     = result?.v1_transaction ?? result;
    const status = tx?.status ?? "";

    console.log(`[checkFedaPayStatus] tx=${transactionId} status=${status}`);
    return {
      success:   true,
      status,
      isPaid:    status === "approved",
      isExpired: status === "expired",
      amount:    tx?.amount ?? 0,
    };

  } catch (e) {
    console.error("[checkFedaPayStatus] Erreur:", e.message);
    throw new HttpsError("internal", `Erreur vérification : ${e.message}`);
  }
});

// ══════════════════════════════════════════════════════════════════
// FEDAPAY WEBHOOK — Validation paiement côté serveur
// Endpoint HTTP POST : /fedapayWebhook
// À configurer dans le dashboard FedaPay > Webhooks
// ══════════════════════════════════════════════════════════════════
exports.fedapayWebhook = onRequest(
  { cors: false, region: "europe-west1" },
  async (req, res) => {
    // FedaPay n'envoie que des POST
    if (req.method !== "POST") {
      res.status(405).send("Method Not Allowed");
      return;
    }

    // ── Vérification signature HMAC (optionnel mais recommandé) ──
    // Récupérer la clé secrète webhook depuis Firebase Secrets ou env
    const webhookSecret = process.env.FEDAPAY_WEBHOOK_SECRET ?? "";
    if (webhookSecret) {
      const signature = req.headers["x-fedapay-signature"] ?? "";
      const payload   = JSON.stringify(req.body);
      const expected  = crypto
        .createHmac("sha256", webhookSecret)
        .update(payload)
        .digest("hex");
      if (signature !== expected) {
        console.warn("[fedapayWebhook] Signature invalide — requête ignorée");
        // On renvoie 200 pour éviter les retentatives, mais on n'agit pas
        res.status(200).json({ ignored: true, reason: "invalid_signature" });
        return;
      }
    }

    const event  = req.body;
    const name   = event?.name ?? "";               // ex. "transaction.approved"
    const tx     = event?.object ?? event?.entity ?? {};
    const txId   = String(tx?.id ?? "");
    const status = tx?.status ?? "";                // "approved" | "declined" | "canceled"
    const amount = tx?.amount ?? 0;

    // L'orderId est stocké dans metadata lors de createTransaction()
    const orderId = tx?.metadata?.order_id ?? tx?.reference ?? "";

    console.log(`[fedapayWebhook] event=${name} txId=${txId} status=${status} orderId=${orderId}`);

    // Toujours répondre 200 dès que possible pour que FedaPay arrête les retentatives
    // Le traitement Firestore se fait en arrière-plan (fire-and-forget)
    res.status(200).json({ received: true });

    if (!orderId) {
      console.warn(`[fedapayWebhook] Pas d'orderId dans metadata — txId=${txId}`);
      return;
    }

    try {
      if (name === "transaction.approved" || status === "approved") {
        // ── Récupérer la commande pour la ventilation ──
        const orderSnap = await db.collection("orders").doc(orderId).get();
        if (!orderSnap.exists) {
          console.warn(`[fedapayWebhook] Commande ${orderId} introuvable`);
          return;
        }
        const order        = orderSnap.data();
        const restaurantId = order.restaurantId ?? "";

        // ── Modèle financier : com1 + com2 ──────────────────────────────────
        // com1 = food × 5% (déduit du restaurant → restoAmount = food - com1)
        // com2 = food × 5% (ajouté au client     → serviceFee)
        // alloProfit = com1 + com2 (bénéfice réel allofoods)
        // driverAmount = deliveryFee (reversé au livreur, transit allofoods)
        const food        = order.foodAmount  ?? 0;
        const deliveryFee = order.deliveryFee ?? 0;
        const commission  = Math.round(food * COMMISSION_RATE); // com1
        const serviceFee  = Math.round(food * COMMISSION_RATE); // com2
        const restoAmount = food - commission;                  // wallet restaurant
        const alloProfit  = commission + serviceFee;            // bénéfice allofoods
        const driverAmount= deliveryFee;                        // transit → livreur

        // Crédit wallet = restoAmount (food net après commission)
        const walletCredit = restoAmount;

        const ventilation = {
          foodAmount:   food,
          commission,           // com1 : déduit du restaurant
          serviceFee,           // com2 : ajouté au client
          deliveryFee,
          restoAmount,          // ce que le restaurant reçoit
          driverAmount,         // ce qui va au livreur (= deliveryFee)
          alloProfit,           // bénéfice net allofoods (com1 + com2)
          totalClient:  food + serviceFee + deliveryFee,
        };

        // ── Transaction Firestore atomique ──────────────────────────────────
        await db.runTransaction(async (t) => {
          // Idempotence : ignorer si déjà traité
          const freshSnap = await t.get(db.collection("orders").doc(orderId));
          if (freshSnap.data()?.paymentStatus === "PAID") return;

          // 1. Commande → PAID
          t.update(db.collection("orders").doc(orderId), {
            paymentStatus:      "PAID",
            status:             "paid",
            transactionId:      txId,
            paymentAmount:      amount,
            ventilation,
            restoAmount,
            alloProfit,
            driverAmount,
            paymentConfirmedAt: FieldValue.serverTimestamp(),
          });

          // 2. Créditer le wallet virtuel du restaurant
          if (restaurantId) {
            t.update(db.collection("restaurants").doc(restaurantId), {
              wallet_balance:       FieldValue.increment(walletCredit),
              wallet_updated_at:    FieldValue.serverTimestamp(),
              total_earned:         FieldValue.increment(walletCredit),
              "stats.totalOrders":  FieldValue.increment(1),
              "stats.totalRevenue": FieldValue.increment(restoAmount),
              "stats.lastOrderAt":  FieldValue.serverTimestamp(),
            });
          }

          // Tracking fonds en attente (libérés par FedaPay dans ~72h)
          t.set(db.collection("admin").doc("finances"), {
            fonds_en_attente: FieldValue.increment(restoAmount),
            last_updated:     FieldValue.serverTimestamp(),
          }, { merge: true });

          // 3. Log transaction wallet
          t.set(db.collection("wallet_transactions").doc(), {
            restaurant_id: restaurantId || null,
            type:          "credit",
            amount:        walletCredit,
            order_id:      orderId,
            food_amount:   food,
            commission,
            status:        "completed",
            description:   `Commande #${orderId.substring(0, 8).toUpperCase()} — paiement reçu`,
            created_at:    FieldValue.serverTimestamp(),
          });

          // 4. Log paiement global
          t.set(db.collection("payment_logs").doc(), {
            transactionId: txId,
            orderId,
            amount,
            ventilation,
            restaurantId:  restaurantId || null,
            event:         name,
            status:        "approved",
            createdAt:     FieldValue.serverTimestamp(),
          });
        });

        // ── Notifier le client ──
        if (order.clientUid) {
          const userSnap = await db.collection("users").doc(order.clientUid).get();
          const fcmToken = userSnap.data()?.fcmToken;
          if (fcmToken) {
            await fcm.send({
              token: fcmToken,
              notification: {
                title: "✅ Paiement confirmé !",
                body:  `Votre commande chez ${order.restaurantName ?? "le restaurant"} est en cours de préparation.`,
              },
              data: { type: "payment_confirmed", orderId, screen: "tracking" },
              android: { priority: "high", notification: { sound: "default", channelId: "allofoods_orders" } },
              apns: { headers: { "apns-priority": "10" }, payload: { aps: { sound: "default", contentAvailable: 1 } } },
            }).catch(e => console.error("[fedapayWebhook] FCM error:", e));
          }

          await db.collection("users").doc(order.clientUid)
            .collection("notifications").add({
              title:     "✅ Paiement confirmé !",
              message:   `Votre commande chez ${order.restaurantName ?? "le restaurant"} a été payée avec succès.`,
              type:      "payment",
              isRead:    false,
              orderId,
              createdAt: FieldValue.serverTimestamp(),
            });

          // ── Reçu email au client ──────────────────────────────
          const clientEmail = userSnap.data()?.email;
          if (clientEmail) {
            _sendPaymentReceipt({
              clientEmail,
              clientName:     userSnap.data()?.name ?? userSnap.data()?.displayName ?? "Client",
              orderId,
              txId,
              restaurantName: order.restaurantName ?? "Restaurant",
              items:          order.items          ?? [],
              foodAmount:     food,
              deliveryFee:    order.deliveryFee    ?? 0,
              serviceFee:     order.serviceFee     ?? 0,
              totalAmount:    amount,
            }).catch(e => console.warn("[fedapayWebhook] Email reçu erreur:", e.message));
          }
        }

        // ── Notifier le restaurant — paiement confirmé (2e notification) ──
        if (restaurantId) {
          const restSnap  = await db.collection("restaurants").doc(restaurantId).get();
          const restToken = restSnap.data()?.fcmToken;
          if (restToken) {
            await fcm.send({
              token: restToken,
              notification: {
                title: "✅ Paiement confirmé — Préparez !",
                body:  `${restoAmount.toLocaleString("fr-FR")} FCFA · Commencez la préparation.`,
              },
              data: { type: "order_paid", orderId, screen: "order_detail" },
              android: {
                priority: "high",
                notification: { sound: "alarme", channelId: "allofoods_orders" },
              },
              apns: {
                headers: { "apns-priority": "10" },
                payload: { aps: { sound: "alarme.mp3", contentAvailable: 1, "interruption-level": "critical" } },
              },
            }).catch(e => console.error("[fedapayWebhook] FCM restaurant error:", e));
          }
        }

        console.log(`[fedapayWebhook] Commande ${orderId} confirmée — ${amount} FCFA | wallet+${walletCredit} FCFA → ${restaurantId}`);

      } else if (
        name === "transaction.declined" || status === "declined" ||
        name === "transaction.canceled" || status === "canceled"
      ) {
        // ── Paiement échoué / annulé ──
        await db.collection("orders").doc(orderId).update({
          paymentStatus: "FAILED",
          status:        "cancelled",
          transactionId: txId,
          failedAt:      FieldValue.serverTimestamp(),
        });

        await db.collection("payment_logs").add({
          transactionId: txId,
          orderId,
          amount,
          event:     name,
          status,
          createdAt: FieldValue.serverTimestamp(),
        });

        console.log(`[fedapayWebhook] Commande ${orderId} échouée — event=${name}`);

      } else {
        // Événement non géré (transaction.created, etc.) — ignorer
        console.log(`[fedapayWebhook] Événement ignoré: ${name}`);
      }

    } catch (err) {
      console.error("[fedapayWebhook] Erreur Firestore:", err);
      // Pas de res.status(500) ici — la réponse 200 a déjà été envoyée
    }
  }
);

// ══════════════════════════════════════════════════════════════════
// 1. NOUVELLE COMMANDE → Notifier le restaurant
// Trigger : nouvelle entrée dans /orders/{orderId}
// ══════════════════════════════════════════════════════════════════
exports.onNewOrder = onDocumentCreated("orders/{orderId}", async (event) => {
  const order    = event.data.data();
  const orderId  = event.params.orderId;

  if (!order) return;

  const restaurantId   = order.restaurantId;
  const restaurantName = order.restaurantName ?? "Restaurant";
  const itemCount      = (order.items ?? []).length;
  const foodAmount     = order.foodAmount ?? order.totalAmount ?? 0;

  console.log(`[onNewOrder] Nouvelle commande ${orderId} → ${restaurantName}`);

  try {
    // ── Récupérer le token FCM du restaurant ──
    const restSnap = await db.collection("restaurants").doc(restaurantId).get();
    if (!restSnap.exists) {
      console.warn(`[onNewOrder] Restaurant ${restaurantId} introuvable`);
      return;
    }

    const fcmToken = restSnap.data()?.fcmToken;

    // ── Notifier le restaurant immédiatement pour toutes les commandes ──
    // Une 2e notification "Paiement confirmé" sera envoyée par fedapayWebhook.
    if (fcmToken) {
      await fcm.send({
        token: fcmToken,
        notification: {
          title: "🍽️ Nouvelle commande !",
          body:  `${itemCount} article${itemCount > 1 ? "s" : ""} · ${foodAmount.toLocaleString("fr-FR")} FCFA`,
        },
        data: {
          type:    "new_order",
          orderId: orderId,
          screen:  "order_detail",
        },
        android: {
          priority: "high",
          notification: { sound: "alarme", channelId: "allofoods_orders" },
        },
        apns: {
          headers: { "apns-priority": "10" },
          payload: { aps: { sound: "alarme.mp3", contentAvailable: 1, "interruption-level": "critical" } },
        },
      });
      console.log(`[onNewOrder] Notif envoyée à ${restaurantName} — commande ${orderId}`);
    } else {
      console.warn(`[onNewOrder] Pas de token FCM pour ${restaurantName} (${restaurantId})`);
    }

    // ── Stats du restaurant (comptées à la création, avant paiement) ──
    await db.collection("restaurants").doc(restaurantId).update({
      "stats.pendingOrders": FieldValue.increment(1),
      "stats.lastOrderAt":   FieldValue.serverTimestamp(),
    }).catch(() => {}); // Non-bloquant si le champ n'existe pas encore

  } catch (err) {
    console.error("[onNewOrder] Erreur:", err);
  }
});

// onOrderStatusChange supprimé — géré par onOrderStatusChanged (codebase allofoods-admin)
// qui inclut la logique de points fidélité.

// ══════════════════════════════════════════════════════════════════
// [SUPPRIMÉ] 2. CHANGEMENT STATUT COMMANDE → dupliqué dans allofoods-admin
// ══════════════════════════════════════════════════════════════════
if (false) exports.onOrderStatusChange = onDocumentUpdated("orders/{orderId}", async (event) => {
  const before  = event.data.before.data();
  const after   = event.data.after.data();
  const orderId = event.params.orderId;

  if (!before || !after) return;
  if (before.status === after.status) return; // Pas de changement

  const clientUid      = after.clientUid;
  const restaurantName = after.restaurantName ?? "le restaurant";
  const newStatus      = after.status;

  console.log(`[onOrderStatusChange] ${orderId} : ${before.status} → ${newStatus}`);

  // Messages par statut
  const messages = {
    // ── Nouveau flow (post-suppression confirmation restaurant) ──
    paid: {
      title: "✅ Commande confirmée !",
      body:  `${restaurantName} commence la préparation de votre commande.`,
    },
    preparing: {
      title: "👨‍🍳 En préparation",
      body:  `${restaurantName} cuisine votre commande.`,
    },
    ready_for_pickup: {
      title: "🎁 Commande prête !",
      body:  "Votre livreur est en route pour récupérer votre commande.",
    },
    delivering: {
      title: "🏍️ Livreur en route !",
      body:  `Votre livreur arrive. ETA: ${after.estimatedArrival ?? "~30 min"}`,
    },
    delivered: {
      title: "🎉 Livré ! Bon appétit !",
      body:  `Votre commande chez ${restaurantName} est arrivée.`,
    },
    cancelled: {
      title: "❌ Commande annulée",
      body:  "Votre commande a été annulée. Contactez le support.",
    },
    cancelled_by_restaurant: {
      title: "❌ Commande non disponible",
      body:  `${restaurantName} n'est pas en mesure de traiter votre commande.`,
    },
    // ── Anciens statuts (rétrocompatibilité commandes existantes) ──
    confirmed: {
      title: "✅ Commande confirmée !",
      body:  `${restaurantName} prépare votre commande.`,
    },
    ready: {
      title: "🎁 Commande prête !",
      body:  "Votre livreur arrive bientôt.",
    },
    en_route: {
      title: "🏍️ Livreur en route !",
      body:  `Votre livreur arrive. ETA: ${after.estimatedArrival ?? "~30 min"}`,
    },
  };

  const msg = messages[newStatus];
  if (!msg) return;

  try {
    // ── Récupérer le token FCM du client ──
    const userSnap = await db.collection("users").doc(clientUid).get();
    if (!userSnap.exists) return;

    const fcmToken = userSnap.data()?.fcmToken;

    // ── Notification FCM ──
    if (fcmToken) {
      await fcm.send({
        token: fcmToken,
        notification: { title: msg.title, body: msg.body },
        data: {
          type:    "order_status",
          orderId: orderId,
          status:  newStatus,
          screen:  "tracking",
        },
        android: {
          priority: "high",
          notification: { sound: "default", channelId: "allofoods_orders" },
        },
        apns: { headers: { "apns-priority": "10" }, payload: { aps: { sound: "default", contentAvailable: 1 } } },
      });
    }

    // ── Notification Firestore (historique) ──
    await db.collection("users").doc(clientUid)
      .collection("notifications").add({
        title:     msg.title,
        message:   msg.body,
        type:      "order",
        isRead:    false,
        orderId:   orderId,
        status:    newStatus,
        createdAt: FieldValue.serverTimestamp(),
      });

    // ── Si livré → créditer les points fidélité ──
    if (newStatus === "delivered") {
      const points = Math.floor((after.totalAmount ?? 0) / 100);
      if (points > 0) {
        const userData  = userSnap.data();
        const newPoints = (userData?.points ?? 0) + points;
        let   newLevel  = "Bronze";
        if      (newPoints >= 3000) newLevel = "Platinum";
        else if (newPoints >= 1500) newLevel = "Gold";
        else if (newPoints >= 500)  newLevel = "Silver";

        await db.collection("users").doc(clientUid).update({
          points:      newPoints,
          level:       newLevel,
          totalOrders: FieldValue.increment(1),
          totalSpent:  FieldValue.increment(after.totalAmount ?? 0),
        });
      }
    }

  } catch (err) {
    console.error("[onOrderStatusChange] Erreur:", err);
  }
});

// onOrderReady supprimé — remplacé par onOrderReadyForPickup (codebase allofoods-admin)
// qui utilise la géolocalisation pour cibler les livreurs proches.

// ══════════════════════════════════════════════════════════════════
// [SUPPRIMÉ] 3. DISPATCH LIVREUR → dupliqué dans allofoods-admin (géolocalisé)
// ══════════════════════════════════════════════════════════════════
if (false) exports.onOrderReady = onDocumentUpdated("orders/{orderId}", async (event) => {
  const before = event.data.before.data();
  const after  = event.data.after.data();

  if (!before || !after) return;
  if (before.status === after.status) return;
  // Dispatcher les livreurs quand le plat est prêt (les deux statuts possibles)
  if (after.status !== "ready" && after.status !== "ready_for_pickup") return;

  const orderId      = event.params.orderId;
  const restaurantId = after.restaurantId;

  console.log(`[onOrderReady] Commande ${orderId} prête — dispatch livreurs`);

  try {
    // ── Trouver livreurs disponibles ──
    const driversSnap = await db.collection("users")
      .where("role",      "==", "driver")
      .where("isOnline",  "==", true)
      .where("isBusy",    "==", false)
      .get();

    if (driversSnap.empty) {
      console.warn("[onOrderReady] Aucun livreur disponible");
      // Notifier l'admin
      await db.collection("alerts").add({
        type:      "no_driver",
        orderId:   orderId,
        message:   "Aucun livreur disponible pour la commande",
        createdAt: FieldValue.serverTimestamp(),
      });
      return;
    }

    // ── Notifier tous les livreurs disponibles ──
    const tokens = driversSnap.docs
      .map(d => d.data()?.fcmToken)
      .filter(Boolean);

    if (tokens.length > 0) {
      // Envoyer à chaque livreur (multicast)
      await fcm.sendEachForMulticast({
        tokens,
        notification: {
          title: "🏍️ Nouvelle course disponible !",
          body:  `Commande prête chez ${after.restaurantName}`,
        },
        data: {
          type:    "new_delivery",
          orderId: orderId,
          screen:  "delivery_request",
          restaurantLat: String(after.restaurantLat ?? ""),
          restaurantLng: String(after.restaurantLng ?? ""),
        },
        android: {
          priority: "high",
          notification: { sound: "default", channelId: "allofoods_orders" },
        },
        apns: { headers: { "apns-priority": "10" }, payload: { aps: { sound: "default", contentAvailable: 1 } } },
      });

      console.log(`[onOrderReady] ${tokens.length} livreur(s) notifié(s)`);
    }

  } catch (err) {
    console.error("[onOrderReady] Erreur:", err);
  }
});

// ══════════════════════════════════════════════════════════════════
// 4. WEBHOOK KKIAPAY — Validation paiement côté serveur
// Endpoint HTTP POST : /kkiapayWebhook
// ══════════════════════════════════════════════════════════════════
exports.kkiapayWebhook = onRequest(
  { cors: true, region: "europe-west1" },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("Method Not Allowed");
      return;
    }

    const { transactionId, status, amount, orderId } = req.body;

    console.log(`[kkiapayWebhook] txId=${transactionId} status=${status}`);

    try {
      if (status === "SUCCESS" && transactionId && orderId) {
        // ── Marquer la commande comme payée ──
        await db.collection("orders").doc(orderId).update({
          paymentStatus:    "paid",
          transactionId:    transactionId,
          paymentAmount:    amount,
          paymentConfirmedAt: FieldValue.serverTimestamp(),
        });

        // ── Log dans payment_logs ──
        await db.collection("payment_logs").add({
          transactionId,
          orderId,
          amount,
          status:    "SUCCESS",
          createdAt: FieldValue.serverTimestamp(),
        });

        console.log(`[kkiapayWebhook] Commande ${orderId} confirmée`);
        res.status(200).json({ success: true });
      } else {
        // Paiement échoué
        if (orderId) {
          await db.collection("orders").doc(orderId).update({
            paymentStatus: "failed",
            status:        "cancelled",
          });
        }
        res.status(200).json({ success: false, reason: status });
      }

    } catch (err) {
      console.error("[kkiapayWebhook] Erreur:", err);
      res.status(500).json({ error: err.message });
    }
  }
);

// ══════════════════════════════════════════════════════════════════
// 5. NOUVEAU TICKET SUPPORT → Notifier l'admin
// ══════════════════════════════════════════════════════════════════
exports.onNewSupportTicket = onDocumentCreated(
  "support_tickets/{ticketId}",
  async (event) => {
    const ticket   = event.data.data();
    const ticketId = event.params.ticketId;

    if (!ticket) return;

    console.log(`[onNewSupportTicket] Nouveau ticket: ${ticket.subject}`);

    try {
      // ── Notifier tous les admins ──
      const adminsSnap = await db.collection("users")
        .where("role", "==", "admin")
        .get();

      const tokens = adminsSnap.docs
        .map(d => d.data()?.fcmToken)
        .filter(Boolean);

      if (tokens.length > 0) {
        await fcm.sendEachForMulticast({
          tokens,
          notification: {
            title: "🎫 Nouveau ticket support",
            body:  `[${ticket.category}] ${ticket.subject}`,
          },
          data: {
            type:     "support_ticket",
            ticketId: ticketId,
            screen:   "support_detail",
          },
          android: {
            priority: "high",
            notification: { sound: "default", channelId: "allofoods_orders" },
          },
          apns: {
            headers: { "apns-priority": "10" },
            payload: { aps: { sound: "default", contentAvailable: 1 } },
          },
        });
      }

    } catch (err) {
      console.error("[onNewSupportTicket] Erreur:", err);
    }
  }
);

// ══════════════════════════════════════════════════════════════════
// 6. KILL SWITCH — Activer/désactiver la maintenance
// Endpoint HTTP : /setMaintenance?active=true&key=SECRET
// ══════════════════════════════════════════════════════════════════
exports.setMaintenance = onRequest(
  { cors: true, region: "europe-west1" },
  async (req, res) => {
    const key    = req.query.key;
    const active = req.query.active === "true";

    // Clé secrète admin (à changer en production)
    const SECRET = process.env.ADMIN_SECRET ?? "allofoods_admin_2026";

    if (key !== SECRET) {
      res.status(403).json({ error: "Unauthorized" });
      return;
    }

    try {
      await db.collection("config").doc("app").set({
        maintenanceMode: active,
        updatedAt:       FieldValue.serverTimestamp(),
        updatedBy:       "admin",
      }, { merge: true });

      console.log(`[setMaintenance] Mode maintenance: ${active}`);
      res.status(200).json({
        success: true,
        maintenanceMode: active,
        message: active ? "🔴 App en maintenance" : "🟢 App en ligne",
      });

    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  }
);

// ══════════════════════════════════════════════════════════════════
// 7. NETTOYAGE AUTOMATIQUE — Chaque nuit à minuit
// Supprime les notifications lues > 30 jours
// Archive les commandes > 90 jours
// ══════════════════════════════════════════════════════════════════
exports.scheduledCleanup = onSchedule(
  { schedule: "0 0 * * *", timeZone: "Africa/Porto-Novo" },
  async () => {
    console.log("[scheduledCleanup] Début nettoyage...");

    const now     = new Date();
    const batch   = db.batch();
    let   deleted = 0;

    try {
      // ── Supprimer notifications lues > 30 jours ──
      const cutoff30 = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
      const usersSnap = await db.collection("users").get();

      for (const userDoc of usersSnap.docs) {
        const notifsSnap = await db
          .collection("users").doc(userDoc.id)
          .collection("notifications")
          .where("isRead",    "==",        true)
          .where("createdAt", "<", cutoff30)
          .get();

        for (const n of notifsSnap.docs) {
          batch.delete(n.ref);
          deleted++;
        }
      }

      // ── Fermer les tickets support ouverts > 7 jours ──
      const cutoff7 = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
      const ticketsSnap = await db.collection("support_tickets")
        .where("status",    "==",       "open")
        .where("createdAt", "<", cutoff7)
        .get();

      for (const t of ticketsSnap.docs) {
        batch.update(t.ref, { status: "auto_closed" });
      }

      await batch.commit();
      console.log(`[scheduledCleanup] ${deleted} notifications supprimées, ${ticketsSnap.size} tickets fermés`);

    } catch (err) {
      console.error("[scheduledCleanup] Erreur:", err);
    }
  }
);

// ══════════════════════════════════════════════════════════════════
// 8. STATS RAPPORT QUOTIDIEN — Calcul côté serveur
// Chaque jour à 23h59 — Évite les calculs sur le client
// ══════════════════════════════════════════════════════════════════
exports.dailyReport = onSchedule(
  { schedule: "59 23 * * *", timeZone: "Africa/Porto-Novo" },
  async () => {
    console.log("[dailyReport] Calcul rapport quotidien...");

    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const tomorrow = new Date(today.getTime() + 24 * 60 * 60 * 1000);

    try {
      const ordersSnap = await db.collection("orders")
        .where("createdAt", ">=", today)
        .where("createdAt", "<",  tomorrow)
        .where("status",    "==", "delivered")
        .get();

      let totalRevenue = 0;
      let totalOrders  = ordersSnap.size;
      const restaurantStats = {};

      for (const doc of ordersSnap.docs) {
        const d = doc.data();
        totalRevenue += d.totalAmount ?? 0;

        // Stats par restaurant
        const rid = d.restaurantId;
        if (rid) {
          if (!restaurantStats[rid]) {
            restaurantStats[rid] = { orders: 0, revenue: 0, name: d.restaurantName };
          }
          restaurantStats[rid].orders++;
          restaurantStats[rid].revenue += d.totalAmount ?? 0;
        }
      }

      // Sauvegarder le rapport
      const dateStr = today.toISOString().split("T")[0];
      await db.collection("reports").doc(dateStr).set({
        date:         dateStr,
        totalOrders,
        totalRevenue,
        restaurants:  restaurantStats,
        generatedAt:  FieldValue.serverTimestamp(),
      });

      console.log(`[dailyReport] ${dateStr}: ${totalOrders} commandes, ${totalRevenue} FCFA`);

    } catch (err) {
      console.error("[dailyReport] Erreur:", err);
    }
  }
);

// ══════════════════════════════════════════════════════════════════
// 9. EMAIL TICKET SUPPORT → Notifier l'admin par email
// Trigger : nouvelle entrée dans /support_tickets/{ticketId}
// Variables requises dans functions/.env :
//   EMAIL_USER=votre.email@gmail.com
//   EMAIL_PASS=xxxx xxxx xxxx xxxx  (App Password Gmail)
//   ADMIN_EMAIL=admin@allofoods.com
// ══════════════════════════════════════════════════════════════════
// ══════════════════════════════════════════════════════════════════
// 10. NOUVEAU MESSAGE CHAT → Notifier le destinataire
// Trigger : nouveau message dans orders/{orderId}/messages/{msgId}
// ══════════════════════════════════════════════════════════════════
exports.onNewChatMessage = onDocumentCreated(
  "orders/{orderId}/messages/{msgId}",
  async (event) => {
    const msg     = event.data.data();
    const orderId = event.params.orderId;
    if (!msg) return;

    const senderRole = msg.senderRole ?? "";   // "driver" | "client"
    const senderName = msg.senderName ?? (senderRole === "driver" ? "Livreur" : "Client");
    const text       = msg.text ?? "";
    if (!text) return;

    try {
      const orderSnap = await db.collection("orders").doc(orderId).get();
      if (!orderSnap.exists) return;
      const order = orderSnap.data();

      // Trouver le destinataire (l'autre partie)
      let recipientUid = null;
      if (senderRole === "driver") {
        recipientUid = order.clientUid;
      } else if (senderRole === "client") {
        recipientUid = order.driverId || order.driverUid || order.assignedDriverId;
      }
      if (!recipientUid) return;

      const userSnap = await db.collection("users").doc(recipientUid).get();
      if (!userSnap.exists) return;
      const token = userSnap.data()?.fcmToken;
      if (!token) return;

      const icon  = senderRole === "driver" ? "🏍️" : "👤";
      const title = `${icon} ${senderName}`;
      const body  = text.length > 80 ? `${text.substring(0, 80)}…` : text;

      await fcm.send({
        token,
        notification: { title, body },
        data: { type: "chat_message", orderId, screen: "chat" },
        android: {
          priority: "high",
          notification: { sound: "default", channelId: "allofoods_orders" },
        },
        apns: {
          headers: { "apns-priority": "10" },
          payload: { aps: { sound: "default", contentAvailable: 1 } },
        },
      });

      console.log(`[onNewChatMessage] Notif envoyée à ${recipientUid} — "${body}"`);
    } catch (err) {
      console.error("[onNewChatMessage] Erreur:", err);
    }
  }
);

// ══════════════════════════════════════════════════════════════════
// RETRAIT MANUEL WALLET — Appelé par l'app restaurant
// Callable Function : requestManualWithdrawal({ restaurantId })
// Prérequis : wallet_balance >= 10 000 FCFA + numéro MoMo configuré
// ══════════════════════════════════════════════════════════════════
exports.requestManualWithdrawal = onCall({ region: "europe-west1" }, handleManualWithdrawal);

exports.onSupportTicketEmail = onDocumentCreated(
  "support_tickets/{ticketId}",
  async (event) => {
    const ticket   = event.data.data();
    const ticketId = event.params.ticketId;
    if (!ticket) return;

    const emailUser  = process.env.EMAIL_USER;
    const adminEmail = process.env.ADMIN_EMAIL;

    const transporter = _createMailer();
    if (!transporter || !adminEmail) {
      console.warn("[onSupportTicketEmail] Variables EMAIL_USER / EMAIL_PASS / ADMIN_EMAIL manquantes dans .env");
      return;
    }

    const shortId = ticketId.substring(0, 8).toUpperCase();
    const date    = new Date().toLocaleString("fr-FR", { timeZone: "Africa/Porto-Novo" });

    // ── Email à l'admin ──────────────────────────────
    const adminHtml = `
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"></head>
<body style="font-family:Arial,sans-serif;background:#f4f4f4;margin:0;padding:20px">
  <div style="max-width:600px;margin:0 auto;background:white;border-radius:12px;overflow:hidden">
    <div style="background:linear-gradient(135deg,#FF6600,#FF9800);padding:24px;text-align:center">
      <h1 style="color:white;margin:0;font-size:22px">🎫 Nouveau ticket support</h1>
      <p style="color:rgba(255,255,255,0.85);margin:6px 0 0">#${shortId} · ${date}</p>
    </div>
    <div style="padding:24px">
      <table style="width:100%;border-collapse:collapse">
        <tr><td style="padding:8px 0;color:#666;width:140px">Catégorie</td>
            <td style="padding:8px 0;font-weight:bold">${ticket.category ?? "—"}</td></tr>
        <tr><td style="padding:8px 0;color:#666">Sujet</td>
            <td style="padding:8px 0;font-weight:bold">${ticket.subject ?? "—"}</td></tr>
        <tr><td style="padding:8px 0;color:#666">Utilisateur</td>
            <td style="padding:8px 0">${ticket.userName ?? ticket.email ?? "Anonyme"}</td></tr>
        <tr><td style="padding:8px 0;color:#666">Email</td>
            <td style="padding:8px 0">${ticket.email ?? "—"}</td></tr>
        <tr><td style="padding:8px 0;color:#666">Priorité</td>
            <td style="padding:8px 0">${ticket.priority ?? "normale"}</td></tr>
      </table>
      <hr style="border:none;border-top:1px solid #eee;margin:16px 0">
      <p style="color:#333;font-weight:bold;margin-bottom:8px">Message :</p>
      <div style="background:#f9f9f9;border-left:4px solid #FF6600;padding:12px 16px;border-radius:0 8px 8px 0;color:#444;line-height:1.6">
        ${(ticket.message ?? "").replace(/\n/g, "<br>")}
      </div>
      <div style="margin-top:24px;text-align:center">
        <a href="https://allofoods-5d32b.web.app" style="background:#FF6600;color:white;padding:12px 28px;border-radius:8px;text-decoration:none;font-weight:bold;font-size:14px">
          Voir dans l'admin
        </a>
      </div>
    </div>
    <div style="background:#f4f4f4;padding:12px;text-align:center;font-size:11px;color:#999">
      allofoods · Cotonou, Bénin · Ticket #${shortId}
    </div>
  </div>
</body>
</html>`;

    await transporter.sendMail({
      from:    `"allofoods Support" <${emailUser}>`,
      to:      adminEmail,
      subject: `[Ticket #${shortId}] [${ticket.category ?? "Support"}] ${ticket.subject ?? "Sans objet"}`,
      html:    adminHtml,
    });

    console.log(`[onSupportTicketEmail] Email envoyé à ${adminEmail} — ticket #${shortId}`);

    // ── Email de confirmation à l'utilisateur (si email renseigné) ──
    const userEmail = ticket.email;
    if (userEmail && userEmail !== adminEmail) {
      const confirmHtml = `
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"></head>
<body style="font-family:Arial,sans-serif;background:#f4f4f4;margin:0;padding:20px">
  <div style="max-width:600px;margin:0 auto;background:white;border-radius:12px;overflow:hidden">
    <div style="background:linear-gradient(135deg,#FF6600,#FF9800);padding:24px;text-align:center">
      <h1 style="color:white;margin:0;font-size:22px">✅ Ticket reçu !</h1>
      <p style="color:rgba(255,255,255,0.85);margin:6px 0 0">Référence #${shortId}</p>
    </div>
    <div style="padding:24px">
      <p>Bonjour ${ticket.userName ?? ""},</p>
      <p>Nous avons bien reçu votre demande et nous la traiterons dans les plus brefs délais.</p>
      <div style="background:#fff8f0;border:1px solid #FF9800;border-radius:8px;padding:16px;margin:16px 0">
        <p style="margin:0 0 8px;font-weight:bold">Votre ticket :</p>
        <p style="margin:0;color:#666">Sujet : <strong>${ticket.subject ?? "—"}</strong></p>
        <p style="margin:4px 0 0;color:#666">Catégorie : ${ticket.category ?? "—"}</p>
      </div>
      <p style="color:#666;font-size:13px">Notre équipe vous répondra à cet email sous 24–48h ouvrées.</p>
    </div>
    <div style="background:#f4f4f4;padding:12px;text-align:center;font-size:11px;color:#999">
      allofoods · Cotonou, Bénin · Ne pas répondre à cet email
    </div>
  </div>
</body>
</html>`;

      await transporter.sendMail({
        from:    `"allofoods Support" <${emailUser}>`,
        to:      userEmail,
        subject: ` Ticket #${shortId} bien reçu — allofoods Support`,
        html:    confirmHtml,
      }).catch(e => console.warn("[onSupportTicketEmail] Erreur email utilisateur:", e.message));
    }
  }
);

// ══════════════════════════════════════════════════════════════════
// CLÔTURE DE JOURNÉE — Fonctions admin sécurisées
// ══════════════════════════════════════════════════════════════════

// ── 1. Envoyer OTP Gmail admin ──────────────────────────────────
exports.sendAdminOtp = onCall({ region: "europe-west1" }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Non connecté");

  const adminUid   = request.auth.uid;
  const adminEmail = request.auth.token.email ?? "";

  const adminDoc = await db.collection("users").doc(adminUid).get();
  if (!adminDoc.exists || adminDoc.data()?.role !== "admin") {
    throw new HttpsError("permission-denied", "Réservé aux administrateurs allofoods");
  }

  const otp       = Math.floor(100000 + Math.random() * 900000).toString();
  const expiresAt = new Date(Date.now() + 10 * 60 * 1000);

  await db.collection("admin_otps").doc(adminUid).set({
    code:      otp,
    expiresAt: expiresAt,
    used:      false,
    createdAt: FieldValue.serverTimestamp(),
  });

  const mailer  = _createMailer();
  const emailTo = adminEmail || process.env.ADMIN_EMAIL;
  if (!mailer || !emailTo) throw new HttpsError("internal", "Configuration email manquante");

  await mailer.sendMail({
    from:    `"allofoods Sécurité" <${process.env.EMAIL_USER}>`,
    to:      emailTo,
    subject: "Code de vérification — Clôture de Journée allofoods",
    html: `<!DOCTYPE html><html><head><meta charset="utf-8"></head>
<body style="font-family:Arial,sans-serif;background:#f4f4f4;padding:20px">
  <div style="max-width:480px;margin:0 auto;background:white;border-radius:12px;overflow:hidden">
    <div style="background:linear-gradient(135deg,#FF6600,#FF9800);padding:24px;text-align:center">
      <h2 style="color:white;margin:0">allofoods Admin</h2>
      <p style="color:rgba(255,255,255,0.85);margin:4px 0 0;font-size:13px">Clôture de Journée</p>
    </div>
    <div style="padding:28px;text-align:center">
      <p style="color:#555;margin-bottom:20px">Votre code de vérification est :</p>
      <div style="font-size:38px;font-weight:bold;letter-spacing:10px;color:#FF6600;background:#fff8f0;padding:16px;border-radius:10px;display:inline-block">${otp}</div>
      <p style="color:#888;font-size:12px;margin-top:20px">Valable <strong>10 minutes</strong>. Ne partagez jamais ce code.</p>
    </div>
    <div style="background:#f4f4f4;padding:10px;text-align:center;font-size:11px;color:#aaa">allofoods · Cotonou, Bénin</div>
  </div>
</body></html>`,
  });

  console.log(`[sendAdminOtp] OTP envoyé à ${emailTo}`);
  return { sent: true };
});

// ── 2. Vérifier OTP ─────────────────────────────────────────────
exports.verifyAdminOtp = onCall({ region: "europe-west1" }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Non connecté");

  const { code } = request.data;
  const adminUid = request.auth.uid;

  if (!code || typeof code !== "string") {
    throw new HttpsError("invalid-argument", "Code requis");
  }

  const otpDoc = await db.collection("admin_otps").doc(adminUid).get();
  if (!otpDoc.exists) throw new HttpsError("not-found", "Aucun code — demandez-en un nouveau");

  const data = otpDoc.data();
  if (data.used)                             throw new HttpsError("already-exists",    "Code déjà utilisé");
  if (data.expiresAt.toDate() < new Date()) throw new HttpsError("deadline-exceeded", "Code expiré — demandez-en un nouveau");
  if (data.code !== code)                   throw new HttpsError("unauthenticated",   "Code incorrect");

  await db.collection("admin_otps").doc(adminUid).update({ used: true });
  return { verified: true };
});

// ── 3. Approuver les virements restaurants ──────────────────────
exports.adminApprovePayouts = onCall({ region: "europe-west1" }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Non connecté");

  const adminUid   = request.auth.uid;
  const adminEmail = request.auth.token.email ?? "admin";
  const { restaurantIds } = request.data ?? {};

  if (!Array.isArray(restaurantIds) || restaurantIds.length === 0) {
    throw new HttpsError("invalid-argument", "Aucun restaurant sélectionné");
  }

  const adminDoc = await db.collection("users").doc(adminUid).get();
  if (!adminDoc.exists || adminDoc.data()?.role !== "admin") {
    throw new HttpsError("permission-denied", "Réservé aux administrateurs");
  }

  const momoRegex  = /^(229)?[0-9]{8}$/;
  const toProcess  = [];
  let   totalToSend = 0;
  const skipped    = [];

  for (const restId of restaurantIds) {
    const snap = await db.collection("restaurants").doc(restId).get();
    if (!snap.exists) { skipped.push({ restId, reason: "Introuvable" }); continue; }
    const rest    = snap.data();
    const balance = Math.round(rest.wallet_balance ?? 0);
    if (balance <= 0) { skipped.push({ restId, name: rest.name, reason: "Solde nul" }); continue; }
    const cleanNumber = (rest.momo_number ?? "").replace(/\s/g, "");
    if (!cleanNumber || !momoRegex.test(cleanNumber)) {
      skipped.push({ restId, name: rest.name, reason: "Numéro MoMo invalide" });
      continue;
    }
    toProcess.push({ id: restId, rest, balance, cleanNumber });
    totalToSend += balance;
  }

  // Vérifier la réserve allofoods
  const financesSnap = await db.collection("admin").doc("finances").get();
  const reserve       = financesSnap.data()?.reserve_disponible ?? 0;
  const seuilAlerte   = financesSnap.data()?.seuil_alerte       ?? 20000;

  if (reserve < totalToSend) {
    throw new HttpsError(
      "resource-exhausted",
      `Réserve insuffisante : ${reserve.toLocaleString("fr-FR")} FCFA disponible, ${totalToSend.toLocaleString("fr-FR")} FCFA requis. Rechargez le compte FedaPay.`
    );
  }

  if (totalToSend > 500000) {
    throw new HttpsError(
      "resource-exhausted",
      `Total ${totalToSend.toLocaleString("fr-FR")} FCFA dépasse le plafond journalier (500 000 FCFA)`
    );
  }

  const results = [];
  const today   = new Date().toISOString().split("T")[0];

  for (const { id: restId, rest, balance, cleanNumber } of toProcess) {
    const idempotencyKey = `payout-${restId}-${today}`;
    try {
      const payoutResult = await _fedaPayRequest("POST", "/v1/payouts", {
        amount:   balance,
        currency: { iso: "XOF" },
        mode:     rest.momo_network || "mtn",
        customer: {
          firstname:    rest.name || "Restaurant",
          phone_number: { number: cleanNumber, country: "BJ" },
        },
        metadata: { restaurant_id: restId, type: "admin_daily_payout", idempotency_key: idempotencyKey },
      });

      const payoutId = payoutResult?.payout?.id ?? payoutResult?.id;
      if (!payoutId) throw new Error(`FedaPay: pas d'ID — ${JSON.stringify(payoutResult)}`);

      await _fedaPayRequest("PUT", `/v1/payouts/${payoutId}/send_now`, {});

      const batch  = db.batch();
      batch.update(db.collection("restaurants").doc(restId), {
        wallet_balance:    0,
        wallet_updated_at: FieldValue.serverTimestamp(),
        total_withdrawn:   FieldValue.increment(balance),
        last_admin_payout: FieldValue.serverTimestamp(),
      });
      batch.set(db.collection("payout_history").doc(), {
        fedapay_payout_id: payoutId,
        restaurant_id:     restId,
        restaurant_name:   rest.name ?? "",
        amount:            balance,
        momo_number:       rest.momo_number,
        momo_network:      rest.momo_network || "mtn",
        status:            "completed",
        admin_uid:         adminUid,
        admin_email:       adminEmail,
        idempotency_key:   idempotencyKey,
        created_at:        FieldValue.serverTimestamp(),
      });

      // Mise à jour réserve + wallet_transactions débit
      batch.set(db.collection("admin").doc("finances"), {
        reserve_disponible: FieldValue.increment(-balance),
        total_paye_jour:    FieldValue.increment(balance),
        last_updated:       FieldValue.serverTimestamp(),
      }, { merge: true });

      batch.set(db.collection("wallet_transactions").doc(), {
        restaurant_id:     restId,
        type:              "cloture_journee",
        amount:            balance,
        network:           rest.momo_network || "mtn",
        momo_number:       rest.momo_number,
        fedapay_payout_id: payoutId,
        status:            "completed",
        description:       `Clôture de journée — ${new Date().toLocaleDateString("fr-FR", { timeZone: "Africa/Porto-Novo" })}`,
        created_at:        FieldValue.serverTimestamp(),
      });

      batch.set(db.collection("audit_logs").doc(), {
        type:         "cloture_journee",
        restaurantId: restId,
        amount:       balance,
        walletBefore: balance,
        walletAfter:  0,
        fedapayId:    payoutId,
        momoNumber:   rest.momo_number,
        adminEmail,
        createdAt:    FieldValue.serverTimestamp(),
      });

      await batch.commit();

      console.log(`[adminApprovePayouts] OK ${rest.name} — ${balance} FCFA`);
      results.push({ restaurantId: restId, name: rest.name, status: "success", amount: balance, payoutId });

    } catch (e) {
      await db.collection("payout_history").add({
        restaurant_id:   restId,
        restaurant_name: rest.name ?? "",
        amount:          balance,
        momo_number:     rest.momo_number,
        momo_network:    rest.momo_network || "mtn",
        status:          "failed",
        error:           String(e.message ?? e),
        admin_uid:       adminUid,
        admin_email:     adminEmail,
        created_at:      FieldValue.serverTimestamp(),
      });
      console.error(`[adminApprovePayouts] ECHEC ${rest.name}:`, e.message);
      results.push({ restaurantId: restId, name: rest.name, status: "error", error: String(e.message) });
    }
  }

  await db.collection("audit_logs").add({
    action:    `Clôture journée — ${results.filter(r => r.status === "success").length}/${toProcess.length} virements — Total: ${totalToSend.toLocaleString("fr-FR")} FCFA`,
    by:        adminEmail,
    category:  "payout",
    meta:      { results, skipped, totalToSend, restaurantIds },
    createdAt: FieldValue.serverTimestamp(),
  });

  // Alerte si réserve basse après clôture
  const reserveApres = reserve - totalToSend;
  if (reserveApres < seuilAlerte) {
    _sendAlertReserveBasse(reserveApres, seuilAlerte).catch(() => {});
  }

  return { results, skipped, totalSent: totalToSend };
});

// ══════════════════════════════════════════════════════════════════
// CLÔTURE AUTOMATIQUE — Chaque soir à 20h00 (Africa/Porto-Novo)
// Paie tous les restaurants ayant wallet_balance > 0
// Utilise la réserve allofoods (fonds de roulement)
// ══════════════════════════════════════════════════════════════════
exports.scheduledCloture = onSchedule(
  { schedule: "0 20 * * *", timeZone: "Africa/Porto-Novo", region: "europe-west1" },
  async () => {
    console.log("[scheduledCloture] ▶ Démarrage clôture automatique...");

    // ── Lire la réserve ─────────────────────────────────────────
    const financesSnap = await db.collection("admin").doc("finances").get();
    const finances      = financesSnap.data() || {};
    const reserve       = finances.reserve_disponible ?? 0;
    const seuilAlerte   = finances.seuil_alerte       ?? 20000;

    // ── Restaurants avec solde > 0 ──────────────────────────────
    const restosSnap = await db.collection("restaurants")
      .where("wallet_balance", ">", 0)
      .get();

    if (restosSnap.empty) {
      console.log("[scheduledCloture] Aucun restaurant à payer ce soir.");
      return;
    }

    const totalAPayer = restosSnap.docs.reduce(
      (sum, d) => sum + Math.round(d.data().wallet_balance ?? 0), 0
    );
    console.log(`[scheduledCloture] ${restosSnap.size} restos · Total: ${totalAPayer.toLocaleString("fr-FR")} FCFA · Réserve: ${reserve.toLocaleString("fr-FR")} FCFA`);

    if (reserve < totalAPayer) {
      console.warn("[scheduledCloture] ⚠️ Réserve insuffisante — clôture annulée");
      await _sendAlertReserveBasse(reserve, totalAPayer);
      return;
    }

    const momoRegex = /^(229)?[0-9]{8}$/;
    const today     = new Date().toISOString().split("T")[0];
    const dateLabel = new Date().toLocaleDateString("fr-FR", { timeZone: "Africa/Porto-Novo" });
    let   totalPaye = 0;
    const errors    = [];

    for (const doc of restosSnap.docs) {
      const restId = doc.id;
      const rest   = doc.data();

      // Relire le solde réel (évite les race conditions)
      const freshSnap = await db.collection("restaurants").doc(restId).get();
      const solde     = Math.round(freshSnap.data()?.wallet_balance ?? 0);
      if (solde <= 0) { console.log(`[scheduledCloture] ${restId}: solde à zéro, ignoré`); continue; }

      const momoNum = (rest.momo_number ?? "").replace(/\s/g, "");
      if (!momoNum || !momoRegex.test(momoNum)) {
        console.warn(`[scheduledCloture] ${restId}: MoMo invalide — ignoré`);
        errors.push({ restId, name: rest.name, error: "MoMo invalide" });
        continue;
      }

      const idempotencyKey = `cloture-auto-${restId}-${today}`;

      try {
        // 1. Créer le payout FedaPay
        const payoutResult = await _fedaPayRequest("POST", "/v1/payouts", {
          amount:   solde,
          currency: { iso: "XOF" },
          mode:     rest.momo_network || "mtn",
          customer: {
            firstname:    rest.name || "Restaurant",
            phone_number: { number: momoNum, country: "BJ" },
          },
          metadata: { restaurant_id: restId, type: "scheduled_cloture", idempotency_key: idempotencyKey },
        });

        const payoutId = payoutResult?.payout?.id ?? payoutResult?.id;
        if (!payoutId) throw new Error(`FedaPay: pas d'ID — ${JSON.stringify(payoutResult)}`);

        // 2. Envoyer immédiatement
        await _fedaPayRequest("PUT", `/v1/payouts/${payoutId}/send_now`, {});

        // 3. Mise à jour Firestore atomique
        const batch = db.batch();

        batch.update(db.collection("restaurants").doc(restId), {
          wallet_balance:    0,
          wallet_updated_at: FieldValue.serverTimestamp(),
          total_withdrawn:   FieldValue.increment(solde),
          last_auto_payout:  FieldValue.serverTimestamp(),
        });

        batch.set(db.collection("admin").doc("finances"), {
          reserve_disponible: FieldValue.increment(-solde),
          total_paye_jour:    FieldValue.increment(solde),
          last_updated:       FieldValue.serverTimestamp(),
        }, { merge: true });

        batch.set(db.collection("wallet_transactions").doc(), {
          restaurant_id:     restId,
          type:              "cloture_journee",
          amount:            solde,
          network:           rest.momo_network || "mtn",
          momo_number:       rest.momo_number,
          fedapay_payout_id: payoutId,
          status:            "completed",
          description:       `Clôture automatique du ${dateLabel}`,
          created_at:        FieldValue.serverTimestamp(),
        });

        batch.set(db.collection("payout_history").doc(), {
          fedapay_payout_id: payoutId,
          restaurant_id:     restId,
          restaurant_name:   rest.name ?? "",
          amount:            solde,
          momo_number:       rest.momo_number,
          momo_network:      rest.momo_network || "mtn",
          type:              "cloture_journee",
          status:            "completed",
          idempotency_key:   idempotencyKey,
          created_at:        FieldValue.serverTimestamp(),
        });

        batch.set(db.collection("audit_logs").doc(), {
          type:         "cloture_journee",
          restaurantId: restId,
          amount:       solde,
          walletBefore: solde,
          walletAfter:  0,
          fedapayId:    payoutId,
          momoNumber:   rest.momo_number,
          createdAt:    FieldValue.serverTimestamp(),
        });

        await batch.commit();
        totalPaye += solde;
        console.log(`[scheduledCloture] ✅ ${rest.name}: ${solde.toLocaleString("fr-FR")} FCFA → ${momoNum}`);

        // 4. Notification FCM restaurant
        if (rest.fcmToken) {
          const networkLabel = rest.momo_network === "moov" ? "Moov Money"
            : rest.momo_network === "celtiis" ? "Celtiis" : "MTN MoMo";
          fcm.send({
            token: rest.fcmToken,
            notification: {
              title: "💸 Virement reçu !",
              body:  `${solde.toLocaleString("fr-FR")} FCFA versés sur ${networkLabel}`,
            },
            data: { type: "cloture_journee", amount: String(solde) },
            android: { priority: "high", notification: { sound: "default", channelId: "allofoods_orders" } },
          }).catch(e => console.error("[scheduledCloture] FCM:", e.message));
        }

      } catch (e) {
        console.error(`[scheduledCloture] ❌ ${restId}: ${e.message}`);
        errors.push({ restId, name: rest.name, error: e.message });
        await db.collection("audit_logs").add({
          type:         "cloture_journee_failed",
          restaurantId: restId,
          amount:       solde,
          error:        e.message,
          createdAt:    FieldValue.serverTimestamp(),
        }).catch(() => {});
      }
    }

    // ── Rapport global ───────────────────────────────────────────
    await db.collection("audit_logs").add({
      type:       "cloture_journee_rapport",
      date:       today,
      totalPaye,
      nbSuccess:  restosSnap.docs.length - errors.length,
      nbErrors:   errors.length,
      errors,
      reserveAvant: reserve,
      reserveApres: reserve - totalPaye,
      createdAt:  FieldValue.serverTimestamp(),
    }).catch(() => {});

    // ── Alerte si réserve basse après clôture ────────────────────
    const reserveApres = reserve - totalPaye;
    if (reserveApres < seuilAlerte) {
      await _sendAlertReserveBasse(reserveApres, seuilAlerte);
    }

    console.log(`[scheduledCloture] ✅ Terminé — ${totalPaye.toLocaleString("fr-FR")} FCFA versés · ${errors.length} erreur(s) · Réserve restante: ${(reserve - totalPaye).toLocaleString("fr-FR")} FCFA`);
  }
);

// ══════════════════════════════════════════════════════════════════
// APPROBATION / REJET RESTAURANT → Notifier le merchant via FCM
// Déclenché quand l'admin change le champ "status" du restaurant
// ══════════════════════════════════════════════════════════════════
exports.onRestaurantStatusChange = onDocumentUpdated(
  "restaurants/{restId}",
  async (event) => {
    const before = event.data.before.data();
    const after  = event.data.after.data();
    if (!before || !after) return;

    const statusBefore = before.status ?? "";
    const statusAfter  = after.status  ?? "";

    // Pas de changement de statut → rien à faire
    if (statusBefore === statusAfter) return;

    const fcmToken = after.fcmToken;
    const restName = after.name ?? "Votre restaurant";

    // ── Approuvé ───────────────────────────────────────────────
    if (statusAfter === "active" && statusBefore !== "active") {
      console.log(`[onRestaurantStatusChange] "${restName}" approuvé`);
      if (!fcmToken) return;
      try {
        await fcm.send({
          token: fcmToken,
          notification: {
            title: "Félicitations ! 🎉",
            body:  `"${restName}" est maintenant en ligne sur allofoods !`,
          },
          data: { type: "restaurant_approved", screen: "home" },
          android: {
            priority: "high",
            notification: { sound: "default", channelId: "allofoods_orders" },
          },
          apns: {
            headers: { "apns-priority": "10" },
            payload: { aps: { sound: "default", badge: 1 } },
          },
        });
        console.log(`[onRestaurantStatusChange] Notif approbation envoyée → ${restName}`);
      } catch (err) {
        console.error("[onRestaurantStatusChange] FCM approve error:", err.message);
      }
    }

    // ── Rejeté ─────────────────────────────────────────────────
    if (statusAfter === "rejected" && statusBefore !== "rejected") {
      const reason = after.rejectReason ?? "";
      console.log(`[onRestaurantStatusChange] "${restName}" rejeté — ${reason || "sans motif"}`);
      if (!fcmToken) return;
      try {
        await fcm.send({
          token: fcmToken,
          notification: {
            title: "Dossier non approuvé",
            body:  reason
              ? `Motif : ${reason}`
              : "Votre dossier n'a pas été approuvé. Corrigez-le et soumettez à nouveau.",
          },
          data: { type: "restaurant_rejected", screen: "profile", reason },
          android: {
            priority: "high",
            notification: { sound: "default", channelId: "allofoods_orders" },
          },
          apns: {
            headers: { "apns-priority": "10" },
            payload: { aps: { sound: "default", badge: 1 } },
          },
        });
        console.log(`[onRestaurantStatusChange] Notif rejet envoyée → ${restName}`);
      } catch (err) {
        console.error("[onRestaurantStatusChange] FCM reject error:", err.message);
      }
    }
  }
);

// ══════════════════════════════════════════════════════════════════
// OTP INSCRIPTION — Vérification Gmail pour livreurs & restaurants
// ══════════════════════════════════════════════════════════════════

// ── Envoyer un code OTP par Gmail ───────────────────────────────
exports.sendRegistrationOtp = onCall(async (request) => {
  const { email, fcmToken } = request.data ?? {};

  if (!email || typeof email !== "string") {
    throw new HttpsError("invalid-argument", "Email requis");
  }
  if (!email.endsWith("@gmail.com")) {
    throw new HttpsError("invalid-argument", "Seules les adresses Gmail sont acceptées");
  }

  const code      = Math.floor(100000 + Math.random() * 900000).toString();
  const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000); // +24h
  const key       = email.replace(/[@.]/g, "_");

  await db.collection("registration_otps").doc(key).set({
    email,
    code,
    expiresAt,
    verified: false,
    attempts: 0,
    createdAt: FieldValue.serverTimestamp(),
  });

  const mailer = _createMailer();
  if (!mailer) throw new HttpsError("internal", "Service email non configuré");

  await mailer.sendMail({
    from:    `"AlloFoods" <${process.env.EMAIL_USER}>`,
    to:      email,
    subject: `${code} — Votre code de vérification AlloFoods`,
    html: `<!DOCTYPE html><html><head><meta charset="utf-8"></head>
<body style="font-family:Arial,sans-serif;background:#f4f4f4;margin:0;padding:20px">
  <div style="max-width:480px;margin:0 auto;background:white;border-radius:16px;overflow:hidden;box-shadow:0 4px 20px rgba(0,0,0,0.08)">
    <div style="background:linear-gradient(135deg,#FF6600,#FF9800);padding:28px;text-align:center">
      <div style="font-size:40px;margin-bottom:8px">🔐</div>
      <h1 style="color:white;margin:0;font-size:22px;font-weight:bold">AlloFoods</h1>
      <p style="color:rgba(255,255,255,0.85);margin:4px 0 0;font-size:13px">Vérification de votre adresse email</p>
    </div>
    <div style="padding:32px;text-align:center">
      <p style="color:#555;font-size:15px;margin:0 0 24px">Votre code de vérification est :</p>
      <div style="font-size:40px;font-weight:bold;letter-spacing:12px;color:#FF6600;background:#fff8f0;padding:20px;border-radius:12px;display:inline-block">${code}</div>
      <p style="color:#888;font-size:12px;margin:24px 0 0">
        Ce code est <strong>valable 24 heures</strong>.<br>
        Si vous n'avez pas demandé ce code, ignorez cet email.
      </p>
    </div>
    <div style="background:#f9f9f9;padding:12px;text-align:center;font-size:11px;color:#bbb;border-top:1px solid #eee">
      AlloFoods · Cotonou, Bénin · Ne pas répondre
    </div>
  </div>
</body></html>`,
  });

  // Notification FCM (non-bloquant — fallback email déjà envoyé)
  if (fcmToken) {
    try {
      await fcm.send({
        token: fcmToken,
        notification: {
          title: `${code} — AlloFoods`,
          body: "Votre code de vérification est arrivé.",
        },
        data: { type: "otp_code", code },
        android: {
          priority: "high",
          notification: { sound: "default", channelId: "allofoods_orders" },
        },
        apns: {
          headers: { "apns-priority": "10" },
          payload: { aps: { sound: "default" } },
        },
      });
      console.log(`[sendRegistrationOtp] Notif FCM envoyée`);
    } catch (fcmErr) {
      console.warn(`[sendRegistrationOtp] FCM ignoré: ${fcmErr.message}`);
    }
  }

  console.log(`[sendRegistrationOtp] Code envoyé à ${email}`);
  return { sent: true };
});

// ── Vérifier le code OTP ─────────────────────────────────────────
exports.verifyRegistrationOtp = onCall(async (request) => {
  const { email, code } = request.data ?? {};

  if (!email || !code) {
    throw new HttpsError("invalid-argument", "Email et code requis");
  }

  const key    = email.replace(/[@.]/g, "_");
  const docRef = db.collection("registration_otps").doc(key);
  const snap   = await docRef.get();

  if (!snap.exists) {
    throw new HttpsError("not-found", "Code introuvable — demandez un nouveau code");
  }

  const otp      = snap.data();
  const attempts = (otp.attempts ?? 0) + 1;
  await docRef.update({ attempts });

  if (attempts > 5) {
    throw new HttpsError("resource-exhausted", "Trop de tentatives — demandez un nouveau code");
  }
  if (otp.verified) {
    throw new HttpsError("already-exists", "Code déjà utilisé — demandez un nouveau code");
  }
  if (new Date(otp.expiresAt) < new Date()) {
    throw new HttpsError("deadline-exceeded", "Code expiré — demandez un nouveau code");
  }
  if (otp.code !== code) {
    throw new HttpsError("unauthenticated", `Code incorrect (${5 - attempts} essai(s) restant(s))`);
  }

  await docRef.update({ verified: true });
  console.log(`[verifyRegistrationOtp] Email vérifié : ${email}`);
  return { verified: true };
});
