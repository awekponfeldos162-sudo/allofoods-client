// lib/pages/ProfilPage.dart
// ✅ Affiche toutes les infos depuis Firestore
// Upload photo Supabase Storage

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../repositories/user_repository.dart';
import 'OrderHistoryPage.dart';
import 'LoyaltyPage.dart';
import '../widgets/image_viewer.dart';
import '../l10n/app_localizations.dart';

class ProfilPage extends StatefulWidget {
  const ProfilPage({super.key});
  @override
  State<ProfilPage> createState() => _ProfilPageState();
}

class _ProfilPageState extends State<ProfilPage> {
  final _repo = UserRepository();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _imgLoading = false;
  bool _editing = false;
  String _email = '';
  String _memberCode = '';
  String? _imageUrl;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  // CHARGER — Firestore + fallback Firebase Auth
  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      final fbUser = FirebaseAuth.instance.currentUser;
      final data = await _repo.loadProfile();
      if (!mounted) return;

      setState(() {
        _nameCtrl.text = (data['name'] as String?)?.isNotEmpty == true
            ? data['name'] as String
            : fbUser?.displayName ?? '';
        _phoneCtrl.text = data['phone'] as String? ?? '';
        _email = (data['email'] as String?)?.isNotEmpty == true
            ? data['email'] as String
            : fbUser?.email ?? '';
        _imageUrl = (data['imageUrl'] as String?)?.isNotEmpty == true
            ? data['imageUrl'] as String
            : fbUser?.photoURL;
        _memberCode = data['memberCode'] as String? ?? '';
        _loading = false;
      });
    } catch (_) {
      final fbUser = FirebaseAuth.instance.currentUser;
      if (mounted)
        setState(() {
          _nameCtrl.text = fbUser?.displayName ?? '';
          _email = fbUser?.email ?? '';
          _imageUrl = fbUser?.photoURL;
          _loading = false;
        });
    }
  }

  // SAUVEGARDER NOM + TÉLÉPHONE
  Future<void> _saveProfile() async {
    final t = AppLocalizations.of(context);
    if (_nameCtrl.text.trim().isEmpty) {
      _snack(t.nameCannotBeEmpty, error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await _repo.updateProfile(
          name: _nameCtrl.text, phone: _phoneCtrl.text, email: _email);
      if (!mounted) return;
      setState(() {
        _editing = false;
        _saving = false;
      });
      _snack(t.profileUpdated);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        _snack(AppLocalizations.of(context).updateError, error: true);
      }
    }
  }

  // PHOTO — Cloudinary
  Future<void> _pickPhoto(ImageSource source) async {
    final xfile = await ImagePicker().pickImage(
        source: source, maxWidth: 800, maxHeight: 800, imageQuality: 75);
    if (xfile == null) return;

    setState(() => _imgLoading = true);

    try {
      final bytes = await xfile.readAsBytes();
      final url = await _repo.updatePhoto(bytes);
      if (!mounted) return;
      if (url != null) {
        setState(() {
          _imageUrl = url;
          _imgLoading = false;
        });
        _snack(AppLocalizations.of(context).photoUpdated);
      } else {
        setState(() => _imgLoading = false);
        _snack(AppLocalizations.of(context).photoUploadError, error: true);
      }
    } catch (_) {
      if (mounted) setState(() => _imgLoading = false);
    }
  }

  Future<void> _deletePhoto() async {
    final t = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(t.deletePhotoTitle),
        content: Text(t.irreversibleAction),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(t.cancel)),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: Text(t.deleteLabel,
                  style: const TextStyle(color: Colors.white))),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _imgLoading = true);
    await _repo.deletePhoto();
    if (mounted)
      setState(() {
        _imageUrl = null;
        _imgLoading = false;
      });
    _snack(t.photoDeleted);
  }

  void _showPhotoSheet() {
    final t = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: SafeArea(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2))),
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(t.profilePhoto,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
          ListTile(
            leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.photo_library_outlined,
                    color: Colors.orange)),
            title: Text(t.chooseFromGallery),
            onTap: () {
              Navigator.pop(context);
              _pickPhoto(ImageSource.gallery);
            },
          ),
          ListTile(
            leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10)),
                child:
                    const Icon(Icons.camera_alt_outlined, color: Colors.blue)),
            title: Text(t.takePhoto),
            onTap: () {
              Navigator.pop(context);
              _pickPhoto(ImageSource.camera);
            },
          ),
          if (_imageUrl != null)
            ListTile(
              leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.delete_outline, color: Colors.red)),
              title: Text(t.deletePhoto,
                  style: const TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deletePhoto();
              },
            ),
          const SizedBox(height: 12),
        ])),
      ),
    );
  }

  Future<void> _logout() async {
    final t = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(t.signOutConfirmTitle),
        content: Text(t.signOutConfirmBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(t.cancel)),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: Text(t.disconnect,
                  style: const TextStyle(color: Colors.white))),
        ],
      ),
    );
    if (ok == true) await FirebaseAuth.instance.signOut();
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red.shade600 : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
  }

  // BUILD
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.orange));
    }

    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: RefreshIndicator(
        color: Colors.orange,
        onRefresh: _loadProfile,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          children: [
            // Header compact
            _buildHeader(),
            const SizedBox(height: 20),

            _Card(
              title: AppLocalizations.of(context).personalInfo,
              icon: Icons.person_outline,
              child: Column(children: [
                _InfoTile(
                  icon: Icons.badge_outlined,
                  label: AppLocalizations.of(context).fullName,
                  ctrl: _nameCtrl,
                  editable: _editing,
                ),
                _divider(),
                _ReadTile(
                  icon: Icons.email_outlined,
                  label: AppLocalizations.of(context).email,
                  value: _email,
                  locked: true,
                ),
                _divider(),
                _InfoTile(
                  icon: Icons.phone_android,
                  label: AppLocalizations.of(context).phone,
                  ctrl: _phoneCtrl,
                  editable: _editing,
                  keyboard: TextInputType.phone,
                ),
                if (_memberCode.isNotEmpty) ...[
                  _divider(),
                  _ReadTile(
                    icon: Icons.confirmation_number_outlined,
                    label: AppLocalizations.of(context).memberCode,
                    value: _memberCode,
                    locked: true,
                    badge: true,
                  ),
                ],
              ]),
            ),
            const SizedBox(height: 16),

            _Card(
              title: AppLocalizations.of(context).myAccount,
              icon: Icons.dashboard_outlined,
              child: Builder(builder: (ctx) {
                final t = AppLocalizations.of(ctx);
                return Column(children: [
                  _Shortcut(
                      icon: Icons.settings_outlined,
                      color: Colors.orange,
                      label: t.settingsSecurity,
                      onTap: () => Navigator.pushNamed(ctx, '/settings')),
                  _divider(),
                  _Shortcut(
                      icon: Icons.notifications_outlined,
                      color: Colors.blue,
                      label: t.notifications,
                      onTap: () =>
                          Navigator.pushNamed(ctx, '/notifications')),
                  _divider(),
                  _Shortcut(
                      icon: Icons.receipt_long_outlined,
                      color: Colors.green,
                      label: t.orderHistory,
                      onTap: () => Navigator.push(
                          ctx,
                          MaterialPageRoute(
                              builder: (_) => const OrderHistoryPage()))),
                  _divider(),
                  _LoyaltyShortcut(
                      uid: FirebaseAuth.instance.currentUser?.uid ?? ''),
                ]);
              }),
            ),
            const SizedBox(height: 24),

            ElevatedButton.icon(
              onPressed: _saving
                  ? null
                  : () {
                      if (_editing)
                        _saveProfile();
                      else
                        setState(() => _editing = true);
                    },
              style: ElevatedButton.styleFrom(
                  backgroundColor: _editing ? Colors.green : Colors.orange,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26))),
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Icon(_editing ? Icons.save_outlined : Icons.edit_outlined),
              label: Builder(builder: (ctx) {
                final t = AppLocalizations.of(ctx);
                return Text(
                    _saving ? t.saving : _editing ? t.save : t.changeMyProfile,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold));
              }),
            ),

            if (_editing) ...[
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () {
                  setState(() => _editing = false);
                  _loadProfile();
                },
                style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey,
                    side: const BorderSide(color: Colors.grey),
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26))),
                child: Text(AppLocalizations.of(context).cancel),
              ),
            ],

            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _logout,
              style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26))),
              icon: const Icon(Icons.logout),
              label: Text(AppLocalizations.of(context).logout,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  // Header
  Widget _buildHeader() {
    final ImageProvider? img = (_imageUrl != null && _imageUrl!.isNotEmpty)
        ? NetworkImage(_imageUrl!)
        : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: Row(children: [
        // Avatar — tap pour voir en plein écran, badge caméra pour éditer
        Stack(alignment: Alignment.bottomRight, children: [
          GestureDetector(
            onTap: () {
              if (_imageUrl != null && _imageUrl!.isNotEmpty) {
                ImageViewer.open(context, _imageUrl!, 'profil_client');
              }
            },
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade300, width: 2.5)),
              child: ClipOval(
                child: _imgLoading
                    ? const CircularProgressIndicator(
                        color: Colors.orange, strokeWidth: 2)
                    : img != null
                        ? Image(
                            image: img,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                                Icons.person,
                                size: 35,
                                color: Colors.black54))
                        : Container(
                            color: Colors.grey.shade100,
                            child: const Icon(Icons.person,
                                size: 35, color: Colors.grey)),
              ),
            ),
          ),
          // Badge caméra — ouvre la feuille d'édition
          GestureDetector(
            onTap: _showPhotoSheet,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                  color: Colors.black87,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5)),
              child:
                  const Icon(Icons.camera_alt, color: Colors.white, size: 13),
            ),
          ),
        ]),
        const SizedBox(width: 14),
        // Infos texte
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_nameCtrl.text.isNotEmpty ? _nameCtrl.text : AppLocalizations.of(context).userFallback,
              style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 17,
                  fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 3),
          Text(_email,
              style: const TextStyle(color: Colors.black54, fontSize: 12),
              overflow: TextOverflow.ellipsis),
          if (_phoneCtrl.text.isNotEmpty) ...[
            const SizedBox(height: 3),
            Row(children: [
              const Icon(Icons.phone, color: Colors.black54, size: 12),
              const SizedBox(width: 4),
              Text(_phoneCtrl.text,
                  style: const TextStyle(
                      color: Colors.black54, fontSize: 12)),
            ]),
          ],
          if (_memberCode.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade300)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.verified_outlined,
                    color: Colors.black54, size: 12),
                const SizedBox(width: 4),
                Text(_memberCode,
                    style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8)),
              ]),
            ),
          ],
        ])),
      ]),
    );
  }

  Widget _divider() =>
      Divider(height: 1, color: Colors.grey.shade100, indent: 36);
}

