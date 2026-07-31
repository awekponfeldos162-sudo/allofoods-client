// lib/pages/AdressesPage.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'adressePage.dart';

class AdressesPage extends StatefulWidget {
  const AdressesPage({super.key});
  @override
  State<AdressesPage> createState() => _AdressesPageState();
}

class _AdressesPageState extends State<AdressesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _searchCtrl.addListener(
        () => setState(() => _query = _searchCtrl.text.toLowerCase().trim()));
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference? get _col {
    final uid = _uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('savedAddresses');
  }

  void _openPicker({String? prefillType}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdressePage(prefillType: prefillType),
      ),
    );
  }

  void _showCreateModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text('Créer',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 20),
              _SheetOption(
                icon: Icons.add_location_alt_outlined,
                label: 'Nouvelle adresse',
                onTap: () {
                  Navigator.pop(context);
                  _openPicker();
                },
              ),
              const SizedBox(height: 12),
              _SheetOption(
                icon: Icons.near_me_outlined,
                label: 'Demande d\'adresse',
                onTap: () {
                  Navigator.pop(context);
                  _tabCtrl.animateTo(1);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddressSheet(Map<String, dynamic> data, String docId) {
    final label = data['label'] as String? ?? 'Adresse';
    final address = data['address'] as String? ?? '';
    final phone = data['phone'] as String? ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Close button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close,
                        size: 18, color: isDark ? Colors.white : Colors.black87),
                  ),
                ),
              ),
            ),
            // Header info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              child: Column(
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87)),
                  const SizedBox(height: 6),
                  Text(
                    [address, if (phone.isNotEmpty) 'Tel. $phone'].join('\n'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Actions row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ActionCircle(
                    icon: Icons.edit_outlined,
                    label: 'Modifier',
                    onTap: () {
                      Navigator.pop(ctx);
                      _openPicker(prefillType: data['type'] as String?);
                    }),
                _ActionCircle(
                    icon: Icons.share_outlined,
                    label: 'Partager',
                    onTap: () => Navigator.pop(ctx)),
                _ActionCircle(
                    icon: Icons.delete_outline,
                    label: 'Supprimer',
                    onTap: () {
                      Navigator.pop(ctx);
                      _deleteAddress(docId);
                    }),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(height: 1),
            ),
            // Options list
            _OptionTile(
              icon: Icons.location_on_outlined,
              label: 'Se rendre à cette adresse',
              onTap: () => Navigator.pop(ctx),
            ),
            _OptionTile(
              icon: Icons.restaurant_menu_outlined,
              label: 'Faire livrer - Food à cette adresse',
              onTap: () => Navigator.pop(ctx),
            ),
            _OptionTile(
              icon: Icons.shopping_bag_outlined,
              label: 'Faire livrer - Shopping à cette adresse',
              onTap: () => Navigator.pop(ctx),
            ),
            _OptionTile(
              icon: Icons.inventory_2_outlined,
              label: 'Envoyer ou recevoir un colis',
              onTap: () => Navigator.pop(ctx),
            ),
            _OptionTile(
              icon: Icons.mobile_friendly_outlined,
              label: 'Acheter du crédit à ce contact',
              onTap: () => Navigator.pop(ctx),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteAddress(String docId) async {
    await _col?.doc(docId).delete();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF121212) : Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
        elevation: 0,
        titleSpacing: 20,
        automaticallyImplyLeading: false,
        title: Text('Adresses',
            style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 22)),
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: Colors.orange,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.orange,
          indicatorWeight: 2.5,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Enregistrées'),
            Tab(text: 'Demandes en attente'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _SavedTab(
            uid: _uid,
            query: _query,
            searchCtrl: _searchCtrl,
            onAddressTap: _showAddressSheet,
            onShortcutTap: _openPicker,
          ),
          const _PendingTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateModal,
        backgroundColor: Colors.orange,
        elevation: 4,
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }
}

// ── Tab Enregistrées ─────────────────────────────────────────────────────────

class _SavedTab extends StatelessWidget {
  final String? uid;
  final String query;
  final TextEditingController searchCtrl;
  final void Function(Map<String, dynamic>, String) onAddressTap;
  final void Function({String? prefillType}) onShortcutTap;

  const _SavedTab({
    required this.uid,
    required this.query,
    required this.searchCtrl,
    required this.onAddressTap,
    required this.onShortcutTap,
  });

