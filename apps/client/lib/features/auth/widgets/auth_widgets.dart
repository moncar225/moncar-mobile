import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../shared/foundation.dart';
import '../application/auth_flow.dart';

/// Champ téléphone avec préfixe « +225 » (connexion, inscription).
class PhoneField extends StatelessWidget {
  const PhoneField({
    super.key,
    required this.controller,
    this.hasError = false,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.textInputAction,
  });

  final TextEditingController controller;
  final bool hasError;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final TextInputAction? textInputAction;

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
      keyboardType: TextInputType.phone,
      autofocus: autofocus,
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
        filled: true,
        fillColor: MoncarColors.surface,
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

/// Champ mot de passe MON CAR : icône cadenas, bouton afficher/masquer
/// et indices d'autoremplissage (gestionnaires de mots de passe).
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    this.label,
    this.hint = 'Votre mot de passe',
    this.error,
    this.isNew = false,
    this.autofocus = false,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String? label;
  final String hint;
  final String? error;

  /// `true` pour un mot de passe à créer (suggestion de mot de passe
  /// fort par le gestionnaire), `false` pour une connexion.
  final bool isNew;
  final bool autofocus;
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
    final hasError = widget.error != null;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(
        color: hasError ? MoncarColors.danger : MoncarColors.hairline,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) MoncarLabel(widget.label!),
        TextField(
          controller: widget.controller,
          autofocus: widget.autofocus,
          obscureText: _obscure,
          enableSuggestions: false,
          autocorrect: false,
          keyboardType: TextInputType.visiblePassword,
          textInputAction: widget.textInputAction,
          autofillHints: [
            widget.isNew ? AutofillHints.newPassword : AutofillHints.password,
          ],
          maxLength: 64,
          onChanged: widget.onChanged,
          onSubmitted: widget.onSubmitted,
          style: const TextStyle(fontSize: 16, letterSpacing: 0.3),
          decoration: InputDecoration(
            counterText: '',
            hintText: widget.hint,
            hintStyle: TextStyle(color: MoncarColors.inkFaint, fontSize: 15),
            filled: true,
            fillColor: MoncarColors.surface,
            prefixIcon: Icon(
              Icons.lock_outline,
              size: 20,
              color: MoncarColors.inkMut,
            ),
            suffixIcon: IconButton(
              tooltip: _obscure
                  ? 'Afficher le mot de passe'
                  : 'Masquer le mot de passe',
              onPressed: () => setState(() => _obscure = !_obscure),
              icon: Icon(
                _obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 20,
                color: MoncarColors.inkMut,
              ),
            ),
            border: border,
            enabledBorder: border,
            focusedBorder: border.copyWith(
              borderSide: BorderSide(
                color: hasError ? MoncarColors.danger : MoncarColors.brand,
                width: 1.5,
              ),
            ),
          ),
        ),
        if (hasError) FieldError(widget.error!),
      ],
    );
  }
}

/// Jauge de robustesse + règles cochées en temps réel.
class PasswordStrengthMeter extends StatelessWidget {
  const PasswordStrengthMeter({super.key, required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final strength = passwordStrength(password);
    final (label, color) = switch (strength) {
      0 => ('', MoncarColors.hairline),
      1 => ('Faible', MoncarColors.danger),
      2 => ('Correct', MoncarColors.warn),
      _ => ('Fort', MoncarColors.success),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Row(
          children: [
            for (var i = 1; i <= 3; i++) ...[
              if (i > 1) const SizedBox(width: 6),
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: 4,
                  decoration: BoxDecoration(
                    color: i <= strength ? color : MoncarColors.hairline,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ],
            const SizedBox(width: 10),
            SizedBox(
              width: 52,
              child: Text(
                label,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            for (final rule in passwordRules)
              _RuleChip(label: rule.label, ok: rule.test(password)),
          ],
        ),
      ],
    );
  }
}

class _RuleChip extends StatelessWidget {
  const _RuleChip({required this.label, required this.ok});

  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Icon(
            ok ? Icons.check_circle : Icons.radio_button_unchecked,
            key: ValueKey(ok),
            size: 14,
            color: ok ? MoncarColors.success : MoncarColors.inkFaint,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: ok ? FontWeight.w600 : FontWeight.w400,
            color: ok ? MoncarColors.ink : MoncarColors.inkMut,
          ),
        ),
      ],
    );
  }
}

