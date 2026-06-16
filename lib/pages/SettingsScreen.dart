// lib/pages/SettingsScreen.dart
// ? Firebase : _logout() ? FirebaseAuth.signOut() (AuthGate redirige auto)
//              _ProfileInfoPage ? Firestore users/{uid}

import 'package:flutter/material.dart';
import 'package:flutter_application_2/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/language_provider.dart';
import '../l10n/app_localizations.dart';
import 'SecurityPage.dart';
import 'SupportPage.dart';
import 'TermsPage.dart';
import 'PrivacyPage.dart';
import 'OrderHistoryPage.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifOrders = true;
  bool _notifPromos = false;

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final t = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(t.settings),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 16),
        itemCount: _sections(lang, t).length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _sections(lang, t)[i],
      ),
    );
  }

  List<Widget> _sections(LanguageProvider lang, AppLocalizations t) => [
        // COMPTE
        _SectionHeader(t.account),
        _SettingsCard(tiles: [
          SettingsTile(
            icon: Icons.person_outline,
            iconColor: Colors.orange,
            title: t.personalInfo,
            subtitle: t.personalInfoSub,
            onTap: () => _goTo(const _ProfileInfoPage()),
          ),
          SettingsTile(
            icon: Icons.location_on_outlined,
            iconColor: Colors.blue,
            title: t.savedAddresses,
            subtitle: t.savedAddressesSub,
            onTap: () => _snack('Bientôt disponible / Coming soon'),
          ),
          SettingsTile(
            icon: Icons.receipt_long_outlined,
            iconColor: Colors.green,
            title: t.orderHistory,
            subtitle: t.orderHistorySub,
            onTap: () => _goTo(const OrderHistoryPage()),
          ),
        ]),

        // SÉCURITÉ
        _SectionHeader(t.security),
        _SettingsCard(tiles: [
          SettingsTile(
            icon: Icons.lock_outline,
            iconColor: Colors.red,
            title: t.changePassword,
            subtitle: t.changePasswordSub,
            onTap: () => _goTo(const SecurityPage()),
          ),
          SettingsTile(
            icon: Icons.fingerprint,
            iconColor: Colors.purple,
            title: t.biometric,
            subtitle: t.biometricSub,
            trailing: Switch(
              value: false,
              activeThumbColor: Colors.orange,
              onChanged: (_) => _snack(t.biometric),
            ),
          ),
        ]),

        // NOTIFICATIONS
        _SectionHeader(t.notifications),
        _SettingsCard(tiles: [
          SettingsTile(
            icon: Icons.notifications_outlined,
            iconColor: Colors.orange,
            title: t.orderNotifs,
            subtitle: t.orderNotifsSub,
            trailing: Switch(
              value: _notifOrders,
              activeThumbColor: Colors.orange,
              onChanged: (v) => setState(() => _notifOrders = v),
            ),
          ),
          SettingsTile(
            icon: Icons.local_offer_outlined,
            iconColor: Colors.pink,
            title: t.promoNotifs,
            subtitle: t.promoNotifsSub,
            trailing: Switch(
              value: _notifPromos,
              activeThumbColor: Colors.orange,
              onChanged: (v) => setState(() => _notifPromos = v),
            ),
          ),
        ]),

        // LOCALISATION
        _SectionHeader(t.localization),
        _SettingsCard(tiles: [
          SettingsTile(
            icon: Icons.language,
            iconColor: Colors.teal,
            title: t.language,
            subtitle: lang.currentName,
            onTap: () => _showLanguagePicker(lang, t),
          ),
          SettingsTile(
            icon: Icons.dark_mode_outlined,
            iconColor: Colors.indigo,
            title: t.darkMode,
            subtitle: t.darkModeSub,
            trailing: Consumer<ThemeProvider>(
              builder: (_, theme, __) => Switch(
                value: theme.isDark,
                activeThumbColor: Colors.orange,
                onChanged: (_) => theme.toggle(),
              ),
            ),
          ),
        ]),

        // ASSISTANCE
        _SectionHeader(t.assistance),
        _SettingsCard(tiles: [
          SettingsTile(
            icon: Icons.help_outline,
            iconColor: Colors.orange,
            title: t.helpCenter,
            subtitle: t.helpCenterSub,
            onTap: () => _goTo(const SupportPage()),
          ),
          SettingsTile(
            icon: Icons.bug_report_outlined,
            iconColor: Colors.red,
            title: t.reportIssue,
            subtitle: t.reportIssueSub,
            onTap: () => _goTo(const SupportPage()),
          ),
          SettingsTile(
            icon: Icons.wifi_outlined,
            iconColor: Colors.green,
            title: t.checkConnection,
            subtitle: t.checkConnectionSub,
            onTap: () => _checkConnectivity(),
          ),
        ]),

        // LÉGAL
        _SectionHeader(t.legal),
        _SettingsCard(tiles: [
          SettingsTile(
            icon: Icons.privacy_tip_outlined,
            iconColor: Colors.grey,
            title: t.privacyPolicy,
            onTap: () => _goTo(const PrivacyPage()),
          ),
          SettingsTile(
            icon: Icons.description_outlined,
            iconColor: Colors.grey,
            title: t.termsOfUse,
            onTap: () => _goTo(const TermsPage()),
          ),
          SettingsTile(
            icon: Icons.info_outline,
            iconColor: Colors.grey,
            title: t.appVersion,
            subtitle: 'allofoods v1.0.0 · Cotonou, Bénin',
          ),
        ]),

        // DÉCONNEXION
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ElevatedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            label: Text(t.signOut,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade50,
              foregroundColor: Colors.red,
              elevation: 0,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: Colors.red.shade200)),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ];

  void _goTo(Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red.shade600 : Colors.black87,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
  }

  Future<void> _checkConnectivity() async {
    _snack('Vérification en cours...');
    try {
      final snap = await FirebaseFirestore.instance
          .collection('restaurants')
          .limit(1)
          .get();
      _snack(snap.docs.isNotEmpty
          ? '? Connexion Firebase OK !'
          : '?? Firebase accessible mais vide');
    } catch (_) {
      _snack('? Impossible de joindre Firebase', error: true);
    }
  }

  void _showLanguagePicker(LanguageProvider lang, AppLocalizations t) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2))),
          Padding(
              padding: const EdgeInsets.all(16),
              child: Text(t.chooseLanguage,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold))),
          ...LanguageProvider.supported.entries.map((e) => ListTile(
                leading: Text(e.value.split('  ')[0],
                    style: const TextStyle(fontSize: 24)),
                title: Text(e.value.split('  ')[1]),
                trailing: lang.locale.languageCode == e.key
                    ? const Icon(Icons.check, color: Colors.orange)
                    : null,
                onTap: () {
                  lang.setLocale(e.key);
                  Navigator.pop(context);
                  _snack(e.value.split('  ')[1]);
                },
              )),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  // DéCONNEXION é Firebase Auth
  // AuthGate détecte authStateChanges() ? redirige automatiquement
  Future<void> _logout() async {
    final t = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
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
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text(t.disconnect,
                  style: const TextStyle(color: Colors.white))),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
    }
  }
}

