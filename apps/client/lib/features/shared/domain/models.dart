// ============================================================
// MON CAR — Modèles de domaine partagés (contract-first)
// Portage Dart de `src/lib/types.ts` du prototype web.
// Ces types décrivent le contrat d'API que le backend Symfony
// implémentera à l'identique. Les champs marqués `serverOnly`
// (montants, totaux) sont calculés côté serveur — le client
// ne les recalcule jamais.
// ============================================================

library;

/// Identifiant technique (string comme côté API).
typedef ID = String;

/// Date ISO "2026-09-22".
typedef ISODate = String;

/// Heure ISO "08:30".
typedef ISOTime = String;

/// Horodatage ISO 8601 complet.
typedef ISODateTime = String;

/// Montant en FCFA — entier, sans décimales (serverOnly).
typedef Money = int;

// ----------------------------- Villes / Arrêts -----------------------------

class City {
  const City({
    required this.id,
    required this.name,
    required this.region,
    required this.country,
    required this.latitude,
    required this.longitude,
    this.popular = false,
  });

  final ID id;
  final String name;
  final String region;
  final String country;
  final double latitude;
  final double longitude;
  final bool popular;
}

class Stop {
  const Stop({
    required this.id,
    required this.cityId,
    required this.cityName,
    required this.label,
    required this.latitude,
    required this.longitude,
    required this.orderInLine,
    required this.minutesFromOrigin,
    this.address,
  });

  final ID id;
  final ID cityId;
  final String cityName;

  /// Ex. « Gare d'Abobo ».
  final String label;
  final String? address;
  final double latitude;
  final double longitude;
  final int orderInLine;

  /// Temps de trajet depuis l'origine de la ligne (minutes).
  final int minutesFromOrigin;
}

// ----------------------------- Compagnies -----------------------------

class Company {
  const Company({
    required this.id,
    required this.name,
    required this.logoColor,
    required this.rating,
    required this.reviewCount,
    required this.fleetCount,
    required this.description,
    required this.amenities,
  });

  final ID id;
  final String name;
  final String logoColor;
  final double rating;
  final int reviewCount;
  final int fleetCount;
  final String description;
  final List<String> amenities;
}

// ----------------------------- Lignes / Véhicules -----------------------------

class Line {
  const Line({
    required this.id,
    required this.companyId,
    required this.companyName,
    required this.originCityId,
    required this.originCityName,
    required this.destinationCityId,
    required this.destinationCityName,
    required this.stops,
    required this.distanceKm,
    required this.durationRefMin,
  });

  final ID id;
  final ID companyId;
  final String companyName;
  final ID originCityId;
  final String originCityName;
  final ID destinationCityId;
  final String destinationCityName;
  final List<Stop> stops;
  final int distanceKm;
  final int durationRefMin;
}

enum VehicleType {
  car,
  minibus,
  bus,
  berline,
  suv,
  monospace,
  utilitaire,

  /// Véhicule de transport avec chauffeur : chauffeur toujours inclus.
  vtc,

  /// 4x4 (location, véhicules particuliers).
  quatreQuatre,

  /// Car / autocar (location, transport collectif).
  autocar,
}

VehicleType vehicleTypeFromName(String name) => VehicleType.values.firstWhere(
  (v) => v.name == name,
  orElse: () => VehicleType.car,
);

class Vehicle {
  const Vehicle({
    required this.id,
    required this.companyId,
    required this.companyName,
    required this.registration,
    required this.type,
    required this.capacity,
    required this.model,
    required this.amenities,
    required this.layout,
    required this.photoColor,
  });

  final ID id;
  final ID companyId;
  final String companyName;
  final String registration;
  final VehicleType type;
  final int capacity;
  final String model;
  final List<String> amenities;
  final VehicleLayout layout;
  final String photoColor;
}

class VehicleLayout {
  const VehicleLayout({
    required this.rows,
    required this.cols,
    required this.hasBackRow,
  });

  final int rows;
  final int cols;
  final bool hasBackRow;
}

// ----------------------------- Trajets -----------------------------

enum TripType { allerSimple, allerRetour }

TripType tripTypeFromName(String name) =>
    name == 'aller_retour' ? TripType.allerRetour : TripType.allerSimple;

extension TripTypeName on TripType {
  String get apiName =>
      this == TripType.allerRetour ? 'aller_retour' : 'aller_simple';
}

enum TripStatus { cree, modifie, annule, enCours, termine }

enum CancellationPolicy { flexible, modere, strict }

CancellationPolicy cancellationPolicyFromName(String name) => CancellationPolicy
    .values
    .firstWhere((c) => c.name == name, orElse: () => CancellationPolicy.modere);

class TripSegment {
  const TripSegment({
    required this.originStopId,
    required this.destinationStopId,
    required this.originCityName,
    required this.destinationCityName,
    required this.departureTime,
    required this.arrivalTime,
    required this.durationMin,
    required this.priceXOF,
  });

  final ID originStopId;
  final ID destinationStopId;
  final String originCityName;
  final String destinationCityName;
  final ISOTime departureTime;
  final ISOTime arrivalTime;
  final int durationMin;
  final Money priceXOF; // serverOnly
}

