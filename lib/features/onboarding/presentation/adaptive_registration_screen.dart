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
import '../../../shared/widgets/adaptive_text_field.dart';
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
  final _phoneFocusNode = FocusNode();
  final _codeFocusNode = FocusNode();
  final _scrollController = ScrollController();

  int _step = 0; // Used when cognitiveMode is simplified / guided.
  String? _phoneError;
  String? _codeError;
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
    _phoneFocusNode.dispose();
    _codeFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _fillDemoData() {
    setState(() {
      _phoneController.text = _demoPhone;
      _codeController.text = _demoCode;
      _phoneError = null;
      _codeError = null;
    });
  }

  String _currentVoicePrompt(AppStrings strings, AccessibilityProfile profile) {
    if (!profile.isSimplifiedUi) return strings.registrationFullPrompt;
    return _step == 0
        ? strings.registrationPhoneStepPrompt
        : strings.registrationCodeStepPrompt;
  }

  String? _validatePhone(AppStrings strings) {
    final trimmed = _phoneController.text.trim();
    if (trimmed.isEmpty) return strings.phoneValidationError;
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) return strings.phoneIncompleteError;
    return null;
  }

  void _announceValidationError(
    String message,
    FocusNode targetFocus,
    AccessibilityProfile profile,
  ) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) targetFocus.requestFocus();
    });
    if (profile.voiceAssistantEnabled) {
      ref.read(voiceSessionProvider.notifier).speak(message, context: context);
    }
  }

  void _advanceFromPhoneStep(AppStrings strings, AccessibilityProfile profile) {
    final phoneErr = _validatePhone(strings);
    if (phoneErr != null) {
      setState(() => _phoneError = phoneErr);
      _announceValidationError(phoneErr, _phoneFocusNode, profile);
      return;
    }
    _goToStep(1, focusCode: true);
    if (profile.voiceAssistantEnabled) {
      ref
          .read(voiceSessionProvider.notifier)
          .speak(strings.registrationCodeStepPrompt, context: context);
    }
  }

  void _goToStep(
    int step, {
    bool focusPhone = false,
    bool focusCode = false,
  }) {
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    setState(() {
      _phoneError = null;
      _codeError = null;
      _step = step;
    });
    if (focusPhone || focusCode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (focusPhone) _phoneFocusNode.requestFocus();
        if (focusCode) _codeFocusNode.requestFocus();
      });
    }
  }

  Future<void> _submitLogin(
    AppStrings strings,
    AccessibilityProfile profile,
  ) async {
    final phoneErr = _validatePhone(strings);
    if (phoneErr != null) {
      setState(() {
        _phoneError = phoneErr;
        _codeError = null;
        if (profile.isSimplifiedUi) _step = 0;
      });
      _announceValidationError(phoneErr, _phoneFocusNode, profile);
      return;
    }
    if (_codeController.text.trim().isEmpty) {
      setState(() {
        _phoneError = null;
        _codeError = strings.codeValidationError;
      });
      _announceValidationError(
        strings.codeValidationError,
        _codeFocusNode,
        profile,
      );
      return;
    }

    setState(() {
      _phoneError = null;
      _codeError = null;
    });
    await ref.read(voiceSessionProvider.notifier).stopAll();
    await ref.read(accessibilityProfileProvider.notifier).completeOnboarding();
    if (!mounted) return;
    await Navigator.of(context)
        .pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
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

    return PopScope(
      canPop: !(isStepByStep && _step == 1),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && isStepByStep && _step == 1) {
          _goToStep(0, focusPhone: true);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(strings.registrationTitle, softWrap: true),
          leading: isStepByStep && _step == 1
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  tooltip: strings.backButton,
                  onPressed: () => _goToStep(0, focusPhone: true),
                )
              : null,
        ),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isStepByStep)
                Container(
                  padding: EdgeInsets.fromLTRB(
                    tokens.spacingUnit * 2,
                    tokens.spacingUnit * 1.25,
                    tokens.spacingUnit * 2,
                    tokens.spacingUnit * 1.25,
                  ),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        strings.stepProgress(_step + 1, 2),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: tokens.accentText,
                        ),
                        softWrap: true,
                      ),
                      SizedBox(height: tokens.spacingUnit * 0.75),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: (_step + 1) / 2,
                          minHeight: 10,
                          backgroundColor: scheme.surfaceContainerHighest,
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: EdgeInsets.all(tokens.spacingUnit * 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      VoiceGuideHeader(
                        promptText: _currentVoicePrompt(strings, profile),
                      ),
                      if (profile.voiceAssistantEnabled)
                        SizedBox(height: tokens.spacingUnit * 1.5),

                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: tokens.spacingUnit * 1.5,
                            vertical: tokens.spacingUnit * 0.75,
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
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ExcludeSemantics(
                                child: Icon(
                                  Icons.info_outline_rounded,
                                  size: tokens.iconSize * 0.85,
                                  color: tokens.accentText,
                                ),
                              ),
                              SizedBox(width: tokens.spacingUnit * 0.75),
                              Flexible(
                                child: Text(
                                  strings.demoLoginBadge,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                  softWrap: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: tokens.spacingUnit * 1.5),

                      if (!isStepByStep || !externalLabels) ...[
                        Text(
                          _currentVoicePrompt(strings, profile),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                          softWrap: true,
                        ),
                        SizedBox(height: tokens.spacingUnit * 2),
                      ],

                      if (isStepByStep &&
                          _step == 1 &&
                          _phoneController.text.trim().isNotEmpty) ...[
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: tokens.spacingUnit * 1.5,
                            vertical: tokens.spacingUnit,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: profile.isHighContrast
                                  ? scheme.outline
                                  : scheme.outlineVariant,
                            ),
                          ),
                          child: Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: tokens.spacingUnit,
                            runSpacing: tokens.spacingUnit * 0.5,
                            children: [
                              Text(
                                '${strings.phoneFieldLabel}: ${_phoneController.text.trim()}',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                                softWrap: true,
                              ),
                              TextButton.icon(
                                onPressed: () => _goToStep(0, focusPhone: true),
                                icon: const Icon(Icons.edit_rounded),
                                label: Text(strings.editButton),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: tokens.spacingUnit * 1.5),
                      ],

                      AdaptiveCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (!isStepByStep || _step == 0) ...[
                              AdaptiveTextField(
                                controller: _phoneController,
                                focusNode: _phoneFocusNode,
                                label: strings.phoneFieldLabel,
                                hint: strings.phoneFieldHint,
                                errorText: _phoneError,
                                externalLabel: externalLabels,
                                keyboardType: TextInputType.phone,
                                prefixIcon: Icons.phone_android_rounded,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[\d+\s()-]'),
                                  ),
                                ],
                                onChanged: (_) {
                                  if (_phoneError != null) {
                                    setState(() => _phoneError = null);
                                  }
                                },
                              ),
                            ],
                            if (!isStepByStep)
                              SizedBox(height: tokens.spacingUnit * 2),
                            if (!isStepByStep || _step == 1) ...[
                              AdaptiveTextField(
                                controller: _codeController,
                                focusNode: _codeFocusNode,
                                label: strings.iinOrSmsFieldLabel,
                                hint: strings.iinOrSmsFieldHint,
                                errorText: _codeError,
                                externalLabel: externalLabels,
                                keyboardType: TextInputType.number,
                                prefixIcon: Icons.lock_outline_rounded,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(12),
                                ],
                                onChanged: (_) {
                                  if (_codeError != null) {
                                    setState(() => _codeError = null);
                                  }
                                },
                              ),
                            ],
                          ],
                        ),
                      ),

                      SizedBox(height: tokens.spacingUnit * 2),

                      if (isStepByStep && _step == 0)
                        AdaptiveActionButton(
                          key: const ValueKey('registration_next'),
                          label: strings.nextButton,
                          icon: Icons.arrow_forward_rounded,
                          onPressed: () =>
                              _advanceFromPhoneStep(strings, profile),
                        )
                      else
                        AdaptiveActionButton(
                          key: const ValueKey('registration_submit'),
                          label: strings.enterBankButton,
                          icon: Icons.login_rounded,
                          onPressed: () => _submitLogin(strings, profile),
                        ),

                      SizedBox(height: tokens.spacingUnit * 1.5),
                      AdaptiveActionButton(
                        label: strings.fillDemoDataButton,
                        variant: AdaptiveButtonVariant.outlined,
                        onPressed: _fillDemoData,
                      ),

                      if (isStepByStep && _step == 1) ...[
                        SizedBox(height: tokens.spacingUnit * 1.5),
                        AdaptiveActionButton(
                          label: strings.backButton,
                          variant: AdaptiveButtonVariant.secondary,
                          onPressed: () => _goToStep(0, focusPhone: true),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
