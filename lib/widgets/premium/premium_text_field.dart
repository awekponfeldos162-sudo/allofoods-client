// lib/widgets/premium/premium_text_field.dart
//
// Remplace TextField/TextFormField standard. S'appuie sur
// AppTheme.inputDecorationTheme (bordure focus orange déjà définie) et
// ajoute : icône préfixe animée selon le focus, validation en temps réel
// avec icône de statut (✓ vert / ✕ rouge) qui apparaît en fondu.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';

class PremiumTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String label;
  final String? hint;
  final IconData? prefixIcon;
  final bool obscureText;
  final TextInputType keyboardType;
  final int maxLines;
  final bool enabled;
  final ValueChanged<String>? onChanged;

  /// Retourne un message d'erreur, ou null si la valeur est valide.
  /// Appelé à chaque frappe pour la validation temps réel.
  final String? Function(String?)? validator;

  const PremiumTextField({
    super.key,
    this.controller,
    required this.label,
    this.hint,
    this.prefixIcon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
    this.enabled = true,
    this.onChanged,
    this.validator,
  });

  @override
  State<PremiumTextField> createState() => _PremiumTextFieldState();
}

enum _ValidationState { neutral, valid, invalid }

class _PremiumTextFieldState extends State<PremiumTextField> {
  final _focusNode = FocusNode();
  bool _focused = false;
  _ValidationState _validation = _ValidationState.neutral;
  String? _errorText;
  bool _touched = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() => _focused = _focusNode.hasFocus));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _handleChanged(String value) {
    _touched = true;
    if (widget.validator != null) {
      final error = widget.validator!(value);
      setState(() {
        _errorText = error;
        _validation = error != null
            ? _ValidationState.invalid
            : (value.isEmpty ? _ValidationState.neutral : _ValidationState.valid);
      });
    }
    widget.onChanged?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    final iconColor = !widget.enabled
        ? (brightness == Brightness.dark ? AppColors.disabledDark : AppColors.disabledLight)
        : _focused
            ? AppColors.accent
            : (brightness == Brightness.dark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight);

    return TextFormField(
      controller: widget.controller,
      focusNode: _focusNode,
      obscureText: widget.obscureText,
      keyboardType: widget.keyboardType,
      maxLines: widget.obscureText ? 1 : widget.maxLines,
      enabled: widget.enabled,
      onChanged: _handleChanged,
      style: AppTextStyles.textTheme(brightness).bodyLarge,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        errorText: _touched ? _errorText : null,
        prefixIcon: widget.prefixIcon == null
            ? null
            : TweenAnimationBuilder<Color?>(
                tween: ColorTween(end: iconColor),
                duration: const Duration(milliseconds: 200),
                builder: (_, color, __) => Icon(widget.prefixIcon, color: color, size: 20),
              ),
        suffixIcon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
          child: switch (_validation) {
            _ValidationState.valid => const Icon(Icons.check_circle_rounded,
                key: ValueKey('valid'), color: AppColors.success, size: 20),
            _ValidationState.invalid => const Icon(Icons.error_rounded,
                key: ValueKey('invalid'), color: AppColors.error, size: 20),
            _ValidationState.neutral => const SizedBox.shrink(key: ValueKey('neutral')),
          },
        ),
      ),
    ).animate(target: _focused ? 1 : 0).scaleXY(end: 1.01, duration: 150.ms, curve: Curves.easeOut);
  }
}
