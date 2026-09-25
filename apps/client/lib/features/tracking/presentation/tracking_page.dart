import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/foundation.dart';

({String label, Color color, Color bg, IconData icon}) _stateMeta(
  TrackingState s,
) => switch (s) {
  TrackingState.enAttente => (
    label: 'En attente',
    color: MoncarColors.warn,
    bg: MoncarColors.warnSoft,
    icon: Icons.schedule,
  ),
  TrackingState.disponible => (
    label: 'En direct',
    color: MoncarColors.success,
    bg: MoncarColors.successSoft,
    icon: Icons.bolt,
  ),
  TrackingState.faible => (
    label: 'Signal faible',
    color: MoncarColors.warn,
    bg: MoncarColors.warnSoft,
    icon: Icons.warning_amber_rounded,
  ),
  TrackingState.horsLigne => (
    label: 'Hors ligne',
    color: MoncarColors.inkMut,
    bg: MoncarColors.muted,
    icon: Icons.wifi_off,
  ),
  TrackingState.termine => (
    label: 'Terminé',
    color: MoncarColors.brand,
    bg: MoncarColors.brandSoft,
    icon: Icons.check,
  ),
};

String _hms(String iso, {bool seconds = true}) {
  final d = DateTime.tryParse(iso);
  if (d == null) return '';
  String p(int n) => n.toString().padLeft(2, '0');
  return seconds
      ? '${p(d.hour)}:${p(d.minute)}:${p(d.second)}'
      : '${p(d.hour)}:${p(d.minute)}';
}

