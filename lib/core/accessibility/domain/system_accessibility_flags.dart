import 'package:flutter/foundation.dart';

/// Snapshot of OS-level accessibility settings.
///
/// Pure value object, so the rules engine stays testable without a binding.
@immutable
class SystemAccessibilityFlags {
  const SystemAccessibilityFlags({
    this.textScaleFactor = 1.0,
    this.accessibleNavigation = false,
    this.boldText = false,
    this.highContrast = false,
  });

  static const SystemAccessibilityFlags none = SystemAccessibilityFlags();

  /// System font scale (Android "Font size", iOS "Larger Text").
  final double textScaleFactor;

  /// TalkBack / VoiceOver (or Switch Access) is active.
  final bool accessibleNavigation;

  /// iOS "Bold Text" / Android "Bold font".
  final bool boldText;

  /// iOS "Increase Contrast" / Android "High contrast text".
  final bool highContrast;

  @override
  bool operator ==(Object other) =>
      other is SystemAccessibilityFlags &&
      other.textScaleFactor == textScaleFactor &&
      other.accessibleNavigation == accessibleNavigation &&
      other.boldText == boldText &&
      other.highContrast == highContrast;

  @override
  int get hashCode =>
      Object.hash(textScaleFactor, accessibleNavigation, boldText, highContrast);

  @override
  String toString() => 'SystemAccessibilityFlags(scale: $textScaleFactor, '
      'a11yNav: $accessibleNavigation, bold: $boldText, hc: $highContrast)';
}
