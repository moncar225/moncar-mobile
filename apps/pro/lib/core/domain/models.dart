// ============================================================
// MON CAR PRO — Modèles domaine (application terrain).
//
// Contract-first : ces modèles suivent le cahier des charges MON CAR PRO
// (postes 8, 9, 10 + agents BUSINESS) et la roadmap (§8 tables, §9 API).
// Le serveur reste la source de vérité : l'app ne décide d'aucune règle
// d'argent, de siège ou de permission. Les statuts affichés sont ceux
// renvoyés (ou mis en file) pour le serveur.
// ============================================================

library;

import 'package:flutter/material.dart';

// ----------------------------- Profils -----------------------------

/// Profils terrain de MON CAR PRO (roadmap §10.2). La liste des profils
/// accessibles à un compte est renvoyée par l'API (`GET /me/capacites`),
/// jamais codée en dur côté app.
enum ProRole {
  controleur(
    code: 'CTRL',
    label: 'Contrôleur',
    tagline: 'Scan des billets et validation de l’embarquement',
    icon: Icons.qr_code_scanner_rounded,
    features: ['Scan QR hors ligne', 'Saisie manuelle tracée', 'Bagages'],
  ),
  convoyeur(
    code: 'CONV',
    label: 'Convoyeur',
    tagline: 'Présence à bord, arrêts, bagages et colis',
    icon: Icons.fact_check_rounded,
    features: ['Manifeste par segment', 'Prochain arrêt', 'Colis'],
  ),
  chauffeur(
    code: 'CHAUF',
    label: 'Chauffeur',
    tagline: 'Démarrer, suivre et clôturer le voyage',
    icon: Icons.airline_seat_recline_normal_rounded,
    features: ['Statuts du voyage', 'GPS & ETA', 'Alertes vocales'],
  ),
  agentBusiness(
    code: 'BIZ',
    label: 'Agent BUSINESS',
    tagline: 'Remise et restitution des véhicules loués',
    icon: Icons.car_rental_rounded,
    features: ['Checklist d’état', 'Photos & km', 'Preuve de remise'],
  );

  const ProRole({
    required this.code,
    required this.label,
    required this.tagline,
    required this.icon,
    required this.features,
  });

  final String code;
  final String label;
  final String tagline;
  final IconData icon;
  final List<String> features;

  static ProRole? fromName(String? name) {
    for (final r in values) {
      if (r.name == name) return r;
    }
    return null;
  }
}

/// Agent connecté (réponse de `GET /me` + `GET /me/capacites`).
@immutable
class ProUser {
  const ProUser({
    required this.id,
    required this.name,
    required this.phone,
    required this.company,
    required this.station,
    required this.roles,
    this.mustChangePassword = false,
  });

  final String id;
  final String name;
  final String phone;
  final String company;
  final String station;

  /// Profils autorisés pour ce compte (fournis par le serveur).
  final List<ProRole> roles;

  /// Mot de passe temporaire à changer à la 1re connexion (CDC).
  final bool mustChangePassword;

  String get firstName => name.split(' ').first;

  String get initials => name
      .split(' ')
      .where((w) => w.isNotEmpty)
      .take(2)
      .map((w) => w[0].toUpperCase())
      .join();

  ProUser copyWith({bool? mustChangePassword}) => ProUser(
    id: id,
    name: name,
    phone: phone,
    company: company,
    station: station,
    roles: roles,
    mustChangePassword: mustChangePassword ?? this.mustChangePassword,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'company': company,
    'station': station,
    'roles': roles.map((r) => r.name).toList(),
    'mustChangePassword': mustChangePassword,
  };

  static ProUser fromJson(Map<String, dynamic> j) => ProUser(
    id: j['id'] as String,
    name: j['name'] as String,
    phone: j['phone'] as String,
    company: j['company'] as String,
    station: j['station'] as String,
    roles: [
      for (final r in (j['roles'] as List).cast<String>()) ?ProRole.fromName(r),
    ],
    mustChangePassword: j['mustChangePassword'] as bool? ?? false,
  );
}

