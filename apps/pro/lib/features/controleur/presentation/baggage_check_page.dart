import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/application/trip_controller.dart';
import '../../../core/domain/models.dart';
import '../../../core/ui/pro_kit.dart';
import '../../../core/ui/role_style.dart';
import '../../../core/ui/status_widgets.dart';

/// Contrôleur · Contrôle des bagages (CTRL-04 « Scanner bagage/colis »).
class BaggageCheckPage extends ConsumerStatefulWidget {
  const BaggageCheckPage({super.key});

  @override
  ConsumerState<BaggageCheckPage> createState() => _BaggageCheckPageState();
}

class _BaggageCheckPageState extends ConsumerState<BaggageCheckPage> {
  final _c = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _check(String ref0) {
    final bag = ref.read(tripProvider.notifier).checkBag(ref0);
    if (bag == null) {
      haptic(HapticKind.error);
      showProToast(
        context,
        'Étiquette inconnue sur ce voyage.',
        tone: ToastTone.error,
      );
      return;
    }
    haptic(HapticKind.success);
    _c.clear();
    showProToast(
      context,
      'Bagage ${bag.ref} contrôlé — ${bag.passengerName} (${bag.seat}).',
      tone: ToastTone.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final trip = ref.watch(tripProvider);
    final accent = ProRole.controleur.accent;
    final checked = trip.bags.where((b) => b.checked).length;
    final q = _q.toLowerCase();
    final bags =
        trip.bags
            .where(
              (b) =>
                  q.isEmpty ||
                  b.ref.toLowerCase().contains(q) ||
                  b.passengerName.toLowerCase().contains(q) ||
                  b.seat.toLowerCase().contains(q),
            )
            .toList()
          ..sort((a, b) => (a.checked ? 1 : 0).compareTo(b.checked ? 1 : 0));

    return ProPage(
      title: 'Contrôle des bagages',
      subtitle: '$checked / ${trip.bags.length} contrôlés',
      children: [
        MoncarCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Étiquette bagage',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: MoncarColors.ink,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _c,
                textCapitalization: TextCapitalization.characters,
                onSubmitted: _check,
                decoration: const InputDecoration(
                  hintText: 'BAG-1003',
                  prefixIcon: Icon(Icons.luggage_rounded),
                ),
              ),
              const SizedBox(height: 12),
              BigActionButton(
                label: 'Contrôler',
                icon: Icons.verified_rounded,
                color: accent,
                height: 54,
                onPressed: () => _check(_c.text),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        LinearProgressIndicator(
          value: trip.bags.isEmpty ? 0 : checked / trip.bags.length,
          minHeight: 8,
          borderRadius: BorderRadius.circular(99),
          color: MoncarColors.success,
          backgroundColor: MoncarColors.muted,
        ),
        const SizedBox(height: 14),
        SearchField(
          hint: 'Réf., passager, siège…',
          onChanged: (v) => setState(() => _q = v),
        ),
        const SectionTitle('Bagages du voyage', top: 16),
        for (final b in bags)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: MoncarCard(
              padding: const EdgeInsets.all(12),
              child: Row(
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
                          '${b.passengerName} · ${b.weightKg.toStringAsFixed(1)} kg · '
                          '${trip.stopById(b.dropStopId).shortName}',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: MoncarColors.inkMut,
                          ),
                        ),
                        if (b.note != null)
                          Text(
                            b.note!,
                            style: TextStyle(
                              fontSize: 12,
                              color: MoncarColors.danger,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (b.checked)
                    MoncarBadge(
                      label: 'Contrôlé',
                      tone: MoncarBadgeTone.success,
                      size: MoncarBadgeSize.sm,
                      icon: Icons.check_rounded,
                    )
                  else if (b.status == BagStatus.incident)
                    MoncarBadge(
                      label: b.status.label,
                      tone: b.status.tone,
                      size: MoncarBadgeSize.sm,
                    )
                  else
                    TextButton(
                      onPressed: () => _check(b.ref),
                      child: const Text('Contrôler'),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
