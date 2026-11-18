import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accessibility/application/accessibility_profile_notifier.dart';
import '../../../core/accessibility/domain/accessibility_profile.dart';
import '../../../core/accessibility/domain/calibration_results.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/adaptive_tokens.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/voice/application/voice_accessibility_service.dart';
import '../../../shared/widgets/adaptive_action_button.dart';
import '../../../shared/widgets/adaptive_card.dart';
import '../../../shared/widgets/voice_guide_header.dart';

enum _VisionPreset { standard, large, maxContrast }

enum _MotorFeedback { none, hit, miss }

/// Screen 2: Interactive 3-step micro-test calibration (Vision & Contrast,
/// Motor Precision, Bank Mode & Voice Assistant).
///
/// Rebuilds the entire interface in real time as the user selects options.
class CalibrationScreen extends ConsumerStatefulWidget {
  const CalibrationScreen({super.key});

  @override
  ConsumerState<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends ConsumerState<CalibrationScreen> {
  int _step = 0;

  // Step 1 state
  late _VisionPreset _selectedVision;
  late bool _card3DarkBg;

  // Step 2 state
  _MotorFeedback _motorFeedback = _MotorFeedback.none;
  int _missedTaps = 0;
  DateTime _step2ShownAt = DateTime.now();

  // Step 3 state
  bool _micDeniedNotice = false;
  late final VoiceAccessibilityService _voiceService;

  @override
  void initState() {
    super.initState();
    _voiceService = ref.read(voiceAccessibilityServiceProvider);
    final p = ref.read(currentAccessibilityProfileProvider);
    _card3DarkBg = p.contrastMode == ContrastMode.highContrastDark;
    if (p.isHighContrast || p.textScaleFactor >= 1.75) {
      _selectedVision = _VisionPreset.maxContrast;
    } else if (p.textScaleFactor >= 1.4) {
      _selectedVision = _VisionPreset.large;
    } else {
      _selectedVision = _VisionPreset.standard;
    }
  }

  @override
  void dispose() {
    _voiceService.stopAll();
    super.dispose();
  }

  String _stepVoicePrompt(AppStrings strings) => switch (_step) {
        0 => strings.calibrationVisionPrompt,
        1 => strings.calibrationMotorPrompt,
        _ => strings.calibrationCognitivePrompt,
      };

  void _speakCurrentStepIfEnabled() {
    final profile = ref.read(currentAccessibilityProfileProvider);
    if (!profile.voiceAssistantEnabled) return;
    final strings = ref.read(appStringsProvider);
    ref.read(voiceSessionProvider.notifier).speak(
          _stepVoicePrompt(strings),
          context: context,
        );
  }

  void _goToStep(int nextStep) {
    setState(() {
      _step = nextStep.clamp(0, 2);
      if (_step == 1) {
        _step2ShownAt = DateTime.now();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _speakCurrentStepIfEnabled();
    });
  }

  Future<void> _selectVisionPreset(_VisionPreset preset) async {
    setState(() => _selectedVision = preset);
    final notifier = ref.read(accessibilityProfileProvider.notifier);

    switch (preset) {
      case _VisionPreset.standard:
        await notifier.applyVisionCalibration(
          const VisionCalibrationResult(
            comfortableTextScale: 1.0,
            prefersHighContrast: false,
            prefersDarkBackground: false,
          ),
        );
      case _VisionPreset.large:
        await notifier.applyVisionCalibration(
          const VisionCalibrationResult(
            comfortableTextScale: 1.5,
            prefersHighContrast: false,
            prefersDarkBackground: false,
          ),
        );
      case _VisionPreset.maxContrast:
        await notifier.applyVisionCalibration(
          VisionCalibrationResult(
            comfortableTextScale: 2.0,
            prefersHighContrast: true,
            prefersDarkBackground: _card3DarkBg,
          ),
        );
    }
  }

  Future<void> _toggleCard3DarkBg(bool dark) async {
    setState(() => _card3DarkBg = dark);
    await _selectVisionPreset(_VisionPreset.maxContrast);
  }

  Future<void> _onMotorTargetHit() async {
    final elapsedMs = DateTime.now().difference(_step2ShownAt).inMilliseconds;
    setState(() => _motorFeedback = _MotorFeedback.hit);
    if (_missedTaps == 0) {
      await ref.read(accessibilityProfileProvider.notifier).applyMotorCalibration(
            MotorCalibrationResult(
              totalTargets: 1,
              missedTaps: 0,
              averageReactionMs: elapsedMs,
            ),
          );
    }
  }

  Future<void> _onMotorTargetMissed() async {
    _missedTaps += 1;
    setState(() => _motorFeedback = _MotorFeedback.miss);
    HapticFeedback.heavyImpact();
    await ref.read(accessibilityProfileProvider.notifier).applyMotorCalibration(
          MotorCalibrationResult(
            totalTargets: 1,
            missedTaps: _missedTaps,
            // Ensure deterministic switch to tremorProtection on miss.
            accidentalRepeatTaps: 3,
          ),
        );
  }

  Future<void> _toggleVoiceAssistant(bool enabled) async {
    final profileNotifier = ref.read(accessibilityProfileProvider.notifier);
    await profileNotifier.setVoiceAssistantEnabled(enabled);

    if (!enabled) {
      setState(() => _micDeniedNotice = false);
      await ref.read(voiceSessionProvider.notifier).stopSpeaking();
      return;
    }

    final granted = await ref
        .read(voiceAccessibilityServiceProvider)
        .requestMicrophonePermission();
    if (!mounted) return;
    setState(() => _micDeniedNotice = !granted);

    final strings = ref.read(appStringsProvider);
    await ref.read(voiceSessionProvider.notifier).speak(
          strings.voiceOptionTitle,
          context: context,
        );
  }

  Future<void> _finishCalibration() async {
    await ref.read(voiceSessionProvider.notifier).stopAll();
    await ref.read(accessibilityProfileProvider.notifier).completeOnboarding();
    if (!mounted) return;
    await Navigator.of(context).pushNamed(AppRoutes.registration);
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentAccessibilityProfileProvider);
    final strings = ref.watch(appStringsProvider);
    final tokens = AdaptiveTokens.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.calibrationTitle, softWrap: true),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: strings.backButton,
          onPressed: () {
            if (_step > 0) {
              _goToStep(_step - 1);
            } else {
              Navigator.of(context).maybePop();
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(tokens.spacingUnit * 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Always visible on calibration so user can switch language or
              // replay spoken prompts at any time.
              VoiceGuideHeader(
                promptText: _stepVoicePrompt(strings),
                alwaysShow: true,
              ),
              SizedBox(height: tokens.spacingUnit * 2),

              // Step progress
              Row(
                children: [
                  Expanded(
                    child: Text(
                      strings.stepProgress(_step + 1, 3),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: tokens.accentText,
                      ),
                      softWrap: true,
                    ),
                  ),
                ],
              ),
              SizedBox(height: tokens.spacingUnit),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: (_step + 1) / 3,
                  minHeight: 10,
                  backgroundColor: scheme.surfaceContainerHighest,
                ),
              ),
              SizedBox(height: tokens.spacingUnit * 2.5),

              // Step body
              if (_step == 0) _buildVisionStep(context, strings, tokens, profile),
              if (_step == 1) _buildMotorStep(context, strings, tokens, profile),
              if (_step == 2)
                _buildCognitiveAndVoiceStep(context, strings, tokens, profile),

              SizedBox(height: tokens.spacingUnit * 3),

              // Step navigation actions
              _buildFooterButtons(strings, tokens),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 1: Vision & Contrast
  // ---------------------------------------------------------------------------
  Widget _buildVisionStep(
    BuildContext context,
    AppStrings strings,
    AdaptiveTokens tokens,
    AccessibilityProfile profile,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          strings.calibrationVisionTitle,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
          softWrap: true,
        ),
        SizedBox(height: tokens.spacingUnit),
        Text(
          strings.calibrationVisionPrompt,
          style: theme.textTheme.bodyLarge,
          softWrap: true,
        ),
        SizedBox(height: tokens.spacingUnit * 2),

        // Option 1: Standard (1.0x)
        _VisionPreviewCard(
          title: strings.visionCardStandardTitle,
          description: strings.visionCardStandardDesc,
          balanceLabel: strings.calibrationSampleBalanceLabel,
          previewScale: 1.0,
          previewPalette: AppPalette.standardBcc,
          selected: _selectedVision == _VisionPreset.standard,
          onTap: () => _selectVisionPreset(_VisionPreset.standard),
        ),
        SizedBox(height: tokens.spacingUnit * 1.5),

        // Option 2: Large text (1.5x, crisp outline)
        _VisionPreviewCard(
          title: strings.visionCardLargeTitle,
          description: strings.visionCardLargeDesc,
          balanceLabel: strings.calibrationSampleBalanceLabel,
          previewScale: 1.5,
          previewPalette: AppPalette.standardBcc,
          forceCrispOutline: true,
          selected: _selectedVision == _VisionPreset.large,
          onTap: () => _selectVisionPreset(_VisionPreset.large),
        ),
        SizedBox(height: tokens.spacingUnit * 1.5),

        // Option 3: Max scale (1.85x preview / 2.0x engine) + HC Dark/Light
        _VisionPreviewCard(
          title: strings.visionCardMaxTitle,
          description: strings.visionCardMaxDesc,
          balanceLabel: strings.calibrationSampleBalanceLabel,
          previewScale: 1.85,
          previewPalette: _card3DarkBg
              ? AppPalette.highContrastDark
              : AppPalette.highContrastLight,
          forceCrispOutline: true,
          selected: _selectedVision == _VisionPreset.maxContrast,
          onTap: () => _selectVisionPreset(_VisionPreset.maxContrast),
          footer: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: tokens.spacingUnit * 1.5),
              Text(
                strings.contrastBackgroundLabel,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: _card3DarkBg
                      ? AppPalette.highContrastDark.onSurface
                      : AppPalette.highContrastLight.onSurface,
                ),
                softWrap: true,
              ),
              SizedBox(height: tokens.spacingUnit),
              Wrap(
                spacing: tokens.spacingUnit,
                runSpacing: tokens.spacingUnit,
                children: [
                  _ContrastBgChip(
                    label: strings.whiteBackgroundOption,
                    selected: !_card3DarkBg,
                    chipBg: Colors.white,
                    chipFg: Colors.black,
                    onTap: () => _toggleCard3DarkBg(false),
                  ),
                  _ContrastBgChip(
                    label: strings.blackBackgroundOption,
                    selected: _card3DarkBg,
                    chipBg: const Color(0xFF0A0A0A),
                    chipFg: Colors.white,
                    onTap: () => _toggleCard3DarkBg(true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Step 2: Motor Precision
  // ---------------------------------------------------------------------------
  Widget _buildMotorStep(
    BuildContext context,
    AppStrings strings,
    AdaptiveTokens tokens,
    AccessibilityProfile profile,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isTremor =
        profile.motorLevel == MotorAssistanceLevel.tremorProtection;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          strings.calibrationMotorTitle,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
          softWrap: true,
        ),
        SizedBox(height: tokens.spacingUnit),
        Text(
          strings.calibrationMotorPrompt,
          style: theme.textTheme.bodyLarge,
          softWrap: true,
        ),
        SizedBox(height: tokens.spacingUnit * 2),

        // Interactive target pad: tapping outside the button triggers miss.
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _onMotorTargetMissed,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spacingUnit * 3,
              vertical: tokens.spacingUnit * 4,
            ),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(tokens.cornerRadius),
              border: Border.all(
                color: _motorFeedback == _MotorFeedback.miss
                    ? scheme.error
                    : scheme.outline,
                width: profile.isHighContrast ? tokens.borderWidth : 1.5,
              ),
            ),
            child: Center(
              child: AdaptiveActionButton(
                label: strings.motorTargetButton,
                icon: Icons.touch_app_rounded,
                expandWidth: false,
                applyTremorSpacing: false,
                onPressed: _onMotorTargetHit,
              ),
            ),
          ),
        ),

