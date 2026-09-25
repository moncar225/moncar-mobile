// ============================================================
// MON CAR PRO — Voyage du jour (contrôleur, convoyeur, chauffeur).
//
// Le manifeste, les billets attendus, les bagages et les colis sont
// téléchargés avant le départ ; toutes les actions terrain fonctionnent
// sans réseau et partent dans la file de synchronisation. Le manifeste
// affiché est recalculé depuis ces données, jamais ajusté à la main.
// ============================================================

library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mock_data.dart';
import '../domain/models.dart';
import 'session_controller.dart';
import 'sync_controller.dart';

@immutable
class TripState {
  const TripState({
    required this.voyage,
    required this.passengers,
    required this.bags,
    required this.parcels,
    required this.incidents,
    required this.scans,
    required this.phase,
    required this.manifestAt,
  });

  final Voyage voyage;
  final List<Passenger> passengers;
  final List<Bag> bags;
  final List<Parcel> parcels;
  final List<Incident> incidents;
  final List<ScanRecord> scans;
  final DriverPhase phase;

  /// Heure du dernier téléchargement du manifeste (hors ligne).
  final DateTime manifestAt;

  // ---- Dérivés (affichage uniquement) ----

  List<Passenger> get validTickets =>
      passengers.where((p) => p.ticketState == TicketState.valide).toList();

  int get expected => validTickets.length;
  int get controlled => validTickets.where((p) => p.isControlled).length;
  int get notControlled => expected - controlled;
  int get onBoard => passengers.where((p) => p.isOnBoard).length;

  int get refused => scans.where((s) => s.outcome.isBlocking).length;

  int stopIndex(String stopId) =>
      voyage.stops.indexWhere((s) => s.id == stopId);

  Stop stopById(String id) =>
      voyage.stops.firstWhere((s) => s.id == id, orElse: () => voyage.origin);

  /// Arrêt « opérationnel » : l'arrêt en cours quand le car y est à quai,
  /// sinon le prochain arrêt.
  Stop? get operationalStop =>
      phase == DriverPhase.aLArret ||
          phase == DriverPhase.arriveDestination ||
          phase == DriverPhase.avantDepart
      ? voyage.currentStop
      : voyage.nextStop;

  /// Passagers attendus à bord : montés à un arrêt déjà atteint.
  List<Passenger> get expectedAboard => validTickets
      .where(
        (p) =>
            stopIndex(p.boardStopId) <= voyage.currentStopIndex &&
            !p.isDisembarked,
      )
      .toList();

  int get absents => expectedAboard.where((p) => !p.isOnBoard).length;

  List<Passenger> toDropAt(String stopId) =>
      passengers.where((p) => p.dropStopId == stopId && p.isOnBoard).toList();

  List<Passenger> toBoardAt(String stopId) => validTickets
      .where((p) => p.boardStopId == stopId && !p.isOnBoard && !p.isDisembarked)
      .toList();

  List<Bag> bagsToUnloadAt(String stopId) => bags
      .where((b) => b.dropStopId == stopId && b.status != BagStatus.remis)
      .toList();

  List<Parcel> parcelsToUnloadAt(String stopId) => parcels
      .where(
        (p) =>
            p.dropStopId == stopId &&
            p.status != ParcelStatus.decharge &&
            p.status != ParcelStatus.litige,
      )
      .toList();

  TripState copyWith({
    Voyage? voyage,
    List<Passenger>? passengers,
    List<Bag>? bags,
    List<Parcel>? parcels,
    List<Incident>? incidents,
    List<ScanRecord>? scans,
    DriverPhase? phase,
    DateTime? manifestAt,
  }) => TripState(
    voyage: voyage ?? this.voyage,
    passengers: passengers ?? this.passengers,
    bags: bags ?? this.bags,
    parcels: parcels ?? this.parcels,
    incidents: incidents ?? this.incidents,
    scans: scans ?? this.scans,
    phase: phase ?? this.phase,
    manifestAt: manifestAt ?? this.manifestAt,
  );
}

class TripController extends Notifier<TripState> {
  @override
  TripState build() {
    final passengers = demoPassengers();
    final now = DateTime.now();
    return TripState(
      voyage: demoVoyage(),
      passengers: passengers,
      bags: demoBags(passengers),
      parcels: demoParcels(),
      incidents: demoIncidents(),
      scans: [
        for (final p in passengers.where((p) => p.isControlled))
          ScanRecord(
            id: 'sc-${p.id}',
            at: p.controlledAt!,
            code: p.ticketRef,
            outcome: ScanOutcome.valide,
            agent: p.controlledBy ?? 'Kouadio Yao',
            passengerName: p.name,
            seat: p.seat,
          ),
        ScanRecord(
          id: 'sc-x1',
          at: now.subtract(const Duration(minutes: 22)),
          code: 'BIL-0430-118',
          outcome: ScanOutcome.mauvaisVoyage,
          agent: 'Kouadio Yao',
          passengerName: 'Eric Gbagbo',
          seat: '12D',
        ),
        ScanRecord(
          id: 'sc-x2',
          at: now.subtract(const Duration(minutes: 16)),
          code: 'XYZ-99',
          outcome: ScanOutcome.invalide,
          agent: 'Kouadio Yao',
        ),
      ]..sort((a, b) => b.at.compareTo(a.at)),
      phase: DriverPhase.avantDepart,
      manifestAt: now.subtract(const Duration(minutes: 50)),
    );
  }

