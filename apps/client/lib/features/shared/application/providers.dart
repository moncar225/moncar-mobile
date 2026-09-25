// ============================================================
// MON CAR — État applicatif (portage des stores Zustand de
// `src/lib/store.ts` + `src/lib/favorites.ts` vers Riverpod).
// ============================================================

library;

import 'dart:async';
import 'dart:convert';
import 'dart:io' show InternetAddress;
import 'dart:math';
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/mock_store.dart';
import '../domain/models.dart';

// ----------------------------- Store mock -----------------------------

/// Instance singleton du store mock. Écouter `mockStoreChangesProvider`
/// pour rafraîchir l'UI à chaque mutation.
final mockStoreProvider = Provider<MockStore>((ref) {
  final store = MockStore();
  ref.onDispose(store.dispose);
  return store;
});

/// Provider « int » qui change d'identifiant à chaque mutation du store
/// mock : `ref.watch(mockStoreChangesProvider)` dans un écran force son
/// rebuild dès qu'une réservation/colis/… change.
final mockStoreChangesProvider = NotifierProvider<_MockStoreTick, int>(
  _MockStoreTick.new,
);

class _MockStoreTick extends Notifier<int> {
  @override
  int build() {
    final store = ref.watch(mockStoreProvider);
    void onChange() => state = state + 1;
    store.addListener(onChange);
    ref.onDispose(() => store.removeListener(onChange));
    return 0;
  }
}

// ----------------------------- Stockage local -----------------------------

/// Préférences locales, injectées dans `main()` (override). `null` dans
/// les tests : l'état reste alors en mémoire, sans persistance.
final sharedPrefsProvider = Provider<SharedPreferences?>((ref) => null);

// ----------------------------- Auth -----------------------------

/// État d'authentification. ⚠️ MOCK : session en mémoire uniquement —
/// la persistance sécurisée (core_api SecureSessionStore) sera branchée
/// quand l'endpoint `/auth/me` réel sera disponible.
class AuthState {
  const AuthState({this.user, this.accessToken, this.isPending = false});

  final AppUser? user;
  final String? accessToken;
  final bool isPending;

  bool get isAuthenticated => user != null;
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    // ⚠️ MOCK : au premier lancement l'utilisateur n'est pas connecté —
    // le flux splash → onboarding → login → OTP s'affiche. La session
    // persistée (core_api SecureSessionStore) sera restaurée ici quand
    // l'endpoint `/auth/me` réel sera disponible.
    return const AuthState();
  }

  void setSession(AppUser user, String accessToken) {
    state = AuthState(user: user, accessToken: accessToken);
  }

  /// ⚠️ MOCK : PATCH /users/me — met à jour l'utilisateur en mémoire.
  void updateUser(AppUser user) {
    state = AuthState(
      user: user,
      accessToken: state.accessToken,
      isPending: state.isPending,
    );
  }

  void clearSession() {
    state = AuthState(user: null, accessToken: null);
  }

  void setPending(bool pending) {
    state = AuthState(
      user: state.user,
      accessToken: state.accessToken,
      isPending: pending,
    );
  }
}

final authProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

/// Déconnexion locale : session, photo, réglages de sécurité et
/// brouillons effacés. ⚠️ MOCK : POST /auth/logout — la session locale
/// est effacée même si le backend renvoie une erreur.
void signOut(WidgetRef ref) {
  ref.read(authProvider.notifier).clearSession();
  ref.read(profilePhotoProvider.notifier).state = null;
  ref.read(securitySettingsProvider.notifier).reset();
  ref.read(bookingDraftProvider.notifier).reset();
}

/// Photo de profil de l'utilisateur connecté (octets de l'image).
/// ⚠️ MOCK : en mémoire — sera remplacée par `photoUrl` après upload
/// via POST /users/me/photo.
final profilePhotoProvider = StateProvider<Uint8List?>((ref) => null);

/// Réglages de sécurité locaux : code PIN de verrouillage, biométrie,
/// confirmation OTP des paiements.
class SecuritySettings {
  const SecuritySettings({
    this.pinHash,
    this.pinSalt,
    this.biometric = false,
    this.otpPayments = true,
  });

