// ============================================================
// MON CAR — Assistant voyage (IA-001).
//
// En production : POST /ia/dialogue — adaptateur serveur (API Anthropic),
// contexte limité aux données autorisées du client, journalisé, coûts
// maîtrisés, MODE DÉGRADÉ (assistant désactivé → support humain).
// L'assistant n'est jamais sur le chemin critique d'une vente ou d'un
// embarquement : il informe et oriente, il n'exécute rien.
//
// ⚠️ MOCK : `AssistantDemo` répond à partir des données de l'app (billets,
// colis) et d'une FAQ, pour démontrer le parcours sans API.
// ============================================================

library;

import '../../shared/data/mock_store.dart';
import '../../shared/domain/models.dart';

enum Auteur { client, assistant }

class MessageAssistant {
  const MessageAssistant({
    required this.auteur,
    required this.texte,
    this.suggestions = const [],
    this.action,
    this.versConseiller = false,
  });

  final Auteur auteur;
  final String texte;

  /// Relances proposées au client (boutons).
  final List<String> suggestions;

  /// Écran à ouvrir directement (lien profond), ex. `/history?tab=tickets`.
  final ({String libelle, String route})? action;

  /// L'assistant propose le passage à un conseiller humain.
  final bool versConseiller;
}

/// Contrat de l'assistant : l'implémentation réelle appellera l'API.
abstract interface class Assistant {
  /// `false` = mode dégradé : l'app propose directement le support humain.
  bool get disponible;

  Future<MessageAssistant> repondre(String question);
}

const suggestionsAccueil = [
  'Où est mon billet ?',
  'Suivre mon colis',
  'Annuler un voyage',
  'Louer un véhicule avec chauffeur',
];

String _normaliser(String s) => s
    .toLowerCase()
    .replaceAll(RegExp('[éèêë]'), 'e')
    .replaceAll(RegExp('[àâä]'), 'a')
    .replaceAll(RegExp('[îï]'), 'i')
    .replaceAll(RegExp('[ôö]'), 'o')
    .replaceAll(RegExp('[ùûü]'), 'u')
    .replaceAll('ç', 'c');

class AssistantDemo implements Assistant {
  AssistantDemo(this._store, {this.disponible = true});

  final MockStore _store;

  @override
  final bool disponible;

  bool _contient(String q, List<String> mots) => mots.any(q.contains);

  @override
  Future<MessageAssistant> repondre(String question) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final q = _normaliser(question);

    if (_contient(q, [
      'conseiller',
      'humain',
      'agent',
      'personne',
      'reclamation',
      'plainte',
    ])) {
      return const MessageAssistant(
        auteur: Auteur.assistant,
        texte:
            'Je vous mets en relation avec un conseiller MON CAR. Il aura accès à '
            'votre demande pour ne pas vous faire répéter.',
        versConseiller: true,
      );
    }

    if (_contient(q, ['colis', 'envoi', 'col-'])) {
      final encours = _store.parcels
          .where(
            (p) =>
                p.status != ParcelStatus.livre &&
                p.status != ParcelStatus.annule,
          )
          .toList();
      if (encours.isEmpty) {
        return const MessageAssistant(
          auteur: Auteur.assistant,
          texte:
              'Vous n’avez aucun colis en cours. Voulez-vous en envoyer un ?',
          action: (libelle: 'Envoyer un colis', route: '/colis/new'),
        );
      }
      final p = encours.first;
      return MessageAssistant(
        auteur: Auteur.assistant,
        texte:
            'Votre colis ${p.trackingNumber} pour ${p.recipientName} '
            '(${p.destinationCity}) est actuellement : ${p.status.label.toLowerCase()}.'
            '${encours.length > 1 ? ' Vous avez ${encours.length} colis en cours.' : ''}',
        action: (libelle: 'Voir le suivi', route: '/colis/${p.id}'),
        suggestions: const [
          'Mon colis est en retard',
          'Parler à un conseiller',
        ],
      );
    }

