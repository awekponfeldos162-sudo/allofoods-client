/**
 * allofoods — Test Cold Start 500 VUs
 * Simule 500 utilisateurs simultanés qui frappent les Cloud Functions d'un coup
 * pour mesurer le comportement au démarrage à froid (cold start Firebase).
 *
 * Usage :
 *   & "C:\Program Files\k6\k6.exe" run test/k6/cold_start_500.js
 */

import http from "k6/http";
import { check, sleep } from "k6";
import { Counter, Trend, Rate } from "k6/metrics";

// ── Config ─────────────────────────────────────────────────────────────────────
const PROJECT_ID   = "allofoods-5d32b";
const REGION       = "europe-west1";
const FIREBASE_KEY = "AIzaSyA8yV62xRHf3BFgE8bXW2o9k_rqUKQM9oo";
const CF_BASE      = `https://${REGION}-${PROJECT_ID}.cloudfunctions.net`;
const AUTH_URL     = `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${FIREBASE_KEY}`;

const TEST_EMAIL    = "test.load@allofoods.bj";
const TEST_PASSWORD = "AlloFoods@Load2026!";

// ── Métriques ──────────────────────────────────────────────────────────────────
const cfDuration  = new Trend("cf_duration_ms", true);
const coldStarts  = new Counter("cold_start_hits");
const timeouts    = new Counter("timeouts");
const errorRate   = new Rate("error_rate");

// ── Scénario cold start ────────────────────────────────────────────────────────
// 500 VUs lancés d'un seul coup (pas de ramp) → force les cold starts Firebase
export const options = {
  scenarios: {
    cold_start: {
      executor:  "ramping-vus",
      exec:      "coldStartTest",
      stages: [
        { duration: "5s",  target: 500 }, // montée brutale en 5s → cold start
        { duration: "30s", target: 500 }, // maintien 30s
        { duration: "10s", target: 0   }, // descente
      ],
      gracefulRampDown: "10s",
    },
  },

  thresholds: {
    // Acceptable sous cold start : p95 < 10s (cold start Firebase peut prendre ~5s)
    "cf_duration_ms":  ["p(95)<10000"],
    // Taux d'erreur < 30% acceptable (cold start + rate limiting)
    "error_rate":      ["rate<0.30"],
    // Au moins 70% des requêtes doivent aboutir
    http_req_failed:   ["rate<0.30"],
  },

  // Timeout HTTP étendu pour cold starts longs
  httpDebug: "",
};

// ── Setup : auth unique partagée ───────────────────────────────────────────────
export function setup() {
  console.log("[setup] Auth Firebase pour cold start test...");
  const res = http.post(AUTH_URL, JSON.stringify({
    email:             TEST_EMAIL,
    password:          TEST_PASSWORD,
    returnSecureToken: true,
  }), { headers: { "Content-Type": "application/json" } });

  if (res.status !== 200) {
    throw new Error(`Auth échouée (${res.status}) — vérifiez le compte ${TEST_EMAIL}`);
  }
  const body = JSON.parse(res.body);
  console.log(`[setup] uid: ${body.localId}`);
  return { token: body.idToken, uid: body.localId };
}

// ── Fonction de test ───────────────────────────────────────────────────────────
export function coldStartTest(ctx) {
  const token   = ctx.token;
  const orderId = `COLD-${__VU}-${Date.now()}`;

  const t0 = Date.now();
  const res = http.post(
    `${CF_BASE}/initFedaPayPayment`,
    JSON.stringify({ data: { orderId } }),
    {
      headers: {
        "Content-Type":  "application/json",
        "Authorization": `Bearer ${token}`,
      },
      timeout: "65s", // dépasse le timeout Firebase (60s) pour capturer les vrais timeouts
    }
  );

  const duration = Date.now() - t0;
  cfDuration.add(duration);

  // Détection cold start : réponse > 3s = cold start probable
  if (duration > 3000) coldStarts.add(1);

  // Détection timeout
  if (res.status === 0 || duration >= 60000) timeouts.add(1);

  const isError = res.status === 0 || res.status >= 500;
  errorRate.add(isError ? 1 : 0);

  check(res, {
    "répond (pas de crash réseau)": (r) => r.status !== 0,
    "réponse JSON valide":          (r) => {
      try { JSON.parse(r.body); return true; } catch { return false; }
    },
    "cold start < 5s":              () => duration < 5000,
    "cold start < 10s":             () => duration < 10000,
  });

  // Log des cas lents
  if (duration > 5000) {
    console.warn(`[VU${__VU}] Lent: ${duration}ms — status=${res.status}`);
  }

  sleep(1);
}

// ── Teardown ───────────────────────────────────────────────────────────────────
export function teardown(ctx) {
  console.log(`[teardown] Cold start test terminé — uid: ${ctx.uid}`);
}