  /// SHA-256(sel + PIN) — le PIN n'est jamais stocké en clair.
  final String? pinHash;
  final String? pinSalt;
  final bool biometric;
  final bool otpPayments;

  bool get hasPin => pinHash != null;
}

/// Réglages de sécurité, persistés sur l'appareil (shared_preferences).
class SecurityController extends Notifier<SecuritySettings> {
  static const _kHash = 'security.pinHash';
  static const _kSalt = 'security.pinSalt';
  static const _kBio = 'security.biometric';
  static const _kOtp = 'security.otpPayments';

  SharedPreferences? get _prefs => ref.read(sharedPrefsProvider);

  @override
  SecuritySettings build() {
    final p = _prefs;
    if (p == null) return const SecuritySettings();
    return SecuritySettings(
      pinHash: p.getString(_kHash),
      pinSalt: p.getString(_kSalt),
      biometric: p.getBool(_kBio) ?? false,
      otpPayments: p.getBool(_kOtp) ?? true,
    );
  }

  static String _hash(String salt, String pin) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();

  void setPin(String pin) {
    final rnd = Random.secure();
    final salt = base64Url.encode(List.generate(16, (_) => rnd.nextInt(256)));
    final hash = _hash(salt, pin);
    _prefs?.setString(_kSalt, salt);
    _prefs?.setString(_kHash, hash);
    state = SecuritySettings(
      pinHash: hash,
      pinSalt: salt,
      biometric: state.biometric,
      otpPayments: state.otpPayments,
    );
  }

  bool verifyPin(String pin) {
    final salt = state.pinSalt;
    final hash = state.pinHash;
    if (salt == null || hash == null) return false;
    return _hash(salt, pin) == hash;
  }

  /// Supprime le PIN (et la biométrie, qui en dépend).
  void clearPin() {
    _prefs?.remove(_kHash);
    _prefs?.remove(_kSalt);
    _prefs?.setBool(_kBio, false);
    state = SecuritySettings(otpPayments: state.otpPayments);
  }

  void setBiometric(bool v) {
    _prefs?.setBool(_kBio, v);
    state = SecuritySettings(
      pinHash: state.pinHash,
      pinSalt: state.pinSalt,
      biometric: v,
      otpPayments: state.otpPayments,
    );
  }

  void setOtpPayments(bool v) {
    _prefs?.setBool(_kOtp, v);
    state = SecuritySettings(
      pinHash: state.pinHash,
      pinSalt: state.pinSalt,
      biometric: state.biometric,
      otpPayments: v,
    );
  }

  /// Déconnexion : réglages remis à zéro sur l'appareil.
  void reset() {
    for (final k in [_kHash, _kSalt, _kBio, _kOtp]) {
      _prefs?.remove(k);
    }
    state = const SecuritySettings();
  }
}

final securitySettingsProvider =
    NotifierProvider<SecurityController, SecuritySettings>(
      SecurityController.new,
    );

// ----------------------------- Préférences -----------------------------

enum AppThemeChoice { clair, sombre, systeme }

/// Préférences d'affichage et de notifications, persistées.
class AppPreferences {
  const AppPreferences({
    this.theme = AppThemeChoice.clair,
    this.languageCode = 'fr',
    this.notifications = defaultNotifications,
  });

  static const defaultNotifications = {
    'voyager': true,
    'colis': true,
    'location': true,
    'paiements': true,
    'promotions': false,
    'securite': true,
  };

  final AppThemeChoice theme;
  final String languageCode;
  final Map<String, bool> notifications;
}

class AppPreferencesController extends Notifier<AppPreferences> {
  static const _kTheme = 'prefs.theme';
  static const _kLang = 'prefs.language';
  static const _kNotif = 'prefs.notifications';

  SharedPreferences? get _prefs => ref.read(sharedPrefsProvider);

