import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// WCAG 2.1 contrast utilities.
abstract final class ContrastChecker {
  static const double aaNormal = 4.5;
  static const double aaaNormal = 7.0;

  /// Contrast ratio between two opaque colors, in range 1..21.
  static double ratio(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final lighter = math.max(la, lb);
    final darker = math.min(la, lb);
    return (lighter + 0.05) / (darker + 0.05);
  }

  static bool meetsAAA(Color foreground, Color background) =>
      ratio(foreground, background) >= aaaNormal;

  static bool meetsAA(Color foreground, Color background) =>
      ratio(foreground, background) >= aaNormal;
}
