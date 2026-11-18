import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accessibility/application/accessibility_profile_notifier.dart';
import '../../../core/accessibility/domain/accessibility_profile.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/adaptive_tokens.dart';
import '../../../core/voice/application/voice_accessibility_service.dart';
import '../../../shared/widgets/adaptive_action_button.dart';
import '../../../shared/widgets/adaptive_card.dart';
import '../../../shared/widgets/voice_guide_header.dart';

/// Screen 3: Adaptive registration / quick sign-in screen.
///
/// Adapts in real time to the active [AccessibilityProfile]:
/// * `simplifiedEssential` / `guidedStepByStep`: splits phone and code entry
///   into two focused steps with clear guidance above each field.
/// * `textScaleFactor >= 1.5`: moves field labels strictly ABOVE the input
///   boxes (`Column`) instead of inside `InputDecoration`, preventing clipping.
/// * Includes a 1-tap demo auto-fill button for rapid hackathon walkthroughs.
class AdaptiveRegistrationScreen extends ConsumerStatefulWidget {
  const AdaptiveRegistrationScreen({super.key});

  @override
  ConsumerState<AdaptiveRegistrationScreen> createState() =>
      _AdaptiveRegistrationScreenState();
}

class _AdaptiveRegistrationScreenState
    extends ConsumerState<AdaptiveRegistrationScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();

  int _step = 0; // Used when cognitiveMode is simplified / guided.
  String? _errorText;
  late final VoiceAccessibilityService _voiceService;

  static const String _demoPhone = '+7 (707) 555-01-99';
  static const String _demoCode = '4829';

  @override
  void initState() {
    super.initState();
    _voiceService = ref.read(voiceAccessibilityServiceProvider);
  }

  @override
  void dispose() {
    _voiceService.stopAll();
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _fillDemoData() {
    setState(() {
      _phoneController.text = _demoPhone;
      _codeController.text = _demoCode;
      _errorText = null;
    });
  }

  String _currentVoicePrompt(
    AppStrings strings,
    AccessibilityProfile profile,
  ) {
    if (!profile.isSimplifiedUi) return strings.registrationFullPrompt;
    return _step == 0
        ? strings.registrationPhoneStepPrompt
        : strings.registrationCodeStepPrompt;
  }

  void _advanceFromPhoneStep(AppStrings strings, AccessibilityProfile profile) {
    if (_phoneController.text.trim().isEmpty) {
      setState(() => _errorText = strings.phoneValidationError);
      return;
    }
    setState(() {
      _errorText = null;
      _step = 1;
    });
    if (profile.voiceAssistantEnabled) {
      ref.read(voiceSessionProvider.notifier).speak(
            strings.registrationCodeStepPrompt,
            context: context,
          );
    }
  }

  Future<void> _submitLogin(
    AppStrings strings,
    AccessibilityProfile profile,
  ) async {
    if (_phoneController.text.trim().isEmpty) {
      setState(() {
        _errorText = strings.phoneValidationError;
        if (profile.isSimplifiedUi) _step = 0;
      });
      return;
    }
    if (_codeController.text.trim().isEmpty) {
      setState(() => _errorText = strings.codeValidationError);
      return;
    }

    setState(() => _errorText = null);
    await ref.read(voiceSessionProvider.notifier).stopAll();
    await ref.read(accessibilityProfileProvider.notifier).completeOnboarding();
    if (!mounted) return;
    await Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.home,
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentAccessibilityProfileProvider);
    final strings = ref.watch(appStringsProvider);
    final tokens = AdaptiveTokens.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final isStepByStep = profile.isSimplifiedUi;
    final externalLabels = profile.textScaleFactor >= 1.5;

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.registrationTitle, softWrap: true),
        leading: isStepByStep && _step == 1
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: strings.backButton,
                onPressed: () => setState(() {
                  _errorText = null;
                  _step = 0;
                }),
              )
            : null,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(tokens.spacingUnit * 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              VoiceGuideHeader(
                promptText: _currentVoicePrompt(strings, profile),
              ),
              if (profile.voiceAssistantEnabled)
                SizedBox(height: tokens.spacingUnit * 2),

              if (isStepByStep) ...[
                Text(
                  strings.stepProgress(_step + 1, 2),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: tokens.accentText,
                  ),
                  softWrap: true,
                ),
                SizedBox(height: tokens.spacingUnit),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: (_step + 1) / 2,
                    minHeight: 10,
                    backgroundColor: scheme.surfaceContainerHighest,
                  ),
                ),
                SizedBox(height: tokens.spacingUnit * 2),
              ],

              Text(
                _currentVoicePrompt(strings, profile),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                softWrap: true,
              ),
              SizedBox(height: tokens.spacingUnit * 2),

              AdaptiveCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!isStepByStep || _step == 0) ...[
                      _AdaptiveLabeledField(
                        controller: _phoneController,
                        label: strings.phoneFieldLabel,
                        hint: strings.phoneFieldHint,
                        externalLabel: externalLabels,
                        keyboardType: TextInputType.phone,
                        prefixIcon: Icons.phone_android_rounded,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[\d+\s()-]'),
                          ),
                        ],
                        onChanged: (_) {
                          if (_errorText != null) {
                            setState(() => _errorText = null);
                          }
                        },
                      ),
                    ],
                    if (!isStepByStep)
                      SizedBox(height: tokens.spacingUnit * 2),
                    if (!isStepByStep || _step == 1) ...[
                      _AdaptiveLabeledField(
                        controller: _codeController,
                        label: strings.iinOrSmsFieldLabel,
                        hint: strings.iinOrSmsFieldHint,
                        externalLabel: externalLabels,
                        keyboardType: TextInputType.number,
                        prefixIcon: Icons.lock_outline_rounded,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(12),
                        ],
                        onChanged: (_) {
                          if (_errorText != null) {
                            setState(() => _errorText = null);
                          }
                        },
                      ),
                    ],

                    if (_errorText != null) ...[
                      SizedBox(height: tokens.spacingUnit * 1.5),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _errorText!,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: scheme.error,
                            fontWeight: FontWeight.w700,
                          ),
                          softWrap: true,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              SizedBox(height: tokens.spacingUnit * 2),

              // 1-click demo prefill button
              AdaptiveActionButton(
                label: strings.fillDemoDataButton,
                icon: Icons.auto_fix_high_rounded,
                variant: AdaptiveButtonVariant.outlined,
                onPressed: _fillDemoData,
              ),

              SizedBox(height: tokens.spacingUnit * 1.5),

              if (isStepByStep && _step == 0)
                AdaptiveActionButton(
                  label: strings.nextButton,
                  icon: Icons.arrow_forward_rounded,
                  onPressed: () => _advanceFromPhoneStep(strings, profile),
                )
              else
                AdaptiveActionButton(
                  label: strings.enterBankButton,
                  icon: Icons.login_rounded,
                  onPressed: () => _submitLogin(strings, profile),
                ),

              if (isStepByStep && _step == 1) ...[
                SizedBox(height: tokens.spacingUnit * 1.5),
                AdaptiveActionButton(
                  label: strings.backButton,
                  variant: AdaptiveButtonVariant.secondary,
                  onPressed: () => setState(() {
                    _errorText = null;
                    _step = 0;
                  }),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AdaptiveLabeledField extends StatelessWidget {
  const _AdaptiveLabeledField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.externalLabel,
    required this.keyboardType,
    required this.prefixIcon,
    this.inputFormatters,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final bool externalLabel;
  final TextInputType keyboardType;
  final IconData prefixIcon;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = AdaptiveTokens.of(context);
    final theme = Theme.of(context);

    final field = Semantics(
      textField: true,
      label: label,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: externalLabel ? null : label,
          hintText: hint,
          prefixIcon: ExcludeSemantics(
            child: Icon(prefixIcon, size: tokens.iconSize),
          ),
        ),
      ),
    );

    if (!externalLabel) return field;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          softWrap: true,
        ),
        SizedBox(height: tokens.spacingUnit),
        field,
      ],
    );
  }
}
