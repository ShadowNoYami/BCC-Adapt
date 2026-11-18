import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accessibility/application/accessibility_profile_notifier.dart';
import '../../../core/accessibility/domain/accessibility_profile.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/l10n/money_formatter.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/adaptive_tokens.dart';
import '../../../core/voice/application/voice_accessibility_service.dart';
import '../../../core/voice/domain/amount_in_words.dart';
import '../../../core/voice/domain/voice_transfer_parser.dart';
import '../../../shared/widgets/adaptive_action_button.dart';
import '../../../shared/widgets/adaptive_card.dart';
import '../../../shared/widgets/voice_guide_header.dart';
import '../data/mock_bank_repository.dart';
import '../domain/bank_models.dart';

/// Screen 5: Step-by-step transfer screen with 4 safety layers:
/// 1. Safe Voice Intent Filler (Push-to-Talk -> draft only, never auto-sends)
/// 2. Trusted contact chips + arbitrary phone entry + quick amount pills
/// 3. Live amount-in-words readout (`Сто тысяч тенге`) to catch extra zeroes
/// 4. Anti-fraud 5-second cooling-off timer for unknown recipients + 1.5 s
///    hold-to-confirm when `tremorProtection` is active.
class TransferScreen extends ConsumerStatefulWidget {
  const TransferScreen({
    super.key,
    this.initialContact,
    this.coolingOffTickDuration = const Duration(seconds: 1),
  });

  final QuickContact? initialContact;

  /// Tick interval for the 5-second cooling-off countdown (overridable in tests).
  final Duration coolingOffTickDuration;

  @override
  ConsumerState<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends ConsumerState<TransferScreen> {
  final _phoneController = TextEditingController();
  final _amountController = TextEditingController();

  QuickContact? _selectedContact;
  String? _formError;
  String? _voiceBannerMessage;

  // Anti-fraud 5-second cooling-off state
  Timer? _coolingTimer;
  int _coolingSecondsRemaining = 0;
  String _lastCoolingKey = '';

  // Receipt state after transfer execution
  _TransferReceipt? _receipt;
  late final VoiceAccessibilityService _voiceService;

  @override
  void initState() {
    super.initState();
    _voiceService = ref.read(voiceAccessibilityServiceProvider);
    _selectedContact = widget.initialContact;
    if (_selectedContact?.defaultAmountTenge != null) {
      _amountController.text =
          _selectedContact!.defaultAmountTenge!.round().toString();
    }
  }

  @override
  void dispose() {
    _coolingTimer?.cancel();
    _coolingTimer = null;
    _voiceService.stopAll();
    _phoneController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  double get _parsedAmount {
    final cleaned = _amountController.text
        .replaceAll(RegExp(r'[\s\u00A0]'), '')
        .replaceAll(',', '.');
    return double.tryParse(cleaned) ?? 0;
  }

  bool _isStrangerRecipient(MockBankRepository bankRepo) {
    if (_selectedContact != null) return false;
    final phoneText = _phoneController.text.trim();
    if (phoneText.isEmpty) return false;
    return bankRepo.findContact(phoneText) == null;
  }

  bool _requiresAntiFraudCooling(
    AccessibilityProfile profile,
    MockBankRepository bankRepo,
  ) {
    if (!_isStrangerRecipient(bankRepo)) return false;
    return profile.isSimplifiedUi || _parsedAmount >= 50000;
  }

  void _reevaluateAntiFraud() {
    final profile = ref.read(currentAccessibilityProfileProvider);
    final bankRepo = ref.read(mockBankRepositoryProvider.notifier);
    final active = _requiresAntiFraudCooling(profile, bankRepo);

    if (!active) {
      _coolingTimer?.cancel();
      _coolingTimer = null;
      _lastCoolingKey = '';
      _coolingSecondsRemaining = 0;
      return;
    }

    final coolingKey =
        '${_phoneController.text.trim()}|${_parsedAmount >= 50000}|${profile.cognitiveMode.name}';
    if (_lastCoolingKey == coolingKey) return;
    _lastCoolingKey = coolingKey;

    _coolingTimer?.cancel();
    _coolingSecondsRemaining = 5;
    _coolingTimer = Timer.periodic(widget.coolingOffTickDuration, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_coolingSecondsRemaining <= 1) {
        timer.cancel();
        setState(() => _coolingSecondsRemaining = 0);
      } else {
        setState(() => _coolingSecondsRemaining -= 1);
      }
    });
  }

