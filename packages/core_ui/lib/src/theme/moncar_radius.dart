import 'package:flutter/painting.dart';

/// Rayons d'angle MON CAR (Design System).
abstract final class MoncarRadius {
  static const double small = 8;
  static const double medium = 12;
  static const double large = 16;
  static const double card = 20;
  static const double xl = 26;
  static const double pill = 999;

  static BorderRadius get sm => BorderRadius.circular(small);
  static BorderRadius get md => BorderRadius.circular(medium);
  static BorderRadius get lg => BorderRadius.circular(large);
  static BorderRadius get cardRadius => BorderRadius.circular(card);
  static BorderRadius get xlRadius => BorderRadius.circular(xl);
}
