// ============================================================
// MON CAR PRO — Jeu de données de démonstration (mocks réalistes).
//
// ⚠️ MOCK : simule les réponses de l'API Symfony / API Platform tant
// que le contrat OpenAPI n'est pas gelé (méthode contract-first,
// roadmap §11). Ligne pilote Abidjan → Yamoussoukro (Jalon 1).
// La compagnie est fictive.
// ============================================================

library;

import '../domain/models.dart';

const demoCompany = 'Lagune Express (démo)';

/// « 0700000001 » → « +225 07 00 00 00 01 ».
String formatCiPhone(String local) {
  final d = local.replaceAll(RegExp(r'\D'), '');
  if (d.length != 10) return local;
  return '+225 ${d.substring(0, 2)} ${d.substring(2, 4)} '
      '${d.substring(4, 6)} ${d.substring(6, 8)} ${d.substring(8)}';
}

const _demoNames = {
  ProRole.controleur: 'Kouadio Yao',
  ProRole.convoyeur: 'Aminata Koné',
  ProRole.chauffeur: 'Issouf Traoré',
  ProRole.agentBusiness: 'Fatou Bamba',
};

/// Compte de démonstration. Un compte multi-postes (tous les profils)
/// permet la recette complète sur un seul téléphone.
ProUser demoAccount(String phone, List<ProRole> roles) => ProUser(
  id: 'agt-${phone.substring(phone.length - 4)}',
  name: roles.length == 1 ? _demoNames[roles.first]! : 'Kouadio Yao',
  phone: formatCiPhone(phone),
  company: roles.length == 1 && roles.first == ProRole.agentBusiness
      ? businessStructures.first.name
      : demoCompany,
  station: roles.length == 1 && roles.first == ProRole.agentBusiness
      ? businessStructures.first.sites.first
      : 'Gare d’Abobo',
  roles: roles,
);

/// Structure de rattachement proposée à l'inscription (compagnie + gares,
/// ou agence de location + sites). ⚠️ MOCK : liste fournie par
/// `GET /compagnies` et `GET /gares` (référentiels REF-001).
class Structure {
  const Structure(this.name, this.sites);
  final String name;
  final List<String> sites;
}

const transportCompanies = [
  Structure(demoCompany, [
    'Gare d’Abobo',
    'Gare d’Adjamé',
    'Gare de Yamoussoukro',
    'Gare de Bouaké',
  ]),
  Structure('Savane Transport (démo)', [
    'Gare d’Adjamé',
    'Gare de Korhogo',
    'Gare de Bouaké',
  ]),
];

const businessStructures = [
  Structure('Plateau Location (démo)', [
    'Agence du Plateau',
    'Agence de Cocody',
    'Agence de Marcory',
  ]),
  Structure('Lagune Auto Services (démo)', [
    'Agence de Yopougon',
    'Agence de Grand-Bassam',
  ]),
];

DateTime _at(int h, int m) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day, h, m);
}

/// Arrêts réels de l'axe pilote (autoroute du Nord).
List<Stop> demoStops() => [
  Stop(
    id: 'abo',
    name: 'Abidjan — Gare d’Abobo',
    shortName: 'Abidjan',
    order: 0,
    lat: 5.4308,
    lng: -4.0197,
    plannedAt: _at(8, 0),
  ),
  Stop(
    id: 'any',
    name: 'Anyama — Carrefour',
    shortName: 'Anyama',
    order: 1,
    lat: 5.4946,
    lng: -4.0518,
    plannedAt: _at(8, 25),
    kmFromOrigin: 12,
  ),
  Stop(
    id: 'ndo',
    name: 'N’Douci — Gare',
    shortName: 'N’Douci',
    order: 2,
    lat: 5.8653,
    lng: -4.7615,
    plannedAt: _at(9, 40),
    kmFromOrigin: 105,
  ),
  Stop(
    id: 'tou',
    name: 'Toumodi — Gare routière',
    shortName: 'Toumodi',
    order: 3,
    lat: 6.5580,
    lng: -5.0194,
    plannedAt: _at(10, 55),
    kmFromOrigin: 190,
  ),
  Stop(
    id: 'yam',
    name: 'Yamoussoukro — Gare principale',
    shortName: 'Yamoussoukro',
    order: 4,
    lat: 6.8205,
    lng: -5.2767,
    plannedAt: _at(11, 40),
    kmFromOrigin: 240,
  ),
];

Voyage demoVoyage() => Voyage(
  id: 'vy-0427',
  number: 'LEX-0427',
  companyName: demoCompany,
  stops: demoStops(),
  departurePlanned: _at(8, 0),
  vehiclePlate: 'CI 5821 AB 01',
  vehicleType: 'Car 53 places · VIP climatisé',
  totalSeats: 53,
  driverName: 'Issouf Traoré',
  convoyeurName: 'Aminata Koné',
  controleurName: 'Kouadio Yao',
  status: VoyageStatus.embarquement,
);

