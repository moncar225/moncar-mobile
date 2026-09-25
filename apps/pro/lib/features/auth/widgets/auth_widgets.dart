// Composants des écrans d'authentification PRO (repris du parcours de
// l'app client : champ +225, mot de passe, étapes, code SMS, CGU).
library;

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ----------------------------- Numéro -----------------------------

/// « 0700112233 » → « 07 00 11 22 33 ».
String groupLocalPhone(String digits) {
  final b = StringBuffer();
  for (var i = 0; i < digits.length && i < 10; i++) {
    if (i > 0 && i.isEven) b.write(' ');
    b.write(digits[i]);
  }
  return b.toString();
}

String phoneDigits(String input) => input.replaceAll(RegExp(r'\D'), '');

/// Libellé de champ.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6, left: 2),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: MoncarColors.inkMut,
      ),
    ),
  );
}

/// Champ téléphone avec préfixe « +225 ».
class PhoneField extends StatelessWidget {
  const PhoneField({
    super.key,
    required this.controller,
    this.hasError = false,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
    this.enabled = true,
  });

  final TextEditingController controller;
  final bool hasError;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(
        color: hasError ? MoncarColors.danger : MoncarColors.hairline,
      ),
    );
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.phone,
      textInputAction: textInputAction,
      autofillHints: const [AutofillHints.telephoneNumberNational],
      maxLength: 14,
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d ]'))],
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: const TextStyle(fontSize: 16, letterSpacing: 0.5),
      decoration: InputDecoration(
        counterText: '',
        hintText: '07 00 11 22 33',
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 12, right: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: MoncarColors.brandSoft,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '+225',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: MoncarColors.brand,
              ),
            ),
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(
            color: hasError ? MoncarColors.danger : MoncarColors.brand,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

/// Champ mot de passe avec bouton afficher / masquer.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    this.hint = 'Votre mot de passe',
    this.isNew = false,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;

  /// `true` : mot de passe à créer (suggestion du gestionnaire).
  final bool isNew;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: _obscure,
      textInputAction: widget.textInputAction,
      autofillHints: [
        widget.isNew ? AutofillHints.newPassword : AutofillHints.password,
      ],
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      decoration: InputDecoration(
        hintText: widget.hint,
        prefixIcon: const Icon(Icons.lock_rounded),
        suffixIcon: IconButton(
          tooltip: _obscure ? 'Afficher' : 'Masquer',
          onPressed: () => setState(() => _obscure = !_obscure),
          icon: Icon(
            _obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded,
          ),
        ),
      ),
    );
  }
}

// ----------------------------- Règles de mot de passe -----------------------------

class PasswordRule {
  const PasswordRule(this.label, this.test);
  final String label;
  final bool Function(String) test;
}

/// Mêmes règles que l'app client (⚠ politique définitive serveur, T-8).
final passwordRules = <PasswordRule>[
  PasswordRule('8 caractères minimum', (p) => p.length >= 8),
  PasswordRule('Une lettre', (p) => RegExp(r'[A-Za-zÀ-ÿ]').hasMatch(p)),
  PasswordRule('Un chiffre', (p) => RegExp(r'\d').hasMatch(p)),
];

bool isPasswordValid(String p) => passwordRules.every((r) => r.test(p));

/// Règles cochées en temps réel + concordance de la confirmation.
class PasswordChecklist extends StatelessWidget {
  const PasswordChecklist({
    super.key,
    required this.password,
    required this.confirm,
  });

  final String password;
  final String confirm;

  @override
  Widget build(BuildContext context) {
    Widget rule(String label, bool ok) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            ok
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 17,
            color: ok ? MoncarColors.success : MoncarColors.inkFaint,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: ok ? MoncarColors.ink : MoncarColors.inkMut,
              fontWeight: ok ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final r in passwordRules) rule(r.label, r.test(password)),
        rule(
          'Confirmation identique',
          confirm.isNotEmpty && confirm == password,
        ),
      ],
    );
  }
}

// ----------------------------- Étapes -----------------------------

/// Barre de progression segmentée des étapes d'inscription.
class StepProgress extends StatelessWidget {
  const StepProgress({super.key, required this.current, required this.total});

  /// Étape courante, de 1 à [total].
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 1; i <= total; i++) ...[
          if (i > 1) const SizedBox(width: 6),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              height: 6,
              decoration: BoxDecoration(
                color: i < current
                    ? MoncarColors.brand
                    : i == current
                    ? MoncarColors.accent
                    : MoncarColors.hairline,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// En-tête d'étape : numéro, titre, sous-titre.
class StepHeader extends StatelessWidget {
  const StepHeader({
    super.key,
    required this.index,
    required this.title,
    required this.subtitle,
  });

  final int index;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: MoncarColors.accentSoft,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$index',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: MoncarColors.accentInk,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: MoncarColors.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 34),
            child: Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: MoncarColors.inkMut,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------- Erreurs, CGU -----------------------------

class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MoncarColors.dangerSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MoncarColors.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 18, color: MoncarColors.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: MoncarColors.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mention CGU / confidentialité (⚠ textes définitifs : A-13).
class TermsNotice extends StatelessWidget {
  const TermsNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final strong = TextStyle(
      fontWeight: FontWeight.w600,
      color: MoncarColors.inkMut,
    );
    return Text.rich(
      TextSpan(
        children: [
          const TextSpan(text: 'En continuant, vous acceptez les '),
          TextSpan(text: 'Conditions d’utilisation', style: strong),
          const TextSpan(text: ' et la '),
          TextSpan(text: 'Politique de confidentialité', style: strong),
          const TextSpan(text: ' de MON CAR PRO.'),
        ],
      ),
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 11.5,
        height: 1.5,
        color: MoncarColors.inkFaint,
      ),
    );
  }
}

// ----------------------------- Code SMS -----------------------------

/// Six cases pour le code SMS, au-dessus d'un champ unique invisible
/// (collage et remplissage automatique du code supportés).
class OtpBoxes extends StatelessWidget {
  const OtpBoxes({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    this.enabled = true,
    this.hasError = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final bool enabled;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => focusNode.requestFocus(),
      child: Stack(
        children: [
          Opacity(
            opacity: 0,
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: enabled,
              autofocus: true,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: onChanged,
              decoration: const InputDecoration(counterText: ''),
            ),
          ),
          ListenableBuilder(
            listenable: Listenable.merge([controller, focusNode]),
            builder: (context, _) {
              final code = controller.text;
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < 6; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        height: 58,
                        constraints: const BoxConstraints(maxWidth: 52),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: MoncarColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            width: 2,
                            color: hasError
                                ? MoncarColors.danger
                                : focusNode.hasFocus && i == code.length
                                ? MoncarColors.brand
                                : i < code.length
                                ? MoncarColors.brand.withValues(alpha: 0.35)
                                : MoncarColors.hairline,
                          ),
                        ),
                        child: Text(
                          i < code.length ? code[i] : '',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: MoncarColors.ink,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
