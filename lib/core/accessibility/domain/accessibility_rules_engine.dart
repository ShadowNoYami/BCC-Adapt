import 'accessibility_profile.dart';
import 'calibration_results.dart';
import 'system_accessibility_flags.dart';

/// Deterministic (rule-based, no ML / LLM) accessibility profile engine.
///
/// Every rule is a pure function: same input -> same profile. This makes the
/// adaptation auditable for the bank's compliance and fully unit-testable.
abstract final class AccessibilityRulesEngine {
  // ---- Thresholds (single source of truth) ---------------------------------
  static const double largeSystemFontThreshold = 1.15;
  static const double boldTextMinScale = 1.25;

  static const double tremorMissRate = 0.35;
  static const int tremorRepeatTaps = 3;
  static const double enlargedMissRate = 0.15;
  static const int slowReactionMs = 1500;

  static const int cognitiveSlowMs = 45000;
  static const int cognitiveModerateMs = 20000;
  static const int cognitiveManyErrors = 4;
  static const int cognitiveSomeErrors = 2;

  /// Applies OS accessibility flags to [current].
  ///
  /// * The screen-reader flag is ALWAYS synced (it drives the TalkBack Guard).
  /// * Before calibration ([AccessibilityProfile.isOnboardingCompleted] ==
  ///   false) the profile is pre-configured from the system settings so the
  ///   calibration itself is already readable / navigable.
  /// * After calibration the user's explicit choices win; only the
  ///   screen-reader flag is synced.
  static AccessibilityProfile applySystemFlags(
    AccessibilityProfile current,
    SystemAccessibilityFlags flags,
  ) {
    var next = current.copyWith(
      screenReaderActive: flags.accessibleNavigation,
    );
    if (current.isOnboardingCompleted) return next;

    var scale = next.textScaleFactor;
    if (flags.textScaleFactor >= largeSystemFontThreshold) {
      scale = _max(scale, flags.textScaleFactor);
    }
    if (flags.boldText) scale = _max(scale, boldTextMinScale);

    next = next.copyWith(textScaleFactor: scale);

    if (flags.highContrast && next.contrastMode == ContrastMode.standard) {
      next = next.copyWith(contrastMode: ContrastMode.highContrastLight);
    }

    if (flags.accessibleNavigation) {
      next = next.copyWith(
        // TalkBack / VoiceOver already speaks — never double-voice.
        voiceAssistantEnabled: false,
        motorLevel: _maxMotor(next.motorLevel,
            MotorAssistanceLevel.enlargedTargets),
      );
    }
    return next;
  }

  /// Calibration test #1 — vision.
  static AccessibilityProfile applyVision(
    AccessibilityProfile current,
    VisionCalibrationResult r,
  ) {
    final ContrastMode contrast;
    if (r.prefersDarkBackground) {
      contrast = ContrastMode.highContrastDark;
    } else if (r.prefersHighContrast) {
      contrast = ContrastMode.highContrastLight;
    } else {
      contrast = ContrastMode.standard;
    }
    return current.copyWith(
      textScaleFactor: r.comfortableTextScale,
      contrastMode: contrast,
      // Very large text is a strong marker that spoken prompts will help.
      voiceAssistantEnabled: current.voiceAssistantEnabled ||
          (r.comfortableTextScale >= AccessibilityProfile.maxTextScale &&
              !current.screenReaderActive),
    );
  }

  /// Calibration test #2 — motor precision.
  static AccessibilityProfile applyMotor(
    AccessibilityProfile current,
    MotorCalibrationResult r,
  ) {
    return current.copyWith(motorLevel: motorLevelFor(r));
  }

  static MotorAssistanceLevel motorLevelFor(MotorCalibrationResult r) {
    if (r.missRate >= tremorMissRate ||
        r.accidentalRepeatTaps >= tremorRepeatTaps) {
      return MotorAssistanceLevel.tremorProtection;
    }
    if (r.missRate >= enlargedMissRate ||
        r.averageReactionMs >= slowReactionMs ||
        r.accidentalRepeatTaps > 0) {
      return MotorAssistanceLevel.enlargedTargets;
    }
    return MotorAssistanceLevel.standard;
  }

  /// Calibration test #3 — cognitive load.
  static AccessibilityProfile applyCognitive(
    AccessibilityProfile current,
    CognitiveCalibrationResult r,
  ) {
    return current.copyWith(cognitiveMode: cognitiveModeFor(r));
  }

  static CognitiveMode cognitiveModeFor(CognitiveCalibrationResult r) {
    if (!r.completed ||
        r.durationMs >= cognitiveSlowMs ||
        r.wrongTaps >= cognitiveManyErrors) {
      return CognitiveMode.guidedStepByStep;
    }
    if (r.requestedHelp ||
        r.durationMs >= cognitiveModerateMs ||
        r.wrongTaps >= cognitiveSomeErrors) {
      return CognitiveMode.simplifiedEssential;
    }
    return CognitiveMode.fullBanking;
  }

  /// Full reset to the standard BCC interface. Keeps language and the live
  /// screen-reader flag (the latter is a fact about the device, not a choice).
  static AccessibilityProfile reset(AccessibilityProfile current) {
    return AccessibilityProfile.standard.copyWith(
      localeCode: current.localeCode,
      screenReaderActive: current.screenReaderActive,
      isOnboardingCompleted: true,
    );
  }

  static double _max(double a, double b) => a > b ? a : b;

  static MotorAssistanceLevel _maxMotor(
          MotorAssistanceLevel a, MotorAssistanceLevel b) =>
      a.index >= b.index ? a : b;
}