  @override
  AppPreferences build() {
    final p = _prefs;
    if (p == null) return const AppPreferences();
    final raw = p.getString(_kNotif);
    final saved = raw == null
        ? const <String, bool>{}
        : (jsonDecode(raw) as Map<String, dynamic>).cast<String, bool>();
    return AppPreferences(
      theme: AppThemeChoice.values.firstWhere(
        (t) => t.name == p.getString(_kTheme),
        orElse: () => AppThemeChoice.clair,
      ),
      languageCode: p.getString(_kLang) ?? 'fr',
      notifications: {...AppPreferences.defaultNotifications, ...saved},
    );
  }

  void setTheme(AppThemeChoice t) {
    _prefs?.setString(_kTheme, t.name);
    state = AppPreferences(
      theme: t,
      languageCode: state.languageCode,
      notifications: state.notifications,
    );
  }

  void setLanguage(String code) {
    _prefs?.setString(_kLang, code);
    state = AppPreferences(
      theme: state.theme,
      languageCode: code,
      notifications: state.notifications,
    );
  }

  void setNotification(String key, bool value) {
    final next = {...state.notifications, key: value};
    _prefs?.setString(_kNotif, jsonEncode(next));
    state = AppPreferences(
      theme: state.theme,
      languageCode: state.languageCode,
      notifications: next,
    );
  }
}

final appPreferencesProvider =
    NotifierProvider<AppPreferencesController, AppPreferences>(
      AppPreferencesController.new,
    );

/// Marqueur « premier lancement » pour le flux onboarding. ⚠️ MOCK :
/// en mémoire ; à persister (SharedPreferences) plus tard.
final onboardingSeenProvider = StateProvider<bool>((ref) => false);

// ----------------------------- Brouillon de réservation -----------------------------

/// Segment déjà choisi d'un aller-retour (trajet, arrêts, sièges).
class DraftLeg {
  const DraftLeg({
    required this.trip,
    required this.boardingStopId,
    required this.alightingStopId,
    required this.seats,
  });

  final Trip trip;
  final String boardingStopId;
  final String alightingStopId;
  final List<String> seats;
}

/// Brouillon éphémère du parcours de réservation Voyager, partagé
/// entre les écrans sans prop drilling (équivalent `useBookingDraft`).
///
/// Aller-retour : l'aller est choisi en premier (trajet → sièges) et
/// mémorisé dans [outboundLeg], puis le retour ([returnLeg]). Les champs
/// principaux ([trip], arrêts, [selectedSeats]) portent l'aller au
/// moment de la saisie des passagers.
class BookingDraft {
  const BookingDraft({
    this.trip,
    this.boardingStopId,
    this.alightingStopId,
    this.selectedSeats = const [],
    this.passengers = const [],
    this.passengerCount = 1,
    this.tripType = TripType.allerSimple,
    this.returnDate,
    this.outboundLeg,
    this.returnLeg,
    this.paymentMethod,
    this.promoCode,
    // Totaux calculés « serveur » — jamais recalculés côté client.
    this.amountXOF,
    this.feesXOF,
    this.discountXOF,
    this.totalXOF,
  });

  final Trip? trip;
  final String? boardingStopId;
  final String? alightingStopId;
  final List<String> selectedSeats;
  final List<Passenger> passengers;

  /// Nombre de passagers choisi à la recherche (1 à [maxPassengers]) :
  /// c'est le nombre de sièges attendu sur le plan de sièges.
  final int passengerCount;
  final TripType tripType;

  /// Date du retour choisie à la recherche (aller-retour).
  final String? returnDate;
  final DraftLeg? outboundLeg;
  final DraftLeg? returnLeg;
  final PaymentMethod? paymentMethod;
  final String? promoCode;
  final int? amountXOF;
  final int? feesXOF;
  final int? discountXOF;
  final int? totalXOF;