  SyncController get _sync => ref.read(syncProvider.notifier);
  String get _agent => ref.read(sessionProvider).user?.name ?? 'Agent';

  // ----------------------------- Contrôleur -----------------------------

  static String normalizeCode(String raw) {
    var c = raw.trim().toUpperCase();
    if (c.startsWith('MCP:')) c = c.substring(4);
    return c;
  }

  /// Pré-vérification locale (hors ligne) du billet à partir du manifeste
  /// téléchargé. ⚠️ La vérification de signature (clé publique embarquée,
  /// T-4) s'ajoutera ici ; le serveur reste juge lors de la synchro.
  ScanResult verify(String raw, {bool manual = false}) {
    final code = normalizeCode(raw);
    final s = state;
    final now = DateTime.now();
    final p = s.passengers.where((x) => x.ticketRef == code).firstOrNull;

    ScanResult result;
    if (p == null) {
      final other = otherVoyageTickets[code];
      result = ScanResult(
        outcome: other != null
            ? ScanOutcome.mauvaisVoyage
            : ScanOutcome.invalide,
        code: code,
        at: now,
        voyageNumber: other?.$1,
        segment: other?.$2,
        manual: manual,
      );
    } else {
      final segment =
          '${s.stopById(p.boardStopId).shortName} → ${s.stopById(p.dropStopId).shortName}';
      final ScanOutcome outcome;
      if (p.ticketState == TicketState.annule) {
        outcome = ScanOutcome.annule;
      } else if (p.isControlled) {
        outcome = ScanOutcome.dejaScanne;
      } else if (s.stopIndex(p.boardStopId) != s.voyage.currentStopIndex) {
        outcome = ScanOutcome.mauvaiseGare;
      } else {
        outcome = ScanOutcome.valide;
      }
      result = ScanResult(
        outcome: outcome,
        code: code,
        at: now,
        passenger: p,
        voyageNumber: s.voyage.number,
        segment: segment,
        previousAt: p.controlledAt,
        previousBy: p.controlledBy,
        manual: manual,
      );
    }

    state = state.copyWith(
      scans: [
        ScanRecord(
          id: 'sc-${now.microsecondsSinceEpoch}',
          at: now,
          code: code,
          outcome: result.outcome,
          agent: _agent,
          passengerName: result.passenger?.name,
          seat: result.passenger?.seat,
          manual: manual,
        ),
        ...state.scans,
      ],
    );
    _sync.enqueue(
      'SCAN',
      '${manual ? 'Saisie manuelle' : 'Scan'} ${result.outcome.title} — $code',
    );
    return result;
  }

  /// Valide l'embarquement après un scan valide (statut confirmé par le
  /// serveur à la synchronisation).
  void confirmBoarding(String passengerId) {
    final p = state.passengers.firstWhere((x) => x.id == passengerId);
    if (p.isControlled) return;
    _updatePassenger(
      passengerId,
      (x) => x.copyWith(controlledAt: DateTime.now(), controlledBy: _agent),
    );
    state = state.copyWith(
      bags: [
        for (final b in state.bags)
          b.passengerName == p.name ? b.copyWith(checked: true) : b,
      ],
    );
    _sync.enqueue(
      'EMBARQUEMENT',
      'Embarquement validé — ${p.name} (siège ${p.seat})',
      key: 'embarquement-${p.id}',
    );
  }

  /// Contrôle d'un bagage par sa référence (null si inconnu).
  Bag? checkBag(String raw) {
    final ref = normalizeCode(raw);
    final bag = state.bags.where((b) => b.ref == ref).firstOrNull;
    if (bag == null) return null;
    state = state.copyWith(
      bags: [
        for (final b in state.bags)
          b.id == bag.id ? b.copyWith(checked: true) : b,
      ],
    );
    _sync.enqueue('BAGAGE', 'Bagage contrôlé — ${bag.ref}');
    return bag.copyWith(checked: true);
  }

  // ----------------------------- Convoyeur -----------------------------

  void confirmPresence(String passengerId) {
    final p = state.passengers.firstWhere((x) => x.id == passengerId);
    if (p.isOnBoard) return;
    _updatePassenger(passengerId, (x) => x.copyWith(boardedAt: DateTime.now()));
    state = state.copyWith(
      bags: [
        for (final b in state.bags)
          b.passengerName == p.name && b.status == BagStatus.enregistre
              ? b.copyWith(status: BagStatus.aBord)
              : b,
      ],
    );
    _sync.enqueue(
      'PRESENCE',
      'Présence à bord — ${p.name} (siège ${p.seat})',
      key: 'presence-${p.id}',
    );
  }

