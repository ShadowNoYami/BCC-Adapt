import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../accessibility/domain/accessibility_profile.dart';
import 'adaptive_tokens.dart';
import 'app_palette.dart';

/// Builds a [ThemeData] fully derived from an [AccessibilityProfile].
///
/// Text scaling strategy: the profile's `textScaleFactor` (which already
/// absorbs the system font scale, see `AccessibilityRulesEngine`) is baked
/// into the [TextTheme]. The app therefore disables the additional
/// `MediaQuery.textScaler` (see `BccAdaptApp`) to avoid double scaling while
/// keeping the 1.0..2.0 range deterministic.
abstract final class AppThemeBuilder {
  /// Set to `false` in tests to avoid runtime font fetching.
  static bool useGoogleFonts = true;

  static ThemeData build(AccessibilityProfile profile) {
    final palette = AppPalette.of(profile.contrastMode);
    final tokens = AdaptiveTokens.fromProfile(profile, palette);
    final hc = profile.isHighContrast;

    final scheme = ColorScheme(
      brightness: palette.brightness,
      primary: palette.primary,
      onPrimary: palette.onPrimary,
      primaryContainer: palette.surfaceVariant,
      onPrimaryContainer: palette.onSurface,
      secondary: palette.accentText,
      onSecondary: palette.background,
      tertiary: palette.emphasis,
      onTertiary: palette.background,
      error: palette.error,
      onError: palette.onError,
      surface: palette.surface,
      onSurface: palette.onSurface,
      onSurfaceVariant: palette.onSurfaceMuted,
      surfaceContainerLowest: palette.background,
      surfaceContainerLow: palette.surface,
      surfaceContainer: palette.surfaceVariant,
      surfaceContainerHigh: palette.surfaceVariant,
      surfaceContainerHighest: palette.surfaceVariant,
      outline: palette.border,
      outlineVariant: palette.divider,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: palette.onSurface,
      onInverseSurface: palette.surface,
      inversePrimary: palette.accentText,
      surfaceTint: Colors.transparent,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: palette.brightness,
    );

    final textTheme = _buildTextTheme(base.textTheme, profile, palette);
    final radius = BorderRadius.circular(tokens.cornerRadius);
    final hcSide = BorderSide(color: palette.border, width: palette.borderWidth);
    final target = tokens.minTouchTarget;
    final buttonPadding = EdgeInsets.symmetric(
      horizontal: tokens.spacingUnit * 3,
      vertical: tokens.spacingUnit * 1.5,
    );
    final buttonShape = RoundedRectangleBorder(
      borderRadius: radius,
      side: hc ? hcSide : BorderSide.none,
    );
    final labelStyle = textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w700,
    );

