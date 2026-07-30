// functions/test/creditApprovedPayment.test.js
//
// Teste le cœur financier partagé par confirmOrderPayment et fedapayWebhook.
// C'est la fonction la plus critique : elle crédite le wallet restaurant et
// doit être rigoureusement idempotente (jamais de double-crédit).

const { seedOrder, seedRestaurant, getOrder, getRestaurant, clearTestData } = require("./helpers/firestore");

let index;
beforeAll(() => {
  index = require("../index.js");
});

afterEach(async () => {
  await clearTestData();
});

describe("_creditApprovedPayment", () => {
  test("crédite le wallet restaurant du montant net (foodAmount - commission 5%)", async () => {
    await seedOrder("order-1", { foodAmount: 5000, deliveryFee: 1000 });
    await seedRestaurant("restaurant-1", { wallet_balance: 0 });

    const result = await index._creditApprovedPayment({
      orderId: "order-1",
      txId: "tx_1",
      amount: 6250,
    });

    expect(result.credited).toBe(true);
    const order = await getOrder("order-1");
    expect(order.paymentStatus).toBe("PAID");
    expect(order.status).toBe("paid");
    expect(order.restoAmount).toBe(4750); // 5000 - 5% (250)

    const restaurant = await getRestaurant("restaurant-1");
    expect(restaurant.wallet_balance).toBe(4750);
    expect(restaurant.total_earned).toBe(4750);
  });

  test("idempotent : deux appels sur la même commande ne créditent le wallet qu'une seule fois", async () => {
    await seedOrder("order-2", { foodAmount: 2000, deliveryFee: 500 });
    await seedRestaurant("restaurant-1", { wallet_balance: 0 });

    await index._creditApprovedPayment({ orderId: "order-2", txId: "tx_a", amount: 2600 });
    const second = await index._creditApprovedPayment({ orderId: "order-2", txId: "tx_b", amount: 2600 });

    expect(second.credited).toBe(false); // no-op détecté par la transaction Firestore

    const restaurant = await getRestaurant("restaurant-1");
    // 2000 - 5% = 1900 — crédité UNE seule fois, pas deux
    expect(restaurant.wallet_balance).toBe(1900);
  });

  test("ne fait jamais confiance au paramètre `amount` pour le calcul de la ventilation — " +
       "seul order.foodAmount (posé par le serveur via prepareOrder) fait foi", async () => {
    await seedOrder("order-3", { foodAmount: 1000, deliveryFee: 200 });
    await seedRestaurant("restaurant-1", { wallet_balance: 0 });

    // `amount` délibérément incohérent avec foodAmount — simule une réponse
    // FedaPay falsifiée ou un appel malveillant direct de la fonction.
    await index._creditApprovedPayment({ orderId: "order-3", txId: "tx_evil", amount: 999999 });

    const restaurant = await getRestaurant("restaurant-1");
    // Doit rester basé sur foodAmount=1000 (5% = 50 → resto = 950), jamais sur 999999
    expect(restaurant.wallet_balance).toBe(950);
  });

  test("commande introuvable → ne plante pas, renvoie credited: false", async () => {
    const result = await index._creditApprovedPayment({
      orderId: "does-not-exist",
      txId: "tx_x",
      amount: 1000,
    });
    expect(result.credited).toBe(false);
  });

  test("écrit un log payment_logs et wallet_transactions à chaque crédit réel", async () => {
    await seedOrder("order-4", { foodAmount: 3000, deliveryFee: 500 });
    await seedRestaurant("restaurant-1");

    await index._creditApprovedPayment({ orderId: "order-4", txId: "tx_4", amount: 3650, eventName: "test" });

    const { db } = require("./helpers/firestore");
    const walletTx = await db().collection("wallet_transactions").where("order_id", "==", "order-4").get();
    const paymentLogs = await db().collection("payment_logs").where("orderId", "==", "order-4").get();
    expect(walletTx.size).toBe(1);
    expect(paymentLogs.size).toBe(1);
    expect(paymentLogs.docs[0].data().event).toBe("test");
  });
});
