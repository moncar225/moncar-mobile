import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/application/app_providers.dart';
import '../../../core/application/trip_controller.dart';
import '../../../core/domain/models.dart';
import '../../../core/ui/format.dart';
import '../../../core/ui/pro_kit.dart';
import '../../../core/ui/status_widgets.dart';

/// Résultat de scan plein écran, codé couleur, lisible au soleil.
/// VALIDE → bouton « Confirmer l'embarquement » ; autres cas → motif clair.
class ScanResultView extends ConsumerStatefulWidget {
  const ScanResultView({
    super.key,
    required this.result,
    required this.onNext,
    this.onManifest,
  });

  final ScanResult result;
  final VoidCallback onNext;
  final VoidCallback? onManifest;

  @override
  ConsumerState<ScanResultView> createState() => _ScanResultViewState();
}

class _ScanResultViewState extends ConsumerState<ScanResultView> {
  bool _confirmed = false;

  @override
  void initState() {
    super.initState();
    haptic(
      widget.result.outcome.isSuccess
          ? HapticKind.success
          : widget.result.outcome.isBlocking
          ? HapticKind.error
          : HapticKind.tap,
    );
  }

  void _confirm() {
    final p = widget.result.passenger;
    if (p == null) return;
    ref.read(tripProvider.notifier).confirmBoarding(p.id);
    haptic(HapticKind.success);
    setState(() => _confirmed = true);
    final online = ref.read(networkProvider).online;
    showProToast(
      context,
      online
          ? 'Embarquement validé — ${p.name}.'
          : 'Embarquement enregistré hors ligne — ${p.name}.',
      tone: online ? ToastTone.success : ToastTone.warning,
    );
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) widget.onNext();
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final o = r.outcome;
    final p = r.passenger;
    final trip = ref.watch(tripProvider);
    final color = o.color;
    return Column(
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            color: color,
            child: SafeArea(
              bottom: false,
              child: Stack(
                children: [
                  Positioned(
                    top: 8,
                    left: 8,
                    child: IconButton(
                      tooltip: 'Fermer',
                      onPressed: widget.onNext,
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                  Center(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.6, end: 1),
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeOutBack,
                      builder: (context, s, child) =>
                          Transform.scale(scale: s, child: child),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 118,
                            height: 118,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.35),
                                width: 4,
                              ),
                            ),
                            child: Icon(o.icon, size: 68, color: Colors.white),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            o == ScanOutcome.valide
                                ? (_confirmed ? 'EMBARQUÉ' : 'VALIDE')
                                : o.title.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              o.hint,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (r.manual) ...[
                            const SizedBox(height: 10),
                            const GlassPill(
                              label: 'Saisie manuelle tracée',
                              icon: Icons.keyboard_rounded,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Container(
          color: MoncarColors.surface,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (p != null)
                    Row(
                      children: [
                        InitialsAvatar(
                          initials: p.initials,
                          color: color,
                          size: 48,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.name,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: MoncarColors.ink,
                                ),
                              ),
                              Text(
                                r.segment ?? '',
                                style: TextStyle(color: MoncarColors.inkMut),
                              ),
                            ],
                          ),
                        ),
                        SeatBadge(p.seat, color: color),
                      ],
                    ),
                  const SizedBox(height: 8),
                  DetailRow(label: 'Billet', value: r.code),
                  DetailRow(
                    label: 'Voyage',
                    value: r.voyageNumber ?? '—',
                    valueColor: o == ScanOutcome.mauvaisVoyage
                        ? MoncarColors.danger
                        : null,
                  ),
                  if (o == ScanOutcome.mauvaisVoyage && r.segment != null)
                    DetailRow(label: 'Trajet du billet', value: r.segment!),
                  if (o == ScanOutcome.mauvaiseGare && p != null)
                    DetailRow(
                      label: 'Gare d’embarquement',
                      value: trip.stopById(p.boardStopId).name,
                      valueColor: MoncarColors.danger,
                    ),
                  if (o == ScanOutcome.valide && p != null)
                    DetailRow(
                      label: 'Descente',
                      value: trip.stopById(p.dropStopId).name,
                    ),
                  if (r.previousAt != null)
                    DetailRow(
                      label: 'Déjà contrôlé',
                      value: '${fmtTime(r.previousAt)} · ${r.previousBy ?? ''}',
                      valueColor: MoncarColors.warn,
                    ),
                  if (p != null && p.hasBaggage)
                    const DetailRow(
                      label: 'Bagage',
                      value: 'Oui — à contrôler',
                      icon: Icons.luggage_rounded,
                    ),
                  const SizedBox(height: 14),
                  if (o == ScanOutcome.valide && !_confirmed)
                    BigActionButton(
                      label: 'Confirmer l’embarquement',
                      icon: Icons.how_to_reg_rounded,
                      color: MoncarColors.success,
                      onPressed: _confirm,
                    )
                  else
                    BigActionButton(
                      label: 'Scanner le suivant',
                      icon: Icons.qr_code_scanner_rounded,
                      color: MoncarColors.brand,
                      onPressed: widget.onNext,
                    ),
                  if (widget.onManifest != null) ...[
                    const SizedBox(height: 6),
                    TextButton.icon(
                      onPressed: widget.onManifest,
                      icon: const Icon(Icons.fact_check_rounded),
                      label: const Text('Ouvrir le manifeste'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
