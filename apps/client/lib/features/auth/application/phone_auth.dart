// ============================================================
// MON CAR — Authentification réelle (Firebase Auth).
//
// • Numéro + mot de passe : le mot de passe est un identifiant
//   Email/Password Firebase dont l'e-mail est dérivé du numéro
//   (`2250700112233@phone.moncar.ci`) et LIÉ au compte vérifié par SMS
//   — un seul compte Firebase par numéro, jamais de mot de passe en
//   clair côté app. ⚠️ Nécessite le fournisseur « E-mail/Mot de passe »
//   activé dans Firebase Console (Auth → Sign-in method).
// • OTP SMS : vérification du numéro à l'inscription et
//   réinitialisation du mot de passe oublié.
//
// L'envoi et la vérification du code sont faits par Firebase :
// l'application ne connaît jamais le code. Le parcours est IDENTIQUE
// pour tous les numéros — les numéros de test déclarés dans Firebase
// Console (Auth → Sign-in → Phone → Numbers to test) reçoivent le code
// de test sans envoi de SMS, uniquement parce que Firebase les
// connaît. Aucun numéro ni code de test n'est stocké dans le code.
//
// Le backend Symfony reste la source de vérité métier : une fois son
// endpoint disponible, le jeton ID Firebase de la session signée lui
// sera transmis pour créer/attacher le compte côté serveur.
// ============================================================

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class MoncarPhoneAuth {
  MoncarPhoneAuth._();

  /// Désactivé dans les tests widget (pas de plugin natif Firebase) —
  /// même garde que `NetworkMonitor.enabled` / `MoncarAnalytics.enabled`.
  static bool enabled = true;

  /// `verificationId` renvoyé par Firebase au moment du codeSent ;
  /// nécessaire pour confirmer le code saisi (voir [verifyCode]).
  static String? _verificationId;

  /// Utilisateur Firebase connecté, `null` sinon.
  static User? get firebaseUser =>
      enabled ? FirebaseAuth.instance.currentUser : null;

  /// Demande à Firebase d'envoyer le code SMS (ou d'appliquer le code
  /// de test pour un numéro de test). [onSignedIn] est appelé si
  /// Android résout la vérification automatiquement (récupération
  /// instantanée du SMS) — l'écran n'a alors plus à demander de code.
  static Future<void> sendCode(
    String fullPhone, {
    required VoidCallback onCodeSent,
    required VoidCallback onSignedIn,
    required ValueChanged<String> onError,
  }) async {
    _verificationId = null;
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: fullPhone,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) async {
        try {
          final result = await FirebaseAuth.instance.signInWithCredential(
            credential,
          );
          lastSignInWasNewUser = result.additionalUserInfo?.isNewUser ?? false;
          onSignedIn();
        } on FirebaseAuthException catch (e) {
          onError(_message(e));
        }
      },
      verificationFailed: (e) => onError(_message(e)),
      codeSent: (verificationId, _) {
        _verificationId = verificationId;
        onCodeSent();
      },
      codeAutoRetrievalTimeout: (verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  /// Confirme le code saisi auprès de Firebase. Retourne `false` en
  /// cas d'échec (code invalide/expiré, numéro non vérifié) — le
  /// message d'erreur affiché à l'utilisateur est alors dans
  /// [lastError].
  static String? lastError;

  /// `true` si la dernière vérification SMS a créé un compte Firebase
  /// (numéro jamais vu) — sert à refuser une réinitialisation de mot
  /// de passe pour un numéro sans compte.
  static bool lastSignInWasNewUser = false;

  static Future<bool> verifyCode(String code) async {
    final verificationId = _verificationId;
    if (verificationId == null) {
      lastError = "Aucune vérification en cours. Renvoyez le code.";
      return false;
    }
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: code,
      );
      final result = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      lastSignInWasNewUser = result.additionalUserInfo?.isNewUser ?? false;
      lastError = null;
      return true;
    } on FirebaseAuthException catch (e) {
      lastError = _message(e);
      return false;
    }
  }

  // ----------------------------- Mot de passe -----------------------------

  /// Identifiant technique Email/Password dérivé du numéro complet
  /// (« +2250700112233 » → « 2250700112233@phone.moncar.ci »).
  static String _emailFor(String fullPhone) =>
      '${fullPhone.replaceAll(RegExp(r'\D'), '')}@phone.moncar.ci';

  static bool _hasPassword(User user) =>
      user.providerData.any((p) => p.providerId == 'password');

  /// Connexion numéro + mot de passe. Retourne `null` si la connexion
  /// réussit, sinon le message d'erreur à afficher.
  static Future<String?> signInWithPassword(
    String fullPhone,
    String password,
  ) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailFor(fullPhone),
        password: password,
      );
      return null;
    } on FirebaseAuthException catch (e) {
      return _message(e);
    }
  }

  /// Inscription : après la vérification SMS, attache le mot de passe
  /// au compte Firebase du numéro. Retourne `null` en cas de succès.
  /// Si le numéro possède déjà un mot de passe, la session Firebase est
  /// fermée et l'utilisateur est invité à se connecter.
  static Future<String?> attachPassword(
    String fullPhone,
    String password,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'Session expirée. Recommencez la vérification.';
    if (_hasPassword(user)) {
      await FirebaseAuth.instance.signOut();
      return accountExistsMessage;
    }
    try {
      await user.linkWithCredential(
        EmailAuthProvider.credential(
          email: _emailFor(fullPhone),
          password: password,
        ),
      );
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'provider-already-linked' ||
          e.code == 'email-already-in-use' ||
          e.code == 'credential-already-in-use') {
        await FirebaseAuth.instance.signOut();
        return accountExistsMessage;
      }
      return _message(e);
    }
  }

  /// Mot de passe oublié : après la vérification SMS, remplace le mot
  /// de passe (ou en crée un pour un compte inscrit avant les mots de
  /// passe). Retourne `null` en cas de succès.
  static Future<String?> resetPassword(
    String fullPhone,
    String newPassword,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'Session expirée. Recommencez la vérification.';
    try {
      if (_hasPassword(user)) {
        await user.updatePassword(newPassword);
      } else {
        await user.linkWithCredential(
          EmailAuthProvider.credential(
            email: _emailFor(fullPhone),
            password: newPassword,
          ),
        );
      }
      return null;
    } on FirebaseAuthException catch (e) {
      return _message(e);
    }
  }

  /// Annule une vérification SMS faite pour un numéro sans compte
  /// (parcours « mot de passe oublié ») : le compte vide que Firebase
  /// vient de créer est supprimé.
  static Future<void> discardNewUser() async {
    try {
      await FirebaseAuth.instance.currentUser?.delete();
    } on FirebaseAuthException {
      // Compte déjà supprimé ou session expirée : rien à nettoyer.
    }
    await FirebaseAuth.instance.signOut();
  }

  /// Ferme la session Firebase (vérification abandonnée).
  static Future<void> signOut() => FirebaseAuth.instance.signOut();

  static const accountExistsMessage =
      'Un compte existe déjà avec ce numéro. Connectez-vous.';
  static const noAccountMessage =
      "Aucun compte n'est associé à ce numéro. Créez un compte.";

  /// Messages d'erreur en français, sans jargon technique.
  static String _message(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
      case 'invalid-email':
        return 'Numéro ou mot de passe incorrect.';
      case 'user-disabled':
        return 'Ce compte est suspendu. Contactez le support MON CAR.';
      case 'weak-password':
        return 'Mot de passe trop faible. Choisissez-en un plus robuste.';
      case 'requires-recent-login':
        return 'Session expirée. Recommencez la vérification par SMS.';
      case 'invalid-phone-number':
        return 'Numéro de téléphone invalide.';
      case 'too-many-requests':
        return 'Trop de tentatives. Réessayez dans quelques minutes.';
      case 'invalid-verification-code':
        return 'Code OTP invalide ou expiré.';
      case 'invalid-verification-id':
        return 'Code expiré. Renvoyez un nouveau code.';
      case 'quota-exceeded':
        return 'Quota de SMS atteint. Réessayez plus tard.';
      case 'network-request-failed':
        return 'Connexion réseau indisponible. Réessayez.';
      case 'operation-not-allowed':
        if ((e.message ?? '').contains('region')) {
          return "L'envoi de SMS vers ce pays n'est pas encore activé. "
              'Réessayez plus tard ou contactez le support MON CAR.';
        }
        return "La connexion par SMS n'est pas activée pour ce projet.";
      default:
        return 'Vérification impossible. (${e.code})';
    }
  }
}