class Trip {
  const Trip({
    required this.id,
    required this.lineId,
    required this.companyId,
    required this.companyName,
    required this.companyColor,
    required this.originCityName,
    required this.destinationCityName,
    required this.date,
    required this.departureTime,
    required this.arrivalTime,
    required this.durationMin,
    required this.distanceKm,
    required this.vehicleId,
    required this.vehicleType,
    required this.vehicleModel,
    required this.amenities,
    required this.segments,
    required this.stops,
    required this.seatsAvailable,
    required this.totalSeats,
    required this.priceFromXOF,
    required this.priceXOF,
    required this.status,
    required this.rating,
    required this.reviewCount,
    required this.direct,
    required this.cancellationPolicy,
    required this.tags,
  });

  final ID id;
  final ID lineId;
  final ID companyId;
  final String companyName;
  final String companyColor;
  final String originCityName;
  final String destinationCityName;
  final ISODate date;
  final ISOTime departureTime;
  final ISOTime arrivalTime;
  final int durationMin;
  final int distanceKm;
  final ID vehicleId;
  final VehicleType vehicleType;
  final String vehicleModel;
  final List<String> amenities;
  final List<TripSegment> segments;
  final List<Stop> stops;
  final int seatsAvailable;
  final int totalSeats;
  final Money priceFromXOF;
  final Money priceXOF;
  final TripStatus status;
  final double rating;
  final int reviewCount;
  final bool direct;
  final CancellationPolicy cancellationPolicy;
  final List<String> tags;
}

// ----------------------------- Sièges -----------------------------

enum SeatStatus { available, selected, taken, blocked, reserved }

enum SeatClass { standard, confort, vip }

SeatClass seatClassFromName(String name) => SeatClass.values.firstWhere(
  (s) => s.name == name,
  orElse: () => SeatClass.standard,
);

enum SeatPosition { fenetre, allee, milieu }

SeatPosition seatPositionFromName(String name) {
  switch (name) {
    case 'fenetre':
      return SeatPosition.fenetre;
    case 'allée':
      return SeatPosition.allee;
    default:
      return SeatPosition.milieu;
  }
}

class Seat {
  const Seat({
    required this.id,
    required this.number,
    required this.row,
    required this.col,
    required this.seatClass,
    required this.position,
    required this.status,
    required this.priceXOF,
    this.segmentLocked = false,
  });

  final ID id;

  /// Numéro lisible, ex. « 12A ».
  final String number;
  final int row;
  final int col;
  final SeatClass seatClass;
  final SeatPosition position;
  final SeatStatus status;
  final Money priceXOF; // serverOnly
  final bool segmentLocked;
}

class SeatMap {
  const SeatMap({
    required this.tripId,
    required this.vehicleId,
    required this.vehicleModel,
    required this.layout,
    required this.seats,
    required this.boardingStopId,
    required this.alightingStopId,
    required this.availableCount,
    required this.legend,
  });

  final ID tripId;
  final ID vehicleId;
  final String vehicleModel;
  final VehicleLayout layout;
  final List<Seat> seats;
  final ID boardingStopId;
  final ID alightingStopId;
  final int availableCount;
  final List<SeatLegendEntry> legend;
}

class SeatLegendEntry {
  const SeatLegendEntry({required this.status, required this.label});
  final SeatStatus status;
  final String label;
}

// ----------------------------- Passagers / Réservation -----------------------------

enum PassengerType { adulte, enfant, bebe }

class Passenger {
  const Passenger({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.type,
    this.seatNumber,
    this.idDocument,
  });

  final ID id;
  final String firstName;
  final String lastName;
  final String phone;
  final PassengerType type;
  final String? seatNumber;
  final String? idDocument;
}

enum BookingStatus { enAttente, paye, embarque, descendu, annule, expire }

BookingStatus bookingStatusFromName(String name) {
  switch (name) {
    case 'en_attente':
      return BookingStatus.enAttente;
    case 'paye':
      return BookingStatus.paye;
    case 'embarque':
      return BookingStatus.embarque;
    case 'descendu':
      return BookingStatus.descendu;
    case 'expire':
      return BookingStatus.expire;
    default:
      return BookingStatus.annule;
  }
}

extension BookingStatusLabel on BookingStatus {
  String get label => switch (this) {
    BookingStatus.enAttente => 'En attente de paiement',
    BookingStatus.paye => 'Payé',
    BookingStatus.embarque => 'Embarqué',
    BookingStatus.descendu => 'Terminé',
    BookingStatus.annule => 'Annulé',
    BookingStatus.expire => 'Expiré',
  };
}

/// Segment retour d'une réservation aller-retour (§14 du cahier des
/// charges : deux segments distincts rattachés à une réservation
/// commune, chacun avec son propre billet et son QR code).
class ReturnLeg {
  const ReturnLeg({
    required this.tripId,
    required this.tripSummary,
    required this.companyName,
    required this.date,
    required this.departureTime,
    required this.arrivalTime,
    required this.originStop,
    required this.destinationStop,
    required this.seats,
    this.ticketId,
  });

  final ID tripId;
  final String tripSummary;
  final String companyName;
  final ISODate date;
  final ISOTime departureTime;
  final ISOTime arrivalTime;
  final String originStop;
  final String destinationStop;
  final List<String> seats;
  final ID? ticketId;

  ReturnLeg withTicket(ID ticketId) => ReturnLeg(
    tripId: tripId,
    tripSummary: tripSummary,
    companyName: companyName,
    date: date,
    departureTime: departureTime,
    arrivalTime: arrivalTime,
    originStop: originStop,
    destinationStop: destinationStop,
    seats: seats,
    ticketId: ticketId,
  );
}

