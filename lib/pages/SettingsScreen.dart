// lib/pages/SettingsScreen.dart
// ✓ Firebase : _logout() — FirebaseAuth.signOut() (AuthGate redirige auto)
//              _ProfileInfoPage — Firestore users/{uid}

import 'package:flutter/material.dart';
import 'package:flutter_application_2/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/language_provider.dart';
import '../l10n/app_localizations.dart';
import '../services/biometric_service.dart';
import 'SecurityPage.dart';
import 'SupportPage.dart';
import 'PrivacyPage.dart';
import 'OrderHistoryPage.dart';
import 'SavedAddressesPage.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _kNotifOrdersKey = 'notif_orders_enabled';
  static const _kNotifPromosKey = 'notif_promos_enabled';

  bool _notifOrders = true;
  bool _notifPromos = false;
  bool _biometricEnabled = false;
  bool _biometricSupported = false;
  bool _loadingPrefs = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final biometricSupported = await BiometricService.isDeviceSupported();
    final biometricEnabled = await BiometricService.isEnabled();
    if (!mounted) return;
    setState(() {
      _notifOrders = prefs.getBool(_kNotifOrdersKey) ?? true;
      _notifPromos = prefs.getBool(_kNotifPromosKey) ?? false;
      _biometricSupported = biometricSupported;
      _biometricEnabled = biometricEnabled && biometricSupported;
      _loadingPrefs = false;
    });
  }

  Future<void> _toggleOrderNotifs(bool value) async {
    setState(() => _notifOrders = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kNotifOrdersKey, value);
  }

  // Contrôle réel : abonne/désabonne le topic FCM 'promotions' (pas
  // seulement un booléen local qui n'avait aucun effet auparavant).
  Future<void> _togglePromoNotifs(bool value) async {
    setState(() => _notifPromos = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kNotifPromosKey, value);
    try {
      if (value) {
        await FirebaseMessaging.instance.subscribeToTopic('promotions');
      } else {
        await FirebaseMessaging.instance.unsubscribeFromTopic('promotions');
      }
    } catch (_) {}
  }

  Future<void> _toggleBiometric(bool value) async {
    if (!_biometricSupported) {
      _snack(
          'Aucune biométrie configurée sur cet appareil — activez-la dans les paramètres du téléphone.',
          error: true);
      return;
    }
    if (value) {
      final ok = await BiometricService.authenticate(
          reason: 'Confirmez votre identité pour activer le déverrouillage biométrique');
      if (!ok) {
        if (mounted) _snack('Authentification annulée ou échouée', error: true);
        return;
      }
    }
    await BiometricService.setEnabled(value);
    if (mounted) setState(() => _biometricEnabled = value);
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final t = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(t.settings),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: isDark ? Colors.white : Colors.black87,
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
            onTap: () => _goTo(const SavedAddressesPage()),
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
            subtitle: _biometricSupported
                ? t.biometricSub
                : 'Non disponible sur cet appareil',
            trailing: Switch(
              value: _biometricEnabled,
              activeThumbColor: Colors.orange,
              onChanged: _loadingPrefs ? null : _toggleBiometric,
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
              onChanged: _loadingPrefs ? null : _toggleOrderNotifs,
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
              onChanged: _loadingPrefs ? null : _togglePromoNotifs,
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
            onTap: () => _openTermsOfUse(),
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

  // Conditions d'utilisation — page officielle sur le site, toujours à jour
  // (plutôt qu'une copie figée dans l'app qu'il faudrait redéployer à
  // chaque changement légal).
  Future<void> _openTermsOfUse() async {
    final uri = Uri.parse('https://allofoods.web.app/conditions-utilisation');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      _snack('Impossible d\'ouvrir la page — vérifiez votre connexion.', error: true);
    }
  }

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

  void _showLanguagePicker(LanguageProvider lang, AppLocalizations t) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2))),
          Padding(
              padding: const EdgeInsets.all(16),
              child: Text(t.chooseLanguage,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87))),
          ...LanguageProvider.supported.entries.map((e) => ListTile(
                leading: Text(e.value.split('  ')[0],
                    style: const TextStyle(fontSize: 24)),
                title: Text(e.value.split('  ')[1],
                    style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87)),
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

  // DÉCONNEXION — Firebase Auth
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

// PAGE INFOS PERSONNELLES — Firestore
class _ProfileInfoPage extends StatefulWidget {
  const _ProfileInfoPage();
  @override
  State<_ProfileInfoPage> createState() => _ProfileInfoPageState();
}

class _ProfileInfoPageState extends State<_ProfileInfoPage> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _loading = true;

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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
          title: const Text('Informations personnelles'),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          foregroundColor: isDark ? Colors.white : Colors.black87,
          elevation: 0),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    const Icon(Icons.lock_outline, color: Colors.orange, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                          'Ces informations sont verrouillées. Contactez le support pour les modifier.',
                          style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white : Colors.black87)),
                    ),
                  ]),
                ),
                const SizedBox(height: 20),
                _Field(
                    ctrl: _nameCtrl,
                    label: 'Nom complet',
                    icon: Icons.person_outline,
                    readOnly: true),
                const SizedBox(height: 16),
                _Field(
                    ctrl: _phoneCtrl,
                    label: 'Téléphone',
                    icon: Icons.phone_outlined,
                    keyboard: TextInputType.phone,
                    readOnly: true),
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
  final bool readOnly;
  const _Field(
      {required this.ctrl,
      required this.label,
      required this.icon,
      this.keyboard = TextInputType.text,
      this.readOnly = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      readOnly: readOnly,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.orange),
        suffixIcon: readOnly
            ? Icon(Icons.lock_outline,
                size: 18, color: isDark ? Colors.grey.shade500 : Colors.grey.shade400)
            : null,
        filled: true,
        fillColor: isDark ? Colors.grey.shade800 : Colors.grey.shade50,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
                color: isDark ? Colors.grey.shade700 : Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
                color: isDark ? Colors.grey.shade700 : Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.orange, width: 2)),
      ),
    );
  }
}

// WIDGETS RÉUTILISABLES
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