  void _selectQuickContact(QuickContact contact) {
    setState(() {
      _selectedContact = contact;
      _phoneController.clear();
      _formError = null;
      if (_amountController.text.trim().isEmpty &&
          contact.defaultAmountTenge != null) {
        _amountController.text = contact.defaultAmountTenge!.round().toString();
      }
      _reevaluateAntiFraud();
    });
  }

  void _addAmount(int delta) {
    final next = _parsedAmount + delta;
    setState(() {
      _amountController.text = next.round().toString();
      _formError = null;
      _reevaluateAntiFraud();
    });
  }

  void _applyVoiceIntent(VoiceTransferIntent intent) {
    final profile = ref.read(currentAccessibilityProfileProvider);
    final strings = ref.read(appStringsProvider);
    final bankRepo = ref.read(mockBankRepositoryProvider.notifier);

    String recipientDisplay = '';
    setState(() {
      _formError = null;
      if (intent.amount != null && intent.amount! > 0) {
        _amountController.text = intent.amount! % 1 == 0
            ? intent.amount!.round().toString()
            : intent.amount!.toStringAsFixed(2);
      }

      final matched = bankRepo.findContact(
        intent.normalizedPhone ?? intent.recipientQuery,
      );
      if (matched != null) {
        _selectedContact = matched;
        _phoneController.clear();
        recipientDisplay = matched.localizedTitle(profile.localeCode);
      } else if (intent.recipientQuery != null &&
          intent.recipientQuery!.trim().isNotEmpty) {
        _selectedContact = null;
        _phoneController.text = intent.recipientQuery!.trim();
        recipientDisplay = intent.recipientQuery!.trim();
      }

      if (intent.amountInWords != null && recipientDisplay.isNotEmpty) {
        _voiceBannerMessage = strings.voiceDraftReadyTemplate(
          intent.amountInWords!,
          recipientDisplay,
        );
      }
      _reevaluateAntiFraud();
    });

    if (intent.amountInWords != null && recipientDisplay.isNotEmpty) {
      ref.read(voiceSessionProvider.notifier).speak(
            strings.voiceDraftReadyTemplate(
              intent.amountInWords!,
              recipientDisplay,
            ),
            context: context,
          );
    }
  }

  Future<void> _onMicButtonPressed() async {
    final session = ref.read(voiceSessionProvider);
    final notifier = ref.read(voiceSessionProvider.notifier);
    if (session.isListening) {
      await notifier.stopPushToTalk();
      return;
    }
    await notifier.startPushToTalk();
  }

  Future<void> _executeTransfer() async {
    final profile = ref.read(currentAccessibilityProfileProvider);
    final strings = ref.read(appStringsProvider);
    final bankState = ref.read(mockBankRepositoryProvider);
    final bankNotifier = ref.read(mockBankRepositoryProvider.notifier);

    final amount = _parsedAmount;
    if (amount <= 0) {
      setState(() => _formError = strings.invalidAmountError);
      return;
    }
    if (amount > bankState.primaryAccount.balanceTenge) {
      setState(() => _formError = strings.insufficientFundsError);
      return;
    }

    final QuickContact? contact = _selectedContact ??
        bankNotifier.findContact(_phoneController.text.trim());
    final rawPhone = _phoneController.text.trim();
    if (contact == null && rawPhone.isEmpty) {
      setState(() => _formError = strings.invalidRecipientError);
      return;
    }

    final titleRu = contact?.titleRu ?? rawPhone;
    final titleKk = contact?.titleKk ?? rawPhone;
    final ok = bankNotifier.executeTransfer(
      amountTenge: amount,
      recipientTitleRu: titleRu,
      recipientTitleKk: titleKk,
      details: contact != null
          ? '${contact.phoneOrAccount} • #bcc карта'
          : '$rawPhone • #bcc карта',
    );
    if (!ok) {
      setState(() => _formError = strings.insufficientFundsError);
      return;
    }

    final updatedBalance =
        ref.read(mockBankRepositoryProvider).primaryAccount.balanceTenge;
    final recipientDisplay = contact?.localizedTitle(profile.localeCode) ?? rawPhone;

    setState(() {
      _formError = null;
      _receipt = _TransferReceipt(
        amountTenge: amount,
        recipientName: recipientDisplay,
        newBalanceTenge: updatedBalance,
      );
    });

    await ref.read(voiceSessionProvider.notifier).speak(
          strings.transferSuccessTitle,
          context: context,
        );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentAccessibilityProfileProvider);
    final strings = ref.watch(appStringsProvider);
    final bankState = ref.watch(mockBankRepositoryProvider);
    final bankNotifier = ref.read(mockBankRepositoryProvider.notifier);
    final voiceSession = ref.watch(voiceSessionProvider);
    final tokens = AdaptiveTokens.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    ref.listen<VoiceSessionState>(voiceSessionProvider, (prev, next) {
      if (next.parsedIntent != null &&
          next.isFinalResult &&
          next.parsedIntent != prev?.parsedIntent) {
        _applyVoiceIntent(next.parsedIntent!);
      }
    });