  BookingDraft copyWith({
    Trip? trip,
    String? boardingStopId,
    String? alightingStopId,
    List<String>? selectedSeats,
    List<Passenger>? passengers,
    int? passengerCount,
    TripType? tripType,
    String? returnDate,
    DraftLeg? outboundLeg,
    DraftLeg? returnLeg,
    bool clearLegs = false,
    PaymentMethod? paymentMethod,
    String? promoCode,
    bool clearPromoCode = false,
    int? amountXOF,
    int? feesXOF,
    int? discountXOF,
    int? totalXOF,
  }) {
    return BookingDraft(
      trip: trip ?? this.trip,
      boardingStopId: boardingStopId ?? this.boardingStopId,
      alightingStopId: alightingStopId ?? this.alightingStopId,
      selectedSeats: selectedSeats ?? this.selectedSeats,
      passengers: passengers ?? this.passengers,
      passengerCount: passengerCount ?? this.passengerCount,
      tripType: tripType ?? this.tripType,
      returnDate: returnDate ?? this.returnDate,
      outboundLeg: clearLegs ? outboundLeg : (outboundLeg ?? this.outboundLeg),
      returnLeg: clearLegs ? returnLeg : (returnLeg ?? this.returnLeg),
      paymentMethod: paymentMethod ?? this.paymentMethod,
      promoCode: clearPromoCode ? null : (promoCode ?? this.promoCode),
      amountXOF: amountXOF ?? this.amountXOF,
      feesXOF: feesXOF ?? this.feesXOF,
      discountXOF: discountXOF ?? this.discountXOF,
      totalXOF: totalXOF ?? this.totalXOF,
    );
  }
}

const BookingDraft _emptyBookingDraft = BookingDraft();

/// Nombre maximal de passagers (et donc de sièges) par réservation.
const maxPassengers = 5;

class BookingDraftController extends Notifier<BookingDraft> {
  @override
  BookingDraft build() => _emptyBookingDraft;

  void patch(BookingDraft delta) {
    final d = state;
    state = d.copyWith(
      trip: delta.trip,
      boardingStopId: delta.boardingStopId,
      alightingStopId: delta.alightingStopId,
      selectedSeats: delta.selectedSeats,
      passengers: delta.passengers,
      passengerCount: delta.passengerCount,
      tripType: delta.tripType,
      paymentMethod: delta.paymentMethod,
      promoCode: delta.promoCode,
      clearPromoCode: delta.promoCode == null,
      amountXOF: delta.amountXOF,
      feesXOF: delta.feesXOF,
      discountXOF: delta.discountXOF,
      totalXOF: delta.totalXOF,
    );
  }

  /// Mise à jour par transformation (préférer à [patch], qui efface
  /// `promoCode` et réinitialise `tripType` quand ils sont omis).
  void update(BookingDraft Function(BookingDraft) fn) => state = fn(state);

  void reset() => state = _emptyBookingDraft;
}

final bookingDraftProvider =
    NotifierProvider<BookingDraftController, BookingDraft>(
      BookingDraftController.new,
    );

/// Dernière réservation créée (écran de confirmation / billet).
final lastBookingProvider = StateProvider<Booking?>((ref) => null);

// ----------------------------- Recherche de location -----------------------------

DateTime _defaultRentalStart() {
  final d = DateTime.now().add(const Duration(days: 1));
  return DateTime(d.year, d.month, d.day, 8);
}

/// Formulaire « Louer un véhicule » (§26 à §32), conservé entre les
/// critères, les résultats et la fiche véhicule.
class RentalSearch {
  RentalSearch({
    this.pickupCity = 'Abidjan',
    this.pickupLabel = 'Abidjan',
    this.usedGps = false,
    this.area = RentalArea.interieur,
    this.destinationCity,
    this.purpose = RentalPurpose.personnel,
    this.persons = 1,
    this.collective,
    this.type,
    DateTime? start,
    this.durationPreset = RentalDurationPreset.journee,
    this.count = 2,
    this.customEnd,
    this.withDriver = false,
  }) : start = start ?? _defaultRentalStart();

  final String pickupCity;
  final String pickupLabel;
  final bool usedGps;
  final RentalArea area;
  final String? destinationCity;
  final RentalPurpose purpose;
  final int persons;

  /// `null` : toutes catégories ; `true` : transport collectif.
  final bool? collective;
  final VehicleType? type;

  /// Heure prévue de prise en charge.
  final DateTime start;
  final RentalDurationPreset durationPreset;

