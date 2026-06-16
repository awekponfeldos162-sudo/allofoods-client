// lib/pages/LoginPage.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../l10n/app_localizations.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  bool _obscureLogin = true;
  bool _obscureReg = true;
  bool _obscureConfirm = true;

  // Connexion
  final _loginEmailCtrl = TextEditingController();
  final _loginPasswordCtrl = TextEditingController();

  // Inscription
  final _regNameCtrl    = TextEditingController();
  final _regEmailCtrl   = TextEditingController();
  final _regPhoneCtrl   = TextEditingController();
  final _regPasswordCtrl = TextEditingController();
  final _regConfirmCtrl  = TextEditingController();

  // Erreurs
  String? _nameErr, _emailErr, _phoneErr, _passErr, _confirmErr;
  String? _loginEmailErr, _loginPassErr;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmailCtrl.dispose();
    _loginPasswordCtrl.dispose();
    _regNameCtrl.dispose();
    _regEmailCtrl.dispose();
    _regPhoneCtrl.dispose();
    _regPasswordCtrl.dispose();
    _regConfirmCtrl.dispose();
    super.dispose();
  }

  // ── VALIDATIONS ──────────────────────────────────────────────────────────────

  bool _validateLogin(AppLocalizations t) {
    bool ok = true;
    setState(() {
      _loginEmailErr = _loginPassErr = null;
      if (_loginEmailCtrl.text.trim().isEmpty ||
          !_loginEmailCtrl.text.contains('@')) {
        _loginEmailErr = t.invalidEmail;
        ok = false;
      }
      if (_loginPasswordCtrl.text.length < 6) {
        _loginPassErr = t.minChars;
        ok = false;
      }
    });
    return ok;
  }

  bool _validateRegister(AppLocalizations t) {
    bool ok = true;
    setState(() {
      _nameErr = _emailErr = _phoneErr = _passErr = _confirmErr = null;

      final name = _regNameCtrl.text.trim();
      if (name.length < 2) {
        _nameErr = t.nameTooShort;
        ok = false;
      } else if (!RegExp(r'^[a-zA-ZÀ-ÿ\s\-]+$').hasMatch(name)) {
        _nameErr = t.nameLettersOnly;
        ok = false;
      }

      if (!RegExp(r'^[\w.-]+@[\w.-]+\.\w+$')
          .hasMatch(_regEmailCtrl.text.trim())) {
        _emailErr = t.invalidEmail;
        ok = false;
      }

      final phone = _regPhoneCtrl.text.trim();
      if (phone.length != 8) {
        _phoneErr = t.phoneDigits;
        ok = false;
      }

      if (_regPasswordCtrl.text.length < 6) {
        _passErr = t.passwordTooShort;
        ok = false;
      } else if (!RegExp(r'[0-9]').hasMatch(_regPasswordCtrl.text)) {
        _passErr = t.passwordNeedsDigit;
        ok = false;
      }

      if (_regConfirmCtrl.text != _regPasswordCtrl.text) {
        _confirmErr = t.passwordsMismatch;
        ok = false;
      }
    });
    return ok;
  }

  // ── CONNEXION EMAIL ───────────────────────────────────────────────────────────

  Future<void> _login() async {
    if (!_validateLogin(AppLocalizations.of(context))) return;
    setState(() => _isLoading = true);
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _loginEmailCtrl.text.trim(),
        password: _loginPasswordCtrl.text,
      );
      if (!mounted) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(cred.user!.uid)
          .get();
      if (!mounted) return;

      final role = (doc.data()?['role'] as String? ?? '').toLowerCase();
      if (role != 'client') {
        await FirebaseAuth.instance.signOut();
        setState(() => _isLoading = false);
        _showRoleDialog(role);
        return;
      }

      if (mounted) _snack(AppLocalizations.of(context).welcome, Colors.green);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final t = AppLocalizations.of(context);
      setState(() => _isLoading = false);
      switch (e.code) {
        case 'user-not-found':
        case 'invalid-credential':
          setState(() => _loginEmailErr = t.noAccountEmail);
          break;
        case 'wrong-password':
          setState(() => _loginPassErr = t.wrongPassword);
          break;
        case 'too-many-requests':
          _snack(t.tooManyAttempts, Colors.red);
          break;
        default:
          _snack('Erreur: ${e.message}', Colors.red);
      }
    } catch (_) {
      setState(() => _isLoading = false);
      if (mounted) _snack(AppLocalizations.of(context).networkError, Colors.red);
    }
  }

  void _showRoleDialog(String role) {
    if (!mounted) return;
    final t = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.block, color: Colors.red, size: 48),
        title: Text(t.accessDenied,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          _roleErrorMessage(t, role),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              minimumSize: const Size(double.infinity, 46),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context),
            child: Text(t.understood, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _roleErrorMessage(AppLocalizations t, String role) => switch (role) {
        'restaurant' || 'merchant' => t.roleRestaurantError,
        'driver'                   => t.roleDriverError,
        'admin'                    => t.roleAdminError,
        _                          => t.roleUnauthorizedError,
      };

  // ── MOT DE PASSE OUBLIÉ ───────────────────────────────────────────────────────

  Future<void> _forgotPassword() async {
    final t = AppLocalizations.of(context);
    final email = _loginEmailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _loginEmailErr = t.resetEmailForEntry);
      return;
    }
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) _snack(t.resetLinkSent, Colors.blue);
    } catch (e) {
      if (mounted) _snack(t.resetEmailError, Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── INSCRIPTION EMAIL ─────────────────────────────────────────────────────────

  Future<void> _register() async {
    if (!_validateRegister(AppLocalizations.of(context))) return;
    setState(() => _isLoading = true);
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _regEmailCtrl.text.trim(),
        password: _regPasswordCtrl.text,
      );
      await cred.user!.updateDisplayName(_regNameCtrl.text.trim());

      // Numéro complet : préfixe "01" + 8 chiffres saisis
      final fullPhone = '01${_regPhoneCtrl.text.trim()}';

      await _saveUserToFirestore(
        uid: cred.user!.uid,
        name: _regNameCtrl.text.trim(),
        email: _regEmailCtrl.text.trim(),
        phone: fullPhone,
        photo: null,
      );

      if (mounted) _snack(AppLocalizations.of(context).accountCreated, Colors.green);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final t = AppLocalizations.of(context);
      setState(() => _isLoading = false);
      switch (e.code) {
        case 'email-already-in-use':
          setState(() => _emailErr = t.emailAlreadyUsed);
          break;
        case 'weak-password':
          setState(() => _passErr = t.weakPassword);
          break;
        default:
          _snack('Erreur: ${e.message}', Colors.red);
      }
    } catch (_) {
      setState(() => _isLoading = false);
      if (mounted) _snack(AppLocalizations.of(context).registrationError, Colors.red);
    }
  }

  // ── CONNEXION GOOGLE ──────────────────────────────────────────────────────────

  Future<void> _loginWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final googleSignIn = GoogleSignIn.instance;
      await googleSignIn.initialize();
      final googleUser = await googleSignIn.authenticate();
      final googleAuth = googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );
      final userCred =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCred.user!;
      final isNew = userCred.additionalUserInfo?.isNewUser ?? false;

      if (!mounted) return;

      if (isNew) {
        await _saveUserToFirestore(
          uid: user.uid,
          name: user.displayName ?? '',
          email: user.email ?? '',
          phone: '',
          photo: user.photoURL,
        );
      } else {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (!mounted) return;
        final role = (doc.data()?['role'] as String? ?? '').toLowerCase();
        if (role != 'client') {
          await FirebaseAuth.instance.signOut();
          setState(() => _isLoading = false);
          _showRoleDialog(role);
          return;
        }
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'name': user.displayName ?? '',
          'email': user.email ?? '',
          if (user.photoURL != null) 'imageUrl': user.photoURL,
        });
      }

      if (mounted) _snack(AppLocalizations.of(context).connectedWithGoogle, Colors.green);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _snack(AppLocalizations.of(context).googleSignInError, Colors.red);
      }
    }
  }

  // ── SAUVEGARDER UTILISATEUR ───────────────────────────────────────────────────

  Future<void> _saveUserToFirestore({
    required String uid,
    required String name,
    required String email,
    required String phone,
    required String? photo,
  }) async {
    final year = DateTime.now().year;
    final memberCode = 'AF-$year-${uid.substring(0, 4).toUpperCase()}';
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'imageUrl': photo,
      'role': 'client',
      'appOrigin': 'client_app',
      'memberCode': memberCode,
      'termsAccepted': false,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            const SizedBox(height: 24),

            // Logo
            Image.asset('assets/images/logo.png',
                width: 130, height: 130, fit: BoxFit.contain),
            const SizedBox(height: 28),

            // Tabs
            Container(
              decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12)),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(12)),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.grey,
                tabs: [
                  Tab(text: AppLocalizations.of(context).signIn),
                  Tab(text: AppLocalizations.of(context).signUp),
                ],
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              height: 520,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildLoginForm(),
                  _buildRegisterForm(),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Info commission
            _CommissionBanner(),
            const SizedBox(height: 16),
          ]),
        ),
      ),
    );
  }

  // ── FORMULAIRE CONNEXION ──────────────────────────────────────────────────────

  Widget _buildLoginForm() {
    final t = AppLocalizations.of(context);
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Field(
            _loginEmailCtrl,
            t.email,
            Icons.email_outlined,
            error: _loginEmailErr,
            keyboard: TextInputType.emailAddress,
            onChange: (_) => setState(() => _loginEmailErr = null),
          ),
          const SizedBox(height: 14),
          _Field(
            _loginPasswordCtrl,
            t.password,
            Icons.lock_outline,
            error: _loginPassErr,
            isPass: true,
            obscure: _obscureLogin,
            onToggle: () => setState(() => _obscureLogin = !_obscureLogin),
            onChange: (_) => setState(() => _loginPassErr = null),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _isLoading ? null : _forgotPassword,
              child: Text(t.forgotPassword,
                  style: const TextStyle(
                      color: Colors.orange, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 6),
          _Btn(t.signInBtn, _login, _isLoading),
          const SizedBox(height: 16),
          _OrDivider(),
          const SizedBox(height: 16),
          _GoogleBtn(onTap: _loginWithGoogle, loading: _isLoading),
        ],
      );
  }

  // ── FORMULAIRE INSCRIPTION ────────────────────────────────────────────────────

  Widget _buildRegisterForm() {
    final t = AppLocalizations.of(context);
    return SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _Field(
            _regNameCtrl,
            t.fullName,
            Icons.person_outline,
            error: _nameErr,
            formatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-ZÀ-ÿ\s\-]')),
            ],
            onChange: (_) => setState(() => _nameErr = null),
          ),
          const SizedBox(height: 10),

          _Field(
            _regEmailCtrl,
            t.email,
            Icons.email_outlined,
            error: _emailErr,
            keyboard: TextInputType.emailAddress,
            onChange: (_) => setState(() => _emailErr = null),
          ),
          const SizedBox(height: 10),

          _PhoneField(
            ctrl: _regPhoneCtrl,
            error: _phoneErr,
            onChange: (_) => setState(() => _phoneErr = null),
          ),
          const SizedBox(height: 10),

          _Field(
            _regPasswordCtrl,
            t.password,
            Icons.lock_outline,
            error: _passErr,
            isPass: true,
            obscure: _obscureReg,
            onToggle: () => setState(() => _obscureReg = !_obscureReg),
            onChange: (_) => setState(() => _passErr = null),
          ),
          if (_passErr == null && _regPasswordCtrl.text.isNotEmpty)
            _PasswordHint(_regPasswordCtrl.text),
          const SizedBox(height: 10),

          _Field(
            _regConfirmCtrl,
            t.confirmPassword,
            Icons.lock_outline,
            error: _confirmErr,
            isPass: true,
            obscure: _obscureConfirm,
            onToggle: () =>
                setState(() => _obscureConfirm = !_obscureConfirm),
            onChange: (_) => setState(() => _confirmErr = null),
          ),
          const SizedBox(height: 20),
          _Btn(t.createAccount, _register, _isLoading),
          const SizedBox(height: 16),
          _OrDivider(),
          const SizedBox(height: 16),
          _GoogleBtn(onTap: _loginWithGoogle, loading: _isLoading),
        ]),
      );
  }
}

