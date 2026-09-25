// ============================================================
// MON CAR PRO — Couche d'accès API (contract-first).
//
// Les chemins cités sont ceux de la liste de cadrage de la roadmap
// (§9 API / endpoints). Ils ne seront figés qu'au gel du contrat
// OpenAPI (le lundi du sprint concerné) : tant que ce n'est pas le cas,
// l'app utilise [MockProApi]. Aucune règle métier n'est tranchée ici :
// le serveur décide (montants, sièges, statuts, permissions).
// ============================================================

library;

import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models.dart';
import 'mock_data.dart';

/// Erreur métier normalisée (format d'erreur unique §11.2).
class ProApiException implements Exception {
  const ProApiException(this.message, {this.statusCode = -1});
  final String message;
  final int statusCode;
  @override
  String toString() => message;
}

/// Demande de création de compte agent (inscription).
class SignupRequest {
  const SignupRequest({
    required this.role,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.email,
    required this.company,
    required this.station,
    required this.matricule,
    required this.password,
  });

  final ProRole role;
  final String firstName;
  final String lastName;

  /// Numéro local à 10 chiffres (« 0700000001 »).
  final String phone;
  final String email;
  final String company;
  final String station;
  final String matricule;
  final String password;
}

abstract interface class ProApi {
  /// POST /auth/connexion-pro — renvoie l'agent et ses capacités
  /// (`GET /me/capacites` : profils autorisés, jamais codés en dur).
  Future<ProUser> login({required String phone, required String password});

  /// POST /auth/inscription — contrôle la demande puis envoie un code SMS
  /// (POST /auth/otp/demande). Le compte n'existe qu'après vérification.
  Future<void> register(SignupRequest request);

  /// POST /auth/otp/verification (inscription) — crée le compte.
  Future<ProUser> confirmSignup({required String phone, required String code});

  /// POST /auth/otp/demande — envoi ou renvoi du code SMS.
  /// [mustExist] : le numéro doit correspondre à un compte (mot de passe
  /// oublié).
  Future<void> requestOtp(String phone, {bool mustExist = false});

  /// POST /auth/otp/verification (mot de passe oublié).
  Future<void> verifyResetOtp({required String phone, required String code});

  /// Nouveau mot de passe après vérification du numéro.
  Future<void> resetPassword({required String phone, required String password});

  /// POST /auth/mot-de-passe/temporaire (changement obligatoire).
  Future<void> changeTemporaryPassword({
    required String phone,
    required String newPassword,
  });

  /// Rejoue une opération terrain mise en file (scans en lot, statuts,
  /// positions, incidents…) avec son `Idempotency-Key` :
  /// POST /embarquements/scans, POST /pro/voyages/{id}/statut,
  /// POST /pro/positions, POST /pro/incidents, POST /locations/{id}/remise…
  /// Renvoie `true` si le serveur l'a déjà reçue (dédoublonnage).
  Future<bool> replay(SyncOp op);

  /// POST /locations/{id}/remise ou /restitutions — renvoie la référence
  /// de preuve / rapport générée par le serveur.
  Future<String> submitRentalTask(RentalTask task);
}

/// Numéro local « 0700000001 » (ou « +225… ») → 10 chiffres.
String localDigits(String phone) {
  final d = phone.replaceAll(RegExp(r'\D'), '');
  return d.length == 13 && d.startsWith('225') ? d.substring(3) : d;
}

/// ⚠️ MOCK : simule le serveur (latence, comptes, code SMS, idempotence).
///
/// Comptes de démonstration (mot de passe « Moncar2026 ») :
/// 07 00 00 00 01 contrôleur · 02 convoyeur · 03 chauffeur ·
/// 04 agent BUSINESS · 05 compte multi-postes. Avec le mot de passe
/// « Temp1234 », ces comptes simulent un mot de passe temporaire.
/// Les comptes créés par inscription sont conservés sur le téléphone.
class MockProApi implements ProApi {
  MockProApi({this.latency = const Duration(milliseconds: 700), this.prefs}) {
    _load();
  }

  final Duration latency;

  /// Stockage des comptes créés (null dans les tests).
  final SharedPreferences? prefs;
  final _received = <String>{};
  final _random = Random();

  /// Code SMS accepté en démonstration.
  static const demoOtp = '123456';
  static const demoPassword = 'Moncar2026';
  static const _kAccounts = 'pro.mock.accounts';

  /// numéro local → (agent, mot de passe).
  final _accounts = <String, (ProUser, String)>{};
  final _pending = <String, SignupRequest>{};

  Future<void> _wait([double factor = 1]) => Future.delayed(
    Duration(milliseconds: (latency.inMilliseconds * factor).round()),
  );

  static bool _isDemo(String phone) => phone.startsWith('07000000');

