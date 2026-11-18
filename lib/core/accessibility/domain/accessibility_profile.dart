import 'package:flutter/foundation.dart';

/// Visual contrast mode of the interface.
///
/// Both high-contrast modes are tuned to WCAG 2.1 AAA (contrast ratio
/// >= 7:1 for body text against its background).
enum ContrastMode { standard, highContrastLight, highContrastDark }

/// Level of motor (fine-motor / tremor) assistance.
enum MotorAssistanceLevel {
  /// Material default touch targets (48x48 dp).
  standard,

  /// Touch targets of at least 64x64 dp.
  enlargedTargets,

  /// Enlarged targets + extra spacing + hold-to-confirm (1.5 s) with haptics.
  tremorProtection,
}

/// Cognitive load mode of the interface.
enum CognitiveMode {
  /// Full BCC banking feature set.
  fullBanking,

  /// Only Balance, Transfers, Payments and History. No banners, no analytics.
  simplifiedEssential,

  /// Step-by-step guidance with an anti-fraud cooling pause.
  guidedStepByStep,
}

/// Immutable, serialisable accessibility profile of the user.
///
/// The profile contains sensitive health-related markers, so it is persisted
/// exclusively through `flutter_secure_storage` and can be synced to the
/// cloud as JSON via [toJson] / [AccessibilityProfile.fromJson].
@immutable
class AccessibilityProfile {
  const AccessibilityProfile({
    this.textScaleFactor = minTextScale,
    this.contrastMode = ContrastMode.standard,
    this.motorLevel = MotorAssistanceLevel.standard,
    this.cognitiveMode = CognitiveMode.fullBanking,
    this.voiceAssistantEnabled = false,
    this.screenReaderActive = false,
    this.localeCode = defaultLocaleCode,
    this.isOnboardingCompleted = false,
  });

  /// Default "standard BCC interface" profile.
  static const AccessibilityProfile standard = AccessibilityProfile();

  static const double minTextScale = 1.0;
  static const double maxTextScale = 2.0;
  static const double textScaleStep = 0.25;
  static const String defaultLocaleCode = 'ru';
  static const List<String> supportedLocaleCodes = ['ru', 'kk'];

  /// Bumped when the JSON contract changes (for cloud-sync migrations).
  static const int schemaVersion = 1;

  final double textScaleFactor;
  final ContrastMode contrastMode;
  final MotorAssistanceLevel motorLevel;
  final CognitiveMode cognitiveMode;
  final bool voiceAssistantEnabled;
  final bool screenReaderActive;
  final String localeCode;
  final bool isOnboardingCompleted;

  // ---------------------------------------------------------------------------
  // Normalisation helpers
  // ---------------------------------------------------------------------------

  /// Clamps [value] into [minTextScale]..[maxTextScale] and snaps it to the
  /// nearest [textScaleStep] (1.0, 1.25, 1.5, 1.75, 2.0).
  static double normalizeTextScale(double value) {
    if (value.isNaN || value.isInfinite) return minTextScale;
    final clamped = value.clamp(minTextScale, maxTextScale).toDouble();
    final steps = ((clamped - minTextScale) / textScaleStep).round();
    return minTextScale + steps * textScaleStep;
  }

  static String normalizeLocale(String? code) {
    final lower = code?.toLowerCase().split(RegExp('[-_]')).first;
    return supportedLocaleCodes.contains(lower) ? lower! : defaultLocaleCode;
  }

  // ---------------------------------------------------------------------------
  // Derived, deterministic UI tokens
  // ---------------------------------------------------------------------------

  bool get isHighContrast => contrastMode != ContrastMode.standard;

  bool get isDark => contrastMode == ContrastMode.highContrastDark;

  /// Minimum interactive target side in logical pixels.
  double get minTouchTarget => switch (motorLevel) {
        MotorAssistanceLevel.standard => 48,
        MotorAssistanceLevel.enlargedTargets => 64,
        MotorAssistanceLevel.tremorProtection => 72,
      };

  /// Multiplier for paddings / gaps between interactive elements.
  double get spacingFactor => switch (motorLevel) {
        MotorAssistanceLevel.standard => 1.0,
        MotorAssistanceLevel.enlargedTargets => 1.25,
        MotorAssistanceLevel.tremorProtection => 1.75,
      };

  /// Whether critical actions must be confirmed with a long press.
  bool get requiresHoldToConfirm =>
      motorLevel == MotorAssistanceLevel.tremorProtection;