// ── CHAMP TÉLÉPHONE AVEC PRÉFIXE 01 ──────────────────────────────────────────

class _PhoneField extends StatelessWidget {
  final TextEditingController ctrl;
  final String? error;
  final ValueChanged<String>? onChange;
  const _PhoneField({required this.ctrl, this.error, this.onChange});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        maxLength: 8,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: onChange,
        style: const TextStyle(color: Colors.black87),
        decoration: InputDecoration(
          hintText: 'XX XX XX XX',
          labelText: 'Numéro de téléphone',
          // "01" affiché en orange, non modifiable
          prefix: Container(
            margin: const EdgeInsets.only(right: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.orange.shade300),
            ),
            child: Text('01',
                style: TextStyle(
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
          ),
          prefixIcon: Icon(Icons.phone_outlined,
              color: error != null ? Colors.red : Colors.orange),
          filled: true,
          fillColor: error != null ? Colors.red.shade50 : Colors.grey.shade50,
          counterText: '',
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: error != null ? Colors.red : Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: error != null ? Colors.red : Colors.grey.shade300)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: error != null ? Colors.red : Colors.orange,
                  width: 2)),
        ),
      ),
      if (error != null)
        Padding(
          padding: const EdgeInsets.only(left: 12, top: 4),
          child: Row(children: [
            const Icon(Icons.error_outline, size: 13, color: Colors.red),
            const SizedBox(width: 4),
            Text(error!,
                style: const TextStyle(color: Colors.red, fontSize: 12)),
          ]),
        ),
      if (error == null)
        Padding(
          padding: const EdgeInsets.only(left: 12, top: 4),
          child: Text('Format : 01 XX XX XX XX (10 chiffres)',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
        ),
    ]);
  }
}

