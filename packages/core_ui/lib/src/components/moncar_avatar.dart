import 'package:flutter/material.dart';

import '../theme/moncar_colors.dart';

/// Avatar MON CAR (Design System) — cercle dégradé navy avec initiales,
/// ou photo de profil si [image] est fournie.
class MoncarAvatar extends StatelessWidget {
  const MoncarAvatar({
    super.key,
    required this.initials,
    this.size = 36,
    this.image,
  });

  final String initials;
  final double size;
  final ImageProvider? image;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: MoncarColors.brandGradient,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF002060).withValues(alpha: 0.14),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
        image: image == null
            ? null
            : DecorationImage(image: image!, fit: BoxFit.cover),
      ),
      alignment: Alignment.center,
      child: image != null
          ? null
          : Text(
              initials,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: size * 0.4,
              ),
            ),
    );
  }
}
