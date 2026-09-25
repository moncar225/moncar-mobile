import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/foundation.dart';
import '../widgets/colis_widgets.dart';

const _disputeTypes = [
  (key: 'retard', label: 'Retard de livraison'),
  (key: 'endommage', label: 'Colis endommagé'),
  (key: 'manquant', label: 'Colis manquant'),
  (key: 'mauvais_colis', label: 'Mauvais colis reçu'),
  (key: 'autre', label: 'Autre motif'),
];

/// Suivi d'un colis (par identifiant ou numéro de suivi) : en-tête,
/// carte stylisée, chronologie et actions (partage, litige, support).
class ColisDetailPage extends ConsumerWidget {
  const ColisDetailPage({super.key, required this.parcelId});

  final String parcelId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(mockStoreChangesProvider);
    final parcel = ref.read(mockStoreProvider).findParcel(parcelId.trim());

    return Scaffold(
      backgroundColor: MoncarColors.background,
      appBar: const TopBar(
        title: 'Suivi de colis',
        showBack: true,
        showBell: false,
      ),
      body: parcel == null
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: MoncarErrorState(
                title: 'Colis introuvable',
                message: 'Aucun colis ne correspond à « $parcelId ».',
                onRetry: () => ref.invalidate(mockStoreChangesProvider),
              ),
            )
          : _Detail(parcel: parcel),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.parcel});

  final Parcel parcel;

  @override
  Widget build(BuildContext context) {
    final p = parcel;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        MoncarCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: brandGradientDecoration(
                  radius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        MoncarBadge(
                          label: parcelStatusLabel(p.status),
                          icon: Icons.inventory_2_outlined,
                          size: MoncarBadgeSize.sm,
                          backgroundColor: Colors.white.withValues(alpha: 0.15),
                          textColor: Colors.white,
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () => copyWithToast(
                            context,
                            p.trackingNumber,
                            message:
                                'Numéro de suivi copié dans le presse-papier.',
                          ),
                          icon: const Icon(Icons.copy, size: 12),
                          label: const Text('Copier'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white.withValues(
                              alpha: 0.85,
                            ),
                            textStyle: const TextStyle(fontSize: 11),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      p.trackingNumber,
                      style: const TextStyle(
                        fontSize: 22,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.place_outlined,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(p.originCity, style: _whiteBold),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            Icons.arrow_forward,
                            size: 12,
                            color: MoncarColors.accent,
                          ),
                        ),
                        Text(p.destinationCity, style: _whiteBold),
                      ],
                    ),
                  ],
                ),
              ),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _Party(
                        label: 'Expéditeur',
                        name: p.senderName,
                        phone: p.senderPhone,
                      ),
                    ),
                    VerticalDivider(width: 1, color: MoncarColors.hairline),
                    Expanded(
                      child: _Party(
                        label: 'Destinataire',
                        name: p.recipientName,
                        phone: p.recipientPhone,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: MoncarColors.hairline),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _MetaCell(
                        icon: Icons.scale_outlined,
                        label: 'Poids',
                        value: '${p.weightKg} kg',
                      ),
                    ),
                    VerticalDivider(width: 1, color: MoncarColors.hairline),
                    Expanded(
                      child: _MetaCell(
                        icon: Icons.straighten,
                        label: 'Dimensions',
                        value: p.dimensions,
                      ),
                    ),
                    VerticalDivider(width: 1, color: MoncarColors.hairline),
                    Expanded(
                      child: _MetaCell(
                        icon: Icons.account_balance_wallet_outlined,
                        label: 'Montant',
                        value: formatXOF(p.amountXOF),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: MoncarColors.hairline),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 14,
                      color: MoncarColors.brand,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Payeur :',
                      style: TextStyle(
                        fontSize: 12,
                        color: MoncarColors.inkMut,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      p.payeeIsSender
                          ? "Expéditeur (à l'envoi)"
                          : 'Destinataire (au retrait)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: MoncarColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _RouteMap(parcel: p),
        const SizedBox(height: 12),
        MoncarCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.navigation_outlined,
                    size: 16,
                    color: MoncarColors.accent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Suivi du colis',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: MoncarColors.ink,
                      ),
                    ),
                  ),
                  MoncarBadge(
                    label: parcelStatusLabel(p.status),
                    tone: parcelStatusTone(p.status),
                    size: MoncarBadgeSize.sm,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _Timeline(timeline: p.timeline, status: p.status),
            ],
          ),
        ),
        const SizedBox(height: 12),
        MoncarButton(
          label: 'Partager le suivi',
          icon: Icons.share_outlined,
          variant: MoncarButtonVariant.primary,
          size: MoncarButtonSize.xl,
          expand: true,
          onPressed: () => copyWithToast(
            context,
            'Suivez mon colis ${p.trackingNumber} sur MON CAR.',
            message: 'Numéro de suivi copié.',
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _openDispute(context, p.trackingNumber),
                icon: const Icon(Icons.gpp_maybe_outlined, size: 16),
                label: const Text(
                  'Signaler un litige',
                  textAlign: TextAlign.center,
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  foregroundColor: MoncarColors.danger,
                  side: BorderSide(color: MoncarColors.danger),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: MoncarButton(
                label: 'Contacter le support',
                icon: Icons.headset_mic_outlined,
                variant: MoncarButtonVariant.outline,
                size: MoncarButtonSize.lg,
                expand: true,
                onPressed: () => showMoncarToast(
                  context,
                  'Mise en relation avec le support…',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static const _whiteBold = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  void _openDispute(BuildContext context, String trackingNumber) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: MoncarColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _DisputeSheet(trackingNumber: trackingNumber),
    );
  }
}

class _Party extends StatelessWidget {
  const _Party({required this.label, required this.name, required this.phone});

  final String label;
  final String name;
  final String phone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OverlineText(label),
          const SizedBox(height: 2),
          Text(
            name,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: MoncarColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(Icons.phone_outlined, size: 12, color: MoncarColors.inkMut),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  phone,
                  style: TextStyle(fontSize: 12, color: MoncarColors.inkMut),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaCell extends StatelessWidget {
  const _MetaCell({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: MoncarColors.brandSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 14, color: MoncarColors.brand),
          ),
          const SizedBox(height: 4),
          OverlineText(label),
          const SizedBox(height: 2),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.2,
              fontWeight: FontWeight.w600,
              color: MoncarColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteMap extends StatefulWidget {
  const _RouteMap({required this.parcel});

  final Parcel parcel;

  @override
  State<_RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<_RouteMap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.parcel;
    final done = p.timeline.where((t) => t.done).toList();
    final current = done.isEmpty ? null : done.last;
    final total = p.timeline.isEmpty ? 1 : p.timeline.length;
    final progress = (done.length / total).clamp(0.05, 0.97);

    return MoncarCard(
      padding: const EdgeInsets.all(12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 192,
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, _) => CustomPaint(
                    painter: _RoutePainter(
                      progress: progress,
                      showCurrent: current != null,
                      pulse: _pulse.value,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: _CityTag(name: p.originCity, color: MoncarColors.brand),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: _CityTag(
                  name: p.destinationCity,
                  color: MoncarColors.accent,
                ),
              ),
              if (current != null)
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: MoncarColors.brand,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.navigation_outlined,
                          size: 12,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Position : ${current.location}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CityTag extends StatelessWidget {
  const _CityTag({required this.name, required this.color});

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            name,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte stylisée : fond dégradé quadrillé, courbe de Bézier origine →
/// destination, portion parcourue en orange et position pulsée.
class _RoutePainter extends CustomPainter {
  _RoutePainter({
    required this.progress,
    required this.showCurrent,
    required this.pulse,
  });

  /// Palette au moment du dessin : redessine au changement de thème.
  final bool dark = MoncarColors.isDark;

  final double progress;
  final bool showCurrent;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: MoncarColors.isDark
              ? [
                  MoncarColors.brandSoft,
                  MoncarColors.muted,
                  MoncarColors.accentSoft,
                ]
              : const [Color(0xFFE7ECF6), Color(0xFFF4F6FA), Color(0xFFFFF0E3)],
        ).createShader(rect),
    );
    final grid = Paint()..color = const Color(0x1F6C7690);
    for (var x = 23.0; x < size.width; x += 24) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 1, size.height), grid);
    }
    for (var y = 23.0; y < size.height; y += 24) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), grid);
    }

    Offset pt(double x, double y) =>
        Offset(x / 300 * size.width, y / 200 * size.height);
    final start = pt(40, 180);
    final ctrl = pt(150, 30);
    final end = pt(260, 40);
    Offset bezier(double t) =>
        start * ((1 - t) * (1 - t)) + ctrl * (2 * (1 - t) * t) + end * (t * t);

    final full = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(ctrl.dx, ctrl.dy, end.dx, end.dy);
    final dash = Paint()
      ..color = MoncarColors.brand.withValues(alpha: 0.25)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final m in full.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 10) {
        canvas.drawPath(m.extractPath(d, d + 4), dash);
      }
    }

    final done = Path()..moveTo(start.dx, start.dy);
    for (var i = 1; i <= 40; i++) {
      final o = bezier(progress * i / 40);
      done.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(
      done,
      Paint()
        ..color = MoncarColors.accent
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );

    void pin(Offset c, Color color, double r) {
      canvas.drawCircle(c, r + 2.5, Paint()..color = Colors.white);
      canvas.drawCircle(c, r, Paint()..color = color);
    }

    pin(start, MoncarColors.brand, 7);
    pin(end, MoncarColors.accent, 7);
    if (showCurrent) {
      final cur = bezier(progress);
      final wave = pulse < 0.5 ? pulse * 2 : (1 - pulse) * 2;
      canvas.drawCircle(
        cur,
        9 + 6 * wave,
        Paint()
          ..color = MoncarColors.accent.withValues(alpha: 0.35 - 0.3 * wave),
      );
      pin(cur, MoncarColors.accent, 6);
    }
  }

  @override
  bool shouldRepaint(covariant _RoutePainter old) =>
      old.progress != progress ||
      old.pulse != pulse ||
      old.showCurrent != showCurrent ||
      old.dark != dark;
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.timeline, required this.status});

  final List<ParcelTimelineEntry> timeline;
  final ParcelStatus status;

  @override
  Widget build(BuildContext context) {
    if (timeline.isEmpty) {
      return Text(
        'Aucune étape enregistrée pour ce colis.',
        style: TextStyle(fontSize: 12, color: MoncarColors.inkMut),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < timeline.length; i++)
          _TimelineRow(
            entry: timeline[i],
            isLast: i == timeline.length - 1,
            isCurrent:
                timeline[i].done &&
                (i == timeline.length - 1 || !timeline[i + 1].done),
            status: status,
          ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.entry,
    required this.isLast,
    required this.isCurrent,
    required this.status,
  });

  final ParcelTimelineEntry entry;
  final bool isLast;
  final bool isCurrent;
  final ParcelStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, ring) = !entry.done
        ? (MoncarColors.surface, Colors.transparent)
        : switch (entry.status) {
            ParcelStatus.litige => (
              MoncarColors.danger,
              MoncarColors.dangerSoft,
            ),
            ParcelStatus.livre => (
              MoncarColors.success,
              MoncarColors.successSoft,
            ),
            _ => (MoncarColors.accent, MoncarColors.accentSoft),
          };
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: ring,
                    border: isCurrent
                        ? Border.all(
                            color: MoncarColors.accent.withValues(alpha: 0.4),
                            width: 2,
                          )
                        : null,
                  ),
                  child: Container(
                    width: 16,
                    height: 16,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: entry.done
                          ? null
                          : Border.all(color: MoncarColors.hairline, width: 2),
                    ),
                    child: entry.done
                        ? const Icon(Icons.check, size: 10, color: Colors.white)
                        : Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: MoncarColors.inkFaint.withValues(
                                alpha: 0.4,
                              ),
                              shape: BoxShape.circle,
                            ),
                          ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      constraints: const BoxConstraints(minHeight: 24),
                      decoration: BoxDecoration(
                        color: entry.done
                            ? MoncarColors.accent.withValues(alpha: 0.7)
                            : MoncarColors.hairline,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16, top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: entry.done
                                ? MoncarColors.ink
                                : MoncarColors.inkFaint,
                          ),
                        ),
                      ),
                      if (isCurrent &&
                          status != ParcelStatus.livre &&
                          status != ParcelStatus.annule)
                        const MoncarBadge(
                          label: 'En cours',
                          tone: MoncarBadgeTone.accent,
                          size: MoncarBadgeSize.sm,
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.place_outlined,
                          size: 12,
                          color: MoncarColors.inkMut,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          entry.location,
                          style: TextStyle(
                            fontSize: 12,
                            color: MoncarColors.inkMut,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.done ? timeAgo(entry.at) : formatDateLong(entry.at),
                    style: TextStyle(
                      fontSize: 11,
                      color: MoncarColors.inkFaint,
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

class _DisputeSheet extends StatefulWidget {
  const _DisputeSheet({required this.trackingNumber});

  final String trackingNumber;

  @override
  State<_DisputeSheet> createState() => _DisputeSheetState();
}

class _DisputeSheetState extends State<_DisputeSheet> {
  String _type = _disputeTypes.first.key;
  final _description = TextEditingController();

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  void _submit() {
    if (_description.text.trim().isEmpty) {
      showMoncarToast(context, 'Veuillez décrire le litige.', error: true);
      return;
    }
    final label = _disputeTypes.firstWhere((t) => t.key == _type).label;
    Navigator.of(context).pop();
    showMoncarToast(
      context,
      'Litige signalé. Notre équipe vous recontacte sous 24h. '
      '(Colis ${widget.trackingNumber} • $label)',
      success: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.gpp_maybe_outlined,
                      size: 16,
                      color: MoncarColors.danger,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Signaler un litige',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: MoncarColors.ink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 12, color: MoncarColors.inkMut),
                    children: [
                      const TextSpan(text: 'Colis '),
                      TextSpan(
                        text: widget.trackingNumber,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                          color: MoncarColors.ink,
                        ),
                      ),
                      const TextSpan(
                        text: ' — décrivez le problème rencontré.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: MoncarColors.hairline),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const MoncarLabel('Motif du litige'),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 3.2,
                    children: [
                      for (final t in _disputeTypes)
                        InkWell(
                          onTap: () => setState(() => _type = t.key),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: _type == t.key
                                  ? MoncarColors.dangerSoft
                                  : MoncarColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _type == t.key
                                    ? MoncarColors.danger
                                    : MoncarColors.hairline,
                                width: 2,
                              ),
                            ),
                            child: Text(
                              t.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: _type == t.key
                                    ? MoncarColors.danger
                                    : MoncarColors.ink,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  MoncarTextField(
                    label: 'Description',
                    controller: _description,
                    hint:
                        "Expliquez ce qui s'est passé, la date du constat, etc.",
                    maxLines: 4,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: MoncarColors.warnSoft.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      "Le traitement d'un litige peut prendre jusqu'à 72h. "
                      "Vous serez notifié par SMS et dans l'application.",
                      style: TextStyle(
                        fontSize: 11,
                        color: MoncarColors.inkFaint,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: MoncarColors.hairline),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: [
                  MoncarButton(
                    label: 'Annuler',
                    variant: MoncarButtonVariant.ghost,
                    size: MoncarButtonSize.lg,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: MoncarButton(
                      label: 'Envoyer le signalement',
                      icon: Icons.gpp_maybe_outlined,
                      variant: MoncarButtonVariant.danger,
                      size: MoncarButtonSize.lg,
                      expand: true,
                      onPressed: _submit,
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
