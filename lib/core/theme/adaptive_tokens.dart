import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../accessibility/domain/accessibility_profile.dart';
import 'app_palette.dart';

/// Accessibility-driven design tokens exposed to widgets through
/// `Theme.of(context).extension<AdaptiveTokens>()` (or [AdaptiveTokens.of]).
@immutable
class AdaptiveTokens extends ThemeExtension<AdaptiveTokens> {
  const AdaptiveTokens({
    required this.minTouchTarget,
    required this.spacingUnit,
    required this.borderWidth,
    required this.cornerRadius,
    required this.iconSize,
    required this.requiresHoldToConfirm,
    required this.holdToConfirmDuration,
    required this.hapticFeedback,
    required this.showsPromoBanners,
    required this.showsAnalytics,
    required this.guidedFlow,
    required this.accentText,
    required this.emphasis,
    required this.warning,
    required this.success,
  });

  factory AdaptiveTokens.fromProfile(
    AccessibilityProfile profile,
    AppPalette palette,
  ) {
    return AdaptiveTokens(
      minTouchTarget: profile.minTouchTarget,
      spacingUnit: 8 * profile.spacingFactor,
      borderWidth: palette.borderWidth,
      cornerRadius: 16,
      iconSize: 24 + (profile.textScaleFactor - 1) * 16,
      requiresHoldToConfirm: profile.requiresHoldToConfirm,
      holdToConfirmDuration: profile.holdToConfirmDuration,
      hapticFeedback:
          profile.motorLevel != MotorAssistanceLevel.standard ||
              profile.screenReaderActive,
      showsPromoBanners: profile.showsPromoBanners,
      showsAnalytics: profile.showsAnalytics,
      guidedFlow: profile.usesGuidedFlow,
      accentText: palette.accentText,
      emphasis: palette.emphasis,
      warning: palette.warning,
      success: palette.success,
    );
  }

  final double minTouchTarget;

  /// Base gap (8 dp * motor spacing factor). Use multiples of it.
  final double spacingUnit;
  final double borderWidth;
  final double cornerRadius;
  final double iconSize;
  final bool requiresHoldToConfirm;
  final Duration holdToConfirmDuration;
  final bool hapticFeedback;
  final bool showsPromoBanners;
  final bool showsAnalytics;
  final bool guidedFlow;
  final Color accentText;
  final Color emphasis;
  final Color warning;
  final Color success;

  static AdaptiveTokens of(BuildContext context) =>
      Theme.of(context).extension<AdaptiveTokens>()!;

  @override
  AdaptiveTokens copyWith({
    double? minTouchTarget,
    double? spacingUnit,
    double? borderWidth,
    double? cornerRadius,
    double? iconSize,
    bool? requiresHoldToConfirm,
    Duration? holdToConfirmDuration,
    bool? hapticFeedback,
    bool? showsPromoBanners,
    bool? showsAnalytics,
    bool? guidedFlow,
    Color? accentText,
    Color? emphasis,
    Color? warning,
    Color? success,
  }) {
    return AdaptiveTokens(
      minTouchTarget: minTouchTarget ?? this.minTouchTarget,
      spacingUnit: spacingUnit ?? this.spacingUnit,
      borderWidth: borderWidth ?? this.borderWidth,
      cornerRadius: cornerRadius ?? this.cornerRadius,
      iconSize: iconSize ?? this.iconSize,
      requiresHoldToConfirm:
          requiresHoldToConfirm ?? this.requiresHoldToConfirm,
      holdToConfirmDuration:
          holdToConfirmDuration ?? this.holdToConfirmDuration,
      hapticFeedback: hapticFeedback ?? this.hapticFeedback,
      showsPromoBanners: showsPromoBanners ?? this.showsPromoBanners,
      showsAnalytics: showsAnalytics ?? this.showsAnalytics,
      guidedFlow: guidedFlow ?? this.guidedFlow,
      accentText: accentText ?? this.accentText,
      emphasis: emphasis ?? this.emphasis,
      warning: warning ?? this.warning,
      success: success ?? this.success,
    );
  }

  @override
  AdaptiveTokens lerp(ThemeExtension<AdaptiveTokens>? other, double t) {
    if (other is! AdaptiveTokens) return this;
    final pick = t < 0.5 ? this : other;
    return AdaptiveTokens(
      minTouchTarget: lerpDouble(minTouchTarget, other.minTouchTarget, t)!,
      spacingUnit: lerpDouble(spacingUnit, other.spacingUnit, t)!,
      borderWidth: lerpDouble(borderWidth, other.borderWidth, t)!,
      cornerRadius: lerpDouble(cornerRadius, other.cornerRadius, t)!,
      iconSize: lerpDouble(iconSize, other.iconSize, t)!,
      requiresHoldToConfirm: pick.requiresHoldToConfirm,
      holdToConfirmDuration: pick.holdToConfirmDuration,
      hapticFeedback: pick.hapticFeedback,
      showsPromoBanners: pick.showsPromoBanners,
      showsAnalytics: pick.showsAnalytics,
      guidedFlow: pick.guidedFlow,
      accentText: Color.lerp(accentText, other.accentText, t)!,
      emphasis: Color.lerp(emphasis, other.emphasis, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      success: Color.lerp(success, other.success, t)!,
    );
  }
}
