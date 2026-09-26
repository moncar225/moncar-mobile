import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../shared/foundation.dart';
import '../application/alerte_descente.dart';

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

  /// Arrêt de descente suivi (celui du billet, modifiable).
  int? _arretIndex;
  EtapeDescente _etape = EtapeDescente.enRoute;
  bool _voix = true;
  final _annonce = AnnonceVocale();

  /// Lien de partage temporaire (⚠ durée de validité à arbitrer).
  ({String lien, DateTime expire})? _partage;

  @override
  void initState() {
    super.initState();
    _arretIndex = _arretDuBillet();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  List<Stop> get _arrets =>
      ref.read(mockStoreProvider).findTrip(widget.tripId)?.stops ?? const [];

  /// Arrêt de descente du billet du passager pour ce voyage, sinon terminus.
  int? _arretDuBillet() {
    final arrets = _arrets;
    if (arrets.isEmpty) return null;
    final billets = ref
        .read(mockStoreProvider)
        .tickets
        .where((t) => t.tripId == widget.tripId);
    if (billets.isNotEmpty) {
      final i = arrets.indexWhere(
        (a) => a.label == billets.first.alightingStop,
      );
      if (i > 0) return i;
    }
    return arrets.length - 1;
  }

  void _refresh() {
    if (!mounted) return;
    final t = ref.read(mockStoreProvider).getTracking(widget.tripId);
    final index = _arretIndex;
    final etape = t == null || index == null
        ? _etape
        : etapeDescente(bus: t, arrets: _arrets, indexArret: index);
    final nouvelle = etape.index > _etape.index;
    setState(() {
      _tracking = t;
      _etape = etape;
    });
    if (nouvelle) _declencher(etape);
  }

  /// Alerte prioritaire : vibration, bandeau, voix (option CDC).
  void _declencher(EtapeDescente etape) {
    if (etape == EtapeDescente.enRoute) return;
    final message = etape == EtapeDescente.proche
        ? messageProche
        : messageArrivee;
    HapticFeedback.heavyImpact();
    if (_voix) _annonce.dire(message);
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 8),
          backgroundColor: MoncarColors.accent,
        ),
      );
  }

  void _changerArret(int index) {
    setState(() {
      _arretIndex = index;
      _etape = EtapeDescente.enRoute;
    });
    _refresh();
  }

  Future<void> _partager(String trajet) async {
    // En production : POST /voyages/{id}/partage renvoie un lien signé et
    // temporaire, limité à la position, la progression et l'ETA (CDC §18).
    final expire = DateTime.now().add(const Duration(hours: 6));
    final jeton = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final lien = 'https://moncar.ci/suivi/${widget.tripId}-$jeton';
    setState(() => _partage = (lien: lien, expire: expire));
    String p(int n) => n.toString().padLeft(2, '0');
    await SharePlus.instance.share(
      ShareParams(
        text:
            'Suivez mon trajet $trajet en direct sur MON CAR : $lien '
            '(position, progression et heure d’arrivée — lien valable '
            'jusqu’à ${p(expire.hour)}h${p(expire.minute)}).',
      ),
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
          if (t.state != TrackingState.termine && _arretIndex != null) ...[
            const SizedBox(height: 16),
            _AlerteDescenteCard(
              arrets: trip?.stops ?? const [],
              indexArret: _arretIndex!,
              premierChoix: t.currentStopIndex + 1,
              etape: _etape,
              bus: t,
              voix: _voix,
              onVoix: (v) => setState(() => _voix = v),
              onArret: _changerArret,
            ),
          ],
          if (t.state != TrackingState.termine) ...[
            const SizedBox(height: 16),
            _PartageCard(
              partage: _partage,
              onPartager: () => _partager(
                trip != null
                    ? '${trip.originCityName} → ${trip.destinationCityName}'
                    : '',
              ),
              onArreter: () => setState(() => _partage = null),
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

/// Carte « Alerte de descente » : arrêt suivi, distance, état, voix.
class _AlerteDescenteCard extends StatelessWidget {
  const _AlerteDescenteCard({
    required this.arrets,
    required this.indexArret,
    required this.premierChoix,
    required this.etape,
    required this.bus,
    required this.voix,
    required this.onVoix,
    required this.onArret,
  });

  final List<Stop> arrets;
  final int indexArret;
  final int premierChoix;
  final EtapeDescente etape;
  final BusPosition bus;
  final bool voix;
  final ValueChanged<bool> onVoix;
  final ValueChanged<int> onArret;

  @override
  Widget build(BuildContext context) {
    final cible = indexArret < arrets.length ? arrets[indexArret] : null;
    final restant = cible == null
        ? null
        : distanceKm(
            bus.latitude,
            bus.longitude,
            cible.latitude,
            cible.longitude,
          );
    final (couleur, fond, texte) = switch (etape) {
      EtapeDescente.arrive => (
        MoncarColors.success,
        MoncarColors.successSoft,
        messageArrivee,
      ),
      EtapeDescente.proche => (
        MoncarColors.accent,
        MoncarColors.accentSoft,
        messageProche,
      ),
      EtapeDescente.enRoute => (
        MoncarColors.brand,
        MoncarColors.brandSoft,
        restant == null
            ? 'Vous serez alerté à l’approche de votre arrêt.'
            : 'Encore ${restant.toStringAsFixed(restant < 10 ? 1 : 0)} km '
                  '— alerte à environ 1 km.',
      ),
    };
    final choix = <int>[
      for (var i = premierChoix.clamp(1, arrets.length); i < arrets.length; i++)
        i,
      if (indexArret < premierChoix) indexArret,
    ];
    return MoncarCard(
      padding: const EdgeInsets.all(14),
      color: fond.withValues(alpha: 0.6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                etape == EtapeDescente.enRoute
                    ? Icons.navigation_outlined
                    : Icons.notifications_active,
                size: 18,
                color: couleur,
              ),
              const SizedBox(width: 8),
              Text(
                'Alerte de descente',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: MoncarColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            texte,
            style: TextStyle(
              fontSize: etape == EtapeDescente.enRoute ? 12 : 14,
              fontWeight: etape == EtapeDescente.enRoute
                  ? FontWeight.w400
                  : FontWeight.w700,
              color: etape == EtapeDescente.enRoute
                  ? MoncarColors.inkMut
                  : couleur,
            ),
          ),
          const SizedBox(height: 8),
          if (choix.isNotEmpty)
            DropdownButtonFormField<int>(
              initialValue: indexArret,
              decoration: const InputDecoration(
                labelText: 'Mon arrêt de descente',
                isDense: true,
              ),
              items: [
                for (final i in choix)
                  DropdownMenuItem(value: i, child: Text(arrets[i].label)),
              ],
              onChanged: etape == EtapeDescente.arrive
                  ? null
                  : (v) {
                      if (v != null) onArret(v);
                    },
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: voix,
            onChanged: onVoix,
            title: const Text('Annonce vocale'),
            subtitle: const Text('En plus de la vibration et du message'),
          ),
        ],
      ),
    );
  }
}

/// Partage temporaire du trajet avec un proche (CDC §18).
class _PartageCard extends StatelessWidget {
  const _PartageCard({
    required this.partage,
    required this.onPartager,
    required this.onArreter,
  });

  final ({String lien, DateTime expire})? partage;
  final VoidCallback onPartager;
  final VoidCallback onArreter;

  @override
  Widget build(BuildContext context) {
    String p(int n) => n.toString().padLeft(2, '0');
    final actif = partage;
    return MoncarCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Partager mon trajet',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: MoncarColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            actif == null
                ? 'Un proche suit la position du car, la progression et '
                      'l’heure d’arrivée — rien d’autre. Accès temporaire.'
                : 'Partage actif jusqu’à '
                      '${p(actif.expire.hour)}h${p(actif.expire.minute)}.',
            style: TextStyle(fontSize: 12, color: MoncarColors.inkMut),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: MoncarButton(
                  label: actif == null
                      ? 'Partager le trajet'
                      : 'Partager à nouveau',
                  icon: Icons.share_outlined,
                  variant: MoncarButtonVariant.soft,
                  size: MoncarButtonSize.md,
                  expand: true,
                  onPressed: onPartager,
                ),
              ),
              if (actif != null) ...[
                const SizedBox(width: 8),
                MoncarButton(
                  label: 'Arrêter',
                  variant: MoncarButtonVariant.ghost,
                  size: MoncarButtonSize.md,
                  onPressed: onArreter,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