class Booking {
  const Booking({
    required this.id,
    required this.reference,
    required this.tripId,
    required this.tripSummary,
    required this.companyName,
    required this.date,
    required this.departureTime,
    required this.arrivalTime,
    required this.originStop,
    required this.destinationStop,
    required this.passengers,
    required this.seats,
    required this.tripType,
    required this.amountXOF,
    required this.feesXOF,
    required this.discountXOF,
    required this.totalXOF,
    required this.status,
    required this.idempotencyKey,
    required this.cancellationPolicy,
    required this.createdAt,
    required this.expiresAt,
    this.paymentId,
    this.ticketId,
    this.returnLeg,
  });

  final ID id;
  final String reference; // "MON-XXXXXX"
  final ID tripId;
  final String tripSummary; // "Abidjan → Yamoussoukro"
  final String companyName;
  final ISODate date;
  final ISOTime departureTime;
  final ISOTime arrivalTime;
  final String originStop;
  final String destinationStop;
  final List<Passenger> passengers;
  final List<String> seats;
  final TripType tripType;
  final Money amountXOF; // serverOnly
  final Money feesXOF; // serverOnly
  final Money discountXOF; // serverOnly
  final Money totalXOF; // serverOnly
  final BookingStatus status;
  final String idempotencyKey;
  final CancellationPolicy cancellationPolicy;
  final ISODateTime createdAt;
  final ISODateTime expiresAt;
  final ID? paymentId;

  /// Billet de l'aller (ou du trajet simple).
  final ID? ticketId;

  /// Segment retour (aller-retour uniquement).
  final ReturnLeg? returnLeg;
}

// ----------------------------- Paiements -----------------------------

enum PaymentMethod {
  orangeMoney,
  mtnMoney,
  moovMoney,
  wave,
  carteBancaire,
  especes;

  String get apiName => switch (this) {
    PaymentMethod.orangeMoney => 'orange_money',
    PaymentMethod.mtnMoney => 'mtn_money',
    PaymentMethod.moovMoney => 'moov_money',
    PaymentMethod.wave => 'wave',
    PaymentMethod.carteBancaire => 'carte_bancaire',
    PaymentMethod.especes => 'especes',
  };

  static PaymentMethod fromName(String name) => switch (name) {
    'mtn_money' => PaymentMethod.mtnMoney,
    'moov_money' => PaymentMethod.moovMoney,
    'carte_bancaire' => PaymentMethod.carteBancaire,
    'wave' => PaymentMethod.wave,
    'especes' => PaymentMethod.especes,
    _ => PaymentMethod.orangeMoney,
  };
}

enum PaymentStatus { enAttente, paye, echoue, expire, annule }

class Payment {
  const Payment({
    required this.id,
    required this.reference,
    required this.amountXOF,
    required this.method,
    required this.status,
    required this.idempotencyKey,
    required this.createdAt,
    required this.expiresAt,
    this.bookingId,
    this.parcelId,
    this.rentalId,
    this.gatewayRef,
    this.failureReason,
    this.confirmedAt,
  });

  final ID id;
  final String reference;
  final ID? bookingId;
  final ID? parcelId;
  final ID? rentalId;
  final Money amountXOF; // serverOnly
  final PaymentMethod method;
  final PaymentStatus status;
  final String idempotencyKey;
  final String? gatewayRef;
  final String? failureReason;
  final ISODateTime createdAt;
  final ISODateTime? confirmedAt;
  final ISODateTime expiresAt;
}

// ----------------------------- Billets -----------------------------

enum TicketStatus { emis, embarque, descendu, annule, expire }

/// Segment couvert par un billet.
enum TicketLeg {
  aller,
  retour;

  String get label => this == TicketLeg.aller ? 'ALLER' : 'RETOUR';
}

class Ticket {
  const Ticket({
    required this.id,
    required this.number,
    required this.bookingId,
    required this.passengerName,
    required this.companyName,
    required this.originCity,
    required this.destinationCity,
    required this.boardingStop,
    required this.alightingStop,
    required this.date,
    required this.departureTime,
    required this.arrivalTime,
    required this.seatNumber,
    required this.vehicleModel,
    required this.qrPayload,
    required this.signature,
    required this.keyVersion,
    required this.status,
    required this.issuedAt,
    required this.tripId,
    this.leg = TicketLeg.aller,
  });

  final ID id;
  final String number; // "MON-BLT-9XK4"
  final ID bookingId;
  final String passengerName;
  final String companyName;
  final String originCity;
  final String destinationCity;
  final String boardingStop;
  final String alightingStop;
  final ISODate date;
  final ISOTime departureTime;
  final ISOTime arrivalTime;
  final String seatNumber;
  final String vehicleModel;
  final String qrPayload;
  final String signature;
  final int keyVersion;
  final TicketStatus status;
  final ISODateTime issuedAt;
  final ID tripId;

  /// Aller ou retour (un billet par segment d'un aller-retour).
  final TicketLeg leg;
}

// ----------------------------- Colis -----------------------------

enum ParcelStatus {
  depose,
  enTransit,
  arriveGare,
  attenteRetrait,
  livre,
  litige,
  annule;