  void _load() {
    for (final (i, role) in ProRole.values.indexed) {
      final phone = '070000000${i + 1}';
      _accounts[phone] = (demoAccount(phone, [role]), demoPassword);
    }
    _accounts['0700000005'] = (
      demoAccount('0700000005', ProRole.values),
      demoPassword,
    );
    final raw = prefs?.getString(_kAccounts);
    if (raw == null) return;
    try {
      final map = (jsonDecode(raw) as Map).cast<String, dynamic>();
      for (final e in map.entries) {
        final j = (e.value as Map).cast<String, dynamic>();
        _accounts[e.key] = (
          ProUser.fromJson((j['user'] as Map).cast<String, dynamic>()),
          j['password'] as String,
        );
      }
    } catch (_) {
      // Données locales illisibles : on repart des comptes de démo.
    }
  }

  void _save() {
    final p = prefs;
    if (p == null) return;
    final created = {
      for (final e in _accounts.entries)
        if (!_isDemo(e.key))
          e.key: {'user': e.value.$1.toJson(), 'password': e.value.$2},
    };
    p.setString(_kAccounts, jsonEncode(created));
  }

  @override
  Future<ProUser> login({
    required String phone,
    required String password,
  }) async {
    await _wait();
    final acc = _accounts[localDigits(phone)];
    if (acc == null) {
      throw const ProApiException(
        'Aucun compte pour ce numéro. Créez votre compte.',
        statusCode: 404,
      );
    }
    final (user, pwd) = acc;
    final temporary = password == 'Temp1234' && _isDemo(localDigits(phone));
    if (password != pwd && !temporary) {
      throw const ProApiException(
        'Numéro ou mot de passe incorrect.',
        statusCode: 401,
      );
    }
    return user.copyWith(mustChangePassword: temporary);
  }

  @override
  Future<void> register(SignupRequest request) async {
    await _wait();
    final phone = localDigits(request.phone);
    if (_accounts.containsKey(phone)) {
      throw const ProApiException(
        'Un compte existe déjà pour ce numéro. Connectez-vous.',
        statusCode: 409,
      );
    }
    _pending[phone] = request;
  }

  @override
  Future<ProUser> confirmSignup({
    required String phone,
    required String code,
  }) async {
    await _wait();
    final p = localDigits(phone);
    final req = _pending[p];
    if (req == null) {
      throw const ProApiException(
        'Inscription expirée. Recommencez la création du compte.',
        statusCode: 410,
      );
    }
    if (code != demoOtp) {
      throw const ProApiException(
        'Code incorrect. Vérifiez le SMS reçu.',
        statusCode: 422,
      );
    }
    final user = ProUser(
      id: 'agt-${DateTime.now().millisecondsSinceEpoch % 100000}',
      name: '${req.firstName.trim()} ${req.lastName.trim()}',
      phone: formatCiPhone(p),
      company: req.company,
      station: req.station,
      roles: [req.role],
    );
    _accounts[p] = (user, req.password);
    _pending.remove(p);
    _save();
    return user;
  }

  @override
  Future<void> requestOtp(String phone, {bool mustExist = false}) async {
    await _wait(0.8);
    if (mustExist && !_accounts.containsKey(localDigits(phone))) {
      throw const ProApiException(
        'Aucun compte pour ce numéro.',
        statusCode: 404,
      );
    }
  }

  @override
  Future<void> verifyResetOtp({
    required String phone,
    required String code,
  }) async {
    await _wait();
    if (code != demoOtp) {
      throw const ProApiException(
        'Code incorrect. Vérifiez le SMS reçu.',
        statusCode: 422,
      );
    }
  }

  @override
  Future<void> resetPassword({
    required String phone,
    required String password,
  }) async {
    await _wait();
    final p = localDigits(phone);
    final acc = _accounts[p];
    if (acc == null) {
      throw const ProApiException(
        'Aucun compte pour ce numéro.',
        statusCode: 404,
      );
    }
    _accounts[p] = (acc.$1, password);
    _save();
  }

  @override
  Future<void> changeTemporaryPassword({
    required String phone,
    required String newPassword,
  }) => resetPassword(phone: phone, password: newPassword);

  @override
  Future<bool> replay(SyncOp op) async {
    await _wait(0.5);
    // 5 % d'échecs réseau simulés : l'opération reste en file.
    if (_random.nextDouble() < 0.05) {
      throw const ProApiException('Délai dépassé. Nouvel essai automatique.');
    }
    return !_received.add(op.idempotencyKey);
  }

  @override
  Future<String> submitRentalTask(RentalTask task) async {
    await _wait(1.3);
    final stamp = DateTime.now().millisecondsSinceEpoch % 100000;
    final prefix = task.type == RentalTaskType.remise ? 'PRF-REM' : 'RPT-RST';
    return '$prefix-${stamp.toString().padLeft(5, '0')}';
  }
}