// WIDGETS
class _Card extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _Card({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 3))
          ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: Colors.black54, size: 17),
          const SizedBox(width: 7),
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ]),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final TextEditingController ctrl;
  final bool editable;
  final TextInputType keyboard;
  const _InfoTile(
      {required this.icon,
      required this.label,
      required this.ctrl,
      required this.editable,
      this.keyboard = TextInputType.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Icon(icon, color: Colors.black54, size: 19),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                editable
                    ? TextField(
                        controller: ctrl,
                        keyboardType: keyboard,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500),
                        decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 10),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300)),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                    color: Colors.black87, width: 2)),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300))))
                    : Text(ctrl.text.isNotEmpty ? ctrl.text : '—',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500)),
              ])),
          if (editable)
            const Icon(Icons.edit, size: 13, color: Colors.black54),
        ]),
      );
}

class _ReadTile extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final bool locked, badge;
  const _ReadTile(
      {required this.icon,
      required this.label,
      required this.value,
      this.locked = false,
      this.badge = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Icon(icon,
              color: locked ? Colors.grey.shade400 : Colors.orange, size: 19),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                badge
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300)),
                        child: Text(value,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                                letterSpacing: 1)))
                    : Text(value.isNotEmpty ? value : '—',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: locked
                                ? Colors.grey.shade600
                                : Colors.black87)),
              ])),
          if (locked)
            Icon(Icons.lock_outline, size: 13, color: Colors.grey.shade300),
        ]),
      );
}

class _Shortcut extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  const _Shortcut(
      {required this.icon,
      required this.color,
      required this.label,
      required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(children: [
            Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 19)),
            const SizedBox(width: 12),
            Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500))),
            Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 19),
          ]),
        ),
      );
}

// Points fidélité en direct (widget pour ProfilPage)
class _LoyaltyShortcut extends StatelessWidget {
  final String uid;
  const _LoyaltyShortcut({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream:
          FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (_, snap) {
        final data = snap.data?.data() as Map<String, dynamic>? ?? {};
        final points = (data['loyaltyPoints'] as num?)?.toInt() ?? 0;
        return InkWell(
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const LoyaltyPage())),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(children: [
              Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.star_outline,
                      color: Colors.amber, size: 19)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppLocalizations.of(context).loyaltyProgram,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500)),
                      Text(AppLocalizations.of(context).pointsAccumulated(points),
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500)),
                    ]),
              ),
              Icon(Icons.chevron_right,
                  color: Colors.grey.shade400, size: 19),
            ]),
          ),
        );
      },
    );
  }
}
