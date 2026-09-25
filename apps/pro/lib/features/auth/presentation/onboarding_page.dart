import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/application/session_controller.dart';
import '../../../core/ui/pro_kit.dart';

class _Slide {
  const _Slide(this.icon, this.title, this.body, this.colors);
  final IconData icon;
  final String title;
  final String body;
  final List<Color> colors;
}

const _slides = [
  _Slide(
    Icons.qr_code_scanner_rounded,
    'Contrôlez en une seconde',
    'Scannez les billets, validez l’embarquement et suivez le manifeste '
        'de votre voyage en temps réel.',
    [Color(0xFF002060), Color(0xFF1547A0)],
  ),
  _Slide(
    Icons.cloud_off_rounded,
    'Même sans réseau',
    'Billets vérifiables hors ligne, actions enregistrées sur le téléphone '
        'puis synchronisées sans doublon au retour du réseau.',
    [Color(0xFF064E47), Color(0xFF0F766E)],
  ),
  _Slide(
    Icons.route_rounded,
    'Toute l’équipe connectée',
    'Chauffeur, convoyeur, contrôleur et gares partagent le même voyage : '
        'arrêts, retards, incidents et alertes.',
    [Color(0xFFCC4D00), Color(0xFFFF7A00)],
  ),
];

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish() {
    ref.read(sessionProvider.notifier).completeOnboarding();
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final last = _index == _slides.length - 1;
    return Scaffold(
      backgroundColor: MoncarColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
              child: Row(
                children: [
                  const ProLogo(size: 34),
                  const SizedBox(width: 10),
                  const ProWordmark(),
                  const Spacer(),
                  if (!last)
                    TextButton(
                      onPressed: _finish,
                      child: Text(
                        'Passer',
                        style: TextStyle(
                          color: MoncarColors.inkMut,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) => _SlideView(slide: _slides[i]),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _slides.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _index ? 26 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _index
                          ? MoncarColors.accent
                          : MoncarColors.hairline,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: BigActionButton(
                label: last ? 'Commencer' : 'Suivant',
                icon: last ? Icons.login_rounded : Icons.arrow_forward_rounded,
                color: MoncarColors.accent,
                onPressed: () {
                  if (last) {
                    _finish();
                  } else {
                    _controller.nextPage(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutCubic,
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});

  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 190,
            height: 190,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: slide.colors,
              ),
              boxShadow: [
                BoxShadow(
                  color: slide.colors.last.withValues(alpha: 0.35),
                  blurRadius: 40,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: Icon(slide.icon, size: 84, color: Colors.white),
          ),
          const SizedBox(height: 40),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: MoncarColors.ink,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            slide.body,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15.5,
              color: MoncarColors.inkMut,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