  String get apiName => switch (this) {
    ParcelStatus.depose => 'depose',
    ParcelStatus.enTransit => 'en_transit',
    ParcelStatus.arriveGare => 'arrive_gare',
    ParcelStatus.attenteRetrait => 'attente_retrait',
    ParcelStatus.livre => 'livre',
    ParcelStatus.litige => 'litige',
    ParcelStatus.annule => 'annule',
  };

  static ParcelStatus fromName(String name) => switch (name) {
    'en_transit' => ParcelStatus.enTransit,
    'arrive_gare' => ParcelStatus.arriveGare,
    'attente_retrait' => ParcelStatus.attenteRetrait,
    'livre' => ParcelStatus.livre,
    'litige' => ParcelStatus.litige,
    'annule' => ParcelStatus.annule,
    _ => ParcelStatus.depose,
  };
}

extension ParcelStatusLabel on ParcelStatus {
  String get label => switch (this) {
    ParcelStatus.depose => 'Déposé',
    ParcelStatus.enTransit => 'En transit',
    ParcelStatus.arriveGare => 'Arrivé à la gare',
    ParcelStatus.attenteRetrait => 'En attente de retrait',
    ParcelStatus.livre => 'Livré',
    ParcelStatus.litige => 'Litige',
    ParcelStatus.annule => 'Annulé',
  };
}

class ParcelTimelineEntry {
  const ParcelTimelineEntry({
    required this.status,
    required this.label,
    required this.location,
    required this.at,
    required this.done,
  });

  final ParcelStatus status;
  final String label;
  final String location;
  final ISODateTime at;
  final bool done;
}

class Parcel {
  const Parcel({
    required this.id,
    required this.trackingNumber,
    required this.senderName,
    required this.senderPhone,
    required this.recipientName,
    required this.recipientPhone,
    required this.originCity,
    required this.destinationCity,
    required this.originStop,
    required this.destinationStop,
    required this.weightKg,
    required this.dimensions,
    required this.description,
    required this.payeeIsSender,
    required this.amountXOF,
    required this.status,
    required this.timeline,
    required this.createdAt,
    this.tripId,
    this.photoUrl,
    this.paymentId,
  });

  final ID id;
  final String trackingNumber; // "MON-COL-XXXXXX"
  final String senderName;
  final String senderPhone;
  final String recipientName;
  final String recipientPhone;
  final String originCity;
  final String destinationCity;
  final String originStop;
  final String destinationStop;
  final ID? tripId;
  final double weightKg;
  final String dimensions; // "30x20x15"
  final String description;
  final String? photoUrl;

  /// Qui paie : expéditeur ou destinataire.
  final bool payeeIsSender;
  final Money amountXOF; // serverOnly
  final ParcelStatus status;
  final List<ParcelTimelineEntry> timeline;
  final ISODateTime createdAt;
  final ID? paymentId;
}

// ----------------------------- Location -----------------------------
// Cahier des charges, partie III (§25 à §51) : demande → confirmation
// du fournisseur → paiement sécurisé → remise → état des lieux →
// location active → restitution → contrôle → clôture.

/// Intérieur (reste dans la localité) ou extérieur (§27).
enum RentalArea {
  interieur,
  exterieur;

  String get label => this == interieur ? 'Intérieur' : 'Extérieur';
}

/// Motif / type d'utilisation (§28).
enum RentalPurpose {
  personnel('Déplacement personnel'),
  professionnel('Déplacement professionnel'),
  mariage('Mariage'),
  ceremonie('Cérémonie'),
  excursion('Excursion'),
  tourisme('Tourisme'),
  familial('Voyage familial'),
  seminaire('Séminaire'),
  evenement('Événement'),
  entreprise("Transport d'entreprise"),
  transfert('Transfert'),
  autre('Autre');

  const RentalPurpose(this.label);
  final String label;
}

/// Type de fournisseur, affiché clairement sur chaque résultat (§34).
enum RentalProviderKind {
  agence('AGENCE'),
  compagnie('COMPAGNIE'),
  individuel('INDIVIDUEL');

  const RentalProviderKind(this.label);
  final String label;
}

/// Offre chauffeur du véhicule. Un VTC est toujours avec chauffeur (§32).
enum DriverOffer { sansChauffeur, avecChauffeur, auChoix }

/// Durées proposées (§31).
enum RentalDurationPreset {
  demiJournee('Demi-journée'),
  journee('Journée'),
  plusieursJours('Plusieurs jours'),
  semaine('Semaine'),
  plusieursSemaines('Plusieurs semaines'),
  mois('Mois'),
  personnalisee('Personnalisée');

  const RentalDurationPreset(this.label);
  final String label;
}

/// Option payante proposée par le fournisseur (siège enfant, GPS…).
class RentalOption {
  const RentalOption({
    required this.id,
    required this.label,
    required this.pricePerDayXOF,
  });

  final ID id;
  final String label;
  final Money pricePerDayXOF; // serverOnly
}

class RentalVehicle {
  const RentalVehicle({
    required this.id,
    required this.type,
    required this.brand,
    required this.model,
    required this.year,
    required this.seats,
    required this.doors,
    required this.transmissionIsAutomatic,
    required this.fuel,
    required this.pricePerDayXOF,
    required this.rating,
    required this.reviewCount,
    required this.partner,
    required this.photoColor,
    required this.features,
    required this.city,
    required this.available,
    this.providerKind = RentalProviderKind.agence,
    this.driverOffer = DriverOffer.auChoix,
    this.color = 'Blanc',
    this.area = 'Plateau',
    this.allowsExterior = true,
    this.driverFeePerDayXOF = 10000,
    this.extraHourXOF = 3000,
    this.exteriorSurchargePct = 25,
    this.requiresExtensionApproval = true,
    this.options = const [],
    this.conditions = const [],
  });