        if (_motorFeedback != _MotorFeedback.none) ...[
          SizedBox(height: tokens.spacingUnit * 1.5),
          Semantics(
            liveRegion: true,
            child: AdaptiveCard(
              borderColor: _motorFeedback == _MotorFeedback.miss
                  ? tokens.warning
                  : tokens.success,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      _motorFeedback == _MotorFeedback.miss
                          ? Icons.shield_rounded
                          : Icons.check_circle_rounded,
                      color: _motorFeedback == _MotorFeedback.miss
                          ? tokens.warning
                          : tokens.success,
                      size: tokens.iconSize,
                    ),
                  ),
                  SizedBox(width: tokens.spacingUnit * 1.5),
                  Expanded(
                    child: Text(
                      _motorFeedback == _MotorFeedback.miss
                          ? strings.motorMissFeedback
                          : strings.motorHitFeedback,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      softWrap: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        SizedBox(height: tokens.spacingUnit * 2),

        // Honest 2-choice selector
        AdaptiveCard(
          selected: !isTremor,
          semanticLabel: strings.motorChoiceStandard,
          onTap: () {
            setState(() => _motorFeedback = _MotorFeedback.none);
            ref
                .read(accessibilityProfileProvider.notifier)
                .setMotorLevel(MotorAssistanceLevel.standard);
          },
          child: _ChoiceRow(
            selected: !isTremor,
            title: strings.motorChoiceStandard,
          ),
        ),
        SizedBox(height: tokens.spacingUnit * 1.5),
        AdaptiveCard(
          selected: isTremor,
          semanticLabel: strings.motorChoiceTremor,
          onTap: () {
            ref
                .read(accessibilityProfileProvider.notifier)
                .setMotorLevel(MotorAssistanceLevel.tremorProtection);
          },
          child: _ChoiceRow(
            selected: isTremor,
            title: strings.motorChoiceTremor,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Step 3: Cognitive Mode & Voice Assistant
  // ---------------------------------------------------------------------------
  Widget _buildCognitiveAndVoiceStep(
    BuildContext context,
    AppStrings strings,
    AdaptiveTokens tokens,
    AccessibilityProfile profile,
  ) {
    final theme = Theme.of(context);
    final isSimplified =
        profile.cognitiveMode == CognitiveMode.simplifiedEssential ||
            profile.cognitiveMode == CognitiveMode.guidedStepByStep;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          strings.calibrationCognitiveTitle,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
          softWrap: true,
        ),
        SizedBox(height: tokens.spacingUnit),
        Text(
          strings.calibrationCognitivePrompt,
          style: theme.textTheme.bodyLarge,
          softWrap: true,
        ),
        SizedBox(height: tokens.spacingUnit * 2),

        // Card Group 1: Bank screen mode
        AdaptiveCard(
          selected: isSimplified,
          semanticLabel:
              '${strings.cognitiveOptionSimplifiedTitle}. ${strings.cognitiveOptionSimplifiedDesc}',
          onTap: () => ref
              .read(accessibilityProfileProvider.notifier)
              .setCognitiveMode(CognitiveMode.simplifiedEssential),
          child: _ChoiceRow(
            selected: isSimplified,
            title: strings.cognitiveOptionSimplifiedTitle,
            subtitle: strings.cognitiveOptionSimplifiedDesc,
          ),
        ),
        SizedBox(height: tokens.spacingUnit * 1.5),
        AdaptiveCard(
          selected: !isSimplified,
          semanticLabel:
              '${strings.cognitiveOptionFullTitle}. ${strings.cognitiveOptionFullDesc}',
          onTap: () => ref
              .read(accessibilityProfileProvider.notifier)
              .setCognitiveMode(CognitiveMode.fullBanking),
          child: _ChoiceRow(
            selected: !isSimplified,
            title: strings.cognitiveOptionFullTitle,
            subtitle: strings.cognitiveOptionFullDesc,
          ),
        ),

        SizedBox(height: tokens.spacingUnit * 2.5),

        // Card 2: Voice assistant toggle + microphone permission
        AdaptiveCard(
          selected: profile.voiceAssistantEnabled,
          semanticLabel:
              '${strings.voiceOptionTitle}. ${strings.voiceOptionDesc}',
          onTap: () => _toggleVoiceAssistant(!profile.voiceAssistantEnabled),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ExcludeSemantics(
                child: Icon(
                  Icons.record_voice_over_rounded,
                  size: tokens.iconSize * 1.2,
                  color: profile.voiceAssistantEnabled
                      ? tokens.accentText
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(width: tokens.spacingUnit * 1.5),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.voiceOptionTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      softWrap: true,
                    ),
                    SizedBox(height: tokens.spacingUnit * 0.5),
                    Text(
                      strings.voiceOptionDesc,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      softWrap: true,
                    ),
                  ],
                ),
              ),
              SizedBox(width: tokens.spacingUnit),
              Switch(
                value: profile.voiceAssistantEnabled,
                onChanged: _toggleVoiceAssistant,
              ),
            ],
          ),
        ),

        if (_micDeniedNotice) ...[
          SizedBox(height: tokens.spacingUnit * 1.5),
          AdaptiveCard(
            borderColor: tokens.warning,
            child: Text(
              strings.micPermissionDeniedNotice,
              style: theme.textTheme.bodyMedium,
              softWrap: true,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFooterButtons(AppStrings strings, AdaptiveTokens tokens) {
    if (_step == 0) {
      return AdaptiveActionButton(
        label: strings.nextButton,
        icon: Icons.arrow_forward_rounded,
        onPressed: () => _goToStep(1),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdaptiveActionButton(
          label: _step == 2 ? strings.finishCalibrationButton : strings.nextButton,
          icon: _step == 2
              ? Icons.check_circle_outline_rounded
              : Icons.arrow_forward_rounded,
          onPressed: _step == 2 ? _finishCalibration : () => _goToStep(2),
        ),
        SizedBox(height: tokens.spacingUnit * 1.5),
        AdaptiveActionButton(
          label: strings.backButton,
          variant: AdaptiveButtonVariant.outlined,
          onPressed: () => _goToStep(_step - 1),
        ),
      ],
    );
  }
}

class _VisionPreviewCard extends ConsumerWidget {
  const _VisionPreviewCard({
    required this.title,
    required this.description,
    required this.balanceLabel,
    required this.previewScale,
    required this.previewPalette,
    required this.selected,
    required this.onTap,
    this.forceCrispOutline = false,
    this.footer,
  });

  final String title;
  final String description;
  final String balanceLabel;
  final double previewScale;
  final AppPalette previewPalette;
  final bool selected;
  final VoidCallback onTap;
  final bool forceCrispOutline;
  final Widget? footer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentAccessibilityProfileProvider);
    final tokens = AdaptiveTokens.of(context);
    final borderRadius = BorderRadius.circular(tokens.cornerRadius);
    final borderWidth = selected ? 3.5 : (forceCrispOutline ? 2.0 : 1.0);
    final borderColor = selected
        ? (previewPalette.brightness == Brightness.dark
            ? previewPalette.emphasis
            : previewPalette.primary)
        : previewPalette.border;

    return Semantics(
      button: true,
      selected: selected,
      label: '$title. $balanceLabel 50 000 ₸. $description',
      child: Material(
        color: previewPalette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius,
          side: BorderSide(color: borderColor, width: borderWidth),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            if (tokens.hapticFeedback) {
              HapticFeedback.selectionClick();
            }
            onTap();
          },
          child: Container(
            constraints: BoxConstraints(minHeight: profile.minTouchTarget),
            padding: EdgeInsets.all(tokens.spacingUnit * 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 16 * previewScale.clamp(1.0, 1.5),
                          fontWeight: FontWeight.w700,
                          color: previewPalette.onSurface,
                        ),
                        softWrap: true,
                      ),
                    ),
                    SizedBox(width: tokens.spacingUnit),
                    ExcludeSemantics(
                      child: Icon(
                        selected
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: selected
                            ? previewPalette.accentText
                            : previewPalette.onSurfaceMuted,
                        size: 28,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: tokens.spacingUnit),
                Text(
                  balanceLabel,
                  style: TextStyle(
                    fontSize: 13 * previewScale.clamp(1.0, 1.4),
                    color: previewPalette.onSurfaceMuted,
                    fontWeight: FontWeight.w600,
                  ),
                  softWrap: true,
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '50 000 ₸',
                    style: TextStyle(
                      fontSize: 22 * previewScale,
                      fontWeight: FontWeight.w800,
                      color: previewPalette.accentText,
                    ),
                  ),
                ),
                SizedBox(height: tokens.spacingUnit * 0.75),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13 * previewScale.clamp(1.0, 1.3),
                    color: previewPalette.onSurfaceMuted,
                  ),
                  softWrap: true,
                ),
                ?footer,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ContrastBgChip extends StatelessWidget {
  const _ContrastBgChip({
    required this.label,
    required this.selected,
    required this.chipBg,
    required this.chipFg,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color chipBg;
  final Color chipFg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: ExcludeSemantics(
          child: Icon(
            selected ? Icons.check_rounded : Icons.circle_outlined,
            color: chipFg,
            size: 20,
          ),
        ),
        label: Text(
          label,
          style: TextStyle(color: chipFg, fontWeight: FontWeight.w700),
          softWrap: true,
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: chipBg,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          side: BorderSide(
            color: selected ? const Color(0xFF00A859) : chipFg,
            width: selected ? 3 : 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

class _ChoiceRow extends ConsumerWidget {
  const _ChoiceRow({
    required this.selected,
    required this.title,
    this.subtitle,
  });

  final bool selected;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = AdaptiveTokens.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                softWrap: true,
              ),
              if (subtitle != null) ...[
                SizedBox(height: tokens.spacingUnit * 0.5),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  softWrap: true,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
