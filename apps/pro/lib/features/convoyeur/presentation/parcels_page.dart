import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/application/trip_controller.dart';
import '../../../core/domain/models.dart';
import '../../../core/ui/pro_kit.dart';
import '../../../core/ui/role_style.dart';
import '../../../core/ui/status_widgets.dart';

enum _F { aDecharger, tous, decharges, litiges }

/// Convoyeur · Colis du voyage : à décharger à l'arrêt, suivi, litiges.
/// La remise au destinataire contre preuve se fait au poste Service colis.
class ParcelsPage extends ConsumerStatefulWidget {
  const ParcelsPage({super.key});

  @override
  ConsumerState<ParcelsPage> createState() => _ParcelsPageState();
}

class _ParcelsPageState extends ConsumerState<ParcelsPage> {
  _F _f = _F.aDecharger;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tripProvider);
    final op = t.operationalStop;
    final atStop = t.phase != DriverPhase.enRoute;
    final unloadIds = (op == null ? <Parcel>[] : t.parcelsToUnloadAt(op.id))
        .map((p) => p.id)
        .toSet();

    List<Parcel> of(_F f) => switch (f) {
      _F.aDecharger =>
        t.parcels.where((p) => unloadIds.contains(p.id)).toList(),
      _F.tous => t.parcels,
      _F.decharges =>
        t.parcels.where((p) => p.status == ParcelStatus.decharge).toList(),
      _F.litiges =>
        t.parcels.where((p) => p.status == ParcelStatus.litige).toList(),
    };
    final list = of(_f);
    final accent = ProRole.convoyeur.accent;

    return ProPage(
      title: 'Colis du voyage',
      subtitle: '${t.parcels.length} colis · ${t.voyage.number}',
      children: [
        FilterBar<_F>(
          accent: accent,
          selected: _f,
          onSelected: (v) => setState(() => _f = v),
          options: [
            FilterOption(
              _F.aDecharger,
              op == null ? 'À décharger' : 'À ${op.shortName}',
              count: of(_F.aDecharger).length,
            ),
            FilterOption(_F.tous, 'Tous', count: t.parcels.length),
            FilterOption(
              _F.decharges,
              'Déchargés',
              count: of(_F.decharges).length,
            ),
            FilterOption(_F.litiges, 'Litiges', count: of(_F.litiges).length),
          ],
        ),
        const SizedBox(height: 14),
        if (list.isEmpty)
          const EmptyCard(
            message: 'Aucun colis dans cette catégorie.',
            icon: Icons.inventory_2_rounded,
          )
        else
          for (final p in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: MoncarCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: MoncarColors.accentSoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.inventory_2_rounded,
                            color: MoncarColors.accent,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.ref,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: MoncarColors.ink,
                                ),
                              ),
                              Text(
                                '${p.nature} · ${p.weightKg} kg',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: MoncarColors.inkMut,
                                ),
                              ),
                            ],
                          ),
                        ),
                        MoncarBadge(
                          label: unloadIds.contains(p.id)
                              ? 'À décharger'
                              : p.status.label,
                          tone: unloadIds.contains(p.id)
                              ? MoncarBadgeTone.warn
                              : p.status.tone,
                          size: MoncarBadgeSize.sm,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    DetailRow(
                      label: 'Expéditeur',
                      value: p.sender,
                      icon: Icons.send_rounded,
                    ),
                    DetailRow(
                      label: 'Destinataire',
                      value: '${p.recipient} · ${p.recipientPhone}',
                      icon: Icons.person_rounded,
                    ),
                    DetailRow(
                      label: 'Destination',
                      value: t.stopById(p.dropStopId).name,
                      icon: Icons.place_rounded,
                    ),
                    if (unloadIds.contains(p.id)) ...[
                      const SizedBox(height: 10),
                      BigActionButton(
                        label: atStop
                            ? 'Marquer déchargé'
                            : 'Disponible à l’arrêt',
                        icon: Icons.move_down_rounded,
                        color: accent,
                        height: 46,
                        onPressed: atStop
                            ? () {
                                haptic(HapticKind.success);
                                ref
                                    .read(tripProvider.notifier)
                                    .unloadParcel(p.id);
                                showProToast(
                                  context,
                                  'Colis ${p.ref} déchargé — remis au Service colis.',
                                  tone: ToastTone.success,
                                );
                              }
                            : null,
                      ),
                    ],
                    if (p.status == ParcelStatus.litige) ...[
                      const SizedBox(height: 8),
                      InfoBanner(
                        icon: Icons.gavel_rounded,
                        color: MoncarColors.danger,
                        message:
                            'Dossier litige ouvert : ne pas remettre sans l’accord du Service colis.',
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
