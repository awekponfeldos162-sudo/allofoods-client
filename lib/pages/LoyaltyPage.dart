// lib/pages/LoyaltyPage.dart
// Programme de fidélité é points gagnés sur chaque commande
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class LoyaltyPage extends StatelessWidget {
  const LoyaltyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Programme Fidélité',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream:
            FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (_, snap) {
          final data = snap.data?.data() as Map<String, dynamic>? ?? {};
          final points = (data['loyaltyPoints'] as num?)?.toInt() ?? 0;
          final level = _level(points);
          final nextReward = _nextReward(points);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Carte points
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF9800), Color(0xFFE65100)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.orange.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6)),
                  ],
                ),
                child: Column(children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12)),
                      child:
                          const Icon(Icons.star, color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Mes Points allofoods',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 12)),
                            Text('$points pts',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold)),
                          ]),
                    ),
                    // Badge niveau
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(level.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                    ),
                  ]),
                  const SizedBox(height: 20),

                  // Barre de progression vers prochain palier
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text('${level.name} ? ${nextReward.levelName}',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 11)),
                          const Spacer(),
                          Text('${nextReward.pointsNeeded} pts restants',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                        ]),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: nextReward.progress,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.2),
                            color: Colors.white,
                            minHeight: 6,
                          ),
                        ),
                      ]),
                ]),
              ),
              const SizedBox(height: 20),

              // Récompenses disponibles
              const Text('Récompenses',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              ..._Reward.all
                  .map((r) => _RewardCard(reward: r, userPoints: points)),
              const SizedBox(height: 20),

              // Comment gagner des points
              _InfoCard(),
              const SizedBox(height: 20),

              // Historique
              const Text('Historique',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              _HistoryList(uid: uid),
            ],
          );
        },
      ),
    );
  }

  _LoyaltyLevel _level(int pts) {
    if (pts >= 2000) return _LoyaltyLevel('Platine', Colors.cyan);
    if (pts >= 1000) return _LoyaltyLevel('Or', Colors.amber);
    if (pts >= 500) return _LoyaltyLevel('Argent', Colors.blueGrey);
    return _LoyaltyLevel('Bronze', Colors.brown);
  }

  _NextReward _nextReward(int pts) {
    const milestones = [500, 1000, 2000, 5000];
    for (final m in milestones) {
      if (pts < m) {
        return _NextReward(
          levelName: m >= 2000
              ? 'Platine'
              : m >= 1000
                  ? 'Or'
                  : m >= 500
                      ? 'Argent'
                      : 'Bronze',
          pointsNeeded: m - pts,
          progress: pts / m,
        );
      }
    }
    return _NextReward(levelName: 'MAX', pointsNeeded: 0, progress: 1.0);
  }
}

class _LoyaltyLevel {
  final String name;
  final Color color;
  const _LoyaltyLevel(this.name, this.color);
}

class _NextReward {
  final String levelName;
  final int pointsNeeded;
  final double progress;
  const _NextReward(
      {required this.levelName,
      required this.pointsNeeded,
      required this.progress});
}

// Récompense
class _Reward {
  final String title, desc, icon;
  final int pointsCost;
  final int discountFcfa;
  const _Reward(
      {required this.title,
      required this.desc,
      required this.icon,
      required this.pointsCost,
      required this.discountFcfa});

  static const all = [
    _Reward(
        title: '-500 FCFA',
        desc: 'Sur votre prochaine commande',
        icon: '??',
        pointsCost: 100,
        discountFcfa: 500),
    _Reward(
        title: '-1 000 FCFA',
        desc: 'Sur une commande +3 000 FCFA',
        icon: '??',
        pointsCost: 200,
        discountFcfa: 1000),
    _Reward(
        title: 'Livraison gratuite',
        desc: 'Frais de livraison offerts',
        icon: '??',
        pointsCost: 150,
        discountFcfa: 0),
    _Reward(
        title: '-2 500 FCFA',
        desc: 'Sur une commande +8 000 FCFA',
        icon: '??',
        pointsCost: 500,
        discountFcfa: 2500),
  ];
}

class _RewardCard extends StatelessWidget {
  final _Reward reward;
  final int userPoints;
  const _RewardCard({required this.reward, required this.userPoints});

