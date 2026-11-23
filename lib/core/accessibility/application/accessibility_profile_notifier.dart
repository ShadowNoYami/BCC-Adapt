import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/accessibility_profile_repository.dart';
import '../data/system_accessibility_source.dart';
import '../domain/accessibility_profile.dart';
import '../domain/accessibility_rules_engine.dart';
import '../domain/calibration_results.dart';

/// Single source of truth for the user's accessibility profile.
///
/// Lifecycle:
/// 1. loads the stored profile from secure storage (or creates a default one
///    in the device language);
/// 2. reads OS flags (font scale, TalkBack/VoiceOver, bold text, high
///    contrast) and pre-configures the profile before calibration;
/// 3. keeps listening to OS changes (e.g. TalkBack toggled at runtime);
/// 4. persists every change back to secure storage.
class AccessibilityProfileNotifier extends AsyncNotifier<AccessibilityProfile> {
  AccessibilityProfileRepository get _repo =>
      ref.read(accessibilityProfileRepositoryProvider);

  @override
  Future<AccessibilityProfile> build() async {
    final repo = ref.watch(accessibilityProfileRepositoryProvider);
    final system = ref.watch(systemAccessibilitySourceProvider);

    final stored = await repo.load();
    final base = stored ??
        AccessibilityProfile.standard.copyWith(
          localeCode: system.readLanguageCode(),
        );
    final profile = AccessibilityRulesEngine.applySystemFlags(
      base,
      system.read(),
    );

    final unsubscribe = system.listen(_onSystemFlagsChanged);
    ref.onDispose(unsubscribe);

    if (profile != stored) await _persist(profile, repo);
    return profile;
  }

  // ---------------------------------------------------------------------------
  // System sync
  // ---------------------------------------------------------------------------

  void _onSystemFlagsChanged() {
    final flags = ref.read(systemAccessibilitySourceProvider).read();
    _update((p) => AccessibilityRulesEngine.applySystemFlags(p, flags));
  }

  // ---------------------------------------------------------------------------
  // Manual settings
  // ---------------------------------------------------------------------------

  Future<void> setTextScale(double value) =>
      _update((p) => p.copyWith(textScaleFactor: value));

  Future<void> increaseTextScale() => _update((p) => p.copyWith(
      textScaleFactor:
          p.textScaleFactor + AccessibilityProfile.textScaleStep));

  Future<void> decreaseTextScale() => _update((p) => p.copyWith(
      textScaleFactor:
          p.textScaleFactor - AccessibilityProfile.textScaleStep));

  Future<void> setContrastMode(ContrastMode mode) =>
      _update((p) => p.copyWith(contrastMode: mode));

  Future<void> setMotorLevel(MotorAssistanceLevel level) =>
      _update((p) => p.copyWith(motorLevel: level));

  Future<void> setCognitiveMode(CognitiveMode mode) =>
      _update((p) => p.copyWith(cognitiveMode: mode));

  /// The flag is stored as the user's preference; actual speaking is still
  /// blocked by the TalkBack Guard while a screen reader is active.
  Future<void> setVoiceAssistantEnabled(bool enabled) =>
      _update((p) => p.copyWith(voiceAssistantEnabled: enabled));

  Future<void> setLocale(String localeCode) =>
      _update((p) => p.copyWith(localeCode: localeCode));

  // ---------------------------------------------------------------------------
  // Calibration (3 micro-tests)
  // ---------------------------------------------------------------------------

  Future<void> applyVisionCalibration(VisionCalibrationResult result) =>
      _update((p) => AccessibilityRulesEngine.applyVision(p, result));

  Future<void> applyMotorCalibration(MotorCalibrationResult result) =>
      _update((p) => AccessibilityRulesEngine.applyMotor(p, result));

  Future<void> applyCognitiveCalibration(CognitiveCalibrationResult result) =>
      _update((p) => AccessibilityRulesEngine.applyCognitive(p, result));

  Future<void> completeOnboarding() =>
      _update((p) => p.copyWith(isOnboardingCompleted: true));

  /// Starts calibration again, re-applying OS presets.
  Future<void> restartCalibration() => _update((p) {
        final flags = ref.read(systemAccessibilitySourceProvider).read();
        return AccessibilityRulesEngine.applySystemFlags(
          p.copyWith(isOnboardingCompleted: false),
          flags,
        );
      });

  /// Full reset to the standard BCC interface.
  Future<void> resetToStandard() => _update(AccessibilityRulesEngine.reset);

  /// Atomically restores a previously captured [AccessibilityProfile] snapshot
  /// (used for instant Undo after resetting accessibility settings).
  Future<void> restoreProfile(AccessibilityProfile snapshot) =>
      _update((_) => snapshot);

  /// Applies a profile received from cloud sync. The local screen-reader
  /// flag always wins — it reflects this particular device.
  Future<void> importFromJson(Map<String, Object?> json) => _update((p) =>
      AccessibilityProfile.fromJson(json)
          .copyWith(screenReaderActive: p.screenReaderActive));

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  Future<void> _update(
    AccessibilityProfile Function(AccessibilityProfile current) transform,
  ) async {
    final current = await future;
    final next = transform(current);
    if (next == current) return;
    state = AsyncData(next);
    await _persist(next, _repo);
  }

  Future<void> _persist(
    AccessibilityProfile profile,
    AccessibilityProfileRepository repo,
  ) async {
    try {
      await repo.save(profile);
    } catch (e, st) {
      // UI keeps working with the in-memory profile.
      debugPrint('Failed to persist accessibility profile: $e\n$st');
    }
  }
}

/// Async profile (loading from secure storage on cold start).
final accessibilityProfileProvider =
    AsyncNotifierProvider<AccessibilityProfileNotifier, AccessibilityProfile>(
  AccessibilityProfileNotifier.new,
);

/// Synchronous view for widgets: falls back to the standard profile while
/// loading, so the UI never has to deal with `AsyncValue` for styling.
final currentAccessibilityProfileProvider = Provider<AccessibilityProfile>(
  (ref) =>
      ref.watch(accessibilityProfileProvider).value ??
      AccessibilityProfile.standard,
);
