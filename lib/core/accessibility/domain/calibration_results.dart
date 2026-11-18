import 'package:flutter/foundation.dart';

/// Result of calibration micro-test #1 — vision.
///
/// The user is shown a sample phrase at growing sizes and picks the first one
/// that is comfortable to read; then chooses between contrast previews.
@immutable
class VisionCalibrationResult {
  const VisionCalibrationResult({
    required this.comfortableTextScale,
    this.prefersHighContrast = false,
    this.prefersDarkBackground = false,
  });

  final double comfortableTextScale;
  final bool prefersHighContrast;
  final bool prefersDarkBackground;
}

/// Result of calibration micro-test #2 — motor precision.
///
/// The user taps a sequence of targets of decreasing size.
@immutable
class MotorCalibrationResult {
  const MotorCalibrationResult({
    required this.totalTargets,
    required this.missedTaps,
    this.accidentalRepeatTaps = 0,
    this.averageReactionMs = 0,
  }) : assert(totalTargets > 0);

  final int totalTargets;

  /// Taps landed outside the target.
  final int missedTaps;

  /// Unintended double / repeated taps within 300 ms (tremor marker).
  final int accidentalRepeatTaps;

  final int averageReactionMs;

  double get missRate => missedTaps / (totalTargets + missedTaps);
}

/// Result of calibration micro-test #3 — cognitive load.
///
/// The user performs a mini-task ("find the balance and open transfers").
@immutable
class CognitiveCalibrationResult {
  const CognitiveCalibrationResult({
    required this.completed,
    required this.durationMs,
    this.wrongTaps = 0,
    this.requestedHelp = false,
  });

  final bool completed;
  final int durationMs;
  final int wrongTaps;
  final bool requestedHelp;
}