const _names = [
  'Aya N’Guessan',
  'Koffi Brou',
  'Mariam Cissé',
  'Serge Aka',
  'Linda Affoué',
  'Yves Esmel',
  'Adjoa Kouamé',
  'Brahima Sidibé',
  'Christelle Tanoh',
  'Moussa Diallo',
  'Pascale Yoboué',
  'Hervé Gnéba',
  'Salimata Coulibaly',
  'Pascal Tano',
  'Euloge Aka',
  'Fatou Bamba',
  'Jean-Marc Kacou',
  'Awa Ouattara',
  'Didier Zadi',
  'Nadège Assi',
  'Ibrahim Konaté',
  'Grâce Ahoua',
  'Rodrigue Mel',
  'Estelle Djédjé',
];

/// Manifeste téléchargé avant le départ (billets attendus).
List<Passenger> demoPassengers() {
  final now = DateTime.now();
  final seatLetters = ['A', 'B', 'C', 'D'];
  return [
    for (var i = 0; i < _names.length; i++)
      Passenger(
        id: 'p${i + 1}',
        name: _names[i],
        seat: '${i ~/ 4 + 1}${seatLetters[i % 4]}',
        ticketRef: 'BIL-0427-${(i + 1).toString().padLeft(3, '0')}',
        // 3 passagers montent en route (embarquement intermédiaire).
        boardStopId: switch (i) {
          20 || 21 => 'any',
          22 => 'ndo',
          _ => 'abo',
        },
        dropStopId: switch (i % 5) {
          0 => 'ndo',
          1 || 2 => 'yam',
          3 => 'tou',
          _ => 'yam',
        },
        phone:
            '+225 07 ${(10 + i).toString()} ${(20 + i).toString()} ${(30 + i).toString()}',
        ticketState: i == 17 ? TicketState.annule : TicketState.valide,
        hasBaggage: i % 3 == 0,
        hasParcel: i % 7 == 0,
        controlledAt: i < 13
            ? now.subtract(Duration(minutes: 40 - i * 2))
            : null,
        controlledBy: i < 13 ? (i == 4 ? 'Aminata Koné' : 'Kouadio Yao') : null,
        boardedAt: i < 9 ? now.subtract(Duration(minutes: 30 - i * 2)) : null,
      ),
  ];
}

/// Billets d'autres voyages connus localement (détection « mauvais voyage »).
const otherVoyageTickets = {
  'BIL-0430-118': ('LEX-0430', 'Abidjan → Bouaké'),
  'BIL-0512-044': ('LEX-0512', 'Abidjan → San-Pédro'),
};

List<Bag> demoBags(List<Passenger> passengers) => [
  for (final (i, p) in passengers.where((p) => p.hasBaggage).indexed)
    Bag(
      id: 'bag${i + 1}',
      ref: 'BAG-${1001 + i}',
      passengerName: p.name,
      seat: p.seat,
      dropStopId: p.dropStopId,
      weightKg: 8.0 + (i * 3.5) % 14,
      status: i == 5
          ? BagStatus.incident
          : (p.boardedAt != null ? BagStatus.aBord : BagStatus.enregistre),
      checked: p.controlledAt != null,
      note: i == 5 ? 'Étiquette arrachée — identification à refaire' : null,
    ),
];

List<Parcel> demoParcels() => const [
  Parcel(
    id: 'col1',
    ref: 'COL-9001',
    sender: 'Affoué K.',
    recipient: 'Brou M.',
    recipientPhone: '+225 07 12 34 56 78',
    dropStopId: 'ndo',
    nature: 'Carton',
    weightKg: 4,
    status: ParcelStatus.enTransit,
  ),
  Parcel(
    id: 'col2',
    ref: 'COL-9002',
    sender: 'Tanoh S.',
    recipient: 'Koné B.',
    recipientPhone: '+225 05 44 21 90 11',
    dropStopId: 'tou',
    nature: 'Sac',
    weightKg: 8,
    status: ParcelStatus.enTransit,
  ),
  Parcel(
    id: 'col3',
    ref: 'COL-9003',
    sender: 'Diallo F.',
    recipient: 'Cissé A.',
    recipientPhone: '+225 01 02 03 04 05',
    dropStopId: 'yam',
    nature: 'Enveloppe',
    weightKg: 0.2,
    status: ParcelStatus.enTransit,
  ),
  Parcel(
    id: 'col4',
    ref: 'COL-9004',
    sender: 'Aka P.',
    recipient: 'Yéo M.',
    recipientPhone: '+225 07 88 77 66 55',
    dropStopId: 'yam',
    nature: 'Électroménager',
    weightKg: 12,
    status: ParcelStatus.enTransit,
  ),
  Parcel(
    id: 'col5',
    ref: 'COL-9005',
    sender: 'Gnéba H.',
    recipient: 'Sidibé K.',
    recipientPhone: '+225 05 11 22 33 44',
    dropStopId: 'ndo',
    nature: 'Carton',
    weightKg: 6,
    status: ParcelStatus.litige,
  ),
];

