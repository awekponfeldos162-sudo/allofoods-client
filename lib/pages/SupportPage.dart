// lib/pages/SupportPage.dart
// ? Centre d'aide avec FAQ interactive + formulaire de contact Firestore

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SupportPage extends StatefulWidget {
  const SupportPage({super.key});
  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  int _expandedFaq = -1;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  static const _faq = [
    {
      'q': 'Comment passer une commande ?',
      'a':
          'Choisissez un restaurant, ajoutez vos plats au panier, sélectionnez votre adresse de livraison et payez via Mobile Money ou à la livraison.',
    },
    {
      'q': 'Quels sont les modes de paiement ?',
      'a':
          'Nous acceptons MTN MoMo, Moov Money, Celtiis Cash via KKiaPay, ainsi que le paiement en espéces à la livraison.',
    },
    {
      'q': 'Comment suivre ma commande en temps réel ?',
      'a':
          'Après confirmation du paiement, vous serez redirigé vers la page de suivi. Vous pouvez voir la position du livreur sur la carte en temps réel.',
    },
    {
      'q': 'Quel est le délai de livraison ?',
      'a':
          'Le délai dépend de la distance entre le restaurant et votre adresse. En moyenne 20 à 45 minutes à Cotonou.',
    },
    {
      'q': 'Puis-je annuler une commande ?',
      'a':
          'Vous pouvez annuler une commande uniquement si elle n\'a pas encore été confirmée par le restaurant. Contactez le support rapidement.',
    },
    {
      'q': 'Que faire si mon paiement échoue ?',
      'a':
          'Vérifiez votre solde Mobile Money. Si le problème persiste, essayez un autre opérateur ou choisissez le paiement à la livraison.',
    },
    {
      'q': 'Comment modifier mon adresse de livraison ?',
      'a':
          'Retournez dans l\'onglet Adresse et déplacez le marqueur sur la carte, ou sélectionnez une adresse sauvegardée.',
    },
    {
      'q': 'L\'application est-elle disponible en dehors de Cotonou ?',
      'a':
          'allofoods est actuellement disponible uniquement à Cotonou. Nous prévoyons d\'étendre le service à d\'autres villes du Bénin.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Centre d\'aide',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).textTheme.bodyLarge?.color,
        elevation: 0,
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.orange,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.orange,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.help_outline, size: 18), text: 'FAQ'),
            Tab(icon: Icon(Icons.mail_outline, size: 18), text: 'Contact'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _FaqTab(
              faq: _faq,
              expanded: _expandedFaq,
              onExpand: (i) =>
                  setState(() => _expandedFaq = _expandedFaq == i ? -1 : i)),
          const _ContactTab(),
        ],
      ),
    );
  }
}

// FAQ
class _FaqTab extends StatelessWidget {
  final List<Map<String, String>> faq;
  final int expanded;
  final ValueChanged<int> onExpand;

  const _FaqTab({
    required this.faq,
    required this.expanded,
    required this.onExpand,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey.shade200)),
          child: Row(children: [
            const Icon(Icons.emoji_objects_outlined,
                color: Colors.black87, size: 32),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Questions fréquentes',
                        style: TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                    Text('Trouvez une réponse rapide',
                        style: TextStyle(color: Colors.black54, fontSize: 12)),
                  ]),
            ),
          ]),
        ),

        // FAQ items
        ...faq.asMap().entries.map((e) {
          final isOpen = expanded == e.key;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: isOpen ? Colors.grey.shade300 : Colors.grey.shade100,
                  width: isOpen ? 1.5 : 1),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2))
              ],
            ),
            child: InkWell(
              onTap: () => onExpand(e.key),
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.help_outline,
                              color: Colors.black54, size: 16),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(e.value['q']!,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: Colors.black87)),
                        ),
                        Icon(
                            isOpen
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            color: Colors.grey,
                            size: 20),
                      ]),
                      if (isOpen) ...[
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        Text(e.value['a']!,
                            style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black87,
                                height: 1.5)),
                      ],
                    ]),
              ),
            ),
          );
        }),

        const SizedBox(height: 8),
        // Tip de contact
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200)),
          child: const Row(children: [
            Icon(Icons.info_outline, color: Colors.black54, size: 18),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                  'Vous ne trouvez pas votre réponse ? Contactez-nous via l\'onglet Contact.',
                  style: TextStyle(fontSize: 12, color: Colors.black54)),
            ),
          ]),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// Contact
class _ContactTab extends StatefulWidget {
  const _ContactTab();
  @override
  State<_ContactTab> createState() => _ContactTabState();
}

class _ContactTabState extends State<_ContactTab> {
  final _subjectCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();
  String _category = 'Commande';
  bool _sending = false;
  bool _sent = false;

  static const _categories = [
    'Commande',
    'Paiement',
    'Livraison',
    'Compte',
    'Autre'
  ];

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_subjectCtrl.text.trim().isEmpty || _msgCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Remplissez tous les champs'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    setState(() => _sending = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
      final email = FirebaseAuth.instance.currentUser?.email ?? '';

      await FirebaseFirestore.instance.collection('support_tickets').add({
        'uid': uid,
        'email': email,
        'category': _category,
        'subject': _subjectCtrl.text.trim(),
        'message': _msgCtrl.text.trim(),
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      setState(() {
        _sending = false;
        _sent = true;
      });
      _subjectCtrl.clear();
      _msgCtrl.clear();
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_sent) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
                color: Colors.green.shade50, shape: BoxShape.circle),
            child: const Icon(Icons.check_circle_outline,
                size: 60, color: Colors.green),
          ),
          const SizedBox(height: 20),
          const Text('Message envoyé !',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Nous vous répondrons dans les\n24 heures ouvrables.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => setState(() => _sent = false),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            child: const Text('Nouveau message'),
          ),
        ]),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Canaux de contact
        Row(children: [
          _ContactChip(
              icon: Icons.phone,
              label: '+229 01 90 12 20 76',
              color: Colors.green),
          const SizedBox(width: 8),
          _ContactChip(
              icon: Icons.email_outlined,
              label: 'support@allofoods.bj',
              color: Colors.blue),
        ]),
        const SizedBox(height: 16),

        // Catégorie
        const Text('Catégorie',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _categories
              .map((c) => ChoiceChip(
                    label: Text(c),
                    selected: _category == c,
                    selectedColor: Colors.orange,
                    labelStyle: TextStyle(
                        color: _category == c ? Colors.white : Colors.black87,
                        fontSize: 12),
                    onSelected: (_) => setState(() => _category = c),
                  ))
              .toList(),
        ),
        const SizedBox(height: 16),

        // Sujet
        const Text('Sujet',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 8),
        TextField(
          controller: _subjectCtrl,
          decoration:
              _deco('Décrivez briévement le problème', Icons.subject_outlined),
        ),
        const SizedBox(height: 16),

        // Message
        const Text('Message',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 8),
        TextField(
          controller: _msgCtrl,
          maxLines: 5,
          decoration:
              _deco('Détaillez votre problème...', Icons.message_outlined),
        ),
        const SizedBox(height: 24),

        ElevatedButton.icon(
          onPressed: _sending ? null : _send,
          icon: _sending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.send_outlined, size: 18),
          label: Text(_sending ? 'Envoi...' : 'Envoyer le message',
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14))),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  InputDecoration _deco(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.black54, size: 20),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.black87, width: 2)),
      );
}

class _ContactChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _ContactChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200)),
          child: Row(children: [
            Icon(icon, color: Colors.black54, size: 16),
            const SizedBox(width: 6),
            Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black87,
                        fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis)),
          ]),
        ),
      );
}
