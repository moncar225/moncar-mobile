import 'package:flutter/material.dart';

import 'package:core_ui/core_ui.dart';

/// Logo officiel MON CAR (asset PNG). En cas d'échec de chargement,
/// un monogramme dégradé navy est affiché à la place.
class MonCarLogo extends StatelessWidget {
  const MonCarLogo({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Container(
        width: size,
        height: size,
        color: MoncarColors.surface,
        child: Image.asset(
          'assets/moncar-logo.png',
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: MoncarColors.brandGradient,
              ),
            ),
            child: Center(
              child: Text(
                'MC',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: size * 0.4,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Logotype « MON CAR » — MON en navy, CAR en orange.
class MonCarWordmark extends StatelessWidget {
  const MonCarWordmark({super.key, this.fontSize = 16});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'MON',
            style: TextStyle(color: MoncarColors.brand),
          ),
          TextSpan(
            text: ' CAR',
            style: TextStyle(color: MoncarColors.accent),
          ),
        ],
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}

/// Lockup complet : logo + logotype (+ tagline optionnelle).
class MonCarLockup extends StatelessWidget {
  const MonCarLockup({super.key, this.size = 40, this.tagline});

  final double size;
  final String? tagline;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MonCarLogo(size: size),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            MonCarWordmark(fontSize: size * 0.4),
            if (tagline != null)
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Text(
                  tagline!,
                  style: TextStyle(fontSize: 10, color: MoncarColors.inkMut),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
