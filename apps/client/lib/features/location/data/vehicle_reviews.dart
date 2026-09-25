import 'dart:math';

import '../../shared/foundation.dart';

typedef VehicleReview = ({
  String name,
  String initials,
  int rating,
  String date,
  String body,
});

const _names = [
  'Awa Koné',
  'Mamadou Touré',
  'Fatou Bamba',
  'Yao Kouassi',
  'Aminata Diallo',
  'Serge Kouamé',
  'Mariam Ouattara',
  'Jean-Marc Aka',
  'Salimata Coulibaly',
  'Didier N’Guessan',
  'Christelle Yapi',
  'Ibrahim Sanogo',
];

const _bodies = {
  5: [
    'Véhicule impeccable, ponctuel au rendez-vous. Je recommande vivement.',
    'Service au top du début à la fin. Réservation simple, paiement Orange Money fluide.',
    'Voiture récente et très propre, climatisation parfaite. Merci MON CAR !',
    'Chauffeur courtois et prudent, trajet très agréable.',
  ],
  4: [
    'Bonne expérience globale. Petit retard au retour mais rien de grave.',
    'Véhicule confortable, prise en charge rapide. Je reprendrai.',
    'Bon rapport qualité-prix, quelques traces d’usure à l’intérieur.',
  ],
  3: [
    'Correct, mais le véhicule n’était pas aussi propre que sur les photos.',
    'Prise en charge avec 30 minutes de retard, sinon rien à signaler.',
  ],
  2: ['Climatisation faible et accueil moyen à l’agence.'],
};

const _dates = [
  'il y a 3 jours',
  'il y a 1 semaine',
  'il y a 2 semaines',
  'il y a 3 semaines',
  'il y a 1 mois',
  'il y a 2 mois',
];

/// Avis de démonstration, stables pour un véhicule donné et cohérents
/// avec sa note moyenne. ⚠️ MOCK : GET /rentals/vehicles/:id/reviews.
List<VehicleReview> vehicleReviews(RentalVehicle v) {
  final rnd = Random(v.id.hashCode);
  final count = min(v.reviewCount, 24);
  return List.generate(count, (i) {
    // Note tirée autour de la moyenne du véhicule.
    final r = (v.rating + (rnd.nextDouble() - 0.5) * 2.2).round().clamp(2, 5);
    final name = _names[(i + rnd.nextInt(_names.length)) % _names.length];
    final parts = name.split(RegExp(r'[ -]'));
    final bodies = _bodies[r]!;
    return (
      name: name,
      initials: '${parts.first[0]}${parts.last[0]}'.toUpperCase(),
      rating: r,
      date: _dates[min(i ~/ 4, _dates.length - 1)],
      body: bodies[rnd.nextInt(bodies.length)],
    );
  });
}
