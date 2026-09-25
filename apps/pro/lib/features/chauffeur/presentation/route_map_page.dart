import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/application/gps_controller.dart';
import '../../../core/application/gps_policy.dart';
import '../../../core/application/trip_controller.dart';
import '../../../core/domain/models.dart';
import '../../../core/ui/pro_kit.dart';
import '../../../core/ui/role_style.dart';
import '../../../core/ui/trip_widgets.dart';
import '../widgets/trip_map.dart';

/// Chauffeur · Itinéraire & GPS (CHAUF-05) : carte de la ligne, arrêts,
/// état de la collecte GPS (stockage local + envoi par lots).
class RouteMapPage extends ConsumerWidget {
  const RouteMapPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tripProvider);
    final gps = ref.watch(gpsProvider);
    final role = ProRole.chauffeur;
    return Scaffold(
      backgroundColor: MoncarColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ProHeader(
              title: 'Itinéraire',
              subtitle: '${t.voyage.line} · ${t.voyage.totalKm.round()} km',
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: SizedBox(
                      height: 300,
                      child: TripMap(trip: t, gps: gps, accent: role.accent),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: MiniStat(
                          value: '${gps.speedKmh.round()}',
                          label: 'km/h',
                          color: role.accent,
                          icon: Icons.speed_rounded,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: MiniStat(
                          value: '±${gps.accuracyM.round()} m',
                          label: 'Précision',
                          color: MoncarColors.info,
                          icon: Icons.gps_fixed_rounded,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: MiniStat(
                          value: '${gps.sentBatches}',
                          label: 'Lots envoyés',
                          color: MoncarColors.success,
                          icon: Icons.cloud_upload_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  MoncarCard(
                    padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
                    child: Column(
                      children: [
                        Material(
                          type: MaterialType.transparency,
                          child: SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: gps.tracking,
                            onChanged: (v) =>
                                ref.read(gpsProvider.notifier).setTracking(v),
                            title: const Text(
                              'Suivi GPS du voyage',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(
                              gps.tracking
                                  ? 'Actif pendant le voyage uniquement'
                                  : 'En pause — la compagnie ne voit plus le car',
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                        Material(
                          type: MaterialType.transparency,
                          child: SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: gps.deviceGps,
                            onChanged: (v) async {
                              final err = await ref
                                  .read(gpsProvider.notifier)
                                  .useDeviceGps(v);
                              if (err != null && context.mounted) {
                                showProToast(
                                  context,
                                  err,
                                  tone: ToastTone.error,
                                );
                              }
                            },
                            title: const Text(
                              'Utiliser le GPS du téléphone',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: const Text(
                              'Suivi écran éteint pendant le voyage actif. '
                              'Désactivé : trajet simulé (démonstration)',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  InfoBanner(
                    icon: Icons.speed_rounded,
                    message:
                        'Fréquence ${gps.mode.libelle.toLowerCase()} : '
                        '${gps.mode == ModeGps.rapproche ? 'toutes les 10 s (ville, approche d’arrêt)' : 'toutes les 30 s (route)'}. '
                        '${gps.pointsCollectes} position(s) collectée(s) depuis le lancement'
                        '${gps.fluxActif ? ' — suivi actif même écran éteint.' : '.'}',
                  ),
                  const SizedBox(height: 8),
                  InfoBanner(
                    icon: Icons.sd_storage_rounded,
                    message:
                        '${gps.bufferedPoints} position(s) stockée(s) sur le téléphone. '
                        'Envoi par lots de 10 ; en l’absence de réseau, les lots '
                        'attendent la reprise. L’ETA et l’approche des arrêts sont calculées par le serveur.',
                  ),
                  const SectionTitle('Arrêts'),
                  MoncarCard(
                    child: StopsTimeline(trip: t, accent: role.accent),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
