// lib/pages/SecurityPage.dart
// ? Firebase Auth é changement mot de passe + ré-authentification

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SecurityPage extends StatefulWidget {
  const SecurityPage({super.key});
  @override
  State<SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends State<SecurityPage> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;
  bool _loading = false;

  // Indicateur de force du mot de passe
  int _strength = 0; // 0-4

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  int _calcStrength(String p) {
    int s = 0;
    if (p.length >= 8) s++;
    if (p.contains(RegExp(r'[A-Z]'))) s++;
    if (p.contains(RegExp(r'[0-9]'))) s++;
    if (p.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'))) s++;
    return s;
  }

  Color _strengthColor() {
    switch (_strength) {
      case 1:
        return Colors.red;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.yellow.shade700;
      case 4:
        return Colors.green;
      default:
        return Colors.grey.shade200;
    }
  }

  String _strengthLabel() {
    switch (_strength) {
      case 1:
        return 'Faible';
      case 2:
        return 'Moyen';
      case 3:
        return 'Bon';
      case 4:
        return 'Fort ?';
      default:
        return '';
    }
  }

  Future<void> _changePassword() async {
    final current = _currentCtrl.text.trim();
    final newPass = _newCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();

    if (current.isEmpty || newPass.isEmpty || confirm.isEmpty) {
      _snack('Remplissez tous les champs', error: true);
      return;
    }
    if (newPass != confirm) {
      _snack('Les mots de passe ne correspondent pas', error: true);
      return;
    }
    if (newPass.length < 6) {
      _snack('Minimum 6 caractéres', error: true);
      return;
    }

    setState(() => _loading = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      // Ré-authentification obligatoire avant changement
      final cred =
          EmailAuthProvider.credential(email: user.email!, password: current);
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newPass);

      if (!mounted) return;
      _snack('? Mot de passe mis à jour !');
      _currentCtrl.clear();
      _newCtrl.clear();
      _confirmCtrl.clear();
      setState(() => _strength = 0);
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'wrong-password':
          msg = 'Mot de passe actuel incorrect';
          break;
        case 'too-many-requests':
          msg = 'Trop de tentatives. Réessayez plus tard';
          break;
        case 'weak-password':
          msg = 'Nouveau mot de passe trop faible';
          break;
        default:
          msg = e.message ?? 'Erreur inconnue';
      }
      if (mounted) _snack(msg, error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red.shade600 : Colors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Sécurité',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).textTheme.bodyLarge?.color,
        elevation: 0,
        bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1), child: Divider(height: 1)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200)),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.grey.shade200, shape: BoxShape.circle),
                child: const Icon(Icons.lock_outline,
                    color: Colors.black87, size: 26),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Changer le mot de passe',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      SizedBox(height: 2),
                      Text(
                          'Utilisez un mot de passe fort\n(lettres, chiffres, symboles).',
                          style:
                              TextStyle(fontSize: 12, color: Colors.black54)),
                    ]),
              ),
            ]),
          ),
          const SizedBox(height: 24),

          // Champs
          const Text('Mot de passe actuel',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          _PasswordField(
            ctrl: _currentCtrl,
            label: 'Mot de passe actuel',
            visible: _showCurrent,
            onToggle: () => setState(() => _showCurrent = !_showCurrent),
          ),
          const SizedBox(height: 20),

          const Text('Nouveau mot de passe',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          _PasswordField(
            ctrl: _newCtrl,
            label: 'Nouveau mot de passe',
            visible: _showNew,
            onToggle: () => setState(() => _showNew = !_showNew),
            onChanged: (v) => setState(() => _strength = _calcStrength(v)),
          ),

          // Barre de force
          if (_newCtrl.text.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(children: [
              ...List.generate(
                  4,
                  (i) => Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          height: 4,
                          decoration: BoxDecoration(
                              color: i < _strength
                                  ? _strengthColor()
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(2)),
                        ),
                      )),
              const SizedBox(width: 10),
              Text(_strengthLabel(),
                  style: TextStyle(
                      fontSize: 11,
                      color: _strengthColor(),
                      fontWeight: FontWeight.bold)),
            ]),
          ],
          const SizedBox(height: 20),

          const Text('Confirmer le nouveau mot de passe',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          _PasswordField(
            ctrl: _confirmCtrl,
            label: 'Confirmer le mot de passe',
            visible: _showConfirm,
            onToggle: () => setState(() => _showConfirm = !_showConfirm),
          ),
          const SizedBox(height: 32),

          // Bouton
          ElevatedButton(
            onPressed: _loading ? null : _changePassword,
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14))),
            child: _loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('Mettre à jour',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(height: 16),

          // Tips sécurité
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.shield_outlined,
                    color: Colors.black87, size: 16),
                SizedBox(width: 6),
                Text('Conseils de sécurité',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        fontSize: 12)),
              ]),
              const SizedBox(height: 8),
              ...[
                'Minimum 8 caractéres',
                'Mélangez majuscules, chiffres et symboles',
                'N\'utilisez pas votre date de naissance',
                'Ne partagez jamais votre mot de passe',
              ].map((tip) => Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(children: [
                      const Icon(Icons.check_circle_outline,
                          size: 13, color: Colors.black54),
                      const SizedBox(width: 6),
                      Text(tip,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.black54)),
                    ]),
                  )),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final bool visible;
  final VoidCallback onToggle;
  final ValueChanged<String>? onChanged;

  const _PasswordField({
    required this.ctrl,
    required this.label,
    required this.visible,
    required this.onToggle,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) => TextField(
        controller: ctrl,
        obscureText: !visible,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon:
              const Icon(Icons.lock_outline, color: Colors.black54, size: 20),
          suffixIcon: IconButton(
            icon: Icon(
                visible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: Colors.grey,
                size: 20),
            onPressed: onToggle,
          ),
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
        ),
      );
}