// ----------------------------- Voyage -----------------------------

/// Statuts d'un voyage (représentation UI — le backend arbitre).
enum VoyageStatus {
  programme('Programmé'),
  embarquement('Embarquement'),
  enCours('En cours'),
  arrive('Arrivé'),
  cloture('Clôturé'),
  incident('Incident'),
  annule('Annulé');

  const VoyageStatus(this.label);
  final String label;
}

/// Arrêt ordonné d'une ligne (gare), avec position géographique.
@immutable
class Stop {
  const Stop({
    required this.id,
    required this.name,
    required this.shortName,
    required this.order,
    required this.lat,
    required this.lng,
    required this.plannedAt,
    this.kmFromOrigin = 0,
  });

  final String id;
  final String name;
  final String shortName;
  final int order;
  final double lat;
  final double lng;

  /// Heure prévue de passage (ETA de référence ; l'ETA réelle est serveur).
  final DateTime plannedAt;
  final double kmFromOrigin;
}

/// Phase de conduite du chauffeur (workflow « changer statut »).
enum DriverPhase {
  avantDepart('Avant départ'),
  enRoute('En route'),
  aLArret('À l’arrêt'),
  arriveDestination('Arrivé à destination'),
  cloture('Voyage clôturé');

  const DriverPhase(this.label);
  final String label;
}

@immutable
class Voyage {
  const Voyage({
    required this.id,
    required this.number,
    required this.companyName,
    required this.stops,
    required this.departurePlanned,
    required this.vehiclePlate,
    required this.vehicleType,
    required this.totalSeats,
    required this.driverName,
    required this.convoyeurName,
    required this.controleurName,
    required this.status,
    this.departureActual,
    this.currentStopIndex = 0,
    this.delayMin = 0,
  });

  final String id;
  final String number;
  final String companyName;
  final List<Stop> stops;
  final DateTime departurePlanned;
  final DateTime? departureActual;
  final String vehiclePlate;
  final String vehicleType;
  final int totalSeats;
  final String driverName;
  final String convoyeurName;
  final String controleurName;
  final VoyageStatus status;

  /// Index du dernier arrêt atteint/quitté.
  final int currentStopIndex;
  final int delayMin;

  Stop get origin => stops.first;
  Stop get destination => stops.last;
  Stop get currentStop => stops[currentStopIndex];
  Stop? get nextStop =>
      currentStopIndex + 1 < stops.length ? stops[currentStopIndex + 1] : null;
  String get line => '${origin.shortName} → ${destination.shortName}';
  double get totalKm => destination.kmFromOrigin;

  /// Progression (0..1) sur la ligne, en distance.
  double get progress =>
      totalKm == 0 ? 0 : (currentStop.kmFromOrigin / totalKm).clamp(0, 1);

  Voyage copyWith({
    VoyageStatus? status,
    DateTime? departureActual,
    int? currentStopIndex,
    int? delayMin,
  }) => Voyage(
    id: id,
    number: number,
    companyName: companyName,
    stops: stops,
    departurePlanned: departurePlanned,
    departureActual: departureActual ?? this.departureActual,
    vehiclePlate: vehiclePlate,
    vehicleType: vehicleType,
    totalSeats: totalSeats,
    driverName: driverName,
    convoyeurName: convoyeurName,
    controleurName: controleurName,
    status: status ?? this.status,
    currentStopIndex: currentStopIndex ?? this.currentStopIndex,
    delayMin: delayMin ?? this.delayMin,
  );
}

// ----------------------------- Passagers -----------------------------

/// État du billet côté serveur (téléchargé avec le manifeste).
enum TicketState { valide, annule }

@immutable
class Passenger {
  const Passenger({
    required this.id,
    required this.name,
    required this.seat,
    required this.ticketRef,
    required this.boardStopId,
    required this.dropStopId,
    required this.phone,
    this.ticketState = TicketState.valide,
    this.hasBaggage = false,
    this.hasParcel = false,
    this.controlledAt,
    this.controlledBy,
    this.boardedAt,
    this.disembarkedAt,
  });

