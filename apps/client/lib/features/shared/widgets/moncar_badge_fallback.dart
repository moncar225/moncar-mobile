import 'package:flutter/material.dart';

/// Badge translucide blanc utilisé sur les fonds colorés (carrousel promo).
Widget transparentBadge(String code) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.25),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.card_giftcard, size: 10, color: Colors.white),
        const SizedBox(width: 4),
        Text(
          code,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    ),
  );
}