  final ID id;
  final VehicleType type;
  final String brand;
  final String model;
  final int year;
  final int seats;
  final int doors;
  final bool transmissionIsAutomatic;
  final String fuel;
  final Money pricePerDayXOF; // serverOnly
  final double rating;
  final int reviewCount;

  /// Nom du fournisseur.
  final String partner;
  final RentalProviderKind providerKind;
  final String photoColor;
  final List<String> features;

  /// Localité et quartier de prise en charge.
  final String city;
  final String area;
  final bool available;
  final DriverOffer driverOffer;
  final String color;

  /// Le fournisseur accepte les déplacements hors de la localité.
  final bool allowsExterior;
  final Money driverFeePerDayXOF; // serverOnly
  final Money extraHourXOF; // serverOnly — heure supplémentaire (§46)
  final int exteriorSurchargePct; // serverOnly
  final bool requiresExtensionApproval;
  final List<RentalOption> options;
  final List<String> conditions;

  bool get isVtc => type == VehicleType.vtc;

  /// Transport collectif (minibus, bus, car) — §30.
  bool get isCollective =>
      type == VehicleType.minibus ||
      type == VehicleType.bus ||
      type == VehicleType.autocar;

  bool get hasAirConditioning => features.contains('Climatisation');

  /// Règle VTC : obligatoirement avec chauffeur.
  bool get canBeWithoutDriver =>
      !isVtc && driverOffer != DriverOffer.avecChauffeur;
  bool get canBeWithDriver => driverOffer != DriverOffer.sansChauffeur;

  /// « Toyota Corolla 2024 » (sans doubler l'année déjà dans le modèle).
  String get summary =>
      model.contains('$year') ? '$brand $model' : '$brand $model $year';
}

/// Critères de la demande de location (§26 à §33).
class RentalCriteria {
  const RentalCriteria({
    required this.pickupCity,
    required this.pickupLabel,
    required this.area,
    required this.purpose,
    required this.persons,
    required this.start,
    required this.end,
    required this.durationPreset,
    required this.withDriver,
    this.destinationCity,
    this.type,
    this.collective,
    this.usedGps = false,
  });

  /// Localité de prise en charge (filtre des véhicules).
  final String pickupCity;

  /// Adresse / point de prise en charge affiché.
  final String pickupLabel;
  final bool usedGps;
  final RentalArea area;

  /// Obligatoire en extérieur ; égale à la localité en intérieur.
  final String? destinationCity;
  final RentalPurpose purpose;
  final int persons;

  /// Catégorie : particulier (`false`), collectif (`true`) ou toutes.
  final bool? collective;
  final VehicleType? type;

  /// Heure PRÉVUE de prise en charge (pas le début réel, §31/§41).
  final ISODateTime start;
  final ISODateTime end;
  final RentalDurationPreset durationPreset;
  final bool withDriver;

  String get destination =>
      area == RentalArea.exterieur ? (destinationCity ?? '—') : pickupCity;
}

class RentalQuoteLine {
  const RentalQuoteLine(this.label, this.amountXOF);
  final String label;
  final Money amountXOF;
}

/// Facture avant paiement (§38) : TOTAL = X + Y + Z. La commission
/// MON CAR sur le fournisseur n'y figure jamais.
class RentalQuote {
  const RentalQuote({
    required this.brutLines,
    required this.brutXOF,
    required this.feesXOF,
    required this.otherFees,
    required this.otherFeesXOF,
    required this.totalXOF,
    required this.billableLabel,
  });

  /// X — montant brut de la location (détail).
  final List<RentalQuoteLine> brutLines;
  final Money brutXOF;

  /// Y — frais d'opération (paramétrables par MON CAR).
  final Money feesXOF;

  /// Z — autres frais applicables.
  final List<RentalQuoteLine> otherFees;
  final Money otherFeesXOF;
  final Money totalXOF;

  /// « 3 jours », « Demi-journée »…
  final String billableLabel;
}

enum RentalStatus {
  /// Demande envoyée — EN ATTENTE DE CONFIRMATION (§36).
  demandee('En attente de confirmation'),
  refusee('Refusée'),

  /// Confirmée par le fournisseur — à payer (§37).
  confirmee('Confirmée · à payer'),

  /// Payée, fonds sécurisés ; véhicule en préparation (§39-40).
  payee('Payée'),

  /// Véhicule remis — état des lieux client attendu (§40-42).
  remise('Véhicule remis'),
  active('Location active'),

  /// Véhicule restitué — contrôle du retour en cours (§47-48).
  restituee('Restitué · contrôle'),
  terminee('Terminée'),
  annulee('Annulée');

  const RentalStatus(this.label);
  final String label;
}

/// Emplacements photo de l'état des lieux (§42).
const rentalPhotoSlots = <(String, String)>[
  ('plaque', 'Plaque'),
  ('carte_grise', 'Carte grise'),
  ('avant', 'Avant'),
  ('arriere', 'Arrière'),
  ('cote_gauche', 'Côté gauche'),
  ('cote_droit', 'Côté droit'),
  ('interieur', 'Intérieur'),
  ('tableau_bord', 'Tableau de bord'),
];

