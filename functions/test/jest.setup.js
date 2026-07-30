// functions/test/jest.setup.js
//
// Exécuté par Jest AVANT le chargement des fichiers de test (et donc avant
// tout require('../index.js')). Bascule l'Admin SDK sur l'émulateur
// Firestore local et fournit des variables d'environnement de test — jamais
// les vraies clés FedaPay live.

process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || "allofoods-test";

// Clé FedaPay factice — jamais la vraie clé live. Les appels HTTP réels sont
// interceptés par nock dans chaque fichier de test (voir test/mocks/fedapay.js).
process.env.FEDAPAY_SECRET_KEY = "sk_test_fake_00000000000000000000";
process.env.FEDAPAY_SANDBOX = "true"; // → sandbox-api.fedapay.com, intercepté par nock
process.env.FEDAPAY_WEBHOOK_SECRET = "test_webhook_secret";

// Coupe-circuit réseau : seuls localhost (émulateur) et les hôtes explicitement
// mockés par nock sont autorisés. Toute requête HTTP réelle non prévue lève
// une erreur immédiate au lieu de silencieusement taper la prod.
const nock = require("nock");
nock.disableNetConnect();
nock.enableNetConnect(/127\.0\.0\.1|localhost/);
