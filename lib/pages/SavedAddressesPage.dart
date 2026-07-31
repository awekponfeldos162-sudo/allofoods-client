// lib/pages/SavedAddressesPage.dart
// Liste des adresses enregistrées par le client (users/{uid}/savedAddresses).
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SavedAddressesPage extends StatelessWidget {
  const SavedAddressesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Adresses enregistrées',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0,
      ),
      body: uid == null
          ? const Center(child: Text('Connectez-vous pour voir vos adresses'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .collection('savedAddresses')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: Colors.orange));
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.location_off_outlined,
                              size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          const Text('Aucune adresse enregistrée',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          Text(
                              'Enregistrez une adresse depuis l\'écran\nde sélection d\'adresse pour la retrouver ici.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.grey.shade500, fontSize: 12)),
                        ]),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    final type = data['type'] as String? ?? 'custom';
                    final icon = type == 'home'
                        ? Icons.home_outlined
                        : type == 'work'
                            ? Icons.business_outlined
                            : Icons.location_on_outlined;
                    final label = data['label'] as String? ??
                        (type == 'home'
                            ? 'Domicile'
                            : type == 'work'
                                ? 'Travail'
                                : 'Adresse');
                    final address = data['address'] as String? ?? '';
                    final phone = data['phone'] as String? ?? '';

                    return Dismissible(
                      key: Key(docs[i].id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                            color: Colors.red.shade400,
                            borderRadius: BorderRadius.circular(16)),
                        child: const Icon(Icons.delete_outline,
                            color: Colors.white),
                      ),
                      onDismissed: (_) => docs[i].reference.delete(),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 6,
                                offset: const Offset(0, 2)),
                          ],
                        ),
                        child: Row(children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10)),
                            child: Icon(icon, color: Colors.orange, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(label,
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87)),
                                  const SizedBox(height: 2),
                                  Text(address,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: isDark
                                              ? Colors.grey.shade400
                                              : Colors.grey.shade600)),
                                  if (phone.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(phone,
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade500)),
                                  ],
                                ]),
                          ),
                        ]),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