/// État du véhicule (départ ou retour) : preuve numérique (§42/§47).
class VehicleCondition {
  const VehicleCondition({
    required this.recordedAt,
    required this.mileageKm,
    required this.fuelEighths,
    required this.photos,
    this.damages = '',
    this.conforme = true,
    this.anomaly = '',
    this.recordedBy = 'client',
  });

  final ISODateTime recordedAt;
  final int mileageKm;

  /// Niveau de carburant en huitièmes (0 à 8).
  final int fuelEighths;

  /// Emplacements photographiés (clés de [rentalPhotoSlots]).
  final List<String> photos;

  /// Dommages déjà présents.
  final String damages;
  final bool conforme;
  final String anomaly;
  final String recordedBy;
}

enum RentalChargeKind { prolongation, heuresSupplementaires }

/// Facture complémentaire à régler (prolongation §45, heures
/// supplémentaires §46).
class RentalCharge {
  const RentalCharge({
    required this.kind,
    required this.label,
    required this.lines,
    required this.amountXOF,
    this.extensionId,
  });

  final RentalChargeKind kind;
  final String label;
  final List<RentalQuoteLine> lines;
  final Money amountXOF; // serverOnly
  final ID? extensionId;
}

enum RentalExtensionStatus {
  demandee('En attente du fournisseur'),
  acceptee('Acceptée · à payer'),
  refusee('Refusée'),
  payee('Payée');

  const RentalExtensionStatus(this.label);
  final String label;
}

class RentalExtension {
  const RentalExtension({
    required this.id,
    required this.extraLabel,
    required this.newEnd,
    required this.amountXOF,
    required this.status,
    required this.requestedAt,
  });

  final ID id;
  final String extraLabel;
  final ISODateTime newEnd;
  final Money amountXOF; // serverOnly
  final RentalExtensionStatus status;
  final ISODateTime requestedAt;
}

enum RentalIncidentNature {
  panne('Panne'),
  accident('Accident'),
  dommage('Dommage'),
  anomalie('Anomalie à la remise'),
  autre('Autre');

  const RentalIncidentNature(this.label);
  final String label;
}

enum RentalIncidentStatus {
  ouvert('Ouvert'),
  enExamen('En examen'),
  clos('Clos');

  const RentalIncidentStatus(this.label);
  final String label;
}

/// Dossier d'incident (§49) : la responsabilité n'est jamais imputée
/// automatiquement au client.
class RentalIncident {
  const RentalIncident({
    required this.id,
    required this.nature,
    required this.description,
    required this.at,
    required this.location,
    required this.status,
    this.photoCount = 0,
    this.declaredBy = 'client',
  });

  final ID id;
  final RentalIncidentNature nature;
  final String description;
  final ISODateTime at;
  final String location;
  final RentalIncidentStatus status;
  final int photoCount;
  final String declaredBy;
}

class RentalEvent {
  const RentalEvent(this.label, this.at);
  final String label;
  final ISODateTime at;
}

class Rental {
  const Rental({
    required this.id,
    required this.reference,
    required this.vehicleId,
    required this.vehicleSummary,
    required this.providerName,
    required this.providerKind,
    required this.criteria,
    required this.quote,
    required this.status,
    required this.createdAt,
    required this.timeline,
    this.optionLabels = const [],
    this.driverName,
    this.paymentId,
    this.refusalReason,
    this.handoverAt,
    this.handoverLocation,
    this.startCondition,
    this.returnedAt,
    this.returnCondition,
    this.extensions = const [],
    this.incidents = const [],
    this.pendingCharge,
    this.extraCharges = const [],
    this.plannedEndOverride,
    this.rating,
    this.review,
    this.licenseNumber,
    this.idDocumentNumber,
  });

  final ID id;
  final String reference; // "MON-LOC-XXXX"
  final ID vehicleId;
  final String vehicleSummary;
  final String providerName;
  final RentalProviderKind providerKind;
  final RentalCriteria criteria;
  final List<String> optionLabels;
  final RentalQuote quote;
  final RentalStatus status;
  final ISODateTime createdAt;

  /// Historique horodaté de chaque étape (§63 règle 20).
  final List<RentalEvent> timeline;
  final String? driverName;
  final ID? paymentId;
  final String? refusalReason;

  /// Remise effective = début RÉEL de la location (§41).
  final ISODateTime? handoverAt;
  final String? handoverLocation;
  final VehicleCondition? startCondition;
  final ISODateTime? returnedAt;
  final VehicleCondition? returnCondition;
  final List<RentalExtension> extensions;
  final List<RentalIncident> incidents;

  /// Facture complémentaire en attente de paiement.
  final RentalCharge? pendingCharge;

  /// Factures complémentaires déjà réglées.
  final List<RentalCharge> extraCharges;

  /// Nouvelle fin prévue après prolongation.
  final ISODateTime? plannedEndOverride;
  final int? rating;
  final String? review;
  final String? licenseNumber;
  final String? idDocumentNumber;

  bool get withDriver => criteria.withDriver;
  ISODateTime get plannedStart => criteria.start;
  ISODateTime get plannedEnd => plannedEndOverride ?? criteria.end;

