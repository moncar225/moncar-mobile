import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/application/trip_controller.dart';
import '../../../core/domain/models.dart';
import '../../../core/ui/pro_kit.dart';
import '../../../core/ui/role_style.dart';
import '../../../core/ui/status_widgets.dart';

enum _Tab { aDecharger, aBord, remis, incident }

/// Convoyeur · Suivi des bagages (MAN-003) : à décharger à l'arrêt,
/// à bord, remis, incidents.
class BaggagePage extends ConsumerStatefulWidget {
  const BaggagePage({super.key});

  @override
  ConsumerState<BaggagePage> createState() => _BaggagePageState();
}

class _BaggagePageState extends ConsumerState<BaggagePage> {
  _Tab _tab = _Tab.aDecharger;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tripProvider);
    final op = t.operationalStop;
    final atStop = t.phase != DriverPhase.enRoute;
    final unload = op == null ? <Bag>[] : t.bagsToUnloadAt(op.id);
    final unloadIds = unload.map((b) => b.id).toSet();

    List<Bag> of(_Tab tab) => switch (tab) {
      _Tab.aDecharger =>
        unload.where((b) => b.status != BagStatus.incident).toList(),
      _Tab.aBord =>
        t.bags
            .where(
              (b) =>
                  (b.status == BagStatus.aBord ||
                      b.status == BagStatus.enregistre) &&
                  !unloadIds.contains(b.id),
            )
            .toList(),
      _Tab.remis => t.bags.where((b) => b.status == BagStatus.remis).toList(),
      _Tab.incident =>
        t.bags.where((b) => b.status == BagStatus.incident).toList(),
    };
    final list = of(_tab);
    final accent = ProRole.convoyeur.accent;

    return ProPage(
      title: 'Bagages',
      subtitle: op == null ? t.voyage.number : 'Déchargement à ${op.shortName}',
      children: [
        FilterBar<_Tab>(
          accent: accent,
          selected: _tab,
          onSelected: (v) => setState(() => _tab = v),
          options: [
            FilterOption(
              _Tab.aDecharger,
              'À décharger',
              count: of(_Tab.aDecharger).length,
            ),
            FilterOption(_Tab.aBord, 'À bord', count: of(_Tab.aBord).length),
            FilterOption(_Tab.remis, 'Remis', count: of(_Tab.remis).length),
            FilterOption(
              _Tab.incident,
              'Incidents',
              count: of(_Tab.incident).length,
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (list.isEmpty)
          const EmptyCard(
            message: 'Aucun bagage dans cette catégorie.',
            icon: Icons.luggage_rounded,
          )
        else
          for (final b in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: MoncarCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        SeatBadge(b.seat, color: accent),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                b.ref,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: MoncarColors.ink,
                                ),
                              ),
                              Text(
                                '${b.passengerName} · ${b.weightKg.toStringAsFixed(1)} kg → ${t.stopById(b.dropStopId).shortName}',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: MoncarColors.inkMut,
                                ),
                              ),
                            ],
                          ),
                        ),
                        MoncarBadge(
                          label: _tab == _Tab.aDecharger
                              ? 'À décharger'
                              : b.status.label,
                          tone: _tab == _Tab.aDecharger
                              ? MoncarBadgeTone.warn
                              : b.status.tone,
                          size: MoncarBadgeSize.sm,
                        ),
                      ],
                    ),
                    if (b.note != null) ...[
                      const SizedBox(height: 8),
                      InfoBanner(
                        message: b.note!,
                        icon: Icons.warning_amber_rounded,
                        color: MoncarColors.danger,
                      ),
                    ],
                    if (_tab == _Tab.aDecharger) ...[
                      const SizedBox(height: 10),
                      BigActionButton(
                        label: atStop
                            ? 'Déchargé et remis'
                            : 'Disponible à l’arrêt',
                        icon: Icons.move_down_rounded,
                        color: accent,
                        height: 46,
                        onPressed: atStop
                            ? () {
                                haptic(HapticKind.success);
                                ref.read(tripProvider.notifier).unloadBag(b.id);
                                showProToast(
                                  context,
                                  'Bagage ${b.ref} remis.',
                                  tone: ToastTone.success,
                                );
                              }
                            : null,
                      ),
                    ],
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
