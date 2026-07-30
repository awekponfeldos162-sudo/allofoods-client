// functions/test/confirmOrderPayment.test.js
//
// Teste le handler confirmOrderPayment directement (sans passer par le
// wrapper onCall) avec de faux objets `request` — voir l'export
// `_confirmOrderPaymentHandler` dans index.js.

const { seedOrder, getOrder, getRestaurant, clearTestData } = require("./helpers/firestore");
const { mockGetTransaction, mockGetTransactionFailure } = require("./mocks/fedapay");

let index;
beforeAll(() => {
  index = require("../index.js");
});

afterEach(async () => {
  await clearTestData();
});

function fakeRequest({ uid = "client-uid-1", orderId, transactionId } = {}) {
  return { auth: uid ? { uid } : null, data: { orderId, transactionId } };
}

describe("confirmOrderPayment", () => {
  test("rejette un appel non authentifié", async () => {
    await expect(
      index._confirmOrderPaymentHandler(fakeRequest({ uid: null, orderId: "o1", transactionId: "t1" }))
    ).rejects.toMatchObject({ code: "unauthenticated" });
  });

  test("rejette si orderId ou transactionId manquant", async () => {
    await expect(
      index._confirmOrderPaymentHandler(fakeRequest({ orderId: "o1" })) // pas de transactionId
    ).rejects.toMatchObject({ code: "invalid-argument" });
  });

  test("rejette si la commande n'existe pas", async () => {
    await expect(
      index._confirmOrderPaymentHandler(fakeRequest({ orderId: "ghost", transactionId: "t1" }))
    ).rejects.toMatchObject({ code: "not-found" });
  });

  test("rejette si la commande appartient à un autre client (sécurité — pas de vol de confirmation)", async () => {
    await seedOrder("order-owner", { clientUid: "someone-else" });
    await expect(
      index._confirmOrderPaymentHandler(
        fakeRequest({ uid: "client-uid-1", orderId: "order-owner", transactionId: "t1" })
      )
    ).rejects.toMatchObject({ code: "permission-denied" });
  });

  test("idempotent : commande déjà PAID → renvoie alreadyPaid sans re-vérifier FedaPay", async () => {
    await seedOrder("order-paid", { paymentStatus: "PAID" });
    // Aucun mock nock enregistré : si le handler appelait FedaPay ici, le test
    // échouerait (nock.disableNetConnect() lève sur toute requête non mockée).
    const result = await index._confirmOrderPaymentHandler(
      fakeRequest({ orderId: "order-paid", transactionId: "t1" })
    );
    expect(result).toEqual({ success: true, alreadyPaid: true });
  });

  test("rejette si FedaPay indique un statut différent de 'approved'", async () => {
    await seedOrder("order-pending-tx");
    mockGetTransaction("tx_pending", { status: "pending" });
    await expect(
      index._confirmOrderPaymentHandler(
        fakeRequest({ orderId: "order-pending-tx", transactionId: "tx_pending" })
      )
    ).rejects.toMatchObject({ code: "failed-precondition" });
  });

  test("rejette si la transaction FedaPay est liée à une AUTRE commande (anti-rejeu)", async () => {
    await seedOrder("order-A");
    await seedOrder("order-B");
    // Transaction réellement approuvée, mais pour order-B — un client malveillant
    // essaie de la réutiliser pour confirmer order-A gratuitement.
    mockGetTransaction("tx_for_B", { status: "approved", orderId: "order-B" });

    await expect(
      index._confirmOrderPaymentHandler(fakeRequest({ orderId: "order-A", transactionId: "tx_for_B" }))
    ).rejects.toMatchObject({ code: "failed-precondition" });

    const orderA = await getOrder("order-A");
    expect(orderA.paymentStatus).not.toBe("PAID");
  });

  test("remonte une erreur propre si l'appel réseau à FedaPay échoue", async () => {
    await seedOrder("order-network-fail");
    mockGetTransactionFailure("tx_fail", 500);
    await expect(
      index._confirmOrderPaymentHandler(
        fakeRequest({ orderId: "order-network-fail", transactionId: "tx_fail" })
      )
    ).rejects.toMatchObject({ code: "internal" });
  });

  test("chemin nominal : transaction approuvée + metadata correcte → PAID + wallet crédité", async () => {
    await seedOrder("order-happy", { foodAmount: 4000, deliveryFee: 800 });
    const { seedRestaurant } = require("./helpers/firestore");
    await seedRestaurant("restaurant-1");
    mockGetTransaction("tx_happy", { status: "approved", amount: 5000, orderId: "order-happy" });

    const result = await index._confirmOrderPaymentHandler(
      fakeRequest({ orderId: "order-happy", transactionId: "tx_happy" })
    );

    expect(result).toEqual({ success: true });
    const order = await getOrder("order-happy");
    expect(order.paymentStatus).toBe("PAID");

    // Le point qui manquait avant le correctif : le wallet DOIT être crédité
    // ici aussi, pas uniquement via fedapayWebhook.
    const restaurant = await getRestaurant("restaurant-1");
    expect(restaurant.wallet_balance).toBeGreaterThan(0);
  });

  test("le montant crédité ignore le montant renvoyé par FedaPay et se base sur Firestore " +
       "(protection contre une réponse gateway falsifiée)", async () => {
    await seedOrder("order-amount-guard", { foodAmount: 1000, deliveryFee: 100 });
    const { seedRestaurant } = require("./helpers/firestore");
    await seedRestaurant("restaurant-1");
    // FedaPay "confirme" un montant délirant — ne doit jamais se propager au wallet.
    mockGetTransaction("tx_guard", { status: "approved", amount: 500000, orderId: "order-amount-guard" });

    await index._confirmOrderPaymentHandler(
      fakeRequest({ orderId: "order-amount-guard", transactionId: "tx_guard" })
    );

    const restaurant = await getRestaurant("restaurant-1");
    expect(restaurant.wallet_balance).toBe(950); // 1000 - 5%, jamais dérivé de 500000
  });
});
