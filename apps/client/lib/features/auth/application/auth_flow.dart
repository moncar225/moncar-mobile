// ============================================================
// MON CAR — Parcours d'authentification (inscription avec mot de
// passe, connexion numéro + mot de passe, mot de passe oublié).
//
// Le mot de passe saisi à l'inscription ne transite JAMAIS par l'URL :
// il reste en mémoire ([pendingSignupProvider]) le temps de la
// vérification SMS, puis est effacé.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';

import '../../shared/foundation.dart';
import 'phone_auth.dart';

/// Raison d'une vérification OTP.
enum OtpPurpose {
  /// Vérification du numéro à la création du compte.
  signup,

  /// Réinitialisation du mot de passe oublié.
  reset;

  static OtpPurpose fromQuery(String? value) =>
      value == 'reset' ? OtpPurpose.reset : OtpPurpose.signup;
}

/// Inscription en attente de la vérification du numéro.
class PendingSignup {
  const PendingSignup({
    required this.phone,
    required this.password,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.city,
    required this.optinPromos,
  });

  /// Numéro complet « +225XXXXXXXXXX ».
  final String phone;
  final String password;
  final String firstName;
  final String lastName;
  final String email;
  final String city;
  final bool optinPromos;
}

final pendingSignupProvider = StateProvider<PendingSignup?>((ref) => null);

/// Numéro dont la possession vient d'être prouvée par OTP dans le
/// parcours « mot de passe oublié ». L'écran de nouveau mot de passe
/// n'est accessible que si cette valeur est renseignée.
final verifiedResetPhoneProvider = StateProvider<String?>((ref) => null);

// ----------------------------- Numéro -----------------------------

/// « 07 00 11 22 33 » → « +2250700112233 ».
String fullCiPhone(String localInput) =>
    '+225${localInput.replaceAll(RegExp(r'\D'), '')}';

/// « +2250700112233 » → « +225 07 00 11 22 33 ».
String formatPhoneDisplay(String phone) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 13 && digits.startsWith('225')) {
    final l = digits.substring(3);
    return '+225 ${l.substring(0, 2)} ${l.substring(2, 4)} '
        '${l.substring(4, 6)} ${l.substring(6, 8)} ${l.substring(8, 10)}';
  }
  return phone;
}

/// « +2250700112233 » → « 07 00 11 22 33 » (pré-remplissage d'un champ).
String localPhoneInput(String phone) {
  final d = phone.replaceAll(RegExp(r'\D'), '');
  final local = d.startsWith('225') && d.length == 13 ? d.substring(3) : d;
  final buf = StringBuffer();
  for (var i = 0; i < local.length && i < 10; i++) {
    if (i > 0 && i.isEven) buf.write(' ');
    buf.write(local[i]);
  }
  return buf.toString();
}

// ----------------------------- Mot de passe -----------------------------

/// Règle de robustesse affichée en temps réel sous le champ.
class PasswordRule {
  const PasswordRule(this.label, this.test);

  final String label;
  final bool Function(String) test;
}

final passwordRules = <PasswordRule>[
  PasswordRule('8 caractères minimum', (p) => p.length >= 8),
  PasswordRule('Une lettre', (p) => RegExp(r'[A-Za-zÀ-ÿ]').hasMatch(p)),
  PasswordRule('Un chiffre', (p) => RegExp(r'\d').hasMatch(p)),
];

bool isPasswordValid(String p) => passwordRules.every((r) => r.test(p));

/// Robustesse de 0 (vide) à 3 (fort).
int passwordStrength(String p) {
  if (p.isEmpty) return 0;
  if (!isPasswordValid(p)) return 1;
  final hasUpperAndLower =
      RegExp(r'[A-Z]').hasMatch(p) && RegExp(r'[a-z]').hasMatch(p);
  final hasSymbol = RegExp(r'[^A-Za-zÀ-ÿ0-9]').hasMatch(p);
  return p.length >= 10 && (hasUpperAndLower || hasSymbol) ? 3 : 2;
}

// ----------------------------- Session -----------------------------

/// Ouvre la session applicative. ⚠️ MOCK : le profil vient du store
/// mock (utilisateur démo), complété par les informations saisies à
/// l'inscription — le backend Symfony créera le vrai profil.
void openAppSession(WidgetRef ref, {PendingSignup? signup}) {
  final session = ref.read(mockStoreProvider).loginDemo();
  var user = session.user;
  if (signup != null) {
    user = user.copyWith(
      firstName: signup.firstName.trim(),
      lastName: signup.lastName.trim(),
      phone: formatPhoneDisplay(signup.phone),
      email: signup.email.trim(),
      city: signup.city,
    );
  }
  ref.read(authProvider.notifier).setSession(user, session.accessToken);
}

/// Suite du parcours une fois le numéro vérifié par OTP (saisie du
/// code ou vérification automatique Android). Retourne un message
/// d'erreur à afficher, ou `null` si la navigation a eu lieu.
Future<String?> completePhoneVerification(
  BuildContext context,
  WidgetRef ref, {
  required OtpPurpose purpose,
  required String phone,
}) async {
  switch (purpose) {
    case OtpPurpose.signup:
      final pending = ref.read(pendingSignupProvider);
      if (pending == null || pending.phone != phone) {
        return 'Inscription expirée. Recommencez la création du compte.';
      }
      if (MoncarPhoneAuth.enabled) {
        final error = await MoncarPhoneAuth.attachPassword(
          phone,
          pending.password,
        );
        if (!context.mounted) return null;
        if (error == MoncarPhoneAuth.accountExistsMessage) {
          ref.read(pendingSignupProvider.notifier).state = null;
          showMoncarToast(context, error!, error: true);
          context.go('/auth/login?phone=${Uri.encodeComponent(phone)}');
          return null;
        }
        if (error != null) return error;
      } else {
        // ⚠️ MOCK : POST /auth/register.
        ref.read(mockStoreProvider).setPassword(phone, pending.password);
      }
      openAppSession(ref, signup: pending);
      ref.read(pendingSignupProvider.notifier).state = null;
      showMoncarToast(
        context,
        'Bienvenue ${pending.firstName.trim()} ! Votre compte est créé.',
        success: true,
      );
      context.go('/home');
      return null;

    case OtpPurpose.reset:
      if (MoncarPhoneAuth.enabled && MoncarPhoneAuth.lastSignInWasNewUser) {
        // Numéro inconnu : Firebase vient de créer un compte vide.
        await MoncarPhoneAuth.discardNewUser();
        return MoncarPhoneAuth.noAccountMessage;
      }
      ref.read(verifiedResetPhoneProvider.notifier).state = phone;
      if (!context.mounted) return null;
      context.pushReplacement('/auth/reset');
      return null;
  }
}
