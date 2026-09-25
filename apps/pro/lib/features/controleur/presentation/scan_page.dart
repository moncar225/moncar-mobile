import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/application/app_providers.dart';
import '../../../core/application/trip_controller.dart';
import '../../../core/data/mock_data.dart';
import '../../../core/domain/models.dart';
import '../../../core/ui/pro_kit.dart';
import '../widgets/scan_result_view.dart';

/// Contrôleur · Scan des billets (CTRL-01) — plein écran, caméra arrière,
/// vérification locale immédiate (fonctionne sans réseau).
class ScanPage extends ConsumerStatefulWidget {
  const ScanPage({super.key});

  @override
  ConsumerState<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends ConsumerState<ScanPage> {
  final _camera = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );
  ScanResult? _result;
  String? _lastCode;
  DateTime _lastAt = DateTime(2000);
  bool _torch = false;

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  void _handle(String raw, {bool manual = false}) {
    if (_result != null) return;
    final now = DateTime.now();
    // Anti-rebond : le même QR relu dans les 3 s est ignoré.
    if (raw == _lastCode && now.difference(_lastAt).inSeconds < 3) return;
    _lastCode = raw;
    _lastAt = now;
    final r = ref.read(tripProvider.notifier).verify(raw, manual: manual);
    setState(() => _result = r);
  }

  void _next() => setState(() => _result = null);

  Future<void> _manual() async {
    final code = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const _ManualSheet(),
    );
    if (code != null && code.trim().isNotEmpty) _handle(code, manual: true);
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    if (r != null) {
      return Scaffold(
        backgroundColor: MoncarColors.surface,
        body: ScanResultView(
          key: ValueKey(r.at),
          result: r,
          onNext: _next,
          onManifest: () => context.push('/manifeste'),
        ),
      );
    }

