// ============================================================
// MON CAR PRO — Session agent (connexion, profil actif).
//
// ⚠️ MOCK : la session est persistée dans les préférences locales. Le
// stockage sécurisé des jetons (core_api SecureSessionStore) sera
// branché avec l'endpoint réel de connexion PRO (AUTH-002).
// ============================================================

library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models.dart';
import 'app_providers.dart';

@immutable
class SessionState {
  const SessionState({this.onboarded = false, this.user, this.activeRole});

  final bool onboarded;
  final ProUser? user;

  /// Profil choisi parmi ceux autorisés par le serveur.
  final ProRole? activeRole;

  bool get isAuthenticated => user != null;
  bool get mustChangePassword => user?.mustChangePassword ?? false;
}

class SessionController extends Notifier<SessionState> {
  static const _kOnboarded = 'pro.onboarded';
  static const _kUser = 'pro.session.user';
  static const _kRole = 'pro.session.role';

  SharedPreferences? get _prefs => ref.read(sharedPrefsProvider);

  @override
  SessionState build() {
    final p = _prefs;
    if (p == null) return const SessionState();
    ProUser? user;
    final raw = p.getString(_kUser);
    if (raw != null) {
      try {
        user = ProUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        user = null;
      }
    }
    final role = ProRole.fromName(p.getString(_kRole));
    return SessionState(
      onboarded: p.getBool(_kOnboarded) ?? false,
      user: user,
      activeRole: user != null && role != null && user.roles.contains(role)
          ? role
          : null,
    );
  }

  void completeOnboarding() {
    state = SessionState(
      onboarded: true,
      user: state.user,
      activeRole: state.activeRole,
    );
    _prefs?.setBool(_kOnboarded, true);
  }

  /// Ouvre la session. Un seul profil autorisé → sélection automatique.
  void signIn(ProUser user) {
    final role = user.roles.length == 1 ? user.roles.first : null;
    state = SessionState(onboarded: true, user: user, activeRole: role);
    _persist();
  }

  void passwordChanged() {
    final u = state.user;
    if (u == null) return;
    signIn(u.copyWith(mustChangePassword: false));
  }

  void selectRole(ProRole role) {
    final u = state.user;
    if (u == null || !u.roles.contains(role)) return;
    state = SessionState(onboarded: true, user: u, activeRole: role);
    _persist();
  }

  /// Revient au choix du profil sans se déconnecter.
  void clearRole() {
    state = SessionState(onboarded: true, user: state.user);
    _prefs?.remove(_kRole);
  }

  /// Déconnexion : les données locales sensibles sont effacées (CDC).
  void signOut() {
    state = const SessionState(onboarded: true);
    _prefs?.remove(_kUser);
    _prefs?.remove(_kRole);
  }

  void _persist() {
    final p = _prefs;
    final u = state.user;
    if (p == null) return;
    if (u != null) p.setString(_kUser, jsonEncode(u.toJson()));
    final r = state.activeRole;
    if (r != null) {
      p.setString(_kRole, r.name);
    } else {
      p.remove(_kRole);
    }
  }
}

final sessionProvider = NotifierProvider<SessionController, SessionState>(
  SessionController.new,
);

/// Objet d'une vérification par code SMS.
enum OtpPurpose { signup, reset }

/// Vérification en cours (inscription ou mot de passe oublié). Reste en
/// mémoire uniquement : le mot de passe ne transite jamais par l'URL.
@immutable
class PendingAuth {
  const PendingAuth({
    required this.purpose,
    required this.phone,
    this.verified = false,
  });

  final OtpPurpose purpose;

  /// Numéro local à 10 chiffres.
  final String phone;

  /// Code SMS validé (mot de passe oublié → écran nouveau mot de passe).
  final bool verified;
}

class PendingAuthController extends Notifier<PendingAuth?> {
  @override
  PendingAuth? build() => null;

  void start(OtpPurpose purpose, String phone) =>
      state = PendingAuth(purpose: purpose, phone: phone);

  void markVerified() {
    final s = state;
    if (s != null) {
      state = PendingAuth(purpose: s.purpose, phone: s.phone, verified: true);
    }
  }

  void clear() => state = null;
}

final pendingAuthProvider =
    NotifierProvider<PendingAuthController, PendingAuth?>(
      PendingAuthController.new,
    );

/// Profil actif (raccourci).
final activeRoleProvider = Provider<ProRole?>(
  (ref) => ref.watch(sessionProvider.select((s) => s.activeRole)),
);