// PAGE INFOS PERSONNELLES é Firestore
class _ProfileInfoPage extends StatefulWidget {
  const _ProfileInfoPage();
  @override
  State<_ProfileInfoPage> createState() => _ProfileInfoPageState();
}

class _ProfileInfoPageState extends State<_ProfileInfoPage> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  // Charge depuis Firestore users/{uid}
  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    final snap =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (mounted && snap.exists) {
      final d = snap.data()!;
      _nameCtrl.text = d['name'] as String? ?? '';
      _phoneCtrl.text = d['phone'] as String? ?? '';
    }
    if (mounted) setState(() => _loading = false);
  }

  // Sauvegarde dans Firestore + Firebase Auth displayName
  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    if (name.isEmpty) {
      _snack('Le nom ne peut pas étre vide', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await Future.wait([
          FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .update({'name': name, 'phone': phone}),
          FirebaseAuth.instance.currentUser!.updateDisplayName(name),
        ]);
      }
      if (!mounted) return;
      _snack('? Profil mis à jour !');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) _snack('Erreur : $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red : Colors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('Informations personnelles'),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          foregroundColor: Colors.black87,
          elevation: 0),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                _Field(
                    ctrl: _nameCtrl,
                    label: 'Nom complet',
                    icon: Icons.person_outline),
                const SizedBox(height: 16),
                _Field(
                    ctrl: _phoneCtrl,
                    label: 'Téléphone',
                    icon: Icons.phone_outlined,
                    keyboard: TextInputType.phone),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Enregistrer',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ]),
            ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final TextInputType keyboard;
  const _Field(
      {required this.ctrl,
      required this.label,
      required this.icon,
      this.keyboard = TextInputType.text});

  @override
  Widget build(BuildContext context) => TextField(
        controller: ctrl,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.orange),
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.orange, width: 2)),
        ),
      );
}

// WIDGETS RéUTILISABLES
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
        child: Text(title.toUpperCase(),
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade500,
                letterSpacing: 1.2)),
      );
}

class _SettingsCard extends StatelessWidget {
  final List<SettingsTile> tiles;
  const _SettingsCard({required this.tiles});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1E1E1E)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ]),
        child: Column(
          children: tiles.asMap().entries.map((e) {
            final isLast = e.key == tiles.length - 1;
            return Column(children: [
              e.value,
              if (!isLast)
                Divider(height: 1, indent: 56, color: Colors.grey.shade100),
            ]);
          }).toList(),
        ),
      );
}

class SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const SettingsTile({
    super.key,
    required this.icon,
    this.iconColor = Colors.orange,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: subtitle != null
            ? Text(subtitle!,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500))
            : null,
        trailing: trailing ??
            (onTap != null
                ? Icon(Icons.chevron_right,
                    color: Colors.grey.shade400, size: 20)
                : null),
      );
}
