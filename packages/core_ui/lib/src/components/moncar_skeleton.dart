import 'package:flutter/material.dart';

import '../theme/moncar_colors.dart';

/// Squelette shimmer MON CAR (Design System) — équivalent du `mc-shimmer` web.
class MoncarSkeleton extends StatefulWidget {
  const MoncarSkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = 12,
    this.circle = false,
  });

  final double? width;
  final double height;
  final double borderRadius;
  final bool circle;

  @override
  State<MoncarSkeleton> createState() => _MoncarSkeletonState();
}

class _MoncarSkeletonState extends State<MoncarSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shape = widget.circle ? BoxShape.circle : BoxShape.rectangle;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            shape: shape,
            borderRadius: shape == BoxShape.rectangle
                ? BorderRadius.circular(widget.borderRadius)
                : null,
            gradient: LinearGradient(
              begin: Alignment(-1 - 2 + 2 * _controller.value, 0),
              end: Alignment(1 - 2 + 2 * _controller.value, 0),
              colors: [
                MoncarColors.muted,
                MoncarColors.isDark
                    ? MoncarColors.hairline
                    : const Color(0xFFF7F8FB),
                MoncarColors.muted,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Squelette de liste MON CAR : cartes « trajet/colis » génériques.
class MoncarListSkeleton extends StatelessWidget {
  const MoncarListSkeleton({super.key, this.count = 4});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(count, (i) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: MoncarColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: MoncarColors.hairline.withValues(alpha: 0.7),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const MoncarSkeleton(width: 48, height: 48, circle: true),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    MoncarSkeleton(width: double.infinity, height: 14),
                    SizedBox(height: 8),
                    MoncarSkeleton(width: 140, height: 12),
                    SizedBox(height: 10),
                    // Pastilles réductibles : pas de débordement sur petit écran.
                    Row(
                      children: [
                        Flexible(
                          child: MoncarSkeleton(
                            width: 64,
                            height: 24,
                            borderRadius: 999,
                          ),
                        ),
                        SizedBox(width: 8),
                        Flexible(
                          child: MoncarSkeleton(
                            width: 80,
                            height: 24,
                            borderRadius: 999,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const MoncarSkeleton(width: 72, height: 30, borderRadius: 10),
            ],
          ),
        );
      }),
    );
  }
}
