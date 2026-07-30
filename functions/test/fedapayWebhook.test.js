// functions/test/fedapayWebhook.test.js
//
// Teste fedapayWebhook directement (_fedapayWebhookHandler) : validation de
// signature HMAC, traitement approved/declined, et surtout la non-régression
// du bug corrigé — confirmOrderPayment et le webhook doivent pouvoir arriver
// dans n'importe quel ordre sans jamais créditer le wallet deux fois ni sauter
// la notification restaurant.

const crypto = require("crypto");
const { seedOrder, seedRestaurant, getOrder, getRestaurant, clearTestData, db } = require("./helpers/firestore");

let index;
beforeAll(() => {
  index = require("../index.js");
});

afterEach(async () => {
  await clearTestData();
});

const WEBHOOK_SECRET = "test_webhook_secret"; // doit matcher jest.setup.js

function sign(body) {
  return crypto.createHmac("sha256", WEBHOOK_SECRET).update(JSON.stringify(body)).digest("hex");
}

function fakeReqRes(body, { validSignature = true } = {}) {
  const req = {
    method: "POST",
    body,
    headers: validSignature ? { "x-fedapay-signature": sign(body) } : { "x-fedapay-signature": "bad-signature" },
  };
  const res = {
    statusCode: null,
    payload: null,
    status(code) { this.statusCode = code; return this; },
    json(payload) { this.payload = payload; return this; },
    send(payload) { this.payload = payload; return this; },
  };
  return { req, res };
}

function approvedEvent({ txId = "tx_wh_1", orderId, amount = 6250 }) {
  return {
    name: "transaction.approved",
    object: { id: txId, status: "approved", amount, custom_metadata: { order_id: orderId } },
  };
}

function declinedEvent({ txId = "tx_wh_2", orderId }) {
  return {
    name: "transaction.declined",
    object: { id: txId, status: "declined", custom_metadata: { order_id: orderId } },
  };
}

describe("fedapayWebhook — sécurité", () => {
  test("rejette les requêtes non-POST", async () => {
    const { req, res } = fakeReqRes({});
    req.method = "GET";
    await index._fedapayWebhookHandler(req, res);
    expect(res.statusCode).toBe(405);
  });

  test("signature invalide → requête ignorée, aucune écriture Firestore", async () => {
    await seedOrder("order-sig", { paymentStatus: "pending" });
    const { req, res } = fakeReqRes(approvedEvent({ orderId: "order-sig" }), { validSignature: false });

    await index._fedapayWebhookHandler(req, res);

    expect(res.statusCode).toBe(200); // 200 quand même — évite les retentatives FedaPay
    expect(res.payload).toMatchObject({ ignored: true, reason: "invalid_signature" });

    const order = await getOrder("order-sig");
    expect(order.paymentStatus).toBe("pending"); // inchangé
  });

  test("signature valide + événement approved → commande PAID + wallet crédité", async () => {
    await seedOrder("order-valid-sig", { foodAmount: 4000, deliveryFee: 500 });
    await seedRestaurant("restaurant-1");
    const { req, res } = fakeReqRes(approvedEvent({ orderId: "order-valid-sig", txId: "tx_ok" }));

    await index._fedapayWebhookHandler(req, res);

    expect(res.statusCode).toBe(200);
    const order = await getOrder("order-valid-sig");
    expect(order.paymentStatus).toBe("PAID");
    const restaurant = await getRestaurant("restaurant-1");
    expect(restaurant.wallet_balance).toBe(3800); // 4000 - 5%
  });
});

describe("fedapayWebhook — idempotence", () => {
  test("le même événement livré deux fois (retry FedaPay) ne crédite le wallet qu'une fois", async () => {
    await seedOrder("order-retry", { foodAmount: 2000, deliveryFee: 300 });
    await seedRestaurant("restaurant-1");
    const event = approvedEvent({ orderId: "order-retry", txId: "tx_retry" });

    const first = fakeReqRes(event);
    await index._fedapayWebhookHandler(first.req, first.res);
    const second = fakeReqRes(event);
    await index._fedapayWebhookHandler(second.req, second.res);

    const restaurant = await getRestaurant("restaurant-1");
    expect(restaurant.wallet_balance).toBe(1900); // 2000 - 5%, une seule fois
  });

  test("événement declined marque la commande FAILED sans toucher au wallet", async () => {
    await seedOrder("order-declined", { foodAmount: 1000, deliveryFee: 200 });
    await seedRestaurant("restaurant-1");
    const { req, res } = fakeReqRes(declinedEvent({ orderId: "order-declined" }));

    await index._fedapayWebhookHandler(req, res);

    const order = await getOrder("order-declined");
    expect(order.paymentStatus).toBe("FAILED");
    expect(order.status).toBe("cancelled");
    const restaurant = await getRestaurant("restaurant-1");
    expect(restaurant.wallet_balance).toBe(0);
  });
});

describe("fedapayWebhook — non-régression : course avec confirmOrderPayment", () => {
  test(
    "si confirmOrderPayment traite le paiement en premier, le webhook qui arrive " +
      "ensuite ne doit PAS re-créditer le wallet — mais le crédit initial (déclenché " +
      "par confirmOrderPayment) doit bien avoir eu lieu. Avant le correctif, aucun des " +
      "deux chemins ne créditait le wallet dans ce scénario.",
    async () => {
      await seedOrder("order-race", { foodAmount: 3000, deliveryFee: 400 });
      await seedRestaurant("restaurant-1");

      // 1. Le client confirme via polling — confirmOrderPayment gagne la course.
      await index._creditApprovedPayment({ orderId: "order-race", txId: "tx_race", amount: 3550 });

      // 2. Le webhook FedaPay arrive après coup pour le même événement.
      const { req, res } = fakeReqRes(approvedEvent({ orderId: "order-race", txId: "tx_race", amount: 3550 }));
      await index._fedapayWebhookHandler(req, res);

      const restaurant = await getRestaurant("restaurant-1");
      expect(restaurant.wallet_balance).toBe(2850); // 3000 - 5%, crédité une seule fois au total

      const walletTx = await db().collection("wallet_transactions").where("order_id", "==", "order-race").get();
      expect(walletTx.size).toBe(1); // pas de doublon de log non plus
    }
  );
});