  @override
  Widget build(BuildContext context) {
    final canRedeem = userPoints >= reward.pointsCost;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: canRedeem
              ? Colors.orange.withValues(alpha: 0.3)
              : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(children: [
        Text(reward.icon, style: const TextStyle(fontSize: 28)),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(reward.title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            Text(reward.desc,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ]),
        ),
        GestureDetector(
          onTap: canRedeem ? () => _showRedeemDialog(context) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: canRedeem ? Colors.orange : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(
                '${reward.pointsCost} pts',
                style: TextStyle(
                    color: canRedeem ? Colors.white : Colors.grey,
                    fontSize: 11,
                    fontWeight: FontWeight.bold),
              ),
              Text(
                canRedeem ? 'Utiliser' : 'Bloquer',
                style: TextStyle(
                    color: canRedeem ? Colors.white70 : Colors.grey.shade400,
                    fontSize: 9),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  void _showRedeemDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Utiliser "${reward.title}" ?'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(reward.icon, style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text(
              'Dépenser ${reward.pointsCost} points pour obtenir ${reward.title}.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10)),
            child: const Text(
              'Le code de réduction sera appliqué automatiquement à votre prochaine commande.',
              style: TextStyle(fontSize: 11, color: Colors.orange),
              textAlign: TextAlign.center,
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _redeem(context);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  Future<void> _redeem(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final db = FirebaseFirestore.instance;
      await db.runTransaction((tx) async {
        final ref = db.collection('users').doc(uid);
        final snap = await tx.get(ref);
        final pts = (snap.data()?['loyaltyPoints'] as num?)?.toInt() ?? 0;
        if (pts < reward.pointsCost) return;
        tx.update(ref, {'loyaltyPoints': pts - reward.pointsCost});
        tx.set(
            db.collection('users').doc(uid).collection('loyalty_history').doc(),
            {
              'type': 'redeem',
              'points': -reward.pointsCost,
              'description': 'échange: ${reward.title}',
              'createdAt': FieldValue.serverTimestamp(),
            });
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${reward.title} appliqué à votre prochain achat !'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (_) {}
  }
}

// Info card
class _InfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.lightbulb_outline, color: Colors.orange, size: 18),
          SizedBox(width: 8),
          Text('Comment gagner des points ?',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.orange)),
        ]),
        const SizedBox(height: 10),
        _InfoRow('??', 'Passez une commande', '1 pt par 100 FCFA'),
        _InfoRow('?', 'Laissez un avis', '+10 pts bonus'),
        _InfoRow('??', 'Parrainez un ami', '+50 pts bonus'),
        _InfoRow('??', 'Anniversaire', '+100 pts offerts'),
      ]),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String emoji, label, value;
  const _InfoRow(this.emoji, this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
          Text(value,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange)),
        ]),
      );
}

// Historique points
class _HistoryList extends StatelessWidget {
  final String uid;
  const _HistoryList({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('loyalty_history')
          .orderBy('createdAt', descending: true)
          .limit(20)
          .snapshots(),
      builder: (_, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Aucun historique de points pour l\'instant.',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
            ),
          );
        }
        return Column(
          children: docs.map((doc) {
            final d = doc.data() as Map<String, dynamic>;
            final points = (d['points'] as num?)?.toInt() ?? 0;
            final desc = d['description'] as String? ?? '';
            final ts = d['createdAt'] as Timestamp?;
            final date = ts != null
                ? DateFormat('dd/MM/yyyy', 'fr_FR').format(ts.toDate())
                : 'é';
            final isEarn = points > 0;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1E1E1E)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: isEarn
                        ? Colors.orange.withValues(alpha: 0.15)
                        : Colors.grey.shade200),
              ),
              child: Row(children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                      color: isEarn
                          ? Colors.orange.withValues(alpha: 0.1)
                          : Colors.purple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(
                      isEarn ? Icons.add_circle_outline : Icons.card_giftcard,
                      color: isEarn ? Colors.orange : Colors.purple,
                      size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(desc,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w500)),
                        Text(date,
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade400)),
                      ]),
                ),
                Text(
                  '${isEarn ? '+' : ''}$points pts',
                  style: TextStyle(
                      color: isEarn ? Colors.orange : Colors.purple,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
              ]),
            );
          }).toList(),
        );
      },
    );
  }
}
