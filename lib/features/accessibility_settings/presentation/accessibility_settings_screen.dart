import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accessibility/application/accessibility_profile_notifier.dart';
import '../../../core/accessibility/domain/accessibility_profile.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/l10n/money_formatter.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/adaptive_tokens.dart';
import '../../../core/voice/application/voice_accessibility_service.dart';
import '../../../shared/widgets/adaptive_action_button.dart';
import '../../../shared/widgets/adaptive_card.dart';
import '../../../shared/widgets/voice_guide_header.dart';
import '../../banking/data/mock_bank_repository.dart';

/// Screen 6: Live Accessibility Profile Control Panel.
///
/// Includes a live BCC balance preview card at the top, manual controls for
/// text scale (`100%..200%`), contrast theme, motor assistance, cognitive mode,
/// and voice assistant, plus 1-tap demo buttons to recalibrate or reset.
class AccessibilitySettingsScreen extends ConsumerWidget {
  const AccessibilitySettingsScreen({super.key});

  static const List<double> _scaleSteps = [1.0, 1.25, 1.5, 1.75, 2.0];

  bool _hasActiveAdaptations(AccessibilityProfile profile) =>
      profile.textScaleFactor > AccessibilityProfile.minTextScale ||
      profile.contrastMode != ContrastMode.standard ||
      profile.motorLevel != MotorAssistanceLevel.standard ||
      profile.cognitiveMode != CognitiveMode.fullBanking ||
      profile.voiceAssistantEnabled;

