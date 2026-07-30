// functions/test/helpers/firestore.js
//
// Helpers Firestore pour les tests — nécessite l'émulateur Firestore lancé
// (voir "npm test", qui utilise `firebase emulators:exec --only firestore`).

const { getFirestore } = require("firebase-admin/firestore");

function db() {
  return getFirestore();
}

/** Crée une commande de test avec des valeurs par défaut raisonnables. */
async function seedOrder(orderId, overrides = {}) {
  const data = {
    clientUid: "client-uid-1",
    restaurantId: "restaurant-1",
    restaurantName: "Chez Test",
    foodAmount: 5000,
    deliveryFee: 1000,
    serviceFee: 250,
    totalAmount: 6250,
    paymentStatus: "pending",
    status: "awaiting_payment",
    items: [{ name: "Poulet braisé", quantity: 2, price: 2500 }],
    ...overrides,
  };
  await db().collection("orders").doc(orderId).set(data);
  return data;
}

// Champs financiers (wallet_balance, total_earned, momo_number...) vivent
// dans restaurants/{id}/private/wallet — voir functions/index.js (_walletRef).
const _WALLET_FIELDS = [
  "wallet_balance", "total_earned", "total_withdrawn",
  "momo_number", "momo_network", "auto_payout",
];

async function seedRestaurant(restaurantId, overrides = {}) {
  const walletOverrides = {};
  const mainOverrides = {};
  for (const [k, v] of Object.entries(overrides)) {
    if (_WALLET_FIELDS.includes(k)) walletOverrides[k] = v;
    else mainOverrides[k] = v;
  }

  const mainData = { name: "Chez Test", ...mainOverrides };
  const walletData = { wallet_balance: 0, total_earned: 0, ...walletOverrides };

  await db().collection("restaurants").doc(restaurantId).set(mainData);
  await db().collection("restaurants").doc(restaurantId)
    .collection("private").doc("wallet").set(walletData);

  return { ...mainData, ...walletData };
}

async function getOrder(orderId) {
  const snap = await db().collection("orders").doc(orderId).get();
  return snap.exists ? snap.data() : null;
}

async function getRestaurant(restaurantId) {
  const snap = await db().collection("restaurants").doc(restaurantId).get();
  if (!snap.exists) return null;
  const walletSnap = await db().collection("restaurants").doc(restaurantId)
    .collection("private").doc("wallet").get();
  return { ...snap.data(), ...(walletSnap.exists ? walletSnap.data() : {}) };
}

/** Vide les collections utilisées par les tests entre deux cas — isolation. */
async function clearTestData() {
  const restosSnap = await db().collection("restaurants").get();
  await Promise.all(restosSnap.docs.map(async (d) => {
    const walletSnap = await d.ref.collection("private").doc("wallet").get();
    if (walletSnap.exists) await walletSnap.ref.delete();
  }));

  const collections = ["orders", "restaurants", "wallet_transactions", "payment_logs", "admin", "users"];
  for (const name of collections) {
    const snap = await db().collection(name).get();
    await Promise.all(snap.docs.map((d) => d.ref.delete()));
  }
}

module.exports = { db, seedOrder, seedRestaurant, getOrder, getRestaurant, clearTestData };
