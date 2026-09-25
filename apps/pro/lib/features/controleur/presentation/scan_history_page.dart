import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/application/trip_controller.dart';
import '../../../core/domain/models.dart';
import '../../../core/ui/format.dart';
import '../../../core/ui/pro_kit.dart';
import '../../../core/ui/role_style.dart';
import '../../../core/ui/status_widgets.dart';

/// Contrôleur · Historique des scans du voyage (rapport du poste 8).
class ScanHistoryPage extends ConsumerStatefulWidget {
  const ScanHistoryPage({super.key});

  @override
  ConsumerState<ScanHistoryPage> createState() => _ScanHistoryPageState();
}

class _ScanHistoryPageState extends ConsumerState<ScanHistoryPage> {
  ScanOutcome? _filter;
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final scans = ref.watch(tripProvider).scans;
    int count(ScanOutcome o) => scans.where((s) => s.outcome == o).length;
    final anomalies = scans.where((s) => !s.outcome.isSuccess).length;
    final q = _q.toLowerCase();
    final rows = scans
        .where((s) => _filter == null || s.outcome == _filter)
        .where(
          (s) =>
              q.isEmpty ||
              s.code.toLowerCase().contains(q) ||
              (s.passengerName ?? '').toLowerCase().contains(q) ||
              (s.seat ?? '').toLowerCase().contains(q),
        )
        .toList();

    return ProPage(
      title: 'Historique des scans',
      subtitle: 'Voyage ${ref.watch(tripProvider).voyage.number}',
      children: [
        Row(
          children: [
            Expanded(
              child: MiniStat(
                value: '${scans.length}',
                label: 'Total',
                color: MoncarColors.ink,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: MiniStat(
                value: '${count(ScanOutcome.valide)}',
                label: 'Valides',
                color: MoncarColors.success,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: MiniStat(
                value: '$anomalies',
                label: 'Anomalies',
                color: MoncarColors.danger,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SearchField(
          hint: 'Billet, passager ou siège…',
          onChanged: (v) => setState(() => _q = v),
        ),
        const SizedBox(height: 12),
        FilterBar<ScanOutcome?>(
          accent: ProRole.controleur.accent,
          selected: _filter,
          onSelected: (v) => setState(() => _filter = v),
          options: [
            FilterOption(null, 'Tous', count: scans.length),
            for (final o in ScanOutcome.values)
              if (count(o) > 0) FilterOption(o, o.title, count: count(o)),
          ],
        ),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          const EmptyCard(
            message: 'Aucun scan pour ce filtre.',
            icon: Icons.history_rounded,
          )
        else
          for (final s in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: MoncarCard(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: s.outcome.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(s.outcome.icon, color: s.outcome.color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.passengerName ?? 'Billet non reconnu',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: MoncarColors.ink,
                            ),
                          ),
                          Text(
                            '${s.code}${s.seat != null ? ' · siège ${s.seat}' : ''}',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: MoncarColors.inkMut,
                            ),
                          ),
                          Text(
                            '${s.agent}${s.manual ? ' · saisie manuelle' : ''}',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: MoncarColors.inkFaint,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          fmtTime(s.at),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: MoncarColors.ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          s.outcome.title,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: s.outcome.color,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