  final String id;
  final String name;
  final String seat;
  final String ticketRef;
  final String boardStopId;
  final String dropStopId;
  final String phone;
  final TicketState ticketState;
  final bool hasBaggage;
  final bool hasParcel;

  /// Scan du contrôleur (heure terrain).
  final DateTime? controlledAt;
  final String? controlledBy;

  /// Présence à bord confirmée par le convoyeur.
  final DateTime? boardedAt;

  /// Débarquement confirmé (libère le siège sur les segments suivants).
  final DateTime? disembarkedAt;

  bool get isControlled => controlledAt != null;
  bool get isOnBoard => boardedAt != null && disembarkedAt == null;
  bool get isDisembarked => disembarkedAt != null;

  String get initials => name
      .split(' ')
      .where((w) => w.isNotEmpty)
      .take(2)
      .map((w) => w[0].toUpperCase())
      .join();

  Passenger copyWith({
    DateTime? controlledAt,
    String? controlledBy,
    DateTime? boardedAt,
    DateTime? disembarkedAt,
  }) => Passenger(
    id: id,
    name: name,
    seat: seat,
    ticketRef: ticketRef,
    boardStopId: boardStopId,
    dropStopId: dropStopId,
    phone: phone,
    ticketState: ticketState,
    hasBaggage: hasBaggage,
    hasParcel: hasParcel,
    controlledAt: controlledAt ?? this.controlledAt,
    controlledBy: controlledBy ?? this.controlledBy,
    boardedAt: boardedAt ?? this.boardedAt,
    disembarkedAt: disembarkedAt ?? this.disembarkedAt,
  );
}

// ----------------------------- Scan -----------------------------

/// Résultats de scan exigés par le cahier des charges (poste 8).
enum ScanOutcome {
  valide('Billet valide', 'Embarquement autorisé'),
  dejaScanne('Déjà contrôlé', 'Billet déjà contrôlé à cette étape'),
  annule('Billet annulé', 'Réservation annulée — refuser l’accès'),
  mauvaisVoyage('Mauvais voyage', 'Ce billet concerne un autre voyage'),
  mauvaiseGare('Mauvaise gare', 'Embarquement prévu dans une autre gare'),
  invalide('Billet invalide', 'QR illisible ou signature non reconnue');

  const ScanOutcome(this.title, this.hint);
  final String title;
  final String hint;

  bool get isSuccess => this == ScanOutcome.valide;
  bool get isBlocking =>
      this == ScanOutcome.mauvaisVoyage ||
      this == ScanOutcome.mauvaiseGare ||
      this == ScanOutcome.invalide ||
      this == ScanOutcome.annule;
}

@immutable
class ScanResult {
  const ScanResult({
    required this.outcome,
    required this.code,
    required this.at,
    this.passenger,
    this.voyageNumber,
    this.segment,
    this.previousAt,
    this.previousBy,
    this.manual = false,
  });

  final ScanOutcome outcome;
  final String code;
  final DateTime at;
  final Passenger? passenger;
  final String? voyageNumber;
  final String? segment;
  final DateTime? previousAt;
  final String? previousBy;
  final bool manual;
}

/// Ligne d'historique de scan (poste 8 — « Historique des scans »).
@immutable
class ScanRecord {
  const ScanRecord({
    required this.id,
    required this.at,
    required this.code,
    required this.outcome,
    required this.agent,
    this.passengerName,
    this.seat,
    this.manual = false,
  });

  final String id;
  final DateTime at;
  final String code;
  final ScanOutcome outcome;
  final String agent;
  final String? passengerName;
  final String? seat;
  final bool manual;
}

// ----------------------------- Bagages / colis -----------------------------

enum BagStatus {
  enregistre('Enregistré'),
  aBord('À bord'),
  aDecharger('À décharger'),
  remis('Remis'),
  incident('Incident');

  const BagStatus(this.label);
  final String label;
}