  /// Nombre de jours (plusieurs jours) ou de semaines (plusieurs semaines).
  final int count;
  final DateTime? customEnd;
  final bool withDriver;

  /// Un VTC est obligatoirement avec chauffeur (§32).
  bool get driverForced => type == VehicleType.vtc;
  bool get effectiveWithDriver => withDriver || driverForced;

  DateTime get end => switch (durationPreset) {
    RentalDurationPreset.demiJournee => start.add(const Duration(hours: 6)),
    RentalDurationPreset.journee => start.add(const Duration(days: 1)),
    RentalDurationPreset.plusieursJours => start.add(Duration(days: count)),
    RentalDurationPreset.semaine => start.add(const Duration(days: 7)),
    RentalDurationPreset.plusieursSemaines => start.add(
      Duration(days: 7 * count),
    ),
    RentalDurationPreset.mois => start.add(const Duration(days: 30)),
    RentalDurationPreset.personnalisee =>
      customEnd != null && customEnd!.isAfter(start)
          ? customEnd!
          : start.add(const Duration(days: 1)),
  };

  /// Message bloquant éventuel (destination manquante, date passée…).
  String? get validationError {
    if (area == RentalArea.exterieur &&
        (destinationCity == null || destinationCity!.isEmpty)) {
      return 'Indiquez le lieu de destination (déplacement extérieur).';
    }
    if (start.isBefore(DateTime.now())) {
      return "L'heure de prise en charge est déjà passée.";
    }
    if (!end.isAfter(start)) return 'La fin doit suivre le début.';
    return null;
  }

  RentalCriteria toCriteria() => RentalCriteria(
    pickupCity: pickupCity,
    pickupLabel: pickupLabel,
    usedGps: usedGps,
    area: area,
    destinationCity: area == RentalArea.exterieur ? destinationCity : null,
    purpose: purpose,
    persons: persons,
    collective: collective,
    type: type,
    start: start.toIso8601String(),
    end: end.toIso8601String(),
    durationPreset: durationPreset,
    withDriver: effectiveWithDriver,
  );

  RentalSearch copyWith({
    String? pickupCity,
    String? pickupLabel,
    bool? usedGps,
    RentalArea? area,
    String? destinationCity,
    RentalPurpose? purpose,
    int? persons,
    bool? collective,
    bool clearCollective = false,
    VehicleType? type,
    bool clearType = false,
    DateTime? start,
    RentalDurationPreset? durationPreset,
    int? count,
    DateTime? customEnd,
    bool? withDriver,
  }) {
    return RentalSearch(
      pickupCity: pickupCity ?? this.pickupCity,
      pickupLabel: pickupLabel ?? this.pickupLabel,
      usedGps: usedGps ?? this.usedGps,
      area: area ?? this.area,
      destinationCity: destinationCity ?? this.destinationCity,
      purpose: purpose ?? this.purpose,
      persons: persons ?? this.persons,
      collective: clearCollective ? null : (collective ?? this.collective),
      type: clearType ? null : (type ?? this.type),
      start: start ?? this.start,
      durationPreset: durationPreset ?? this.durationPreset,
      count: count ?? this.count,
      customEnd: customEnd ?? this.customEnd,
      withDriver: withDriver ?? this.withDriver,
    );
  }
}

class RentalSearchController extends Notifier<RentalSearch> {
  @override
  RentalSearch build() => RentalSearch();

  void update(RentalSearch Function(RentalSearch) fn) => state = fn(state);

  void reset() => state = RentalSearch();
}

final rentalSearchProvider =
    NotifierProvider<RentalSearchController, RentalSearch>(
      RentalSearchController.new,
    );

// ----------------------------- Favoris + recherches récentes -----------------------------

class FavoriteRoute {
  const FavoriteRoute({
    required this.id,
    required this.origin,
    required this.destination,
    required this.addedAt,
    this.label,
  });

  /// `${origin}-${destination}`.
  final String id;
  final String origin;
  final String destination;
  final String? label;
  final DateTime addedAt;
}

class RecentSearch {
  const RecentSearch({
    required this.id,
    required this.origin,
    required this.destination,
    required this.date,
    required this.passengers,
    required this.searchedAt,
  });