  /// Hold duration for critical confirmations.
  Duration get holdToConfirmDuration => requiresHoldToConfirm
      ? const Duration(milliseconds: 1500)
      : Duration.zero;

  bool get isSimplifiedUi => cognitiveMode != CognitiveMode.fullBanking;

  bool get showsPromoBanners => cognitiveMode == CognitiveMode.fullBanking;

  bool get showsAnalytics => cognitiveMode == CognitiveMode.fullBanking;

  bool get usesGuidedFlow => cognitiveMode == CognitiveMode.guidedStepByStep;

  /// TalkBack Guard: built-in TTS may speak only when enabled and no system
  /// screen reader is active (prevents double voice-over).
  bool get canUseBuiltInVoice => voiceAssistantEnabled && !screenReaderActive;

  // ---------------------------------------------------------------------------
  // Copy / equality / serialisation
  // ---------------------------------------------------------------------------

  AccessibilityProfile copyWith({
    double? textScaleFactor,
    ContrastMode? contrastMode,
    MotorAssistanceLevel? motorLevel,
    CognitiveMode? cognitiveMode,
    bool? voiceAssistantEnabled,
    bool? screenReaderActive,
    String? localeCode,
    bool? isOnboardingCompleted,
  }) {
    return AccessibilityProfile(
      textScaleFactor: textScaleFactor == null
          ? this.textScaleFactor
          : normalizeTextScale(textScaleFactor),
      contrastMode: contrastMode ?? this.contrastMode,
      motorLevel: motorLevel ?? this.motorLevel,
      cognitiveMode: cognitiveMode ?? this.cognitiveMode,
      voiceAssistantEnabled:
          voiceAssistantEnabled ?? this.voiceAssistantEnabled,
      screenReaderActive: screenReaderActive ?? this.screenReaderActive,
      localeCode:
          localeCode == null ? this.localeCode : normalizeLocale(localeCode),
      isOnboardingCompleted:
          isOnboardingCompleted ?? this.isOnboardingCompleted,
    );
  }

  Map<String, Object?> toJson() => {
        'schemaVersion': schemaVersion,
        'textScaleFactor': textScaleFactor,
        'contrastMode': contrastMode.name,
        'motorLevel': motorLevel.name,
        'cognitiveMode': cognitiveMode.name,
        'voiceAssistantEnabled': voiceAssistantEnabled,
        'screenReaderActive': screenReaderActive,
        'localeCode': localeCode,
        'isOnboardingCompleted': isOnboardingCompleted,
      };

  /// Defensive deserialisation: unknown / corrupted values fall back to the
  /// standard profile values instead of throwing.
  factory AccessibilityProfile.fromJson(Map<String, Object?> json) {
    T enumOf<T extends Enum>(List<T> values, Object? raw, T fallback) {
      for (final v in values) {
        if (v.name == raw) return v;
      }
      return fallback;
    }

    final rawScale = json['textScaleFactor'];
    return AccessibilityProfile(
      textScaleFactor: normalizeTextScale(
        rawScale is num ? rawScale.toDouble() : minTextScale,
      ),
      contrastMode: enumOf(
          ContrastMode.values, json['contrastMode'], ContrastMode.standard),
      motorLevel: enumOf(MotorAssistanceLevel.values, json['motorLevel'],
          MotorAssistanceLevel.standard),
      cognitiveMode: enumOf(CognitiveMode.values, json['cognitiveMode'],
          CognitiveMode.fullBanking),
      voiceAssistantEnabled: json['voiceAssistantEnabled'] == true,
      screenReaderActive: json['screenReaderActive'] == true,
      localeCode: normalizeLocale(json['localeCode'] as String?),
      isOnboardingCompleted: json['isOnboardingCompleted'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccessibilityProfile &&
          other.textScaleFactor == textScaleFactor &&
          other.contrastMode == contrastMode &&
          other.motorLevel == motorLevel &&
          other.cognitiveMode == cognitiveMode &&
          other.voiceAssistantEnabled == voiceAssistantEnabled &&
          other.screenReaderActive == screenReaderActive &&
          other.localeCode == localeCode &&
          other.isOnboardingCompleted == isOnboardingCompleted;

  @override
  int get hashCode => Object.hash(
        textScaleFactor,
        contrastMode,
        motorLevel,
        cognitiveMode,
        voiceAssistantEnabled,
        screenReaderActive,
        localeCode,
        isOnboardingCompleted,
      );

  @override
  String toString() => 'AccessibilityProfile(${toJson()})';
}
