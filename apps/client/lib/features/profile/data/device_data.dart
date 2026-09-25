import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';

import '../../shared/foundation.dart';

/// Vide le cache d'images et le dossier temporaire de l'app (PDF
/// générés, photos redimensionnées…). Renvoie le nombre d'octets libérés.
Future<int> clearAppCache() async {
  final images = PaintingBinding.instance.imageCache;
  var freed = images.currentSizeBytes;
  images
    ..clear()
    ..clearLiveImages();
  if (kIsWeb) return freed;
  try {
    final tmp = await getTemporaryDirectory();
    if (await tmp.exists()) {
      await for (final e in tmp.list(followLinks: false)) {
        try {
          if (e is File) {
            freed += await e.length();
          } else if (e is Directory) {
            await for (final f in e.list(recursive: true, followLinks: false)) {
              if (f is File) freed += await f.length();
            }
          }
          await e.delete(recursive: true);
        } catch (_) {
          // Fichier en cours d'utilisation : ignoré.
        }
      }
    }
  } catch (_) {}
  return freed;
}

/// Taille lisible (« 5,2 Mo »).
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes o';
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1).replaceAll('.', ',')} Ko';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1).replaceAll('.', ',')} Mo';
}

/// Export des données personnelles (droit d'accès, loi n°2013-450) au
/// format JSON lisible. ⚠️ MOCK : construit à partir des données
/// locales ; à terme GET /users/me/export.
String buildPersonalDataExport({
  required AppUser user,
  required MockStore store,
  required AppPreferences prefs,
  required List<FavoriteRoute> favorites,
}) {
  final data = {
    'export': {'application': 'MON CAR', 'genere_le': isoNow()},
    'profil': {
      'prenom': user.firstName,
      'nom': user.lastName,
      'telephone': user.phone,
      'email': user.email,
      'ville': user.city,
      'niveau_fidelite': user.loyaltyTier.name,
      'points_fidelite': user.loyaltyPoints,
      'cgu_acceptees_le': user.cguAcceptedAt,
      'appareils': [
        for (final d in user.devices)
          {'appareil': d.label, 'derniere_activite': d.lastActive},
      ],
    },
    'reservations': [
      for (final b in store.bookings)
        {
          'reference': b.reference,
          'trajet': b.tripSummary,
          'compagnie': b.companyName,
          'date': b.date,
          'depart': b.departureTime,
          'sieges': b.seats,
          'passagers': [
            for (final p in b.passengers)
              {
                'nom': '${p.firstName} ${p.lastName}',
                'telephone': p.phone,
                'siege': p.seatNumber,
              },
          ],
          'total_fcfa': b.totalXOF,
          'statut': b.status.name,
        },
    ],
    'colis': [
      for (final p in store.parcels)
        {
          'suivi': p.trackingNumber,
          'de': p.originCity,
          'vers': p.destinationCity,
          'destinataire': p.recipientName,
          'montant_fcfa': p.amountXOF,
          'statut': p.status.name,
          'cree_le': p.createdAt,
        },
    ],
    'locations': [
      for (final r in store.rentals)
        {
          'reference': r.reference,
          'vehicule': r.vehicleSummary,
          'fournisseur': r.providerName,
          'prise_en_charge_prevue': r.plannedStart,
          'debut_reel': r.handoverAt,
          'fin_prevue': r.plannedEnd,
          'restitution': r.returnedAt,
          'destination': r.criteria.destination,
          'montant_fcfa': r.quote.totalXOF,
          'statut': r.status.name,
        },
    ],
    'paiements': [
      for (final p in store.payments)
        {
          'reference': p.reference,
          'moyen': p.method.name,
          'montant_fcfa': p.amountXOF,
          'statut': p.status.name,
          'le': p.createdAt,
        },
    ],
    'trajets_favoris': [
      for (final f in favorites) {'de': f.origin, 'vers': f.destination},
    ],
    'preferences': {
      'langue': prefs.languageCode,
      'theme': prefs.theme.name,
      'notifications': prefs.notifications,
    },
  };
  return const JsonEncoder.withIndent('  ').convert(data);
}
