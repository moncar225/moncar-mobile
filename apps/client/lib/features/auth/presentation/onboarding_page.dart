import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../shared/foundation.dart';
import '../widgets/onboarding_illustrations.dart';

class _Slide {
  const _Slide({
    required this.id,
    required this.title,
    required this.description,
    required this.cta,
    required this.svg,
  });

  final String id;
  final String title;
  final String description;
  final String cta;
  final String svg;
}

const _slides = [
  _Slide(
    id: 'voyager',
    title: 'Voyagez simplement',
    description:
        'Trouvez votre trajet, choisissez votre siège et réservez en quelques instants.',
    cta: 'Suivant',
    svg: voyagerIllustrationSvg,
  ),
  _Slide(
    id: 'colis',
    title: 'Envoyez en toute simplicité',
    description:
        'Expédiez vos colis et suivez leur acheminement depuis MON CAR.',
    cta: 'Suivant',
    svg: colisIllustrationSvg,
  ),
  _Slide(
    id: 'location',
    title: 'Louez votre véhicule',
    description:
        'Trouvez un véhicule adapté à vos besoins et réservez simplement.',
    cta: 'Commencer',
    svg: locationIllustrationSvg,
  ),
];

/// Onboarding premium en 3 écrans (Voyager, Colis, Location).
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  int _direction = 1;
  late final AnimationController _dots = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _dots.dispose();
    super.dispose();
  }

  void _finish() {
    ref.read(onboardingSeenProvider.notifier).state = true;
    context.go('/auth/login');
  }

  void _goTo(int i) {
    setState(() {
      _direction = i >= _index ? 1 : -1;
      _index = i;
    });
  }

  void _next() {
    if (_index < _slides.length - 1) {
      _goTo(_index + 1);
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = _slides[_index];
    final isLast = _index == _slides.length - 1;
    return Scaffold(
      body: Container(
        decoration: brandGradientDecoration(),
        child: Stack(
          children: [
            // Motif swoosh du logo.
            Positioned(
              top: -80,
              right: -80,
              child: Opacity(
                opacity: 0.15,
                child: SvgPicture.string(swooshTopSvg, width: 320, height: 320),
              ),
            ),
            Positioned(
              bottom: -128,
              left: -96,
              child: Opacity(
                opacity: 0.1,
                child: SvgPicture.string(
                  swooshBottomSvg,
                  width: 384,
                  height: 384,
                ),
              ),
            ),
            ..._floatingDots(context),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Row(
                      children: [
                        const MonCarLogo(size: 32),
                        const SizedBox(width: 8),
                        RichText(
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                            children: [
                              TextSpan(text: 'MON'),
                              TextSpan(
                                text: ' CAR',
                                style: TextStyle(color: MoncarColors.accent),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        if (!isLast)
                          TextButton(
                            onPressed: _finish,
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white70,
                              shape: const StadiumBorder(),
                            ),
                            child: const Text(
                              'Passer',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onHorizontalDragEnd: (d) {
                        final v = d.primaryVelocity ?? 0;
                        if (v < -200) _next();
                        if (v > 200 && _index > 0) _goTo(_index - 1);
                      },
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 420),
                        switchInCurve: const Cubic(0.22, 1, 0.36, 1),
                        transitionBuilder: (child, anim) {
                          final incoming = child.key == ValueKey(current.id);
                          final dx = (incoming ? 0.15 : -0.1) * _direction;
                          return FadeTransition(
                            opacity: anim,
                            child: SlideTransition(
                              position: Tween(
                                begin: Offset(dx, 0),
                                end: Offset.zero,
                              ).animate(anim),
                              child: child,
                            ),
                          );
                        },
                        child: _SlideView(
                          key: ValueKey(current.id),
                          slide: current,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                    child: Column(
                      children: [
                        _ProgressDots(
                          count: _slides.length,
                          index: _index,
                          onTap: _goTo,
                        ),
                        const SizedBox(height: 24),
                        MoncarButton(
                          label: current.cta,
                          icon: isLast ? null : Icons.chevron_right,
                          variant: MoncarButtonVariant.primary,
                          size: MoncarButtonSize.xl,
                          expand: true,
                          onPressed: _next,
                        ),
                        if (_index > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: TextButton.icon(
                              onPressed: () => _goTo(_index - 1),
                              icon: const Icon(Icons.chevron_left, size: 16),
                              label: const Text('Précédent'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white60,
                                textStyle: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _floatingDots(BuildContext context) {
    const dots = [
      (x: 0.15, y: 0.25, s: 4.0, phase: 0.0),
      (x: 0.85, y: 0.60, s: 3.0, phase: 0.25),
      (x: 0.20, y: 0.70, s: 5.0, phase: 0.5),
      (x: 0.75, y: 0.30, s: 3.0, phase: 0.75),
    ];
    final size = MediaQuery.sizeOf(context);
    return [
      for (final d in dots)
        AnimatedBuilder(
          animation: _dots,
          builder: (context, _) {
            final t = (_dots.value + d.phase) % 1.0;
            final wave = (t < 0.5 ? t : 1 - t) * 2; // 0 → 1 → 0
            return Positioned(
              left: size.width * d.x,
              top: size.height * d.y - 12 * wave,
              child: Container(
                width: d.s,
                height: d.s,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.2 + 0.3 * wave),
                ),
              ),
            );
          },
        ),
    ];
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({super.key, required this.slide});

  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.92, end: 1),
              duration: const Duration(milliseconds: 500),
              curve: const Cubic(0.22, 1, 0.36, 1),
              builder: (context, v, child) => Opacity(
                opacity: ((v - 0.92) / 0.08).clamp(0, 1),
                child: Transform.scale(scale: v, child: child),
              ),
              child: SvgPicture.string(slide.svg, width: 280, height: 220),
            ),
            const SizedBox(height: 32),
            Text(
              slide.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 26,
                height: 1.2,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Text(
                slide.description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressDots extends StatelessWidget {
  const _ProgressDots({
    required this.count,
    required this.index,
    required this.onTap,
  });

  final int count;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++) ...[
          Semantics(
            button: true,
            label: 'Écran ${i + 1}',
            child: GestureDetector(
              onTap: () => onTap(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: const Cubic(0.22, 1, 0.36, 1),
                width: i == index ? 28 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i == index
                      ? MoncarColors.accent
                      : Colors.white.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
          if (i < count - 1)
            Container(
              width: 24,
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              color: Colors.white.withValues(alpha: 0.2),
            ),
        ],
      ],
    );
  }
}