@immutable
class Bag {
  const Bag({
    required this.id,
    required this.ref,
    required this.passengerName,
    required this.seat,
    required this.dropStopId,
    required this.status,
    this.weightKg = 0,
    this.note,
    this.checked = false,
  });

  final String id;
  final String ref;
  final String passengerName;
  final String seat;
  final String dropStopId;
  final BagStatus status;
  final double weightKg;
  final String? note;

  /// Contrôlé par le contrôleur au chargement.
  final bool checked;

  Bag copyWith({BagStatus? status, bool? checked}) => Bag(
    id: id,
    ref: ref,
    passengerName: passengerName,
    seat: seat,
    dropStopId: dropStopId,
    status: status ?? this.status,
    weightKg: weightKg,
    note: note,
    checked: checked ?? this.checked,
  );
}

enum ParcelStatus {
  charge('Chargé'),
  enTransit('En transit'),
  aDecharger('À décharger'),
  decharge('Déchargé'),
  litige('Litige');

  const ParcelStatus(this.label);
  final String label;
}

@immutable
class Parcel {
  const Parcel({
    required this.id,
    required this.ref,
    required this.sender,
    required this.recipient,
    required this.recipientPhone,
    required this.dropStopId,
    required this.nature,
    required this.weightKg,
    required this.status,
  });

  final String id;
  final String ref;
  final String sender;
  final String recipient;
  final String recipientPhone;
  final String dropStopId;
  final String nature;
  final double weightKg;
  final ParcelStatus status;

  Parcel copyWith({ParcelStatus? status}) => Parcel(
    id: id,
    ref: ref,
    sender: sender,
    recipient: recipient,
    recipientPhone: recipientPhone,
    dropStopId: dropStopId,
    nature: nature,
    weightKg: weightKg,
    status: status ?? this.status,
  );
}

// ----------------------------- Incidents -----------------------------

enum IncidentCategory {
  panne('Panne', Icons.car_repair_rounded),
  accident('Accident', Icons.car_crash_rounded),
  retard('Retard', Icons.schedule_rounded),
  routeBloquee('Route bloquée', Icons.block_rounded),
  passager('Passager', Icons.person_off_rounded),
  billet('Billet', Icons.confirmation_number_rounded),
  bagage('Bagage', Icons.luggage_rounded),
  colis('Colis', Icons.inventory_2_rounded),
  securite('Sécurité', Icons.health_and_safety_rounded),
  autre('Autre', Icons.more_horiz_rounded);

  const IncidentCategory(this.label, this.icon);
  final String label;
  final IconData icon;
}

enum IncidentStatus {
  ouvert('Ouvert'),
  enCours('En cours'),
  resolu('Résolu');

  const IncidentStatus(this.label);
  final String label;
}

enum IncidentSeverity {
  faible('Faible'),
  moyenne('Moyenne'),
  critique('Critique');

  const IncidentSeverity(this.label);
  final String label;
}

@immutable
class Incident {
  const Incident({
    required this.id,
    required this.category,
    required this.severity,
    required this.description,
    required this.createdAt,
    required this.author,
    required this.status,
    this.withPhoto = false,
    this.locationLabel,
    this.synced = false,
  });

  final String id;
  final IncidentCategory category;
  final IncidentSeverity severity;
  final String description;
  final DateTime createdAt;
  final String author;
  final IncidentStatus status;
  final bool withPhoto;
  final String? locationLabel;
  final bool synced;

  Incident copyWith({bool? synced}) => Incident(
    id: id,
    category: category,
    severity: severity,
    description: description,
    createdAt: createdAt,
    author: author,
    status: status,
    withPhoto: withPhoto,
    locationLabel: locationLabel,
    synced: synced ?? this.synced,
  );
}

// ----------------------------- Location BUSINESS -----------------------------

enum RentalTaskType {
  remise('Remise'),
  restitution('Restitution');

  const RentalTaskType(this.label);
  final String label;
}

enum RentalTaskStatus {
  aFaire('À faire'),
  termine('Terminé');

  const RentalTaskStatus(this.label);
  final String label;
}

