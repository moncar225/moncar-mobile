import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

/// Zone de signature du client (preuve de remise / restitution).
/// ⚠️ La preuve définitive (horodatage, PV) est générée par le serveur.
class SignaturePad extends StatefulWidget {
  const SignaturePad({super.key, required this.onChanged});

  /// `true` dès qu'un tracé existe.
  final ValueChanged<bool> onChanged;

  @override
  State<SignaturePad> createState() => _SignaturePadState();
}

class _SignaturePadState extends State<SignaturePad> {
  final _strokes = <List<Offset>>[];

  void _clear() {
    setState(_strokes.clear);
    widget.onChanged(false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 180,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: MoncarColors.hairline, width: 1.5),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: GestureDetector(
              onPanStart: (d) {
                setState(() => _strokes.add([d.localPosition]));
                widget.onChanged(true);
              },
              onPanUpdate: (d) =>
                  setState(() => _strokes.last.add(d.localPosition)),
              child: CustomPaint(
                painter: _SignaturePainter(_strokes),
                child: _strokes.isEmpty
                    ? const Center(
                        child: Text(
                          'Signature du client',
                          style: TextStyle(color: Colors.black38, fontSize: 15),
                        ),
                      )
                    : const SizedBox.expand(),
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _strokes.isEmpty ? null : _clear,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Effacer'),
          ),
        ),
      ],
    );
  }
}

class _SignaturePainter extends CustomPainter {
  _SignaturePainter(this.strokes);
  final List<List<Offset>> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFF002060)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final s in strokes) {
      if (s.length < 2) continue;
      final path = Path()..moveTo(s.first.dx, s.first.dy);
      for (final o in s.skip(1)) {
        path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(_SignaturePainter old) => true;
}
