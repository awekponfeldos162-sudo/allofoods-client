// lib/pages/NotificationsPage.dart
// ? Firestore temps réel é users/{uid}/notifications

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  String _timeAgo(Timestamp? ts) {
    if (ts == null) return '';
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 1) return 'é l\'instant';
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours} h';
    return DateFormat('dd/MM/yyyy à HH:mm').format(ts.toDate());
  }

  IconData _icon(String type) {
    switch (type) {
      case 'order':
        return Icons.receipt_long_outlined;
      case 'promo':
        return Icons.local_offer_outlined;
      case 'delivery':
        return Icons.delivery_dining;
      case 'payment':
        return Icons.mobile_friendly;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _iconColor(String type) {
    switch (type) {
      case 'order':
        return Colors.orange;
      case 'promo':
        return Colors.pink;
      case 'delivery':
        return Colors.purple;
      case 'payment':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }

  Future<void> _markAllRead(String uid) async {
    final batch = FirebaseFirestore.instance.batch();
    final snaps = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .get();
    for (final doc in snaps.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  Future<void> _deleteAll(String uid) async {
    final batch = FirebaseFirestore.instance.batch();
    final snaps = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .get();
    for (final doc in snaps.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).notifications,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).textTheme.bodyLarge?.color,
        elevation: 0,
        bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1), child: Divider(height: 1)),
        actions: uid == null
            ? []
            : [
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (v) {
                    if (v == 'read') _markAllRead(uid);
                    if (v == 'clear') _deleteAll(uid);
                  },
                  itemBuilder: (ctx) {
                    final t = AppLocalizations.of(ctx);
                    return [
                      PopupMenuItem(
                          value: 'read',
                          child: Row(children: [
                            const Icon(Icons.done_all, size: 18, color: Colors.orange),
                            const SizedBox(width: 8),
                            Text(t.markAllRead),
                          ])),
                      PopupMenuItem(
                          value: 'clear',
                          child: Row(children: [
                            const Icon(Icons.delete_outline,
                                size: 18, color: Colors.red),
                            const SizedBox(width: 8),
                            Text(t.deleteAll),
                          ])),
                    ];
                  },
                ),
              ],
      ),
      body: uid == null
          ? Center(
              child: Text(AppLocalizations.of(context).loginToSeeNotifications))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .collection('notifications')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: Colors.orange));
                }

                final docs = snap.data?.docs ?? [];

                if (docs.isEmpty) return _EmptyState();

                // Séparer lues / non lues
                final unread = docs
                    .where((d) => (d.data() as Map)['isRead'] != true)
                    .toList();
                final read = docs
                    .where((d) => (d.data() as Map)['isRead'] == true)
                    .toList();

                return ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    if (unread.isNotEmpty) ...[
                      _SectionLabel(AppLocalizations.of(context).newNotifs(unread.length)),
                      ...unread.map((d) => _NotifCard(
                            doc: d,
                            uid: uid,
                            timeAgo: _timeAgo,
                            icon: _icon,
                            iconColor: _iconColor,
                          )),
                    ],
                    if (read.isNotEmpty) ...[
                      _SectionLabel(AppLocalizations.of(context).readNotifs),
                      ...read.map((d) => _NotifCard(
                            doc: d,
                            uid: uid,
                            timeAgo: _timeAgo,
                            icon: _icon,
                            iconColor: _iconColor,
                          )),
                    ],
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),
    );
  }
}

// Carte notification
class _NotifCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final String uid;
  final String Function(Timestamp?) timeAgo;
  final IconData Function(String) icon;
  final Color Function(String) iconColor;

  const _NotifCard({
    required this.doc,
    required this.uid,
    required this.timeAgo,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final isRead = data['isRead'] as bool? ?? false;
    final type = data['type'] as String? ?? 'info';
    final ts = data['createdAt'] as Timestamp?;
    final color = iconColor(type);

    return Dismissible(
      key: Key(doc.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
            color: Colors.red.shade400,
            borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 24),
      ),
      onDismissed: (_) => doc.reference.delete(),
      child: GestureDetector(
        onTap: () {
          if (!isRead) doc.reference.update({'isRead': true});
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => _NotifDetailPage(data: data),
            ),
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isRead ? Colors.white : Colors.orange.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: isRead ? Colors.grey.shade100 : Colors.orange.shade200,
                width: isRead ? 1 : 1.5),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon(type), color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(data['title'] as String? ?? '',
                            style: TextStyle(
                                fontWeight:
                                    isRead ? FontWeight.w500 : FontWeight.bold,
                                fontSize: 13)),
                      ),
                      if (!isRead)
                        Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                                color: Colors.orange, shape: BoxShape.circle)),
                    ]),
                    const SizedBox(height: 4),
                    Text(data['message'] as String? ?? '',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Text(timeAgo(ts),
                        style: TextStyle(
                            fontSize: 10, color: Colors.grey.shade400)),
                  ]),
            ),
            // Miniature si imageUrl défini
            if ((data['imageUrl'] as String?)?.isNotEmpty == true) ...[
              const SizedBox(width: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  data['imageUrl'] as String,
                  width: 58,
                  height: 58,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
        child: Text(label.toUpperCase(),
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade500,
                letterSpacing: 1.2)),
      );
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
                color: Colors.orange.shade50, shape: BoxShape.circle),
            child: Icon(Icons.notifications_none_outlined,
                size: 56, color: Colors.orange.shade300),
          ),
          const SizedBox(height: 20),
          Text(AppLocalizations.of(context).noNotifications,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(AppLocalizations.of(context).noNotificationsHint,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
        ]),
      );
}

// PAGE DÉTAIL NOTIFICATION
class _NotifDetailPage extends StatelessWidget {
  final Map<String, dynamic> data;
  const _NotifDetailPage({required this.data});

  @override
  Widget build(BuildContext context) {
    final title = data['title'] as String? ?? '';
    final message = data['message'] as String? ?? '';
    final imageUrl = data['imageUrl'] as String? ?? '';
    final link = data['link'] as String? ?? '';
    final ts = data['createdAt'] as Timestamp?;
    final date = ts != null
        ? DateFormat('dd MMM yyyy à HH:mm', 'fr').format(ts.toDate())
        : '';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        title: Text(AppLocalizations.of(context).notifications,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1), child: Divider(height: 1)),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl.isNotEmpty)
              Image.network(
                imageUrl,
                width: double.infinity,
                height: 220,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : Container(
                        height: 220,
                        color: Colors.orange.shade50,
                        child: const Center(
                            child: CircularProgressIndicator(
                                color: Colors.orange, strokeWidth: 2))),
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (date.isNotEmpty) ...[
                    Text(date,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade400)),
                    const SizedBox(height: 10),
                  ],
                  Text(title,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text(message,
                      style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey.shade700,
                          height: 1.6)),
                  if (link.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final uri = Uri.tryParse(link);
                          if (uri != null) await launchUrl(uri);
                        },
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: Text(AppLocalizations.of(context).followLink,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