  /// Retard de remise en minutes (heure réelle − heure prévue).
  int? get handoverDelayMin {
    final real = DateTime.tryParse(handoverAt ?? '');
    final planned = DateTime.tryParse(plannedStart);
    if (real == null || planned == null) return null;
    return real.difference(planned).inMinutes;
  }

  /// Litige éventuel : incident non clos.
  bool get hasOpenIncident =>
      incidents.any((i) => i.status != RentalIncidentStatus.clos);

  Money get paidTotalXOF =>
      quote.totalXOF + extraCharges.fold(0, (s, c) => s + c.amountXOF);

  Rental copyWith({
    RentalStatus? status,
    List<RentalEvent>? timeline,
    String? driverName,
    ID? paymentId,
    String? refusalReason,
    ISODateTime? handoverAt,
    String? handoverLocation,
    VehicleCondition? startCondition,
    ISODateTime? returnedAt,
    VehicleCondition? returnCondition,
    List<RentalExtension>? extensions,
    List<RentalIncident>? incidents,
    RentalCharge? pendingCharge,
    bool clearPendingCharge = false,
    List<RentalCharge>? extraCharges,
    ISODateTime? plannedEndOverride,
    int? rating,
    String? review,
  }) {
    return Rental(
      id: id,
      reference: reference,
      vehicleId: vehicleId,
      vehicleSummary: vehicleSummary,
      providerName: providerName,
      providerKind: providerKind,
      criteria: criteria,
      optionLabels: optionLabels,
      quote: quote,
      status: status ?? this.status,
      createdAt: createdAt,
      timeline: timeline ?? this.timeline,
      driverName: driverName ?? this.driverName,
      paymentId: paymentId ?? this.paymentId,
      refusalReason: refusalReason ?? this.refusalReason,
      handoverAt: handoverAt ?? this.handoverAt,
      handoverLocation: handoverLocation ?? this.handoverLocation,
      startCondition: startCondition ?? this.startCondition,
      returnedAt: returnedAt ?? this.returnedAt,
      returnCondition: returnCondition ?? this.returnCondition,
      extensions: extensions ?? this.extensions,
      incidents: incidents ?? this.incidents,
      pendingCharge: clearPendingCharge
          ? null
          : (pendingCharge ?? this.pendingCharge),
      extraCharges: extraCharges ?? this.extraCharges,
      plannedEndOverride: plannedEndOverride ?? this.plannedEndOverride,
      rating: rating ?? this.rating,
      review: review ?? this.review,
      licenseNumber: licenseNumber,
      idDocumentNumber: idDocumentNumber,
    );
  }
}

// ----------------------------- Promotions -----------------------------

enum PromoType { pourcentage, montant }

enum PromoService { voyager, colis, location, tous }

class Promotion {
  const Promotion({
    required this.id,
    required this.code,
    required this.title,
    required this.description,
    required this.type,
    required this.value,
    required this.service,
    required this.minTier,
    required this.validFrom,
    required this.validUntil,
    required this.usageMax,
    required this.usageCount,
    required this.terms,
    required this.imageColor,
    this.featured = false,
  });

  final ID id;
  final String code;
  final String title;
  final String description;
  final PromoType type;

  /// Pourcentage (5-50) ou montant XOF selon [type].
  final int value;
  final PromoService service;
  final LoyaltyTier minTier;
  final ISODate validFrom;
  final ISODate validUntil;
  final int usageMax;
  final int usageCount;
  final String terms;
  final String imageColor;
  final bool featured;
}

enum PromoInvalidReason {
  invalide,
  expire,
  mauvaisService,
  tierInsuffisant,
  usageAtteint,
}

class PromoValidation {
  const PromoValidation({
    required this.valid,
    required this.message,
    required this.discountXOF,
    required this.newTotalXOF,
    this.reasonCode,
  });

  final bool valid;
  final PromoInvalidReason? reasonCode;
  final String message;
  final Money discountXOF;
  final Money newTotalXOF;
}

// ----------------------------- Fidélité -----------------------------

enum LoyaltyTier { standard, argent, or, vip }

LoyaltyTier loyaltyTierFromName(String name) => switch (name) {
  'argent' => LoyaltyTier.argent,
  'or' => LoyaltyTier.or,
  'vip' => LoyaltyTier.vip,
  _ => LoyaltyTier.standard,
};

extension LoyaltyTierLabel on LoyaltyTier {
  String get label => switch (this) {
    LoyaltyTier.standard => 'Standard',
    LoyaltyTier.argent => 'Argent',
    LoyaltyTier.or => 'Or',
    LoyaltyTier.vip => 'VIP',
  };
}

int loyaltyTierRank(LoyaltyTier tier) => switch (tier) {
  LoyaltyTier.standard => 0,
  LoyaltyTier.argent => 1,
  LoyaltyTier.or => 2,
  LoyaltyTier.vip => 3,
};

enum LoyaltyRewardType { remise, trajetGratuit, upgrade, cadeau }

class LoyaltyReward {
  const LoyaltyReward({
    required this.id,
    required this.title,
    required this.description,
    required this.pointCost,
    required this.type,
    required this.tierMin,
    required this.imageColor,
  });

  final ID id;
  final String title;
  final String description;
  final int pointCost;
  final LoyaltyRewardType type;
  final LoyaltyTier tierMin;
  final String imageColor;
}

