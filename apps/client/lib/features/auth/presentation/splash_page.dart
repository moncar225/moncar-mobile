import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/foundation.dart';

/// Écran de démarrage : logo animé puis redirection vers
/// l'onboarding (premier lancement) ou la connexion.
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..forward();

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      if (ref.read(authProvider).isAuthenticated) {
        context.go('/home');
        return;
      }
      final seen = ref.read(onboardingSeenProvider);
      context.go(seen ? '/auth/login' : '/auth/onboarding');
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logoAnim = CurvedAnimation(
      parent: _anim,
      curve: const Interval(0, 0.5, curve: Cubic(0.22, 1, 0.36, 1)),
    );
    final taglineAnim = CurvedAnimation(
      parent: _anim,
      curve: const Interval(0.25, 0.65, curve: Curves.easeOut),
    );
    final loaderAnim = CurvedAnimation(
      parent: _anim,
      curve: const Interval(0.7, 1, curve: Curves.easeOut),
    );
    return Scaffold(
      body: Container(
        decoration: brandGradientDecoration(),
        child: Stack(
          children: [
            Positioned(
              top: -96,
              right: -96,
              child: _Blob(color: MoncarColors.accent.withValues(alpha: 0.2)),
            ),
            Positioned(
              bottom: -96,
              left: -96,
              child: _Blob(color: Colors.white.withValues(alpha: 0.1)),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FadeTransition(
                    opacity: logoAnim,
                    child: ScaleTransition(
                      scale: Tween(begin: 0.8, end: 1.0).animate(logoAnim),
                      child: Column(
                        children: [
                          const MonCarLogo(size: 96),
                          const SizedBox(height: 16),
                          RichText(
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
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
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FadeTransition(
                    opacity: taglineAnim,
                    child: SlideTransition(
                      position: Tween(
                        begin: const Offset(0, 0.4),
                        end: Offset.zero,
                      ).animate(taglineAnim),
                      child: Text(
                        'Voyagez en toute confiance',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 48,
              child: FadeTransition(
                opacity: loaderAnim,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                        backgroundColor: Colors.white30,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Chargement…',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 288,
      height: 288,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [BoxShadow(color: color, blurRadius: 64, spreadRadius: 16)],
      ),
    );
  }
}