    final trip = ref.watch(tripProvider);
    final samples = _demoSamples(trip);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _camera,
            onDetect: (capture) {
              final code = capture.barcodes.firstOrNull?.rawValue;
              if (code != null) _handle(code);
            },
            errorBuilder: (context, error) => const _CameraUnavailable(),
          ),
          const _ScanOverlay(),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: Row(
                    children: [
                      _RoundButton(
                        icon: Icons.arrow_back_rounded,
                        tooltip: 'Retour',
                        onTap: () => context.canPop()
                            ? context.pop()
                            : context.go('/home'),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Contrôle des billets',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
                              ),
                            ),
                            Text(
                              '${trip.voyage.number} · ${trip.voyage.currentStop.shortName}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _RoundButton(
                        icon: _torch
                            ? Icons.flash_on_rounded
                            : Icons.flash_off_rounded,
                        tooltip: 'Lampe',
                        active: _torch,
                        onTap: () async {
                          try {
                            await _camera.toggleTorch();
                            setState(() => _torch = !_torch);
                          } catch (_) {}
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _Counter(done: trip.controlled, total: trip.expected),
                const Spacer(),
                const Text(
                  'Placez le QR du billet dans le cadre',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Vérification locale · fonctionne sans réseau',
                  style: TextStyle(color: Colors.white60, fontSize: 12.5),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: _manual,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.keyboard_rounded),
                      label: const Text(
                        'Saisir la référence du billet',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
                if (kDemoMode) ...[
                  const SizedBox(height: 14),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'SCANS DE DÉMONSTRATION',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      scrollDirection: Axis.horizontal,
                      itemCount: samples.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final (label, code) = samples[i];
                        return ActionChip(
                          label: Text(label),
                          labelStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                          backgroundColor: Colors.white.withValues(alpha: 0.12),
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                          shape: const StadiumBorder(),
                          onPressed: () => _handle(code),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Codes couvrant les 6 cas du CDC, calculés depuis le manifeste courant.
  List<(String, String)> _demoSamples(TripState t) {
    final here = t.voyage.currentStop.id;
    final valid = t.validTickets
        .where((p) => !p.isControlled && p.boardStopId == here)
        .firstOrNull;
    final dup = t.passengers.where((p) => p.isControlled).firstOrNull;
    final cancelled = t.passengers
        .where((p) => p.ticketState == TicketState.annule)
        .firstOrNull;
    final wrongStation = t.validTickets
        .where((p) => !p.isControlled && p.boardStopId != here)
        .firstOrNull;
    return [
      if (valid != null) ('Billet valide', 'MCP:${valid.ticketRef}'),
      if (dup != null) ('Déjà contrôlé', 'MCP:${dup.ticketRef}'),
      if (cancelled != null) ('Annulé', 'MCP:${cancelled.ticketRef}'),
      ('Mauvais voyage', 'MCP:${otherVoyageTickets.keys.first}'),
      if (wrongStation != null)
        ('Mauvaise gare', 'MCP:${wrongStation.ticketRef}'),
      ('QR invalide', 'XYZ-NOT-A-TICKET'),
    ];
  }
}

class _Counter extends StatelessWidget {
  const _Counter({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.verified_rounded,
            color: Color(0xFF34C477),
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            '$done / $total scannés',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.active = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active ? Colors.white : Colors.white.withValues(alpha: 0.14),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 46,
            height: 46,
            child: Icon(icon, color: active ? Colors.black : Colors.white),
          ),
        ),
      ),
    );
  }
}

/// Cadre de visée animé (coins + ligne de balayage).
class _ScanOverlay extends StatefulWidget {
  const _ScanOverlay();

  @override
  State<_ScanOverlay> createState() => _ScanOverlayState();
}

class _ScanOverlayState extends State<_ScanOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final size = (c.maxWidth * 0.72).clamp(200.0, 320.0);
        final top = (c.maxHeight - size) / 2 - 30;
        final left = (c.maxWidth - size) / 2;
        final rect = Rect.fromLTWH(left, top, size, size);
        return Stack(
          children: [
            CustomPaint(size: Size.infinite, painter: _MaskPainter(rect)),
            Positioned.fromRect(
              rect: rect,
              child: CustomPaint(painter: _CornersPainter(MoncarColors.accent)),
            ),
            AnimatedBuilder(
              animation: _c,
              builder: (context, _) => Positioned(
                left: rect.left + 16,
                width: rect.width - 32,
                top: rect.top + 12 + (rect.height - 24) * _c.value,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(99),
                    color: MoncarColors.accent,
                    boxShadow: [
                      BoxShadow(
                        color: MoncarColors.accent.withValues(alpha: 0.7),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MaskPainter extends CustomPainter {
  _MaskPainter(this.hole);
  final Rect hole;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(hole, const Radius.circular(26)));
    canvas.drawPath(
      path,
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(_MaskPainter old) => old.hole != hole;
}

class _CornersPainter extends CustomPainter {
  _CornersPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const l = 34.0;
    const r = 26.0;
    void corner(Offset o, double dx, double dy) {
      final path = Path()
        ..moveTo(o.dx, o.dy + dy * l)
        ..lineTo(o.dx, o.dy + dy * r)
        ..arcToPoint(
          Offset(o.dx + dx * r, o.dy),
          radius: const Radius.circular(r),
          clockwise: dx * dy > 0,
        )
        ..lineTo(o.dx + dx * l, o.dy);
      canvas.drawPath(path, p);
    }

    corner(Offset.zero, 1, 1);
    corner(Offset(s.width, 0), -1, 1);
    corner(Offset(0, s.height), 1, -1);
    corner(Offset(s.width, s.height), -1, -1);
  }

  @override
  bool shouldRepaint(_CornersPainter old) => old.color != color;
}

class _CameraUnavailable extends StatelessWidget {
  const _CameraUnavailable();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0B1220),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(40),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.no_photography_rounded, color: Colors.white54, size: 48),
          SizedBox(height: 12),
          Text(
            'Caméra indisponible.\nAutorisez la caméra ou saisissez la référence du billet.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _ManualSheet extends StatefulWidget {
  const _ManualSheet();

  @override
  State<_ManualSheet> createState() => _ManualSheetState();
}

class _ManualSheetState extends State<_ManualSheet> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Référence du billet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: MoncarColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'La saisie manuelle est tracée (auteur, heure, appareil).',
            style: TextStyle(color: MoncarColors.inkMut, fontSize: 13),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _c,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            onSubmitted: (v) => Navigator.of(context).pop(v),
            decoration: const InputDecoration(
              hintText: 'BIL-0427-014',
              prefixIcon: Icon(Icons.confirmation_number_rounded),
            ),
          ),
          const SizedBox(height: 16),
          BigActionButton(
            label: 'Vérifier le billet',
            icon: Icons.search_rounded,
            color: MoncarColors.brand,
            height: 54,
            onPressed: () => Navigator.of(context).pop(_c.text),
          ),
        ],
      ),
    );
  }
}