// ── INDICATEUR FORCE MOT DE PASSE ────────────────────────────────────────────

class _PasswordHint extends StatelessWidget {
  final String password;
  const _PasswordHint(this.password);

  @override
  Widget build(BuildContext context) {
    final hasLength = password.length >= 6;
    final hasDigit  = RegExp(r'[0-9]').hasMatch(password);
    final hasUpper  = RegExp(r'[A-Z]').hasMatch(password);

    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 6),
      child: Wrap(spacing: 8, runSpacing: 4, children: [
        _HintChip('6+ caractères', hasLength),
        _HintChip('Un chiffre', hasDigit),
        _HintChip('Majuscule', hasUpper),
      ]),
    );
  }
}

class _HintChip extends StatelessWidget {
  final String label;
  final bool ok;
  const _HintChip(this.label, this.ok);

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(ok ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 12,
            color: ok ? Colors.green : Colors.grey.shade400),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: ok ? Colors.green : Colors.grey.shade500)),
      ]);
}

// ── BANNER COMMISSION ─────────────────────────────────────────────────────────

class _CommissionBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
                color: Colors.orange.shade100, shape: BoxShape.circle),
            child: Icon(Icons.info_outline,
                color: Colors.orange.shade700, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                    color: Colors.grey.shade700, fontSize: 12, height: 1.5),
                children: [
                  TextSpan(
                    text: 'Commission AlloFoods\n',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade700,
                        fontSize: 13),
                  ),
                  const TextSpan(
                    text:
                        'AlloFoods prend ',
                  ),
                  TextSpan(
                    text: '5%',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade800),
                  ),
                  const TextSpan(
                    text:
                        ' de commission sur le montant de chaque commande. '
                        'Les frais de livraison sont calculés selon la distance.',
                  ),
                ],
              ),
            ),
          ),
        ]),
      );
}

