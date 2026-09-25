import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/application/session_controller.dart';
import '../../../core/domain/models.dart';
import '../../../core/ui/pro_kit.dart';
import '../../../core/ui/role_style.dart';

List<(String, String)> _faq(ProRole role) => switch (role) {
  ProRole.controleur => const [
    (
      'Le QR ne passe pas',
      'Augmentez la luminosité du téléphone du passager, allumez la lampe, puis utilisez « Saisir la référence » : la saisie est tracée.',
    ),
    (
      '« Déjà contrôlé » s’affiche',
      'Le billet a déjà été scanné à cette étape. Vérifiez l’heure et l’agent du premier contrôle avant d’autoriser l’accès.',
    ),
    (
      'Pas de réseau en gare',
      'Continuez à scanner : la vérification se fait sur le manifeste téléchargé et les scans partent au retour du réseau, sans doublon.',
    ),
  ],
  ProRole.convoyeur => const [
    (
      'Confirmer une présence',
      'Manifeste → bouton « Présent » sur la ligne du passager, ou fiche passager pour le détail.',
    ),
    (
      'Débarquement à un arrêt',
      'Quand le chauffeur signale l’arrivée, ouvrez « Prochain arrêt » et confirmez chaque descente : le siège est libéré pour la suite du trajet.',
    ),
    (
      'Colis en litige',
      'Ne remettez pas un colis en litige : laissez-le au Service colis de la gare.',
    ),
  ],
  ProRole.chauffeur => const [
    (
      'Démarrer le voyage',
      'Glissez le bouton vert : l’heure réelle de départ est enregistrée et l’équipe prévenue.',
    ),
    (
      'Alertes vocales',
      'Activées par défaut : « Arrêt à 1 km », arrivée à l’arrêt. Coupez-les avec l’icône haut-parleur.',
    ),
    (
      'Signaler une panne',
      'Conduite → Incident → Panne. La position GPS est jointe automatiquement.',
    ),
  ],
  ProRole.agentBusiness => const [
    (
      'Photos obligatoires',
      'Six photos : avant, arrière, deux côtés, intérieur et compteur. Elles servent de preuve en cas de litige.',
    ),
    (
      'Écart à la restitution',
      'Marquez le point « KO », décrivez l’anomalie et proposez des frais indicatifs : le montant final est fixé par le serveur.',
    ),
    (
      'VTC',
      'Un véhicule VTC est toujours loué avec chauffeur : la remise se fait au client en présence du chauffeur.',
    ),
  ],
};

class HelpPage extends ConsumerWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(activeRoleProvider) ?? ProRole.controleur;
    return ProPage(
      title: 'Aide & support',
      subtitle: 'Guide du poste ${role.label}',
      children: [
        for (final (q, a) in _faq(role))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: MoncarCard(
              padding: EdgeInsets.zero,
              child: Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: Material(
                  type: MaterialType.transparency,
                  child: ExpansionTile(
                    leading: Icon(
                      Icons.help_outline_rounded,
                      color: role.accent,
                    ),
                    title: Text(
                      q,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: [
                      Text(
                        a,
                        style: TextStyle(
                          color: MoncarColors.inkMut,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        const SectionTitle('Contacts'),
        MoncarCard(
          child: Column(
            children: [
              DetailRow(
                label: 'Chef de gare',
                value: 'Via votre gare de rattachement',
                icon: Icons.person_pin_circle_rounded,
              ),
              DetailRow(
                label: 'Support MON CAR',
                value: 'Via votre responsable RH / Gares',
                icon: Icons.support_agent_rounded,
              ),
              DetailRow(
                label: 'Urgence route',
                value: '110 · 111 · 180',
                icon: Icons.emergency_rounded,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const InfoBanner(
          icon: Icons.policy_rounded,
          message:
              'Toutes vos actions sensibles sont journalisées (auteur, heure, avant/après). '
              'Le serveur MON CAR reste la source de vérité.',
        ),
      ],
    );
  }
}
