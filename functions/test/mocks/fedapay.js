// functions/test/mocks/fedapay.js
//
// Mock du gateway FedaPay via nock — intercepte les vrais appels HTTPS que
// _fedaPayGet/_fedaPayRequest émettent, sans toucher au code de production.
// Aucune requête ne part réellement vers FedaPay pendant les tests.

const nock = require("nock");

const FEDAPAY_SANDBOX_HOST = "https://sandbox-api.fedapay.com";

/**
 * Simule GET /v1/transactions/:id → transaction avec le statut donné.
 * Utilisé par confirmOrderPayment et checkFedaPayStatus.
 */
function mockGetTransaction(txId, { status = "approved", amount = 5000, orderId } = {}) {
  return nock(FEDAPAY_SANDBOX_HOST)
    .get(`/v1/transactions/${txId}`)
    .reply(200, {
      "v1/transaction": {
        id: txId,
        status,
        amount,
        custom_metadata: orderId ? { order_id: orderId } : undefined,
      },
    });
}

/** Simule une panne réseau/API FedaPay (timeout, 500, etc.) */
function mockGetTransactionFailure(txId, statusCode = 500) {
  return nock(FEDAPAY_SANDBOX_HOST)
    .get(`/v1/transactions/${txId}`)
    .reply(statusCode, { message: "Erreur FedaPay simulée" });
}

/** Simule POST /v1/transactions (création) → renvoie id + token. */
function mockCreateTransaction({ id = "tx_mock_1", token = "tok_mock_1" } = {}) {
  return nock(FEDAPAY_SANDBOX_HOST)
    .post("/v1/transactions")
    .reply(201, { "v1/transaction": { id, token, status: "pending" } });
}

/** Simule POST /v1/transactions/:id/send_now (push USSD). */
function mockSendNow(txId, { statusCode = 200 } = {}) {
  return nock(FEDAPAY_SANDBOX_HOST)
    .post(`/v1/transactions/${txId}/send_now`)
    .reply(statusCode, { "v1/payment_intent": { status: "pending" } });
}

module.exports = {
  FEDAPAY_SANDBOX_HOST,
  mockGetTransaction,
  mockGetTransactionFailure,
  mockCreateTransaction,
  mockSendNow,
};
