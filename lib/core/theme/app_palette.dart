import 'package:flutter/material.dart';

import '../accessibility/domain/accessibility_profile.dart';

/// Raw color palettes for every [ContrastMode].
///
/// High-contrast palettes are verified by unit tests against WCAG 2.1 AAA
/// (>= 7:1, see `test/core/theme/contrast_test.dart`).
@immutable
class AppPalette {
  const AppPalette({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.onSurface,
    required this.onSurfaceMuted,
    required this.primary,
    required this.onPrimary,
    required this.accentText,
    required this.emphasis,
    required this.border,
    required this.borderWidth,
    required this.divider,
    required this.error,
    required this.onError,
    required this.warning,
    required this.success,
    required this.focus,
  });

  final Brightness brightness;
  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color onSurface;
  final Color onSurfaceMuted;

  /// Button / brand fill color.
  final Color primary;
  final Color onPrimary;

  /// Brand-colored text on [background] (links, amounts).
  final Color accentText;

  /// Extra-emphasis text (e.g. yellow in HC dark).
  final Color emphasis;
  final Color border;
  final double borderWidth;
  final Color divider;
  final Color error;
  final Color onError;
  final Color warning;
  final Color success;
  final Color focus;

  static AppPalette of(ContrastMode mode) => switch (mode) {
        ContrastMode.standard => standardBcc,
        ContrastMode.highContrastLight => highContrastLight,
        ContrastMode.highContrastDark => highContrastDark,
      };

  // ---------------------------------------------------------------------------
  // Standard BCC (Bank CenterCredit brand)
  // ---------------------------------------------------------------------------
  static const Color bccEmerald = Color(0xFF00A859);
  static const Color bccGraphite = Color(0xFF1A1D1F);
  static const Color bccWhite = Color(0xFFFFFFFF);

  static const AppPalette standardBcc = AppPalette(
    brightness: Brightness.light,
    background: bccWhite,
    surface: bccWhite,
    surfaceVariant: Color(0xFFF3F6F4),
    onSurface: bccGraphite,
    onSurfaceMuted: Color(0xFF5B6166),
    primary: bccEmerald,
    onPrimary: bccWhite,
    // Darker brand shade for green TEXT on white (AA 5.6:1).
    accentText: Color(0xFF007A3F),
    emphasis: bccGraphite,
    border: Color(0xFFD9DEDB),
    borderWidth: 1,
    divider: Color(0xFFE9ECEA),
    error: Color(0xFFD32F2F),
    onError: bccWhite,
    warning: Color(0xFFB26A00),
    success: bccEmerald,
    focus: Color(0xFF00753D),
  );

  // ---------------------------------------------------------------------------
  // High Contrast Light — WCAG 2.1 AAA
  // ---------------------------------------------------------------------------
  /// NOTE: the brief suggested `#006B38`, but its real contrast on white is
  /// 6.6:1 (< 7:1, AA only). `#005C30` keeps the dark-emerald brand feel and
  /// reaches 8.2:1, satisfying AAA.
  static const Color hcLightEmerald = Color(0xFF005C30);

  static const AppPalette highContrastLight = AppPalette(
    brightness: Brightness.light,
    background: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFFFFFFF),
    onSurface: Color(0xFF000000),
    onSurfaceMuted: Color(0xFF2B2B2B),
    primary: hcLightEmerald,
    onPrimary: Color(0xFFFFFFFF),
    accentText: hcLightEmerald,
    emphasis: Color(0xFF000000),
    border: Color(0xFF000000),
    borderWidth: 2,
    divider: Color(0xFF000000),
    error: Color(0xFFB00020),
    onError: Color(0xFFFFFFFF),
    warning: Color(0xFF7A4100),
    success: hcLightEmerald,
    focus: Color(0xFF0033CC),
  );

  // ---------------------------------------------------------------------------
  // High Contrast Dark — WCAG 2.1 AAA
  // ---------------------------------------------------------------------------
  static const AppPalette highContrastDark = AppPalette(
    brightness: Brightness.dark,
    background: Color(0xFF0A0A0A),
    surface: Color(0xFF0A0A0A),
    surfaceVariant: Color(0xFF141414),
    onSurface: Color(0xFFFFFFFF),
    onSurfaceMuted: Color(0xFFE6E6E6),
    primary: Color(0xFF00E676),
    onPrimary: Color(0xFF000000),
    accentText: Color(0xFF00E676),
    emphasis: Color(0xFFFFE600),
    border: Color(0xFFFFFFFF),
    borderWidth: 2,
    divider: Color(0xFFFFFFFF),
    error: Color(0xFFFF9E9E),
    onError: Color(0xFF000000),
    warning: Color(0xFFFFE600),
    success: Color(0xFF00E676),
    focus: Color(0xFFFFE600),
  );
}