List<Incident> demoIncidents() => [
  Incident(
    id: 'inc1',
    category: IncidentCategory.retard,
    severity: IncidentSeverity.faible,
    description: 'Affluence au départ — embarquement prolongé de 7 min.',
    createdAt: DateTime.now().subtract(const Duration(minutes: 35)),
    author: 'Issouf Traoré',
    status: IncidentStatus.resolu,
    locationLabel: 'Gare d’Abobo',
    synced: true,
  ),
  Incident(
    id: 'inc2',
    category: IncidentCategory.bagage,
    severity: IncidentSeverity.moyenne,
    description: 'BAG-1006 : étiquette arrachée, identification à refaire.',
    createdAt: DateTime.now().subtract(const Duration(minutes: 18)),
    author: 'Aminata Koné',
    status: IncidentStatus.enCours,
    locationLabel: 'Gare d’Abobo',
    synced: true,
  ),
];

List<RentalTask> demoRentalTasks() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return [
    RentalTask(
      id: 'rt1',
      ref: 'LOC-2026-1187',
      type: RentalTaskType.remise,
      clientName: 'Office du Tourisme — Délégation Bouaké',
      clientPhone: '+225 27 31 00 00 00',
      vehiclePlate: 'CI 9921 CD 01',
      vehicleModel: 'Toyota Hiace · 12 places',
      scheduledAt: today.add(const Duration(hours: 10)),
      withDriver: false,
      status: RentalTaskStatus.aFaire,
      initialKm: 42180,
      initialFuel: 100,
    ),
    RentalTask(
      id: 'rt2',
      ref: 'LOC-2026-1162',
      type: RentalTaskType.restitution,
      clientName: 'Société Cofonis',
      clientPhone: '+225 27 30 55 12 00',
      vehiclePlate: 'CI 7730 AB 01',
      vehicleModel: 'Hyundai H1 · 8 places',
      scheduledAt: today.add(const Duration(hours: 14, minutes: 30)),
      withDriver: false,
      status: RentalTaskStatus.aFaire,
      initialKm: 38540,
      initialFuel: 100,
      initialChecklist: const [
        true,
        true,
        true,
        true,
        true,
        true,
        true,
        true,
        true,
        true,
      ],
    ),
    RentalTask(
      id: 'rt3',
      ref: 'VTC-2026-0311',
      type: RentalTaskType.remise,
      clientName: 'M. Serge Kouassi',
      clientPhone: '+225 07 58 21 44 10',
      vehiclePlate: 'CI 1144 EF 01',
      vehicleModel: 'Toyota Corolla · VTC avec chauffeur',
      scheduledAt: today.add(const Duration(hours: 17)),
      withDriver: true,
      status: RentalTaskStatus.aFaire,
      initialKm: 18702,
      initialFuel: 80,
    ),
  ];
}

/// Points de contrôle de la checklist d'état (remise / restitution).
const checklistLabels = [
  'Carrosserie / chocs',
  'Pneus (état + pression)',
  'Phares, feux, clignotants',
  'Rétroviseurs',
  'Pare-brise & essuie-glaces',
  'Intérieur & sièges',
  'Climatisation',
  'Clés & carte grise',
  'Roue de secours & outillage',
  'Extincteur & triangle',
];

List<ProNotification> demoNotifications() {
  final now = DateTime.now();
  return [
    ProNotification(
      id: 'n1',
      title: 'Voyage LEX-0427 affecté',
      body: 'Départ 08:00 · Abidjan → Yamoussoukro · Car CI 5821 AB 01.',
      category: NotifCategory.information,
      at: now.subtract(const Duration(hours: 2)),
      route: '/voyage',
    ),
    ProNotification(
      id: 'n2',
      title: 'Bagage en anomalie',
      body: 'BAG-1006 : étiquette arrachée, identification à refaire.',
      category: NotifCategory.alerte,
      at: now.subtract(const Duration(minutes: 18)),
      route: '/incidents',
    ),
    ProNotification(
      id: 'n3',
      title: 'Colis en litige — COL-9005',
      body: 'Emballage endommagé signalé par la gare d’Abobo.',
      category: NotifCategory.critique,
      at: now.subtract(const Duration(minutes: 12)),
      route: '/conv/colis',
    ),
    ProNotification(
      id: 'n4',
      title: 'Manifeste téléchargé',
      body: '24 billets attendus disponibles hors ligne.',
      category: NotifCategory.succes,
      at: now.subtract(const Duration(minutes: 50)),
      read: true,
      route: '/manifeste',
    ),
  ];
}