class LoyaltyPointMovement {
  const LoyaltyPointMovement({
    required this.id,
    required this.type,
    required this.reason,
    required this.points,
    required this.at,
  });

  final ID id;

  /// "gain" | "spend" | "expiry".
  final String type;
  final String reason;
  final int points;
  final ISODateTime at;
}

class Loyalty {
  const Loyalty({
    required this.userId,
    required this.tier,
    required this.points,
    required this.pointsToNextTier,
    required this.nextTier,
    required this.progressPct,
    required this.tierBenefits,
    required this.expiryDate,
    required this.rewards,
    required this.history,
  });

  final ID userId;
  final LoyaltyTier tier;
  final int points;
  final int pointsToNextTier;
  final LoyaltyTier? nextTier;
  final int progressPct;
  final List<String> tierBenefits;
  final ISODate expiryDate;
  final List<LoyaltyReward> rewards;
  final List<LoyaltyPointMovement> history;
}

// ----------------------------- Notifications -----------------------------

enum NotificationCategory {
  voyager,
  colis,
  location,
  paiement,
  securite,
  promotion,
  systeme;

  static NotificationCategory fromName(String name) =>
      NotificationCategory.values.firstWhere(
        (c) => c.name == name,
        orElse: () => NotificationCategory.systeme,
      );
}

class NotificationLinkTarget {
  const NotificationLinkTarget({required this.type, required this.id});
  final String type; // "billet" | "colis" | "voyage" | "location" | "promo"
  final ID id;
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.category,
    required this.title,
    required this.body,
    required this.read,
    required this.createdAt,
    required this.iconColor,
    this.linkTarget,
    this.muted = false,
  });

  final ID id;
  final NotificationCategory category;
  final String title;
  final String body;
  final bool read;
  final NotificationLinkTarget? linkTarget;
  final ISODateTime createdAt;
  final String iconColor;
  final bool muted;
}

// ----------------------------- Auth / Utilisateur -----------------------------

class UserDevice {
  const UserDevice({
    required this.id,
    required this.label,
    required this.lastActive,
    required this.current,
  });

  final ID id;
  final String label;
  final ISODateTime lastActive;
  final bool current;
}

class AppUser {
  const AppUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.email,
    required this.city,
    required this.initials,
    required this.cguAcceptedAt,
    required this.loyaltyTier,
    required this.loyaltyPoints,
    required this.permissions,
    required this.devices,
    this.photoUrl,
  });

  final ID id;
  final String firstName;
  final String lastName;
  final String phone;
  final String email;
  final String city;
  final String? photoUrl;
  final String initials;
  final ISODateTime cguAcceptedAt;
  final LoyaltyTier loyaltyTier;
  final int loyaltyPoints;
  final List<String> permissions;
  final List<UserDevice> devices;

  /// Copie avec les champs éditables du profil ; les initiales sont
  /// recalculées à partir du prénom et du nom.
  AppUser copyWith({
    String? firstName,
    String? lastName,
    String? phone,
    String? email,
    String? city,
    List<UserDevice>? devices,
  }) {
    final f = firstName ?? this.firstName;
    final l = lastName ?? this.lastName;
    return AppUser(
      id: id,
      firstName: f,
      lastName: l,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      city: city ?? this.city,
      initials: '${f.isEmpty ? '' : f[0]}${l.isEmpty ? '' : l[0]}'
          .toUpperCase(),
      cguAcceptedAt: cguAcceptedAt,
      loyaltyTier: loyaltyTier,
      loyaltyPoints: loyaltyPoints,
      permissions: permissions,
      devices: devices ?? this.devices,
      photoUrl: photoUrl,
    );
  }
}

class AuthSession {
  const AuthSession({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  final AppUser user;
  final String accessToken;
  final String refreshToken;
  final ISODateTime expiresAt;
}

// ----------------------------- Suivi GPS -----------------------------

enum TrackingState { enAttente, disponible, faible, horsLigne, termine }

TrackingState trackingStateFromName(String name) => switch (name) {
  'disponible' => TrackingState.disponible,
  'faible' => TrackingState.faible,
  'hors_ligne' => TrackingState.horsLigne,
  'termine' => TrackingState.termine,
  _ => TrackingState.enAttente,
};

class TrackingStopState {
  const TrackingStopState({
    required this.id,
    required this.name,
    required this.status,
    this.arrivalTime,
    this.reachedAt,
  });

  final ID id;
  final String name;
  final ISOTime? arrivalTime;

  /// "passe" | "actuel" | "a_venir".
  final String status;
  final ISODateTime? reachedAt;
}

class BusPosition {
  const BusPosition({
    required this.tripId,
    required this.latitude,
    required this.longitude,
    required this.heading,
    required this.speedKmh,
    required this.lastUpdate,
    required this.state,
    required this.currentStopIndex,
    required this.etaToNextStopMin,
    required this.progressPct,
    required this.stops,
    this.nextStopId,
    this.nextStopName,
  });

  final ID tripId;
  final double latitude;
  final double longitude;
  final double heading;
  final double speedKmh;
  final ISODateTime lastUpdate;
  final TrackingState state;
  final int currentStopIndex;
  final ID? nextStopId;
  final String? nextStopName;
  final int etaToNextStopMin;
  final int progressPct; // 0-100 le long de la ligne
  final List<TrackingStopState> stops;
}
