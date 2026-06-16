// lib/widgets/pending_order_banner.dart
// ? Firebase : pas de changement nécessaire é Provider local uniquement

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/pending_order_provider.dart';

class PendingOrderBanner extends StatelessWidget {
  const PendingOrderBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PendingOrderProvider>(
      builder: (context, provider, _) {
        if (!provider.hasPending) return const SizedBox.shrink();
        final order = provider.pendingOrder!;

        return AnimatedSlide(
          offset: Offset.zero,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
          child: Container(
            margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B00), Color(0xFFFF9800)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.orange.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4))
                ]),
            child: Row(children: [
              Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle),
                  child:
                      const Icon(Icons.payment, color: Colors.white, size: 22)),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('Paiement interrompu !',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                    Text(
                        'Commande chez ${order['restaurantName'] ?? 'le restaurant'} '
                        'é ${order['total']?.toStringAsFixed(0) ?? 0} FCFA',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 12)),
                  ])),
              Column(children: [
                ElevatedButton(
                  onPressed: () => _resumePayment(context, order),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20))),
                  child: const Text('Reprendre',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                    onTap: () => provider.dismiss(),
                    child: Text('Ignorer',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 11,
                            decoration: TextDecoration.underline,
                            decorationColor: Colors.white54))),
              ]),
            ]),
          ),
        );
      },
    );
  }

  void _resumePayment(BuildContext context, Map<String, dynamic> order) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ResumeSheet(order: order),
    );
  }
}

class _ResumeSheet extends StatelessWidget {
  final Map<String, dynamic> order;
  const _ResumeSheet({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 20),
        const Icon(Icons.payment, color: Colors.orange, size: 48),
        const SizedBox(height: 12),
        const Text('Reprendre le paiement',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
            'Votre commande chez ${order['restaurantName']} d\'un montant de '
            '${order['total']?.toStringAsFixed(0)} FCFA est en attente de paiement.',
            textAlign: TextAlign.center,
            style:
                const TextStyle(color: Colors.grey, fontSize: 13, height: 1.5)),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Redirection vers le paiement...'),
                backgroundColor: Colors.orange));
          },
          icon: const Icon(Icons.credit_card),
          label: Text('Payer ${order['total']?.toStringAsFixed(0)} FCFA'),
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14))),
        ),
        const SizedBox(height: 8),
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler', style: TextStyle(color: Colors.grey))),
      ]),
    );
  }
}