// ── WIDGETS GÉNÉRIQUES ────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final IconData icon;
  final String? error;
  final bool isPass, obscure;
  final VoidCallback? onToggle;
  final TextInputType keyboard;
  final ValueChanged<String>? onChange;
  final List<TextInputFormatter>? formatters;

  const _Field(
    this.ctrl,
    this.hint,
    this.icon, {
    this.error,
    this.isPass = false,
    this.obscure = false,
    this.onToggle,
    this.keyboard = TextInputType.text,
    this.onChange,
    this.formatters,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: ctrl,
            obscureText: isPass ? obscure : false,
            keyboardType: keyboard,
            onChanged: onChange,
            inputFormatters: formatters,
            style: const TextStyle(color: Colors.black87),
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: Icon(icon,
                  color: error != null ? Colors.red : Colors.orange),
              suffixIcon: isPass
                  ? IconButton(
                      icon: Icon(
                          obscure
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: Colors.grey,
                          size: 20),
                      onPressed: onToggle)
                  : null,
              filled: true,
              fillColor:
                  error != null ? Colors.red.shade50 : Colors.grey.shade50,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: error != null
                          ? Colors.red
                          : Colors.grey.shade300)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: error != null
                          ? Colors.red
                          : Colors.grey.shade300)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: error != null ? Colors.red : Colors.orange,
                      width: 2)),
            ),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 4),
              child: Row(children: [
                const Icon(Icons.error_outline, size: 13, color: Colors.red),
                const SizedBox(width: 4),
                Text(error!,
                    style:
                        const TextStyle(color: Colors.red, fontSize: 12)),
              ]),
            ),
        ],
      );
}

class _Btn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool loading;
  const _Btn(this.label, this.onTap, this.loading);

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: loading ? null : onTap,
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12))),
          child: loading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5))
              : Text(label,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
        ),
      );
}

class _OrDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: Divider(color: Colors.grey.shade300)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('OU',
              style: TextStyle(
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w600,
                  fontSize: 12)),
        ),
        Expanded(child: Divider(color: Colors.grey.shade300)),
      ]);
}

class _GoogleBtn extends StatelessWidget {
  final VoidCallback onTap;
  final bool loading;
  const _GoogleBtn({required this.onTap, required this.loading});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 52,
        child: OutlinedButton(
          onPressed: loading ? null : onTap,
          style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.grey.shade300),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              backgroundColor: Colors.white),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            SvgPicture.asset('assets/images/google-logo.svg',
                width: 24, height: 24),
            const SizedBox(width: 12),
            const Text('Continuer avec Google',
                style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                    fontSize: 15)),
          ]),
        ),
      );
}
