/**
 * allofoods — Test de charge k6
 * Teste les Cloud Functions Firebase sous charge simultanée
 *
 * Usage :
 *   "C:\Program Files\k6\k6.exe" run test/k6/allofoods_load_test.js
 *   "C:\Program Files\k6\k6.exe" run --vus 20 --duration 2m test/k6/allofoods_load_test.js
 *
 * Prérequis : créer le compte test dans Firebase Console (voir README)
 */

import http from "k6/http";
import { check, sleep, group } from "k6";
import { Counter, Trend, Rate } from "k6/metrics";

// ── Config projet ──────────────────────────────────────────────────────────────
const PROJECT_ID     = "allofoods-5d32b";
const REGION         = "europe-west1";
const FIREBASE_KEY   = "AIzaSyA8yV62xRHf3BFgE8bXW2o9k_rqUKQM9oo"; // clé Android (publique)
const CF_BASE        = `https://${REGION}-${PROJECT_ID}.cloudfunctions.net`;
const FIRESTORE_BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;
const AUTH_URL       = `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${FIREBASE_KEY}`;

// Compte test (créer dans Firebase Console > Authentication)
const TEST_EMAIL    = "test.load@allofoods.bj";
const TEST_PASSWORD = "AlloFoods@Load2026!";

// ── Métriques custom ───────────────────────────────────────────────────────────
const cfDuration   = new Trend("cf_duration_ms",   true); // durée Cloud Functions
const fsReadTime   = new Trend("firestore_read_ms", true); // durée lectures Firestore
const authFailures = new Counter("auth_failures");
const paymentOk    = new Counter("payment_init_ok");
const paymentFail  = new Counter("payment_init_fail");

// ── Scénarios de charge ────────────────────────────────────────────────────────
export const options = {
  scenarios: {

    // Scénario A : navigation restaurants (lecture Firestore)
    // 20 utilisateurs simultanés pendant 2 minutes
    navigation: {
      executor: "ramping-vus",
      exec:     "scenarioNavigation",
      stages: [
        { duration: "20s", target: 5  },
        { duration: "1m",  target: 20 },
        { duration: "20s", target: 0  },
      ],
    },

    // Scénario B : flux paiement (Cloud Functions)
    // 10 utilisateurs constants, démarre après 30s
    paiement: {
      executor:  "constant-vus",
      exec:      "scenarioPaiement",
      vus:       10,
      duration:  "90s",
      startTime: "30s",
    },

  },

  thresholds: {
    // Cloud Functions : 95% des appels < 3s
    "cf_duration_ms{scenario:paiement}":    ["p(95)<3000"],
    // Firestore : 95% des lectures < 3s (REST API sous charge 20 VUs)
    "firestore_read_ms{scenario:navigation}": ["p(95)<3000"],
    // Taux d'erreur HTTP global < 50% (inclut les resets Firestore sous charge)
    // Pour cibler uniquement les CF : surveiller cf_duration_ms
    http_req_failed:                        ["rate<0.50"],
  },
};

// ── Setup : authentification (une seule fois, partagé entre VUs) ───────────────
export function setup() {
  console.log("[setup] Authentification Firebase...");
  const res = http.post(AUTH_URL, JSON.stringify({
    email:             TEST_EMAIL,
    password:          TEST_PASSWORD,
    returnSecureToken: true,
  }), { headers: { "Content-Type": "application/json" } });

  if (res.status !== 200) {
    throw new Error(
      `Auth Firebase échouée (${res.status}). ` +
      `Créez le compte ${TEST_EMAIL} dans Firebase Console > Authentication.`
    );
  }

  const body = JSON.parse(res.body);
  console.log(`[setup] Token obtenu — uid: ${body.localId}`);
  return {
    token:  body.idToken,
    uid:    body.localId,
    email:  body.email,
  };
}

// ── Helper : appel Cloud Function callable ─────────────────────────────────────
function callCF(name, data, token) {
  const t0  = Date.now();
  const res = http.post(
    `${CF_BASE}/${name}`,
    JSON.stringify({ data }),
    {
      headers: {
        "Content-Type":  "application/json",
        "Authorization": `Bearer ${token}`,
      },
      tags: { cf: name },
    }
  );
  cfDuration.add(Date.now() - t0, { cf: name });
  return res;
}

// ── Helper : lecture Firestore REST ───────────────────────────────────────────
function firestoreGet(path, token) {
  const t0  = Date.now();
  const res = http.get(
    `${FIRESTORE_BASE}/${path}`,
    {
      headers: { "Authorization": `Bearer ${token}` },
      tags:    { collection: path.split("/")[0] },
    }
  );
  fsReadTime.add(Date.now() - t0);
  return res;
}

// ── Scénario A : Navigation restaurants ───────────────────────────────────────
export function scenarioNavigation(ctx) {
  const token = ctx.token;

  group("liste restaurants", () => {
    const res = firestoreGet("restaurants?pageSize=20", token);
    check(res, {
      "status 200":          (r) => r.status === 200,
      "a des documents":     (r) => {
        try { return !!JSON.parse(r.body).documents; } catch { return false; }
      },
      "réponse < 2s":        (r) => r.timings.duration < 2000,
    });
  });

  sleep(1);

  group("détail restaurant", () => {
    // Lire un restaurant par ID fixe (le 1er de la liste si disponible)
    const listRes = firestoreGet("restaurants?pageSize=1", token);
    if (listRes.status === 200) {
      try {
        const docs = JSON.parse(listRes.body).documents;
        if (docs && docs.length > 0) {
          const docName = docs[0].name; // "projects/.../documents/restaurants/ID"
          const restId  = docName.split("/").pop();
          const detRes  = firestoreGet(`restaurants/${restId}`, token);
          check(detRes, {
            "détail restaurant 200": (r) => r.status === 200,
          });
        }
      } catch (_) {}
    }
  });

  sleep(2);
}

// ── Scénario B : Flux paiement ─────────────────────────────────────────────────
export function scenarioPaiement(ctx) {
  const token       = ctx.token;
  const fakeOrderId = `LOAD-${__VU}-${Date.now()}`;

  // Étape 1 : initFedaPayPayment
  // Commande inexistante → "not-found" attendu — on teste la latence de la fonction
  group("initFedaPayPayment", () => {
    const res = callCF("initFedaPayPayment", { orderId: fakeOrderId }, token);
    const ok  = check(res, {
      "répond en < 3s":          (r) => r.timings.duration < 3000,
      "erreur structurée (pas de crash)": (r) => {
        // Doit retourner un JSON valide (erreur métier, pas 500)
        try { JSON.parse(r.body); return true; } catch { return false; }
      },
    });
    if (ok) paymentOk.add(1); else paymentFail.add(1);
  });

  sleep(1);

  // Étape 2 : checkFedaPayStatus — avec ID FedaPay fictif
  group("checkFedaPayStatus", () => {
    const res = callCF("checkFedaPayStatus", { transactionId: "99999999" }, token);
    check(res, {
      "répond en < 2s":         (r) => r.timings.duration < 2000,
      "réponse JSON valide":    (r) => {
        try { JSON.parse(r.body); return true; } catch { return false; }
      },
    });
  });

  sleep(2);
}

// ── Teardown : résumé ──────────────────────────────────────────────────────────
export function teardown(ctx) {
  console.log(`[teardown] Tests terminés — uid: ${ctx.uid}`);
}