/// Suivi GPS en direct : carte interactive, progression, ETA et
/// chronologie des arrêts. Rafraîchi toutes les 3 s (mode dégradé
/// en attendant Mercure).
class TrackingPage extends ConsumerStatefulWidget {
  const TrackingPage({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<TrackingPage> createState() => _TrackingPageState();
}

class _TrackingPageState extends ConsumerState<TrackingPage> {
  BusPosition? _tracking;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    setState(
      () => _tracking = ref.read(mockStoreProvider).getTracking(widget.tripId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trip = ref.read(mockStoreProvider).findTrip(widget.tripId);
    final t = _tracking;
    if (t == null) {
      return Scaffold(
        appBar: const TopBar(
          title: 'Suivi GPS',
          showBack: true,
          showBell: false,
        ),
        body: MoncarErrorState(
          message: 'Suivi indisponible',
          onRetry: _refresh,
        ),
      );
    }
    final meta = _stateMeta(t.state);

    return Scaffold(
      backgroundColor: MoncarColors.background,
      appBar: TopBar(
        title: 'Suivi GPS',
        subtitle: trip != null
            ? '${trip.originCityName} → ${trip.destinationCityName}'
            : null,
        showBack: true,
        showBell: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          MoncarCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  child: SizedBox(
                    height: 280,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: LiveMap(
                            stops: trip?.stops ?? const [],
                            busPosition: t,
                            progressPct: t.progressPct,
                            state: t.state,
                            currentStopIndex: t.currentStopIndex,
                            height: 280,
                            onRetry: _refresh,
                          ),
                        ),
                        Positioned(
                          top: 12,
                          left: 12,
                          child: _Pill(
                            color: meta.bg,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(meta.icon, size: 14, color: meta.color),
                                const SizedBox(width: 6),
                                Text(
                                  meta.label,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: meta.color,
                                  ),
                                ),
                                if (t.state == TrackingState.disponible) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: MoncarColors.success,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        if (t.state == TrackingState.disponible)
                          Positioned(
                            top: 12,
                            right: 12,
                            child: _Pill(
                              child: Text(
                                '${t.speedKmh.round()} km/h',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: MoncarColors.ink,
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          bottom: 12,
                          right: 12,
                          child: _Pill(
                            child: Text(
                              'MàJ ${_hms(t.lastUpdate)}',
                              style: TextStyle(
                                fontSize: 9,
                                color: MoncarColors.inkMut,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const OverlineText('Prochain arrêt'),
                                Text(
                                  t.nextStopName ?? '—',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: MoncarColors.ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const OverlineText('ETA'),
                              Text(
                                formatDuration(t.etaToNextStopMin),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: MoncarColors.accent,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          height: 8,
                          color: MoncarColors.muted,
                          alignment: Alignment.centerLeft,
                          child: AnimatedFractionallySizedBox(
                            duration: const Duration(seconds: 1),
                            widthFactor: (t.progressPct / 100)
                                .clamp(0, 1)
                                .toDouble(),
                            child: Container(
                              decoration: accentGradientDecoration(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${t.progressPct}% du trajet parcouru',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: MoncarColors.inkMut,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: Text(
              'Arrêts',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: MoncarColors.ink,
              ),
            ),
          ),
          MoncarCard(
            child: Column(
              children: [
                for (var i = 0; i < t.stops.length; i++)
                  _StopRow(stop: t.stops[i], isLast: i == t.stops.length - 1),
              ],
            ),
          ),
          if (t.state != TrackingState.termine) ...[
            const SizedBox(height: 16),
            MoncarCard(
              padding: const EdgeInsets.all(14),
              color: MoncarColors.accentSoft.withValues(alpha: 0.4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.navigation_outlined,
                    size: 16,
                    color: MoncarColors.accent,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Alerte de descente',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: MoncarColors.ink,
                          ),
                        ),
                        Text(
                          'Vous serez notifié 15 min avant votre arrêt de descente.',
                          style: TextStyle(
                            fontSize: 11,
                            color: MoncarColors.inkMut,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (t.state == TrackingState.horsLigne) ...[
            const SizedBox(height: 16),
            MoncarCard(
              color: MoncarColors.warnSoft.withValues(alpha: 0.4),
              child: Column(
                children: [
                  Icon(Icons.wifi_off, size: 32, color: MoncarColors.warn),
                  const SizedBox(height: 8),
                  Text(
                    'Signal GPS indisponible',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: MoncarColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Le bus n'envoie pas de position. Rafraîchissement automatique en cours.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: MoncarColors.inkMut),
                  ),
                  const SizedBox(height: 12),
                  MoncarButton(
                    label: 'Rafraîchir',
                    variant: MoncarButtonVariant.outline,
                    size: MoncarButtonSize.sm,
                    onPressed: _refresh,
                  ),
                ],
              ),
            ),
          ],
          if (t.state == TrackingState.termine) ...[
            const SizedBox(height: 16),
            MoncarCard(
              color: MoncarColors.successSoft.withValues(alpha: 0.4),
              child: Column(
                children: [
                  Icon(Icons.check, size: 32, color: MoncarColors.success),
                  SizedBox(height: 8),
                  Text(
                    'Voyage terminé',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: MoncarColors.ink,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Merci d'avoir voyagé avec MON CAR. À bientôt !",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: MoncarColors.inkMut),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.child, this.color});

  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color ?? Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6),
        ],
      ),
      child: child,
    );
  }
}

class _StopRow extends StatelessWidget {
  const _StopRow({required this.stop, required this.isLast});

  final TrackingStopState stop;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final passed = stop.status == 'passe';
    final current = stop.status == 'actuel';
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: passed
                      ? MoncarColors.success
                      : current
                      ? MoncarColors.accent
                      : Colors.white,
                  border: Border.all(
                    color: passed
                        ? MoncarColors.success
                        : current
                        ? MoncarColors.accent
                        : MoncarColors.hairline,
                    width: 2,
                  ),
                  boxShadow: current
                      ? [
                          BoxShadow(
                            color: MoncarColors.accent.withValues(alpha: 0.35),
                            spreadRadius: 3,
                          ),
                        ]
                      : null,
                ),
                child: passed
                    ? const Icon(Icons.check, size: 10, color: Colors.white)
                    : current
                    ? Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: MoncarColors.surface,
                          shape: BoxShape.circle,
                        ),
                      )
                    : null,
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    constraints: const BoxConstraints(minHeight: 32),
                    color: passed
                        ? MoncarColors.success
                        : MoncarColors.hairline,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stop.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: passed
                          ? MoncarColors.inkMut
                          : current
                          ? MoncarColors.accent
                          : MoncarColors.ink,
                      decoration: passed ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (passed && stop.reachedAt != null)
                    Text(
                      'Atteint à ${_hms(stop.reachedAt!, seconds: false)}',
                      style: TextStyle(
                        fontSize: 10,
                        color: MoncarColors.success,
                      ),
                    ),
                  if (current)
                    Text(
                      'Position actuelle',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: MoncarColors.accent,
                      ),
                    ),
                  if (stop.status == 'a_venir' && stop.arrivalTime != null)
                    Text(
                      'Prévu à ${stop.arrivalTime}',
                      style: TextStyle(
                        fontSize: 10,
                        color: MoncarColors.inkMut,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
