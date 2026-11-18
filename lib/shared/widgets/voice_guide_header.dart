import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/accessibility/application/accessibility_profile_notifier.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/adaptive_tokens.dart';
import '../../core/voice/application/voice_accessibility_service.dart';

/// Language switcher (`РУС / ҚАЗ`) guaranteed to be at least `48×48 dp`
/// (and growing with [AdaptiveTokens.minTouchTarget]) without text overflow
/// at up to 200% text scaling.
class LanguageSwitchButton extends ConsumerWidget {
  const LanguageSwitchButton({
    super.key,
    this.onBeforeSwitch,
  });

  final VoidCallback? onBeforeSwitch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentAccessibilityProfileProvider);
    final strings = ref.watch(appStringsProvider);
    final tokens = AdaptiveTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    final minSide = math.max(48.0, tokens.minTouchTarget);
    final isKk = profile.localeCode == 'kk';

    return Semantics(
      button: true,
      label: strings.languageLabel,
      value: isKk ? strings.languageKk : strings.languageRu,
      excludeSemantics: true,
      child: OutlinedButton(
        onPressed: () {
          onBeforeSwitch?.call();
          if (tokens.hapticFeedback) {
            HapticFeedback.selectionClick();
          }
          ref
              .read(accessibilityProfileProvider.notifier)
              .setLocale(isKk ? 'ru' : 'kk');
        },
        style: OutlinedButton.styleFrom(
          minimumSize: Size(minSide, minSide),
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacingUnit * 1.5,
            vertical: tokens.spacingUnit,
          ),
          side: BorderSide(
            color: profile.isHighContrast ? scheme.outline : scheme.primary,
            width: profile.isHighContrast ? tokens.borderWidth : 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: scheme.surface,
        ),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: strings.langShortRu,
                style: TextStyle(
                  fontWeight: !isKk ? FontWeight.w800 : FontWeight.w500,
                  color: !isKk
                      ? (profile.isHighContrast
                          ? scheme.onSurface
                          : tokens.accentText)
                      : scheme.onSurfaceVariant,
                  decoration: !isKk && profile.isHighContrast
                      ? TextDecoration.underline
                      : null,
                ),
              ),
              TextSpan(
                text: ' / ',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              TextSpan(
                text: strings.langShortKk,
                style: TextStyle(
                  fontWeight: isKk ? FontWeight.w800 : FontWeight.w500,
                  color: isKk
                      ? (profile.isHighContrast
                          ? scheme.onSurface
                          : tokens.accentText)
                      : scheme.onSurfaceVariant,
                  decoration: isKk && profile.isHighContrast
                      ? TextDecoration.underline
                      : null,
                ),
              ),
            ],
          ),
          style: theme.textTheme.labelLarge,
          softWrap: true,
        ),
      ),
    );
  }
}

/// Compact top bar shown whenever [voiceAssistantEnabled] is active or when
/// [alwaysShow] is true (e.g. on calibration screens).
///
/// Includes a «Повторить озвучку» speaker button (protected by TalkBack Guard)
/// and a >= `48×48 dp` `РУС / ҚАЗ` language toggle.
class VoiceGuideHeader extends ConsumerWidget {
  const VoiceGuideHeader({
    super.key,
    required this.promptText,
    this.alwaysShow = false,
    this.onLanguageSwitched,
  });

  /// Spoken text triggered when the user taps «Повторить озвучку».
  final String promptText;

  /// Displays the header even if `voiceAssistantEnabled == false`
  /// (used on the Calibration flow).
  final bool alwaysShow;

  final VoidCallback? onLanguageSwitched;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentAccessibilityProfileProvider);
    if (!alwaysShow && !profile.voiceAssistantEnabled) {
      return const SizedBox.shrink();
    }

    final strings = ref.watch(appStringsProvider);
    final tokens = AdaptiveTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    final voiceSession = ref.watch(voiceSessionProvider);
    final minSide = math.max(48.0, tokens.minTouchTarget);
    final talkBackActive =
        profile.screenReaderActive || MediaQuery.accessibleNavigationOf(context);

    return Semantics(
      container: true,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacingUnit * 1.5,
          vertical: tokens.spacingUnit,
        ),
        decoration: BoxDecoration(
          color: profile.isHighContrast
              ? scheme.surfaceContainer
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(tokens.cornerRadius),
          border: Border.all(
            color: profile.isHighContrast
                ? scheme.outline
                : scheme.outlineVariant,
            width: profile.isHighContrast ? tokens.borderWidth : 1,
          ),
        ),
        child: Wrap(
          spacing: tokens.spacingUnit * 1.5,
          runSpacing: tokens.spacingUnit,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Semantics(
              button: true,
              enabled: !talkBackActive,
              label: strings.repeatVoiceButton,
              excludeSemantics: true,
              child: ElevatedButton.icon(
                onPressed: talkBackActive
                    ? null
                    : () {
                        if (tokens.hapticFeedback) {
                          HapticFeedback.selectionClick();
                        }
                        ref.read(voiceSessionProvider.notifier).speak(
                              promptText,
                              context: context,
                              force: true,
                            );
                      },
                icon: ExcludeSemantics(
                  child: Icon(
                    voiceSession.isSpeaking
                        ? Icons.graphic_eq
                        : Icons.volume_up_rounded,
                    size: tokens.iconSize,
                  ),
                ),
                label: Text(
                  strings.repeatVoiceButton,
                  softWrap: true,
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(minSide, minSide),
                  padding: EdgeInsets.symmetric(
                    horizontal: tokens.spacingUnit * 2,
                    vertical: tokens.spacingUnit,
                  ),
                ),
              ),
            ),
            LanguageSwitchButton(onBeforeSwitch: onLanguageSwitched),
          ],
        ),
      ),
    );
  }
}