    if (_receipt != null) {
      return _TransferSuccessView(
        receipt: _receipt!,
        profile: profile,
        strings: strings,
        onDone: () {
          ref.read(voiceSessionProvider.notifier).resetSession();
          Navigator.of(context).pushNamedAndRemoveUntil(
            AppRoutes.home,
            (_) => false,
          );
        },
      );
    }

    final showAntiFraud = _requiresAntiFraudCooling(profile, bankNotifier);
    final amount = _parsedAmount;
    final amountWords = amount > 0
        ? AmountInWords.format(amount, localeCode: profile.localeCode)
        : null;
    final externalLabels = profile.textScaleFactor >= 1.5;

    final micUnavailable =
        voiceSession.status == VoiceListeningStatus.permissionDenied ||
            voiceSession.status == VoiceListeningStatus.unavailable ||
            voiceSession.status == VoiceListeningStatus.error;

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.transferScreenTitle, softWrap: true),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(tokens.spacingUnit * 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              VoiceGuideHeader(
                promptText: strings.voiceExamplePrompt,
              ),
              if (profile.voiceAssistantEnabled)
                SizedBox(height: tokens.spacingUnit * 2),

              // 1. Safe Voice Intent Filler (Push-to-Talk)
              AdaptiveCard(
                backgroundColor: voiceSession.isListening
                    ? scheme.primaryContainer
                    : null,
                borderColor: voiceSession.isListening ? scheme.primary : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AdaptiveActionButton(
                      label: voiceSession.isListening
                          ? strings.voiceListeningNow
                          : strings.voiceFillTransferButton,
                      subtitle: voiceSession.isListening
                          ? null
                          : strings.voiceExamplePrompt,
                      icon: voiceSession.isListening
                          ? Icons.stop_rounded
                          : Icons.mic_rounded,
                      onPressed: _onMicButtonPressed,
                    ),
                    if (micUnavailable) ...[
                      SizedBox(height: tokens.spacingUnit * 1.25),
                      Text(
                        strings.micUnavailableDemoHint,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: tokens.warning,
                          fontWeight: FontWeight.w600,
                        ),
                        softWrap: true,
                      ),
                    ],
                    if (_voiceBannerMessage != null) ...[
                      SizedBox(height: tokens.spacingUnit * 1.25),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _voiceBannerMessage!,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: tokens.accentText,
                            fontWeight: FontWeight.w700,
                          ),
                          softWrap: true,
                        ),
                      ),
                    ],
                    SizedBox(height: tokens.spacingUnit * 1.5),
                    Text(
                      strings.voiceDemoSamplesLabel,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                      softWrap: true,
                    ),
                    SizedBox(height: tokens.spacingUnit),
                    Wrap(
                      spacing: tokens.spacingUnit,
                      runSpacing: tokens.spacingUnit,
                      children: [
                        _DemoVoiceChip(
                          label: strings.voiceDemoSampleArman,
                          onTap: () => ref
                              .read(voiceSessionProvider.notifier)
                              .simulateVoiceInput(
                                profile.localeCode == 'kk'
                                    ? 'Арманға 5000 теңге аудар'
                                    : 'Перевести 5000 тенге Арману',
                              ),
                        ),
                        _DemoVoiceChip(
                          label: strings.voiceDemoSampleStranger,
                          onTap: () => ref
                              .read(voiceSessionProvider.notifier)
                              .simulateVoiceInput(
                                profile.localeCode == 'kk'
                                    ? '8 777 999 88 77 нөміріне 60000 теңге жібер'
                                    : 'Перевести 60000 тенге на 8 777 999 88 77',
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: tokens.spacingUnit * 2),

              // 2. Trusted Contacts + Phone Input
              Text(
                strings.trustedContactsLabel,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                softWrap: true,
              ),
              SizedBox(height: tokens.spacingUnit),
              ...bankState.quickContacts.map((contact) {
                final selected = _selectedContact?.id == contact.id;
                final contactTitle = contact.localizedTitle(profile.localeCode);
                return Padding(
                  padding: EdgeInsets.only(bottom: tokens.spacingUnit),
                  child: AdaptiveCard(
                    selected: selected,
                    semanticLabel: '$contactTitle, ${contact.phoneOrAccount}',
                    onTap: () => _selectQuickContact(contact),
                    child: Row(
                      children: [
                        ExcludeSemantics(
                          child: Icon(
                            selected
                                ? Icons.check_circle_rounded
                                : (contact.category ==
                                        QuickContactCategory.utilities
                                    ? Icons.receipt_long_rounded
                                    : Icons.person_rounded),
                            color: selected
                                ? tokens.accentText
                                : scheme.onSurfaceVariant,
                            size: tokens.iconSize,
                          ),
                        ),
                        SizedBox(width: tokens.spacingUnit * 1.5),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                contactTitle,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                                softWrap: true,
                              ),
                              Text(
                                contact.phoneOrAccount,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                                softWrap: true,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              SizedBox(height: tokens.spacingUnit * 1.5),

              AdaptiveCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (externalLabels) ...[
                      Text(
                        strings.otherPhoneRecipientLabel,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        softWrap: true,
                      ),
                      SizedBox(height: tokens.spacingUnit),
                    ],
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      onChanged: (value) {
                        setState(() {
                          if (value.trim().isNotEmpty) {
                            _selectedContact = null;
                          }
                          _formError = null;
                          _reevaluateAntiFraud();
                        });
                      },
                      decoration: InputDecoration(
                        labelText: externalLabels
                            ? null
                            : strings.otherPhoneRecipientLabel,
                        hintText: strings.phoneFieldHint,
                        prefixIcon: Icon(
                          Icons.phone_rounded,
                          size: tokens.iconSize,
                        ),
                      ),
                    ),
                    SizedBox(height: tokens.spacingUnit * 2),

                    // Amount Input
                    if (externalLabels) ...[
                      Text(
                        strings.amountFieldLabel,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        softWrap: true,
                      ),
                      SizedBox(height: tokens.spacingUnit),
                    ],
                    TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(9),
                      ],
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                      onChanged: (_) => setState(() {
                        _formError = null;
                        _reevaluateAntiFraud();
                      }),
                      decoration: InputDecoration(
                        labelText:
                            externalLabels ? null : strings.amountFieldLabel,
                        hintText: '5000',
                        suffixText: '₸',
                      ),
                    ),
                    SizedBox(height: tokens.spacingUnit * 1.5),

                    // Quick amount buttons (+1000, +5000, +10000)
                    Wrap(
                      spacing: tokens.spacingUnit,
                      runSpacing: tokens.spacingUnit,
                      children: [1000, 5000, 10000].map((delta) {
                        return OutlinedButton(
                          onPressed: () => _addAmount(delta),
                          style: OutlinedButton.styleFrom(
                            minimumSize: Size(
                              math.max(48, tokens.minTouchTarget),
                              math.max(48, tokens.minTouchTarget),
                            ),
                          ),
                          child: Text(
                            '+${MoneyFormatter.format(delta, localeCode: profile.localeCode)}',
                            softWrap: true,
                          ),
                        );
                      }).toList(),
                    ),

                    // 3. Amount in words readout (anti-extra-zero guard)
                    if (amountWords != null) ...[
                      SizedBox(height: tokens.spacingUnit * 2),
                      Semantics(
                        liveRegion: true,
                        label: '${strings.amountInWordsPrefix} $amountWords',
                        child: Container(
                          padding: EdgeInsets.all(tokens.spacingUnit * 1.5),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: profile.isHighContrast
                                  ? scheme.outline
                                  : scheme.primary,
                              width: profile.isHighContrast
                                  ? tokens.borderWidth
                                  : 1.5,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                strings.amountInWordsPrefix,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                ),
                                softWrap: true,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                amountWords,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: tokens.accentText,
                                  fontWeight: FontWeight.w800,
                                ),
                                softWrap: true,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // 4a. Anti-fraud warning + cooling-off countdown
              if (showAntiFraud) ...[
                SizedBox(height: tokens.spacingUnit * 2),
                Semantics(
                  liveRegion: true,
                  container: true,
                  label:
                      '${strings.antiFraudStrangerTitle}. ${strings.antiFraudStrangerBody}',
                  child: AdaptiveCard(
                    backgroundColor: scheme.errorContainer,
                    borderColor: scheme.error,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ExcludeSemantics(
                              child: Icon(
                                Icons.warning_amber_rounded,
                                color: scheme.error,
                                size: tokens.iconSize * 1.3,
                              ),
                            ),
                            SizedBox(width: tokens.spacingUnit * 1.25),
                            Expanded(
                              child: Text(
                                strings.antiFraudStrangerTitle,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: scheme.onErrorContainer,
                                  fontWeight: FontWeight.w800,
                                ),
                                softWrap: true,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: tokens.spacingUnit),
                        Text(
                          strings.antiFraudStrangerBody,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: scheme.onErrorContainer,
                            fontWeight: FontWeight.w600,
                          ),
                          softWrap: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              if (_formError != null) ...[
                SizedBox(height: tokens.spacingUnit * 1.5),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _formError!,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: scheme.error,
                      fontWeight: FontWeight.w700,
                    ),
                    softWrap: true,
                  ),
                ),
              ],

              SizedBox(height: tokens.spacingUnit * 2.5),

              // 4b. Confirmation button: Cooling-off block OR Hold-to-confirm OR Standard
              if (_coolingSecondsRemaining > 0)
                Semantics(
                  liveRegion: true,
                  child: AdaptiveActionButton(
                    label:
                        strings.antiFraudWaitTemplate(_coolingSecondsRemaining),
                    icon: Icons.hourglass_top_rounded,
                    onPressed: null,
                  ),
                )
              else if (profile.requiresHoldToConfirm)
                _HoldToConfirmButton(
                  idleLabel: strings.holdToConfirmProgressLabel,
                  activeLabel: strings.holdToConfirmActiveLabel,
                  duration: profile.holdToConfirmDuration,
                  onConfirmed: _executeTransfer,
                )
              else
                AdaptiveActionButton(
                  label: strings.sendTransferButton,
                  icon: Icons.check_circle_rounded,
                  onPressed: _executeTransfer,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DemoVoiceChip extends StatelessWidget {
  const _DemoVoiceChip({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = AdaptiveTokens.of(context);
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(Icons.play_arrow_rounded, size: tokens.iconSize * 0.9),
      label: Text(label, softWrap: true),
      style: OutlinedButton.styleFrom(
        minimumSize: Size(48, math.max(48, tokens.minTouchTarget)),
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacingUnit * 1.5,
          vertical: tokens.spacingUnit,
        ),
      ),
    );
  }
}

/// Hold-to-confirm (1.5 s) button with smooth animated progress fill and
/// tactile haptics for [MotorAssistanceLevel.tremorProtection].
class _HoldToConfirmButton extends StatefulWidget {
  const _HoldToConfirmButton({
    required this.idleLabel,
    required this.activeLabel,
    required this.duration,
    required this.onConfirmed,
  });

  final String idleLabel;
  final String activeLabel;
  final Duration duration;
  final VoidCallback onConfirmed;

  @override
  State<_HoldToConfirmButton> createState() => _HoldToConfirmButtonState();
}

class _HoldToConfirmButtonState extends State<_HoldToConfirmButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Offset? _downPosition;
  bool _holding = false;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && !_completed) {
          _completed = true;
          _holding = false;
          HapticFeedback.heavyImpact();
          widget.onConfirmed();
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startHold(Offset position) {
    _downPosition = position;
    _completed = false;
    setState(() => _holding = true);
    HapticFeedback.mediumImpact();
    _controller.forward(from: 0);
  }

  void _cancelHold() {
    if (!mounted || _completed) return;
    if (!_holding && _controller.value == 0) return;
    setState(() => _holding = false);
    _controller.reset();
    _downPosition = null;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AdaptiveTokens.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final radius = BorderRadius.circular(tokens.cornerRadius);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final pct = (_controller.value * 100).round();
          return Semantics(
            button: true,
            liveRegion: _holding,
            label: _holding ? widget.activeLabel : widget.idleLabel,
            value: _holding ? '$pct%' : null,
            onLongPress: widget.onConfirmed,
            child: Listener(
              onPointerDown: (e) => _startHold(e.position),
              onPointerMove: (e) {
                if (_downPosition != null &&
                    (e.position - _downPosition!).distance > 28) {
                  _cancelHold();
                }
              },
              onPointerUp: (_) => _cancelHold(),
              onPointerCancel: (_) => _cancelHold(),
              child: Container(
                constraints: const BoxConstraints(minHeight: 72),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: radius,
                  border: Border.all(
                    color: scheme.outline,
                    width: tokens.borderWidth.clamp(2.0, 4.0),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: _controller.value,
                        child: Container(color: scheme.primary),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: tokens.spacingUnit * 2.5,
                        vertical: tokens.spacingUnit * 2,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ExcludeSemantics(
                            child: Icon(
                              Icons.fingerprint_rounded,
                              size: tokens.iconSize,
                              color: _controller.value > 0.5
                                  ? scheme.onPrimary
                                  : scheme.onPrimaryContainer,
                            ),
                          ),
                          SizedBox(width: tokens.spacingUnit * 1.25),
                          Flexible(
                            child: Text(
                              _holding ? widget.activeLabel : widget.idleLabel,
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: _controller.value > 0.5
                                    ? scheme.onPrimary
                                    : scheme.onPrimaryContainer,
                              ),
                              softWrap: true,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TransferReceipt {
  const _TransferReceipt({
    required this.amountTenge,
    required this.recipientName,
    required this.newBalanceTenge,
  });

  final double amountTenge;
  final String recipientName;
  final double newBalanceTenge;
}

class _TransferSuccessView extends StatelessWidget {
  const _TransferSuccessView({
    required this.receipt,
    required this.profile,
    required this.strings,
    required this.onDone,
  });

  final _TransferReceipt receipt;
  final AccessibilityProfile profile;
  final AppStrings strings;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final tokens = AdaptiveTokens.of(context);
    final theme = Theme.of(context);

    final formattedAmount = MoneyFormatter.format(
      receipt.amountTenge,
      localeCode: profile.localeCode,
    );
    final amountWords = AmountInWords.format(
      receipt.amountTenge,
      localeCode: profile.localeCode,
    );
    final formattedNewBalance = MoneyFormatter.format(
      receipt.newBalanceTenge,
      localeCode: profile.localeCode,
    );

    return Scaffold(
      appBar: AppBar(title: Text(strings.transferScreenTitle, softWrap: true)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(tokens.spacingUnit * 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdaptiveCard(
                borderColor: tokens.success,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: tokens.success,
                      size: tokens.iconSize * 2,
                    ),
                    SizedBox(height: tokens.spacingUnit * 1.5),
                    Text(
                      strings.transferSuccessTitle,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                      softWrap: true,
                    ),
                    SizedBox(height: tokens.spacingUnit * 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        formattedAmount,
                        style: theme.textTheme.displaySmall?.copyWith(
                          color: tokens.accentText,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    SizedBox(height: tokens.spacingUnit * 0.5),
                    Text(
                      amountWords,
                      style: theme.textTheme.bodyLarge,
                      softWrap: true,
                    ),
                    SizedBox(height: tokens.spacingUnit * 1.5),
                    Text(
                      '${strings.recipientFieldLabel}: ${receipt.recipientName}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      softWrap: true,
                    ),
                    SizedBox(height: tokens.spacingUnit),
                    Text(
                      '${strings.newBalanceLabel} $formattedNewBalance',
                      style: theme.textTheme.bodyLarge,
                      softWrap: true,
                    ),
                  ],
                ),
              ),
              SizedBox(height: tokens.spacingUnit * 3),
              AdaptiveActionButton(
                label: strings.backToHomeButton,
                icon: Icons.home_rounded,
                onPressed: onDone,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