  @override
  Widget build(BuildContext context) {
    if (uid == null) {
      return const Center(child: Text('Connectez-vous pour voir vos adresses.'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('savedAddresses')
          .orderBy('createdAt')
          .snapshots(),
      builder: (ctx, snap) {
        final docs = snap.data?.docs ?? [];

        final homeDoc = docs
            .where((d) => (d.data() as Map)['type'] == 'home')
            .firstOrNull;
        final workDoc = docs
            .where((d) => (d.data() as Map)['type'] == 'work')
            .firstOrNull;
        final customs = docs.where((d) {
          final t = (d.data() as Map)['type'] as String? ?? 'custom';
          if (t == 'home' || t == 'work') return false;
          if (query.isEmpty) return true;
          final data = d.data() as Map;
          final lbl = (data['label'] as String? ?? '').toLowerCase();
          final adr = (data['address'] as String? ?? '').toLowerCase();
          return lbl.contains(query) || adr.contains(query);
        }).toList();

        final isDark = Theme.of(context).brightness == Brightness.dark;
        final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            // Barre recherche
            Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: searchCtrl,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  hintText: 'Rechercher une adresse',
                  hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
                  prefixIcon: Icon(Icons.search,
                      color: isDark ? Colors.grey.shade400 : Colors.black54,
                      size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Card shortcuts Domicile + Travail
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  _ShortcutTile(
                    icon: Icons.home_outlined,
                    label: 'Domicile',
                    subtitle: homeDoc != null
                        ? (homeDoc.data() as Map)['address'] as String? ?? ''
                        : 'Ajouter une adresse pour ce lieu',
                    isSet: homeDoc != null,
                    onTap: homeDoc != null
                        ? () => onAddressTap(
                            homeDoc.data() as Map<String, dynamic>, homeDoc.id)
                        : () => onShortcutTap(prefillType: 'home'),
                  ),
                  Divider(
                      height: 1,
                      indent: 56,
                      color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                  _ShortcutTile(
                    icon: Icons.work_outline,
                    label: 'Travail',
                    subtitle: workDoc != null
                        ? (workDoc.data() as Map)['address'] as String? ?? ''
                        : 'Ajouter une adresse pour ce lieu',
                    isSet: workDoc != null,
                    onTap: workDoc != null
                        ? () => onAddressTap(
                            workDoc.data() as Map<String, dynamic>, workDoc.id)
                        : () => onShortcutTap(prefillType: 'work'),
                  ),
                ],
              ),
            ),

            // Autres adresses enregistrées
            if (customs.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < customs.length; i++) ...[
                      _ShortcutTile(
                        icon: Icons.location_on_outlined,
                        label: (customs[i].data()
                            as Map)['label'] as String? ?? 'Adresse',
                        subtitle: (customs[i].data()
                            as Map)['address'] as String? ?? '',
                        isSet: true,
                        onTap: () => onAddressTap(
                            customs[i].data() as Map<String, dynamic>,
                            customs[i].id),
                      ),
                      if (i < customs.length - 1)
                        Divider(
                            height: 1,
                            indent: 56,
                            color: isDark
                                ? Colors.grey.shade800
                                : Colors.grey.shade200),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

// ── Tab Demandes en attente ───────────────────────────────────────────────────

class _PendingTab extends StatelessWidget {
  const _PendingTab();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 44,
                backgroundColor: Colors.grey.shade200,
                child: Icon(Icons.person_outlined,
                    size: 44, color: Colors.grey.shade400),
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.priority_high,
                      size: 15, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Aucune demande en attente',
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            'Toutes vos demandes d\'adresse en attente\napparaîtront ici.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

// ── Widgets helpers ───────────────────────────────────────────────────────────

class _ShortcutTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool isSet;
  final VoidCallback onTap;

  const _ShortcutTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.isSet,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      leading: Icon(icon, size: 22, color: textColor),
      title: Text(label,
          style: TextStyle(
              fontWeight: FontWeight.w600, fontSize: 15, color: textColor)),
      subtitle: Text(
        subtitle,
        style: TextStyle(
            fontSize: 12,
            color: isSet
                ? (isDark ? Colors.grey.shade400 : Colors.black54)
                : Colors.grey.shade500),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing:
          const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
      onTap: onTap,
    );
  }
}

class _SheetOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SheetOption(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: textColor),
            const SizedBox(width: 14),
            Text(label,
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w500, color: textColor)),
          ],
        ),
      ),
    );
  }
}

class _ActionCircle extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionCircle(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 22, color: textColor),
          ),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 12, color: textColor)),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _OptionTile(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      leading: Icon(icon,
          size: 20, color: isDark ? Colors.grey.shade400 : Colors.black54),
      title: Text(label,
          style: TextStyle(
              fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
      trailing:
          const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
      onTap: onTap,
    );
  }
}