/// En-tête des écrans d'authentification secondaires : pastille
/// icône, titre et sous-titre centrés.
class AuthHeader extends StatelessWidget {
  const AuthHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: MoncarColors.brandSoft,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 30, color: MoncarColors.brand),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: MoncarColors.ink,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            height: 1.45,
            color: MoncarColors.inkMut,
          ),
        ),
      ],
    );
  }
}

/// Bandeau d'erreur (identifiants incorrects, compte inexistant…).
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
                fontWeight: FontWeight.w500,
                color: MoncarColors.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Étapes du parcours « mot de passe oublié » : Numéro → Code SMS →
/// Nouveau mot de passe ([current] de 1 à 3).
class ResetStepsIndicator extends StatelessWidget {
  const ResetStepsIndicator({super.key, required this.current});

  final int current;

  static const _labels = ['Numéro', 'Code SMS', 'Nouveau mot de passe'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 1; i <= _labels.length; i++) ...[
          if (i > 1)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.only(bottom: 18),
                color: i <= current
                    ? MoncarColors.brand
                    : MoncarColors.hairline,
              ),
            ),
          _StepDot(index: i, label: _labels[i - 1], current: current),
        ],
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.index,
    required this.label,
    required this.current,
  });

  final int index;
  final String label;
  final int current;

  @override
  Widget build(BuildContext context) {
    final done = index < current;
    final active = index == current;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done || active ? MoncarColors.brand : MoncarColors.surface,
            border: Border.all(
              color: done || active
                  ? MoncarColors.brand
                  : MoncarColors.hairline,
              width: 2,
            ),
          ),
          child: done
              ? const Icon(Icons.check, size: 14, color: Colors.white)
              : Text(
                  '$index',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : MoncarColors.inkFaint,
                  ),
                ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? MoncarColors.ink : MoncarColors.inkFaint,
          ),
        ),
      ],
    );
  }
}

/// Confirmation visuelle : les deux saisies du mot de passe concordent.
class PasswordMatchHint extends StatelessWidget {
  const PasswordMatchHint({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 14, color: MoncarColors.success),
          const SizedBox(width: 4),
          Text(
            'Les mots de passe correspondent.',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: MoncarColors.success,
            ),
          ),
        ],
      ),
    );
  }
}

/// Mention CGU / confidentialité en pied d'écran d'authentification.
class TermsNotice extends StatelessWidget {
  const TermsNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final strong = TextStyle(
      fontWeight: FontWeight.w500,
      color: MoncarColors.inkMut,
    );
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: TextStyle(
          fontSize: 11,
          height: 1.5,
          color: MoncarColors.inkFaint,
        ),
        children: [
          TextSpan(text: 'En continuant, vous acceptez nos '),
          TextSpan(text: "Conditions d'utilisation", style: strong),
          TextSpan(text: ' et notre '),
          TextSpan(text: 'Politique de confidentialité', style: strong),
          TextSpan(text: '.'),
        ],
      ),
    );
  }
}

/// Snackbar « code de démo » : affiche le code OTP généré par le
/// serveur mock (environnement de dev uniquement).
void showDemoOtpCode(BuildContext context, String code, String phone) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 9),
        backgroundColor: MoncarColors.brand,
        content: Text(
          'CODE DE DÉMO : $code\n'
          'Code OTP envoyé par SMS au $phone (environnement de dev uniquement).',
        ),
      ),
    );
}