    return base.copyWith(
      scaffoldBackgroundColor: palette.background,
      canvasColor: palette.background,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      focusColor: palette.focus.withValues(alpha: hc ? 0.35 : 0.2),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      iconTheme: IconThemeData(color: palette.onSurface, size: tokens.iconSize),
      dividerTheme: DividerThemeData(
        color: palette.divider,
        thickness: hc ? 2 : 1,
        space: tokens.spacingUnit * 2,
      ),
      appBarTheme: AppBarThemeData(
        backgroundColor: palette.background,
        foregroundColor: palette.onSurface,
        elevation: 0,
        scrolledUnderElevation: hc ? 0 : 1,
        centerTitle: false,
        titleTextStyle:
            textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        toolbarHeight: 56 + (profile.textScaleFactor - 1) * 32,
        shape: hc ? Border(bottom: hcSide) : null,
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        elevation: hc ? 0 : 1,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        margin: EdgeInsets.all(tokens.spacingUnit),
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: hc ? hcSide : BorderSide(color: palette.divider),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.primary,
          foregroundColor: palette.onPrimary,
          minimumSize: Size(target, target),
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: labelStyle,
          elevation: hc ? 0 : 1,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.primary,
          foregroundColor: palette.onPrimary,
          minimumSize: Size(target, target),
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: labelStyle,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.accentText,
          minimumSize: Size(target, target),
          padding: buttonPadding,
          shape: RoundedRectangleBorder(borderRadius: radius),
          side: BorderSide(
            color: hc ? palette.border : palette.primary,
            width: hc ? palette.borderWidth : 1.5,
          ),
          textStyle: labelStyle,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.accentText,
          minimumSize: Size(target, target),
          padding: buttonPadding,
          textStyle: labelStyle?.copyWith(
            decoration: hc ? TextDecoration.underline : null,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: palette.onSurface,
          minimumSize: Size(target, target),
          iconSize: tokens.iconSize,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: palette.primary,
        foregroundColor: palette.onPrimary,
        sizeConstraints: BoxConstraints.tightFor(
          width: target + 8,
          height: target + 8,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: hc ? hcSide : BorderSide.none,
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: hc ? palette.background : palette.surfaceVariant,
        contentPadding: EdgeInsets.symmetric(
          horizontal: tokens.spacingUnit * 2,
          vertical: tokens.spacingUnit * 2,
        ),
        labelStyle: textTheme.bodyLarge?.copyWith(color: palette.onSurfaceMuted),
        floatingLabelStyle:
            textTheme.bodyLarge?.copyWith(color: palette.accentText),
        hintStyle: textTheme.bodyLarge?.copyWith(color: palette.onSurfaceMuted),
        errorStyle: textTheme.bodyMedium?.copyWith(
          color: palette.error,
          fontWeight: FontWeight.w600,
        ),
        border: _inputBorder(radius, palette.border, palette.borderWidth),
        enabledBorder:
            _inputBorder(radius, palette.border, palette.borderWidth),
        focusedBorder:
            _inputBorder(radius, palette.focus, palette.borderWidth + 1),
        errorBorder: _inputBorder(radius, palette.error, palette.borderWidth),
        focusedErrorBorder:
            _inputBorder(radius, palette.error, palette.borderWidth + 1),
      ),
      listTileTheme: ListTileThemeData(
        minVerticalPadding: tokens.spacingUnit,
        minTileHeight: target,
        iconColor: palette.onSurface,
        textColor: palette.onSurface,
        contentPadding:
            EdgeInsets.symmetric(horizontal: tokens.spacingUnit * 2),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: hc ? hcSide : BorderSide.none,
        ),
        titleTextStyle:
            textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        contentTextStyle: textTheme.bodyLarge,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.onSurface,
        contentTextStyle:
            textTheme.bodyLarge?.copyWith(color: palette.background),
        behavior: SnackBarBehavior.floating,
      ),
      switchTheme: SwitchThemeData(
        materialTapTargetSize: MaterialTapTargetSize.padded,
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? palette.onPrimary
              : palette.onSurfaceMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? palette.primary
              : palette.surfaceVariant,
        ),
        trackOutlineColor: WidgetStateProperty.all(palette.border),
      ),
      progressIndicatorTheme:
          ProgressIndicatorThemeData(color: palette.primary),
      extensions: [tokens],
    );
  }

  static TextTheme _buildTextTheme(
    TextTheme base,
    AccessibilityProfile profile,
    AppPalette palette,
  ) {
    // Inter has full Cyrillic + Kazakh glyph coverage (Ә І Ң Ғ Ү Ұ Қ Ө Һ).
    // Merge Material 2021 typography first so every TextStyle has an explicit
    // fontSize before applying fontSizeFactor.
    final fontFamily = useGoogleFonts ? GoogleFonts.inter().fontFamily : null;
    final withGeometry = Typography.englishLike2021.merge(base);
    final scaled = withGeometry.apply(
      fontFamily: fontFamily,
      fontSizeFactor: profile.textScaleFactor,
      bodyColor: palette.onSurface,
      displayColor: palette.onSurface,
    );
    if (!profile.isHighContrast) return scaled;
    // High contrast: no thin strokes — enforce at least Medium weight.
    TextStyle? heavier(TextStyle? s) {
      if (s == null) return null;
      final w = s.fontWeight ?? FontWeight.w400;
      return s.copyWith(
        fontWeight: w.value < 500 ? FontWeight.w500 : w,
      );
    }

    return scaled.copyWith(
      displayLarge: heavier(scaled.displayLarge),
      displayMedium: heavier(scaled.displayMedium),
      displaySmall: heavier(scaled.displaySmall),
      headlineLarge: heavier(scaled.headlineLarge),
      headlineMedium: heavier(scaled.headlineMedium),
      headlineSmall: heavier(scaled.headlineSmall),
      titleLarge: heavier(scaled.titleLarge),
      titleMedium: heavier(scaled.titleMedium),
      titleSmall: heavier(scaled.titleSmall),
      bodyLarge: heavier(scaled.bodyLarge),
      bodyMedium: heavier(scaled.bodyMedium),
      bodySmall: heavier(scaled.bodySmall),
      labelLarge: heavier(scaled.labelLarge),
      labelMedium: heavier(scaled.labelMedium),
      labelSmall: heavier(scaled.labelSmall),
    );
  }

  static OutlineInputBorder _inputBorder(
    BorderRadius radius,
    Color color,
    double width,
  ) =>
      OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: color, width: width),
      );
}