  final String id;
  final String origin;
  final String destination;
  final String date;
  final int passengers;
  final DateTime searchedAt;
}

class FavoritesController
    extends
        Notifier<
          ({List<FavoriteRoute> favorites, List<RecentSearch> recents})
        > {
  static const _maxFavorites = 10;
  static const _maxRecents = 8;

  @override
  ({List<FavoriteRoute> favorites, List<RecentSearch> recents}) build() =>
      (favorites: const <FavoriteRoute>[], recents: const <RecentSearch>[]);

  void addFavorite(String origin, String destination) {
    final o = origin.trim();
    final d = destination.trim();
    if (o.isEmpty || d.isEmpty || o == d) return;
    final id = '$o-$d';
    if (state.favorites.any((f) => f.id == id)) return;
    state = (
      favorites: [
        FavoriteRoute(
          id: id,
          origin: o,
          destination: d,
          addedAt: DateTime.now(),
        ),
        ...state.favorites,
      ].take(_maxFavorites).toList(),
      recents: state.recents,
    );
  }

  void removeFavorite(String id) {
    state = (
      favorites: state.favorites.where((f) => f.id != id).toList(),
      recents: state.recents,
    );
  }

  void removeFavoriteByRoute(String origin, String destination) {
    removeFavorite('${origin.trim()}-${destination.trim()}');
  }

  bool isFavorite(String origin, String destination) => state.favorites.any(
    (f) => f.id == '${origin.trim()}-${destination.trim()}',
  );

  void addRecent({
    required String origin,
    required String destination,
    required String date,
    required int passengers,
  }) {
    final o = origin.trim();
    final d = destination.trim();
    if (o.isEmpty || d.isEmpty || o == d) return;
    final id = '$o-$d-$date-${DateTime.now().millisecondsSinceEpoch}';
    state = (
      favorites: state.favorites,
      recents: [
        RecentSearch(
          id: id,
          origin: o,
          destination: d,
          date: date,
          passengers: passengers,
          searchedAt: DateTime.now(),
        ),
        ...state.recents,
      ].take(_maxRecents).toList(),
    );
  }

  void clearRecents() {
    state = (favorites: state.favorites, recents: const <RecentSearch>[]);
  }
}

final favoritesProvider =
    NotifierProvider<
      FavoritesController,
      ({List<FavoriteRoute> favorites, List<RecentSearch> recents})
    >(FavoritesController.new);

// ----------------------------- État UI -----------------------------

/// Connexion réseau réelle : interface active (connectivity_plus) puis
/// vérification qu'Internet répond (résolution DNS). En ligne par défaut
/// tant que rien n'indique le contraire (tests, web).
class NetworkMonitor extends Notifier<bool> {
  StreamSubscription<List<ConnectivityResult>>? _sub;
  Timer? _retry;

  /// Désactivé dans les tests (pas de plugin natif).
  static bool enabled = true;

  @override
  bool build() {
    if (enabled && !kIsWeb) {
      _sub = Connectivity().onConnectivityChanged.listen(_onChange);
      Connectivity().checkConnectivity().then(_onChange).ignore();
    }
    ref.onDispose(() {
      _sub?.cancel();
      _retry?.cancel();
    });
    return true;
  }

  Future<void> _onChange(List<ConnectivityResult> results) async {
    _retry?.cancel();
    final hasInterface = results.any((r) => r != ConnectivityResult.none);
    if (!hasInterface) {
      state = false;
      return;
    }
    final reachable = await _internetReachable();
    state = reachable;
    // Wi-Fi sans Internet : on revérifie périodiquement.
    if (!reachable) {
      _retry = Timer(const Duration(seconds: 10), () => _onChange(results));
    }
  }

  static Future<bool> _internetReachable() async {
    try {
      final r = await InternetAddress.lookup(
        'one.one.one.one',
      ).timeout(const Duration(seconds: 5));
      return r.isNotEmpty && r.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}

final onlineProvider = NotifierProvider<NetworkMonitor, bool>(
  NetworkMonitor.new,
);