  void confirmDisembark(String passengerId) {
    final p = state.passengers.firstWhere((x) => x.id == passengerId);
    if (p.isDisembarked) return;
    _updatePassenger(
      passengerId,
      (x) => x.copyWith(disembarkedAt: DateTime.now()),
    );
    _sync.enqueue(
      'DEBARQUEMENT',
      'Débarquement — ${p.name} · siège ${p.seat} libéré',
      key: 'debarquement-${p.id}',
    );
  }

  void unloadBag(String bagId) {
    final b = state.bags.firstWhere((x) => x.id == bagId);
    state = state.copyWith(
      bags: [
        for (final x in state.bags)
          x.id == bagId ? x.copyWith(status: BagStatus.remis) : x,
      ],
    );
    _sync.enqueue('BAGAGE', 'Bagage déchargé et remis — ${b.ref}');
  }

  void unloadParcel(String parcelId) {
    final p = state.parcels.firstWhere((x) => x.id == parcelId);
    state = state.copyWith(
      parcels: [
        for (final x in state.parcels)
          x.id == parcelId ? x.copyWith(status: ParcelStatus.decharge) : x,
      ],
    );
    _sync.enqueue('COLIS', 'Colis déchargé — ${p.ref}');
  }

  // ----------------------------- Chauffeur -----------------------------

  void startTrip() {
    if (state.phase != DriverPhase.avantDepart) return;
    state = state.copyWith(
      phase: DriverPhase.enRoute,
      voyage: state.voyage.copyWith(
        status: VoyageStatus.enCours,
        departureActual: DateTime.now(),
      ),
    );
    _sync.enqueue(
      'STATUT',
      'Départ réel — ${state.voyage.number}',
      key: 'depart-${state.voyage.id}',
    );
  }

  void arriveAtStop() {
    final next = state.voyage.nextStop;
    if (state.phase != DriverPhase.enRoute || next == null) return;
    final isLast = next.id == state.voyage.destination.id;
    state = state.copyWith(
      phase: isLast ? DriverPhase.arriveDestination : DriverPhase.aLArret,
      voyage: state.voyage.copyWith(
        currentStopIndex: state.voyage.currentStopIndex + 1,
        status: isLast ? VoyageStatus.arrive : null,
      ),
    );
    _sync.enqueue(
      'STATUT',
      '${isLast ? 'Arrivée destination' : 'Arrivée à l’arrêt'} — ${next.shortName}',
    );
  }

  void departFromStop() {
    if (state.phase != DriverPhase.aLArret) return;
    state = state.copyWith(phase: DriverPhase.enRoute);
    _sync.enqueue(
      'STATUT',
      'Départ de l’arrêt — ${state.voyage.currentStop.shortName}',
    );
  }

  void closeTrip({required int km, required bool withIncident}) {
    if (state.phase != DriverPhase.arriveDestination) return;
    state = state.copyWith(
      phase: DriverPhase.cloture,
      voyage: state.voyage.copyWith(status: VoyageStatus.cloture),
    );
    _sync.enqueue(
      'CLOTURE',
      'Clôture ${state.voyage.number} — $km km${withIncident ? ' · incident signalé' : ''}',
      key: 'cloture-${state.voyage.id}',
    );
  }

  // ----------------------------- Incidents -----------------------------

  Incident reportIncident({
    required IncidentCategory category,
    required IncidentSeverity severity,
    required String description,
    required bool withPhoto,
    String? locationLabel,
  }) {
    final now = DateTime.now();
    final incident = Incident(
      id: 'inc-${now.millisecondsSinceEpoch}',
      category: category,
      severity: severity,
      description: description,
      createdAt: now,
      author: _agent,
      status: IncidentStatus.ouvert,
      withPhoto: withPhoto,
      locationLabel: locationLabel ?? state.voyage.currentStop.shortName,
    );
    state = state.copyWith(incidents: [incident, ...state.incidents]);
    _sync.enqueue(
      'INCIDENT',
      'Incident ${category.label} (${severity.label.toLowerCase()})',
      key: 'incident-${incident.id}',
    );
    return incident;
  }

  /// Nouveau téléchargement du manifeste (avant départ / reprise réseau).
  void refreshManifest() {
    state = state.copyWith(manifestAt: DateTime.now());
  }

  /// Réinitialise le voyage de démonstration.
  void resetDemo() => ref.invalidateSelf();

  void _updatePassenger(String id, Passenger Function(Passenger) f) {
    state = state.copyWith(
      passengers: [for (final p in state.passengers) p.id == id ? f(p) : p],
    );
  }
}

final tripProvider = NotifierProvider<TripController, TripState>(
  TripController.new,
);