    if (_contient(q, ['annul', 'rembours'])) {
      return const MessageAssistant(
        auteur: Auteur.assistant,
        texte:
            'Un billet non utilisé peut être annulé depuis « Mes billets » avant le '
            'départ. Le remboursement suit les conditions de la compagnie ; en cas de '
            'paiement débité sans billet, le remboursement est automatique sous 24 à 72 h.',
        action: (libelle: 'Mes billets', route: '/history?tab=tickets'),
        suggestions: ['Parler à un conseiller'],
      );
    }

    if (_contient(q, ['billet', 'qr', 'ticket', 'embarqu'])) {
      final billets = _store.tickets
          .where((t) => t.status == TicketStatus.emis)
          .toList();
      if (billets.isEmpty) {
        return const MessageAssistant(
          auteur: Auteur.assistant,
          texte:
              'Vous n’avez pas de billet à venir. Je peux vous aider à trouver un voyage.',
          action: (libelle: 'Rechercher un trajet', route: '/voyager'),
        );
      }
      final b = billets.first;
      return MessageAssistant(
        auteur: Auteur.assistant,
        texte:
            'Votre prochain billet : ${b.originCity} → ${b.destinationCity}, le ${b.date} '
            'à ${b.departureTime}, siège ${b.seatNumber}. Son QR code reste lisible même '
            'sans réseau : présentez-le au contrôleur à l’embarquement.',
        action: (
          libelle: 'Afficher mon billet',
          route: '/voyager/ticket/${b.id}',
        ),
        suggestions: const ['Suivre mon car', 'Annuler un voyage'],
      );
    }

    if (_contient(q, [
      'suivre',
      'ou est le car',
      'retard',
      'gps',
      'position',
    ])) {
      final b = _store.tickets
          .where(
            (t) =>
                t.status == TicketStatus.emis ||
                t.status == TicketStatus.embarque,
          )
          .firstOrNull;
      return MessageAssistant(
        auteur: Auteur.assistant,
        texte: b == null
            ? 'Le suivi en direct est disponible pour vos voyages en cours.'
            : 'Vous pouvez suivre le car en direct, recevoir une alerte avant votre arrêt '
                  'et partager le trajet avec un proche.',
        action: b == null
            ? null
            : (libelle: 'Suivre le car', route: '/tracking/${b.tripId}'),
      );
    }

    if (_contient(q, ['louer', 'location', 'vtc', 'chauffeur', 'vehicule'])) {
      return const MessageAssistant(
        auteur: Auteur.assistant,
        texte:
            'Vous pouvez louer une berline, un 4x4, un minibus ou un car, avec ou sans '
            'chauffeur. Un véhicule VTC est toujours fourni avec chauffeur. Le loueur '
            'confirme d’abord votre demande, puis vous payez.',
        action: (libelle: 'Louer un véhicule', route: '/location'),
      );
    }

    if (_contient(q, ['bagage', 'valise'])) {
      return const MessageAssistant(
        auteur: Auteur.assistant,
        texte:
            'Chaque bagage enregistré en gare reçoit une étiquette (BAG-MC-…) rattachée à '
            'votre billet. Vous le récupérez à votre arrêt de descente.',
        suggestions: ['Parler à un conseiller'],
      );
    }

    if (_contient(q, [
      'paiement',
      'payer',
      'orange',
      'wave',
      'mtn',
      'moov',
      'debite',
    ])) {
      return const MessageAssistant(
        auteur: Auteur.assistant,
        texte:
            'Vous pouvez payer par Orange Money, MTN MoMo, Moov Money, Wave ou carte. Le '
            'billet n’est émis qu’une fois le paiement confirmé par le serveur.',
        suggestions: ['J’ai été débité sans billet', 'Parler à un conseiller'],
      );
    }

    return const MessageAssistant(
      auteur: Auteur.assistant,
      texte:
          'Je peux vous aider pour vos billets, le suivi du car, vos colis, la location '
          'ou le paiement. Que souhaitez-vous faire ?',
      suggestions: suggestionsAccueil,
    );
  }
}