  Future<void> _resetAccessibilityWithUndo(
    BuildContext context,
    WidgetRef ref,
    AccessibilityProfile previous,
  ) async {
    final notifier = ref.read(accessibilityProfileProvider.notifier);
    final strings = ref.read(appStringsProvider);
    final messenger = ScaffoldMessenger.of(context);

    await notifier.resetToStandard();
    await ref.read(voiceSessionProvider.notifier).stopAll();
    if (!context.mounted) return;

    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 8),
        content: Text(strings.accessibilityResetDoneNotice, softWrap: true),
        action: SnackBarAction(
          label: strings.undoButton,
          onPressed: () {
            notifier.restoreProfile(previous);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentAccessibilityProfileProvider);
    final notifier = ref.read(accessibilityProfileProvider.notifier);
    final strings = ref.watch(appStringsProvider);
    final bank = ref.watch(mockBankRepositoryProvider);
    final tokens = AdaptiveTokens.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final formattedBalance = MoneyFormatter.format(
      bank.primaryAccount.balanceTenge,
      localeCode: profile.localeCode,
    );
    final hasAdaptations = _hasActiveAdaptations(profile);
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final previewHeightFraction = 0.45 + (profile.textScaleFactor - 1) * 0.2;

    return Scaffold(
      appBar: AppBar(title: Text(strings.a11ySettingsTitle, softWrap: true)),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Pinned top quick-reset + compact live preview (no scrolling needed)
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: viewportHeight * previewHeightFraction,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: scheme.surface,
                  border: Border(
                    bottom: BorderSide(
                      color: profile.isHighContrast
                          ? scheme.outline
                          : scheme.outlineVariant,
                      width: profile.isHighContrast ? tokens.borderWidth : 1,
                    ),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    tokens.spacingUnit * 2,
                    tokens.spacingUnit,
                    tokens.spacingUnit * 2,
                    tokens.spacingUnit * 1.25,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (hasAdaptations)
                        AdaptiveActionButton(
                          key: const ValueKey('quick_reset_accessibility'),
                          label: strings.quickResetAccessibilityButton,
                          icon: Icons.restart_alt_rounded,
                          variant: AdaptiveButtonVariant.outlined,
                          applyTremorSpacing: false,
                          onPressed: () =>
                              _resetAccessibilityWithUndo(context, ref, profile),
                        )
                      else
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: tokens.spacingUnit * 1.5,
                            vertical: tokens.spacingUnit,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: scheme.outlineVariant),
                          ),
                          child: Row(
                            children: [
                              ExcludeSemantics(
                                child: Icon(
                                  Icons.check_circle_outline_rounded,
                                  color: tokens.success,
                                  size: tokens.iconSize,
                                ),
                              ),
                              SizedBox(width: tokens.spacingUnit),
                              Expanded(
                                child: Text(
                                  strings.standardModeActiveStatus,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  softWrap: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                      SizedBox(height: tokens.spacingUnit),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: tokens.spacingUnit,
                        runSpacing: tokens.spacingUnit * 0.5,
                        children: [
                          Text(
                            strings.livePreviewTitle,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurfaceVariant,
                            ),
                            softWrap: true,
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: tokens.spacingUnit * 1.25,
                              vertical: tokens.spacingUnit * 0.4,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: profile.isHighContrast
                                    ? scheme.outline
                                    : scheme.outlineVariant,
                              ),
                            ),
                            child: Text(
                              strings.previewBadge,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurfaceVariant,
                              ),
                              softWrap: true,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: tokens.spacingUnit * 0.75),
                      AdaptiveCard(
                        padding: EdgeInsets.all(tokens.spacingUnit * 1.25),
                        borderColor: profile.isHighContrast
                            ? scheme.outline
                            : scheme.outlineVariant,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${bank.primaryAccount.localizedTitle(profile.localeCode)} '
                              '${bank.primaryAccount.maskedPan}',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              softWrap: true,
                            ),
                            SizedBox(height: tokens.spacingUnit * 0.25),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                formattedBalance,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: tokens.accentText,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Scrollable accessibility controls
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(tokens.spacingUnit * 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Align(
                      alignment: Alignment.centerRight,
                      child: LanguageSwitchButton(),
                    ),
                    SizedBox(height: tokens.spacingUnit * 1.5),

                    // 1. Text Scale (100%..200% slider + segment chips)
                    _SectionTitle(
                      '${strings.textScaleLabel}: ${(profile.textScaleFactor * 100).round()}%',
                    ),
                    SizedBox(height: tokens.spacingUnit),
                    AdaptiveCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Slider(
                            value: profile.textScaleFactor,
                            min: AccessibilityProfile.minTextScale,
                            max: AccessibilityProfile.maxTextScale,
                            divisions: 4,
                            label: '${(profile.textScaleFactor * 100).round()}%',
                            semanticFormatterCallback: (value) =>
                                '${(value * 100).round()}%',
                            onChanged: (v) => notifier.setTextScale(v),
                          ),
                          SizedBox(height: tokens.spacingUnit),
                          Wrap(
                            spacing: tokens.spacingUnit,
                            runSpacing: tokens.spacingUnit,
                            children: _scaleSteps.map((step) {
                              final selected =
                                  (profile.textScaleFactor - step).abs() < 0.01;
                              final pct = '${(step * 100).round()}%';
                              return Semantics(
                                selected: selected,
                                child: OutlinedButton(
                                  onPressed: () => notifier.setTextScale(step),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: Size(
                                      math.max(48, tokens.minTouchTarget),
                                      math.max(48, tokens.minTouchTarget),
                                    ),
                                    backgroundColor: selected
                                        ? scheme.primary
                                        : scheme.surface,
                                    foregroundColor: selected
                                        ? scheme.onPrimary
                                        : scheme.onSurface,
                                    side: BorderSide(
                                      color: selected
                                          ? scheme.primary
                                          : scheme.outline,
                                      width: selected
                                          ? 2.5
                                          : tokens.borderWidth,
                                    ),
                                  ),
                                  child: Semantics(
                                    label: '${strings.textScaleLabel} $pct',
                                    excludeSemantics: true,
                                    child: Text(
                                      pct,
                                      style: theme.textTheme.labelLarge
                                          ?.copyWith(
                                            color: selected
                                                ? scheme.onPrimary
                                                : scheme.onSurface,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: tokens.spacingUnit * 2.5),

                    // 2. Contrast Mode
                    _SectionTitle(strings.contrastModeLabel),
                    SizedBox(height: tokens.spacingUnit),
                    ...ContrastMode.values.map(
                      (mode) => Padding(
                        padding: EdgeInsets.only(bottom: tokens.spacingUnit),
                        child: AdaptiveCard(
                          selected: profile.contrastMode == mode,
                          semanticLabel: strings.contrastModeName(mode),
                          onTap: () => notifier.setContrastMode(mode),
                          child: _SettingsOptionRow(
                            selected: profile.contrastMode == mode,
                            label: strings.contrastModeName(mode),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: tokens.spacingUnit * 2),

                    // 3. Motor Level
                    _SectionTitle(strings.motorModeLabel),
                    SizedBox(height: tokens.spacingUnit),
                    ...MotorAssistanceLevel.values.map((level) {
                      final label = switch (level) {
                        MotorAssistanceLevel.standard =>
                          strings.motorShortStandard,
                        MotorAssistanceLevel.enlargedTargets =>
                          strings.motorShortEnlarged,
                        MotorAssistanceLevel.tremorProtection =>
                          strings.motorShortTremor,
                      };
                      return Padding(
                        padding: EdgeInsets.only(bottom: tokens.spacingUnit),
                        child: AdaptiveCard(
                          selected: profile.motorLevel == level,
                          semanticLabel: label,
                          onTap: () => notifier.setMotorLevel(level),
                          child: _SettingsOptionRow(
                            selected: profile.motorLevel == level,
                            label: label,
                          ),
                        ),
                      );
                    }),
                    SizedBox(height: tokens.spacingUnit * 2),

                    // 4. Cognitive Mode
                    _SectionTitle(strings.cognitiveModeLabel),
                    SizedBox(height: tokens.spacingUnit),
                    ...CognitiveMode.values.map((mode) {
                      final label = switch (mode) {
                        CognitiveMode.fullBanking => strings.cognitiveShortFull,
                        CognitiveMode.simplifiedEssential =>
                          strings.cognitiveShortEssential,
                        CognitiveMode.guidedStepByStep =>
                          strings.cognitiveShortGuided,
                      };
                      return Padding(
                        padding: EdgeInsets.only(bottom: tokens.spacingUnit),
                        child: AdaptiveCard(
                          selected: profile.cognitiveMode == mode,
                          semanticLabel: label,
                          onTap: () => notifier.setCognitiveMode(mode),
                          child: _SettingsOptionRow(
                            selected: profile.cognitiveMode == mode,
                            label: label,
                          ),
                        ),
                      );
                    }),
                    SizedBox(height: tokens.spacingUnit * 2),

                    // 5. Voice Assistant (TTS only — never requests microphone!)
                    VoiceAssistantToggle(
                      enabled: profile.voiceAssistantEnabled,
                      title: strings.voiceAssistantLabel,
                      description:
                          profile.screenReaderActive ||
                              MediaQuery.accessibleNavigationOf(context)
                          ? (kIsWeb
                                ? strings.browserAccessibilityNotice
                                : strings.talkBackGuardActiveNotice)
                          : strings.voiceOptionDesc,
                      onChanged: (enabled) async {
                        await notifier.setVoiceAssistantEnabled(enabled);
                        if (!context.mounted) return;
                        if (!enabled) {
                          await ref
                              .read(voiceSessionProvider.notifier)
                              .stopSpeaking();
                        }
                      },
                    ),
                    SizedBox(height: tokens.spacingUnit * 3),

                    // 6. Primary Done button + Divider + Secondary Calibration / Reset
                    AdaptiveActionButton(
                      label: strings.doneButton,
                      icon: Icons.check_rounded,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: tokens.spacingUnit * 2,
                      ),
                      child: const Divider(),
                    ),
                    AdaptiveActionButton(
                      label: strings.recalibrateThreeStepsButton,
                      icon: Icons.tune_rounded,
                      variant: AdaptiveButtonVariant.outlined,
                      onPressed: () async {
                        await ref.read(voiceSessionProvider.notifier).stopAll();
                        if (!context.mounted) return;
                        final navigator = Navigator.of(context);
                        final saved = await navigator.pushNamed<bool>(
                          AppRoutes.calibration,
                          arguments: true,
                        );
                        if (saved == true &&
                            context.mounted &&
                            navigator.canPop()) {
                          navigator.pop();
                        }
                      },
                    ),
                    SizedBox(height: tokens.spacingUnit * 1.5),
                    AdaptiveActionButton(
                      label: strings.resetToStandardBccButton,
                      icon: Icons.restart_alt_rounded,
                      variant: AdaptiveButtonVariant.secondary,
                      onPressed: () =>
                          _resetAccessibilityWithUndo(context, ref, profile),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleLarge
          ?.copyWith(fontWeight: FontWeight.w800),
      softWrap: true,
    );
  }
}

class _SettingsOptionRow extends StatelessWidget {
  const _SettingsOptionRow({required this.selected, required this.label});

  final bool selected;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = AdaptiveTokens.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      children: [
        ExcludeSemantics(
          child: Icon(
            selected
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: selected ? tokens.accentText : scheme.onSurfaceVariant,
            size: tokens.iconSize,
          ),
        ),
        SizedBox(width: tokens.spacingUnit * 1.5),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            softWrap: true,
          ),
        ),
      ],
    );
  }
}
