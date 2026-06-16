// lib/pages/TermsPage.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ── Contenu partagé ──────────────────────────────────────────────────────────

const _kSections = [
  _Section(
    title: "1. Objet",
    content:
        "Les présentes conditions générales d'utilisation (CGU) régissent l'accès et l'utilisation de l'application mobile allofoods, disponible sur Android, éditée par allofoods SARL, société enregistrée à Cotonou, République du Bénin.",
  ),
  _Section(
    title: "2. Acceptation des conditions",
    content:
        "En téléchargeant, installant ou utilisant l'application allofoods, vous acceptez sans réserve les présentes CGU. Si vous n'acceptez pas ces conditions, vous devez cesser immédiatement d'utiliser l'application.",
  ),
  _Section(
    title: "3. Description du service",
    content:
        "allofoods est une plateforme de commande et de livraison de repas à domicile ou au bureau, opérant à Cotonou et dans ses environs. L'application permet aux utilisateurs de :\n• Parcourir les menus des restaurants partenaires\n• Passer des commandes en ligne\n• Payer via Mobile Money (MTN MoMo, Moov Money)\n• Suivre leur livraison en temps réel",
  ),
  _Section(
    title: "4. Inscription et compte utilisateur",
    content:
        "Pour utiliser les services allofoods, vous devez créer un compte en fournissant des informations exactes et à jour. Vous êtes responsable de la confidentialité de vos identifiants de connexion. Tout accès à votre compte via vos identifiants est réputé effectué par vous.",
  ),
  _Section(
    title: "5. Commandes et paiements",
    content:
        "Toute commande passée via allofoods constitue un contrat entre vous et le restaurant concerné. Les prix affichés sont en francs CFA (FCFA) et incluent les taxes applicables. Les frais de livraison sont calculés en fonction de la distance. Le paiement s'effectue via Mobile Money (MTN MoMo, Moov Money) ou en espèces à la livraison.",
  ),
  _Section(
    title: "6. Annulation et remboursement",
    content:
        "Une commande peut être annulée dans les 5 minutes suivant sa validation, avant que le restaurant ne l'accepte. Passé ce délai, l'annulation n'est plus possible. En cas de problème avéré (commande incorrecte, non livrée), allofoods s'engage à traiter votre réclamation sous 48 heures ouvrées.",
  ),
  _Section(
    title: "7. Responsabilités",
    content:
        "allofoods agit en tant qu'intermédiaire entre les clients et les restaurants. La qualité des repas est sous la responsabilité exclusive des restaurants partenaires. allofoods ne peut être tenu responsable des retards causés par des événements indépendants de sa volonté (trafic, météo, force majeure).",
  ),
  _Section(
    title: "8. Propriété intellectuelle",
    content:
        "L'ensemble des éléments constituant l'application allofoods (logo, design, textes, fonctionnalités) est protégé par le droit de la propriété intellectuelle. Toute reproduction, même partielle, est interdite sans autorisation préalable écrite.",
  ),
  _Section(
    title: "9. Modification des CGU",
    content:
        "allofoods se réserve le droit de modifier les présentes CGU à tout moment. Les utilisateurs seront informés des modifications par notification dans l'application. La poursuite de l'utilisation du service après notification vaut acceptation des nouvelles conditions.",
  ),
  _Section(
    title: "10. Droit applicable",
    content:
        "Les présentes CGU sont soumises au droit béninois. Tout litige relatif à leur interprétation ou à leur exécution relève de la compétence exclusive des tribunaux de Cotonou, République du Bénin.",
  ),
  _Section(
    title: "11. Contact",
    content:
        "Pour toute question relative aux présentes CGU, contactez-nous :\n• Email : legal@allofoods.bj\n• Téléphone : +229 01 47 17 49 51\n• Adresse : Cotonou, République du Bénin\n\nDernière mise à jour : Mars 2025",
  ),
];

// ── Page lecture seule (accessible depuis Paramètres) ─────────────────────────

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Conditions d'utilisation",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: _kSections,
      ),
    );
  }
}

// ── Page d'acceptation (affichée après inscription) ───────────────────────────

class TermsAcceptancePage extends StatefulWidget {
  final String uid;
  const TermsAcceptancePage({super.key, required this.uid});

  @override
  State<TermsAcceptancePage> createState() => _TermsAcceptancePageState();
}

class _TermsAcceptancePageState extends State<TermsAcceptancePage> {
  bool _checked = false;
  bool _loading = false;

  Future<void> _accept() async {
    if (!_checked || _loading) return;
    setState(() => _loading = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .set({
        'termsAccepted': true,
        'termsAcceptedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      // AuthGate StreamBuilder Firestore reagit automatiquement → MainScaffold
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Erreur réseau. Réessayez.'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Future<void> _decline() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .delete();
    } catch (_) {}
    try {
      await FirebaseAuth.instance.currentUser?.delete();
    } catch (_) {}
    await FirebaseAuth.instance.signOut();
    // AuthGate StreamBuilder reagit → LoginPage
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(children: [
            // ── En-tête ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.description_outlined,
                        color: Colors.orange.shade700, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Conditions d'utilisation",
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87)),
                          SizedBox(height: 2),
                          Text('Lisez attentivement avant de continuer',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.black54)),
                        ]),
                  ),
                ]),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(children: [
                    Icon(Icons.info_outline,
                        color: Colors.orange.shade700, size: 16),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Vous devez accepter les conditions pour créer votre compte allofoods.',
                        style: TextStyle(fontSize: 12, color: Colors.black87),
                      ),
                    ),
                  ]),
                ),
              ]),
            ),

            // ── Contenu défilable ────────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                children: _kSections,
              ),
            ),

            // ── Panneau bas : checkbox + boutons ─────────────────────────────
            Container(
              padding: EdgeInsets.fromLTRB(
                  16, 12, 16, MediaQuery.of(context).padding.bottom + 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: Offset(0, -3))
                ],
              ),
              child: Column(children: [
                // Checkbox
                InkWell(
                  onTap: _loading
                      ? null
                      : () => setState(() => _checked = !_checked),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Checkbox(
                        value: _checked,
                        onChanged: _loading
                            ? null
                            : (v) => setState(
                                () => _checked = v ?? false),
                        activeColor: Colors.orange,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      ),
                      const SizedBox(width: 4),
                      const Expanded(
                        child: Text(
                          "J'ai lu et j'accepte les conditions d'utilisation d'allofoods",
                          style: TextStyle(
                              fontSize: 13, color: Colors.black87),
                        ),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 10),

                // Bouton accepter
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: (_checked && !_loading) ? _accept : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      disabledBackgroundColor: Colors.grey.shade200,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5))
                        : Text(
                            'Accepter et continuer',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _checked
                                  ? Colors.white
                                  : Colors.grey.shade500,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 6),

                // Bouton refuser
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: _loading ? null : _decline,
                    child: const Text(
                      'Refuser et annuler mon inscription',
                      style: TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Widget section ────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final String content;
  const _Section({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.orange)),
        const SizedBox(height: 8),
        Text(content,
            style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
                height: 1.6)),
      ]),
    );
  }
}