@immutable
class RentalTask {
  const RentalTask({
    required this.id,
    required this.ref,
    required this.type,
    required this.clientName,
    required this.clientPhone,
    required this.vehiclePlate,
    required this.vehicleModel,
    required this.scheduledAt,
    required this.withDriver,
    required this.status,
    this.initialKm,
    this.initialFuel,
    this.initialChecklist,
    this.proofRef,
  });

  final String id;
  final String ref;
  final RentalTaskType type;
  final String clientName;
  final String clientPhone;
  final String vehiclePlate;
  final String vehicleModel;
  final DateTime scheduledAt;
  final bool withDriver;
  final RentalTaskStatus status;

  /// État enregistré à la remise (pour la comparaison avant/après).
  final int? initialKm;
  final int? initialFuel;
  final List<bool?>? initialChecklist;

  /// Référence de preuve / rapport renvoyée par le serveur.
  final String? proofRef;

  RentalTask copyWith({RentalTaskStatus? status, String? proofRef}) =>
      RentalTask(
        id: id,
        ref: ref,
        type: type,
        clientName: clientName,
        clientPhone: clientPhone,
        vehiclePlate: vehiclePlate,
        vehicleModel: vehicleModel,
        scheduledAt: scheduledAt,
        withDriver: withDriver,
        status: status ?? this.status,
        initialKm: initialKm,
        initialFuel: initialFuel,
        initialChecklist: initialChecklist,
        proofRef: proofRef ?? this.proofRef,
      );
}

// ----------------------------- Notifications -----------------------------

enum NotifCategory {
  critique('Critique'),
  alerte('Alerte'),
  information('Information'),
  succes('Succès');

  const NotifCategory(this.label);
  final String label;
}

@immutable
class ProNotification {
  const ProNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.at,
    this.read = false,
    this.route,
  });

  final String id;
  final String title;
  final String body;
  final NotifCategory category;
  final DateTime at;
  final bool read;

  /// Lien profond interne (ex. `/incidents`).
  final String? route;

  ProNotification copyWith({bool? read}) => ProNotification(
    id: id,
    title: title,
    body: body,
    category: category,
    at: at,
    read: read ?? this.read,
    route: route,
  );
}

// ----------------------------- Synchronisation -----------------------------

enum SyncOpStatus { pending, syncing, done, error }

/// Action terrain en file locale, rejouée sans doublon (Idempotency-Key)
/// au retour du réseau (roadmap QR-002 / §13.5).
@immutable
class SyncOp {
  const SyncOp({
    required this.id,
    required this.kind,
    required this.idempotencyKey,
    required this.summary,
    required this.createdAt,
    this.status = SyncOpStatus.pending,
    this.attempts = 0,
    this.lastError,
  });

  final String id;

  /// Type d'opération (SCAN, PRESENCE, STATUT, INCIDENT, POSITIONS…).
  final String kind;
  final String idempotencyKey;
  final String summary;

  /// Heure terrain (distincte de l'heure serveur).
  final DateTime createdAt;
  final SyncOpStatus status;
  final int attempts;
  final String? lastError;

  SyncOp copyWith({SyncOpStatus? status, int? attempts, String? lastError}) =>
      SyncOp(
        id: id,
        kind: kind,
        idempotencyKey: idempotencyKey,
        summary: summary,
        createdAt: createdAt,
        status: status ?? this.status,
        attempts: attempts ?? this.attempts,
        lastError: lastError,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'key': idempotencyKey,
    'summary': summary,
    'at': createdAt.toIso8601String(),
    'status': status.name,
    'attempts': attempts,
    'error': lastError,
  };

  static SyncOp fromJson(Map<String, dynamic> j) => SyncOp(
    id: j['id'] as String,
    kind: j['kind'] as String,
    idempotencyKey: j['key'] as String,
    summary: j['summary'] as String,
    createdAt: DateTime.parse(j['at'] as String),
    status: SyncOpStatus.values.byName(j['status'] as String),
    attempts: j['attempts'] as int? ?? 0,
    lastError: j['error'] as String?,
  );
}
