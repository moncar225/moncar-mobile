import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/application/business_controller.dart';
import '../../../core/domain/models.dart';
import '../../../core/ui/format.dart';
import '../../../core/ui/pro_kit.dart';
import '../../../core/ui/role_style.dart';

/// Agent BUSINESS · Missions du jour (remises et restitutions).
class MissionsPage extends ConsumerStatefulWidget {
  const MissionsPage({super.key});

  @override
  ConsumerState<MissionsPage> createState() => _MissionsPageState();
}

class _MissionsPageState extends ConsumerState<MissionsPage> {
  RentalTaskStatus _f = RentalTaskStatus.aFaire;

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(businessProvider);
    final accent = ProRole.agentBusiness.accent;
    final list = tasks.where((t) => t.status == _f).toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return ProPage(
      title: 'Missions',
      subtitle: fmtLongDate(DateTime.now()),
      children: [
        FilterBar<RentalTaskStatus>(
          accent: accent,
          selected: _f,
          onSelected: (v) => setState(() => _f = v),
          options: [
            for (final s in RentalTaskStatus.values)
              FilterOption(
                s,
                s.label,
                count: tasks.where((t) => t.status == s).length,
              ),
          ],
        ),
        const SizedBox(height: 14),
        if (list.isEmpty)
          EmptyCard(
            message: _f == RentalTaskStatus.aFaire
                ? 'Toutes les missions du jour sont terminées.'
                : 'Aucune mission terminée pour le moment.',
            icon: Icons.event_available_rounded,
          )
        else
          for (final t in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: MoncarCard(
                onTap: () => context.push('/biz/mission/${t.id}'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color:
                                (t.type == RentalTaskType.remise
                                        ? accent
                                        : MoncarColors.info)
                                    .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            t.type == RentalTaskType.remise
                                ? Icons.key_rounded
                                : Icons.assignment_return_rounded,
                            color: t.type == RentalTaskType.remise
                                ? accent
                                : MoncarColors.info,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${t.type.label} · ${fmtTime(t.scheduledAt)}',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: t.type == RentalTaskType.remise
                                      ? accent
                                      : MoncarColors.info,
                                ),
                              ),
                              Text(
                                t.vehicleModel,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: MoncarColors.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: MoncarColors.inkFaint,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    DetailRow(
                      label: 'Client',
                      value: t.clientName,
                      icon: Icons.person_rounded,
                    ),
                    DetailRow(
                      label: 'Véhicule',
                      value: t.vehiclePlate,
                      icon: Icons.directions_car_rounded,
                    ),
                    DetailRow(
                      label: 'Dossier',
                      value: t.ref,
                      icon: Icons.tag_rounded,
                    ),
                    if (t.withDriver)
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: MoncarBadge(
                          label: 'VTC — avec chauffeur obligatoire',
                          tone: MoncarBadgeTone.accent,
                          size: MoncarBadgeSize.sm,
                          icon: Icons.badge_rounded,
                        ),
                      ),
                    if (t.proofRef != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: MoncarBadge(
                          label: 'Preuve ${t.proofRef}',
                          tone: MoncarBadgeTone.success,
                          size: MoncarBadgeSize.sm,
                          icon: Icons.verified_rounded,
                        ),
                      ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
