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
import '../../../shared/widgets/adaptive_text_field.dart';
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
  final _phoneFocusNode = FocusNode();
  final _amountFocusNode = FocusNode();
  final _draftKey = GlobalKey();
  final _phoneFieldKey = GlobalKey();
  final _amountFieldKey = GlobalKey();
  final _holdControlsKey = GlobalKey();

  QuickContact? _selectedContact;
  String? _phoneError;
  String? _amountError;
  String? _voiceBannerMessage;
  String? _voiceInfoMessage;
  bool _voiceHasError = false;
  VoiceTransferIntent? _pendingPartialIntent;
  String? _earlyReleaseHint;

  // Anti-fraud 5-second cooling-off state
  Timer? _coolingTimer;
  int _coolingSecondsRemaining = 0;
  bool _coolingCompleted = false;
  ({String phone, int amountTiyn})? _lastCoolingDraft;

  // Receipt state after transfer execution
  _TransferReceipt? _receipt;
  bool _awaitingAccessibleConfirmation = false;
  late final VoiceAccessibilityService _voiceService;

  bool get _isUtilityPayment =>
      widget.initialContact?.category == QuickContactCategory.utilities;

  @override
  void initState() {
    super.initState();
    _voiceService = ref.read(voiceAccessibilityServiceProvider);
    _selectedContact = widget.initialContact;
    if (_selectedContact?.defaultAmountTenge != null) {
      _amountController.text = _formatInputAmount(
        _selectedContact!.defaultAmountTenge!,
      );
    }
    if (widget.initialContact != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToDraft();
      });
    }
  }

  @override
  void dispose() {
    _coolingTimer?.cancel();
    _coolingTimer = null;
    _voiceService.stopAll();
    _phoneController.dispose();
    _amountController.dispose();
    _phoneFocusNode.dispose();
    _amountFocusNode.dispose();
    super.dispose();
  }

  String _formatInputAmount(double value) {
    final normalized = MoneyFormatter.normalizeAmount(value);
    if (!MoneyFormatter.hasTiyn(normalized)) {
      return normalized.round().toString();
    }
    return normalized.toStringAsFixed(2).replaceAll('.', ',');
  }

  double get _parsedAmount {
    final cleaned = _amountController.text
        .replaceAll(RegExp(r'[\s\u00A0\u202F]'), '')
        .replaceAll(',', '.');
    return MoneyFormatter.normalizeAmount(double.tryParse(cleaned) ?? 0);
  }

  bool _isStrangerRecipient(MockBankRepository bankRepo) {
    if (_selectedContact != null) return false;
    final phone = _normalizedPhone;
    return phone != null && bankRepo.findContact(phone) == null;
  }

  String? get _normalizedPhone =>
      VoiceTransferParser.normalizePhone(_phoneController.text);

  (String?, String?, double) get _draft =>
      (_selectedContact?.id, _normalizedPhone, _parsedAmount);

  bool _isCompactStandard(AccessibilityProfile profile) =>
      !profile.isSimplifiedUi &&
      profile.textScaleFactor < 1.4 &&
      !profile.voiceAssistantEnabled;

  bool _requiresAntiFraudCooling(
    AccessibilityProfile profile,
    MockBankRepository bankRepo,
  ) {
    final amountTiyn = MoneyFormatter.toTiyn(_parsedAmount);
    if (amountTiyn <= 0 || !_isStrangerRecipient(bankRepo)) return false;
    if (profile.isSimplifiedUi || profile.requiresHoldToConfirm) return true;
    // Standard mode enforces the 5s block only on large transfers
    // (>= 150 000 ₸) while keeping a non-blocking warning below that threshold.
    return amountTiyn >= 15000000;
  }

  void _reevaluateAntiFraud() {
    final profile = ref.read(currentAccessibilityProfileProvider);
    final bankRepo = ref.read(mockBankRepositoryProvider.notifier);
    final active = _requiresAntiFraudCooling(profile, bankRepo);

    if (!active) {
      _coolingTimer?.cancel();
      _coolingTimer = null;
      _lastCoolingDraft = null;
      _coolingSecondsRemaining = 0;
      _coolingCompleted = false;
      return;
    }

    final draft = (
      phone: _normalizedPhone!,
      amountTiyn: MoneyFormatter.toTiyn(_parsedAmount),
    );
    if (_lastCoolingDraft == draft) return;
    _lastCoolingDraft = draft;

    _coolingTimer?.cancel();
    _coolingSecondsRemaining = 5;
    _coolingCompleted = false;
    _coolingTimer = Timer.periodic(widget.coolingOffTickDuration, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_coolingSecondsRemaining <= 1) {
        timer.cancel();
        setState(() {
          _coolingSecondsRemaining = 0;
          _coolingCompleted = true;
        });
      } else {
        setState(() => _coolingSecondsRemaining -= 1);
      }
    });
  }

  void _selectQuickContact(QuickContact contact) {
    setState(() {
      _selectedContact = contact;
      _phoneController.clear();
      _phoneError = null;
      _amountError = null;
      _earlyReleaseHint = null;
      _voiceBannerMessage = null;
      _voiceInfoMessage = null;
      _pendingPartialIntent = null;
      if (contact.category == QuickContactCategory.utilities &&
          _amountController.text.trim().isEmpty &&
          contact.defaultAmountTenge != null) {
        _amountController.text = _formatInputAmount(
          contact.defaultAmountTenge!,
        );
      }
      _reevaluateAntiFraud();
    });
    _scrollToDraft();
  }

  void _addAmount(int delta) {
    final next = MoneyFormatter.normalizeAmount(_parsedAmount + delta);
    setState(() {
      _amountController.text = _formatInputAmount(next);
      _amountError = null;
      _earlyReleaseHint = null;
      _voiceBannerMessage = null;
      _reevaluateAntiFraud();
    });
  }

  void _applyVoiceIntent(VoiceTransferIntent intent) {
    final profile = ref.read(currentAccessibilityProfileProvider);
    final strings = ref.read(appStringsProvider);
    final bankRepo = ref.read(mockBankRepositoryProvider.notifier);

    String recipientDisplay = '';
    setState(() {
      _phoneError = null;
      _amountError = null;
      _earlyReleaseHint = null;
      _voiceBannerMessage = null;
      _voiceInfoMessage = null;
      _voiceHasError = false;
      _pendingPartialIntent = null;
      if (intent.amount != null && intent.amount! > 0) {
        _amountController.text = _formatInputAmount(intent.amount!);
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

    _scrollToDraft();

    if (intent.amountInWords != null && recipientDisplay.isNotEmpty) {
      ref
          .read(voiceSessionProvider.notifier)
          .speak(
            strings.voiceDraftReadyTemplate(
              intent.amountInWords!,
              recipientDisplay,
            ),
            context: context,
          );
    }
  }

  void _applyPartialVoiceIntent(VoiceTransferIntent intent) {
    final bankRepo = ref.read(mockBankRepositoryProvider.notifier);
    setState(() {
      _phoneError = null;
      _amountError = null;
      _earlyReleaseHint = null;
      _voiceInfoMessage = null;
      _voiceHasError = false;
      _pendingPartialIntent = null;

      if (intent.hasAmount && intent.amount != null) {
        _amountController.text = _formatInputAmount(intent.amount!);
      }
      if (intent.hasRecipient) {
        final matched = bankRepo.findContact(
          intent.normalizedPhone ?? intent.recipientQuery,
        );
        if (matched != null) {
          _selectedContact = matched;
          _phoneController.clear();
        } else if (intent.recipientQuery != null &&
            intent.recipientQuery!.trim().isNotEmpty) {
          _selectedContact = null;
          _phoneController.text = intent.recipientQuery!.trim();
        }
      }
      _reevaluateAntiFraud();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!intent.hasRecipient) {
        _scrollToKey(_phoneFieldKey);
        _phoneFocusNode.requestFocus();
      } else if (!intent.hasAmount) {
        _scrollToKey(_amountFieldKey);
        _amountFocusNode.requestFocus();
      }
    });
  }

  void _handleVoiceSessionUpdate(
    VoiceSessionState? prev,
    VoiceSessionState next,
  ) {
    final profile = ref.read(currentAccessibilityProfileProvider);
    final strings = ref.read(appStringsProvider);
    final bankRepo = ref.read(mockBankRepositoryProvider.notifier);

    if (next.status != prev?.status) {
      if (next.status == VoiceListeningStatus.permissionDenied) {
        setState(() {
          _voiceHasError = true;
          _pendingPartialIntent = null;
          _voiceInfoMessage = strings.micPermissionBlockedTransferNotice;
        });
        return;
      }
      if (next.status == VoiceListeningStatus.unavailable ||
          next.status == VoiceListeningStatus.error) {
        setState(() {
          _voiceHasError = true;
          _pendingPartialIntent = null;
          _voiceInfoMessage = strings.micUnavailableDemoHint;
        });
        return;
      }
    }

    final resultChanged =
        next.parsedIntent != prev?.parsedIntent ||
        next.recognizedText != prev?.recognizedText ||
        next.isFinalResult != prev?.isFinalResult;
    if (!resultChanged ||
        !next.isFinalResult ||
        next.status != VoiceListeningStatus.completed) {
      return;
    }

    final intent = next.parsedIntent;
    final matchedContact = intent == null
        ? null
        : bankRepo.findContact(intent.normalizedPhone ?? intent.recipientQuery);
    final hasValidRecipient =
        intent != null &&
        (intent.normalizedPhone != null || matchedContact != null);
    final hasAmount = intent != null && intent.hasAmount;

    if (!hasAmount && !hasValidRecipient) {
      final heard = next.recognizedText.trim();
      final msg = heard.isNotEmpty
          ? '${strings.voiceRecognizedPrefix} «$heard». ${strings.voiceNotUnderstoodNotice}'
          : strings.voiceNotUnderstoodNotice;
      setState(() {
        _voiceHasError = true;
        _pendingPartialIntent = null;
        _voiceBannerMessage = null;
        _voiceInfoMessage = msg;
      });
      if (profile.voiceAssistantEnabled) {
        ref.read(voiceSessionProvider.notifier).speak(msg, context: context);
      }
      return;
    }

    if (hasAmount && hasValidRecipient) {
      _applyVoiceIntent(intent);
      return;
    }

    // Partial recognition: do not silently overwrite or mix old/new values;
    // display what was heard and ask the user to Apply or Retry.
    final heard = intent.rawText.trim();
    final String detail;
    if (hasAmount && intent.amount != null) {
      final formatted =
          intent.amountFormatted ??
          MoneyFormatter.format(intent.amount!, localeCode: profile.localeCode);
      detail = strings.voicePartialAmountOnlyTemplate(formatted);
    } else {
      final recipientLabel =
          matchedContact?.localizedTitle(profile.localeCode) ??
          (intent.normalizedPhone != null
              ? VoiceTransferParser.formatPhone(intent.normalizedPhone!)
              : intent.recipientQuery ?? '');
      detail = strings.voicePartialRecipientOnlyTemplate(recipientLabel);
    }
    final msg = heard.isNotEmpty
        ? '${strings.voiceRecognizedPrefix} «$heard». $detail'
        : detail;

    setState(() {
      _voiceHasError = false;
      _pendingPartialIntent = intent;
      _voiceBannerMessage = null;
      _voiceInfoMessage = msg;
    });
    if (profile.voiceAssistantEnabled) {
      ref.read(voiceSessionProvider.notifier).speak(msg, context: context);
    }
  }

  void _scrollToKey(GlobalKey key, {bool showWholeTarget = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = key.currentContext;
      if (target != null && target.mounted) {
        if (showWholeTarget) {
          final viewportHeight = Scrollable.of(target).position.viewportDimension;
          if (target.size!.height > viewportHeight) return;
        }
        Scrollable.ensureVisible(
          target,
          alignmentPolicy: showWholeTarget
              ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
              : ScrollPositionAlignmentPolicy.explicit,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _scrollToDraft() => _scrollToKey(_draftKey);

  Future<void> _onMicButtonPressed() async {
    final session = ref.read(voiceSessionProvider);
    final notifier = ref.read(voiceSessionProvider.notifier);
    setState(() {
      _voiceInfoMessage = null;
      _voiceHasError = false;
      _pendingPartialIntent = null;
    });
    if (session.isListening) {
      await notifier.stopPushToTalk();
      return;
    }
    await notifier.startPushToTalk();
  }

  bool _validateDraft() {
    final profile = ref.read(currentAccessibilityProfileProvider);
    final strings = ref.read(appStringsProvider);
    final bankState = ref.read(mockBankRepositoryProvider);
    final bankNotifier = ref.read(mockBankRepositoryProvider.notifier);

    final phone = _normalizedPhone;
    final contact = _selectedContact ?? bankNotifier.findContact(phone);
    if (contact == null && phone == null) {
      setState(() {
        _phoneError = strings.invalidRecipientError;
        _amountError = null;
        _earlyReleaseHint = null;
      });
      _scrollToKey(_phoneFieldKey);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _phoneFocusNode.requestFocus();
      });
      if (profile.voiceAssistantEnabled) {
        ref
            .read(voiceSessionProvider.notifier)
            .speak(strings.invalidRecipientError, context: context);
      }
      return false;
    }

    final amount = _parsedAmount;
    final amountTiyn = MoneyFormatter.toTiyn(amount);
    if (amountTiyn <= 0) {
      setState(() {
        _amountError = strings.invalidAmountError;
        _phoneError = null;
        _earlyReleaseHint = null;
      });
      _scrollToKey(_amountFieldKey);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _amountFocusNode.requestFocus();
      });
      if (profile.voiceAssistantEnabled) {
        ref
            .read(voiceSessionProvider.notifier)
            .speak(strings.invalidAmountError, context: context);
      }
      return false;
    }

    final balanceTiyn = MoneyFormatter.toTiyn(
      bankState.primaryAccount.balanceTenge,
    );
    if (amountTiyn > balanceTiyn) {
      final availableStr = MoneyFormatter.format(
        bankState.primaryAccount.balanceTenge,
        localeCode: profile.localeCode,
      );
      final err = strings.insufficientFundsWithBalanceTemplate(availableStr);
      setState(() {
        _amountError = err;
        _phoneError = null;
        _earlyReleaseHint = null;
      });
      _scrollToKey(_amountFieldKey);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _amountFocusNode.requestFocus();
      });
      if (profile.voiceAssistantEnabled) {
        ref.read(voiceSessionProvider.notifier).speak(err, context: context);
      }
      return false;
    }

    return true;
  }

  Future<void> _executeTransfer() async {
    if (_receipt != null || _coolingSecondsRemaining > 0) return;
    if (!_validateDraft()) return;

    final profile = ref.read(currentAccessibilityProfileProvider);
    final strings = ref.read(appStringsProvider);
    final bankNotifier = ref.read(mockBankRepositoryProvider.notifier);

    final amount = _parsedAmount;
    final phone = _normalizedPhone;
    final contact = _selectedContact ?? bankNotifier.findContact(phone);

    final rawPhone = phone == null
        ? ''
        : VoiceTransferParser.formatPhone(phone);
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
      final availableStr = MoneyFormatter.format(
        ref.read(mockBankRepositoryProvider).primaryAccount.balanceTenge,
        localeCode: profile.localeCode,
      );
      setState(
        () => _amountError = strings.insufficientFundsWithBalanceTemplate(
          availableStr,
        ),
      );
      return;
    }

    final updatedBalance = ref
        .read(mockBankRepositoryProvider)
        .primaryAccount
        .balanceTenge;
    final recipientDisplay =
        contact?.localizedTitle(profile.localeCode) ?? rawPhone;

    setState(() {
      _phoneError = null;
      _amountError = null;
      _earlyReleaseHint = null;
      _receipt = _TransferReceipt(
        amountTenge: amount,
        recipientName: recipientDisplay,
        newBalanceTenge: updatedBalance,
      );
    });

    await ref
        .read(voiceSessionProvider.notifier)
        .speak(strings.transferSuccessTitle, context: context);
  }

  Future<void> _confirmWithCodeDialog() async {
    if (_coolingSecondsRemaining > 0) return;
    if (!_validateDraft()) return;
    final strings = ref.read(appStringsProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: Text(strings.confirmCodeDialogTitle),
        content: Text(strings.confirmCodeDialogDemoHint),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(strings.backButton),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(strings.confirmWithCodeAction),
          ),
        ],
      ),
    );
    if (mounted && confirmed == true) {
      await _executeTransfer();
    }
  }

  Future<void> _confirmWithAssistiveInput() async {
    if (_awaitingAccessibleConfirmation || _coolingSecondsRemaining > 0) return;
    if (!_validateDraft()) return;
    final draft = _draft;
    final profile = ref.read(currentAccessibilityProfileProvider);
    final strings = ref.read(appStringsProvider);

    final ready = Future<void>.delayed(profile.holdToConfirmDuration);
    final recipient =
        _selectedContact?.localizedTitle(profile.localeCode) ??
        VoiceTransferParser.formatPhone(_normalizedPhone!);
    _awaitingAccessibleConfirmation = true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: Text(strings.sendTransferButton),
        content: Text(
          strings.speakTransferCheckTemplate(
            recipient: recipient,
            amountInWords: AmountInWords.format(
              draft.$3,
              localeCode: profile.localeCode,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(strings.backButton),
          ),
          FutureBuilder<void>(
            future: ready,
            builder: (context, snapshot) => TextButton(
              onPressed: snapshot.connectionState == ConnectionState.done
                  ? () => Navigator.of(dialogContext).pop(true)
                  : null,
              child: Text(strings.sendTransferButton),
            ),
          ),
        ],
      ),
    );
    _awaitingAccessibleConfirmation = false;
    if (mounted && confirmed == true && draft == _draft) {
      await _executeTransfer();
    }
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

    ref.listen<VoiceSessionState>(voiceSessionProvider, _handleVoiceSessionUpdate);

    final screenTitle = _isUtilityPayment
        ? strings.actionPayments
        : strings.transferScreenTitle;

    if (_receipt != null) {
      return _TransferSuccessView(
        receipt: _receipt!,
        screenTitle: screenTitle,
        profile: profile,
        strings: strings,
        onDone: () {
          ref.read(voiceSessionProvider.notifier).resetSession();
          Navigator.of(context)
              .pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
        },
      );
    }

    final isCompactStandard = _isCompactStandard(profile);
    final showAntiFraud = _requiresAntiFraudCooling(profile, bankNotifier);
    final isCoolingComplete = showAntiFraud && _coolingCompleted;
    final showSoftStrangerWarning =
        !showAntiFraud &&
        _isStrangerRecipient(bankNotifier) &&
        MoneyFormatter.toTiyn(_parsedAmount) > 0;
    final amount = _parsedAmount;
    final amountWords = amount > 0
        ? AmountInWords.format(amount, localeCode: profile.localeCode)
        : null;
    final externalLabels = profile.textScaleFactor >= 1.5;
    final selectedName = _selectedContact?.localizedTitle(profile.localeCode);
    final phone = _normalizedPhone;
    final recipientName =
        selectedName ??
        bankNotifier.findContact(phone)?.localizedTitle(profile.localeCode) ??
        (phone == null ? null : VoiceTransferParser.formatPhone(phone));

    final availableBalance = bankState.primaryAccount.balanceTenge;
    final availableTiyn = MoneyFormatter.toTiyn(availableBalance);
    final amountTiyn = MoneyFormatter.toTiyn(amount);
    final hasValidRemaining = amountTiyn > 0 && amountTiyn <= availableTiyn;
    final remainingBalance = (availableTiyn - amountTiyn) / 100.0;

    final micPreparing =
        voiceSession.status == VoiceListeningStatus.initializing;
    final micUnavailable =
        voiceSession.status == VoiceListeningStatus.permissionDenied ||
        voiceSession.status == VoiceListeningStatus.unavailable ||
        voiceSession.status == VoiceListeningStatus.error;

    return Scaffold(
      appBar: AppBar(title: Text(screenTitle, softWrap: true)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(tokens.spacingUnit * 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!isCompactStandard) ...[
                Text(
                  strings.transferStepRecipient,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: tokens.accentText,
                  ),
                  softWrap: true,
                ),
                SizedBox(height: tokens.spacingUnit * 0.5),
              ],
              Text(
                strings.trustedContactsLabel,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: tokens.spacingUnit),

              AdaptiveCard(
                padding: EdgeInsets.zero,
                backgroundColor: voiceSession.isListening
                    ? scheme.primaryContainer
                    : null,
                borderColor: voiceSession.isListening ? scheme.primary : null,
                child: ExpansionTile(
                  initiallyExpanded: false,
                  title: Text(strings.voiceTransferOptions),
                  leading: Icon(
                    Icons.mic_none_rounded,
                    color: tokens.accentText,
                  ),
                  minTileHeight: tokens.minTouchTarget,
                  tilePadding: EdgeInsets.symmetric(
                    horizontal: tokens.spacingUnit,
                  ),
                  childrenPadding: EdgeInsets.all(tokens.spacingUnit * 1.5),
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          strings.voiceDraftOnly,
                          style: theme.textTheme.bodyMedium,
                        ),
                        if (profile.voiceAssistantEnabled) ...[
                          SizedBox(height: tokens.spacingUnit),
                          VoiceGuideHeader(
                            promptText: strings.voiceExamplePrompt,
                          ),
                        ],
                        SizedBox(height: tokens.spacingUnit),
                        AdaptiveActionButton(
                          label: voiceSession.isListening
                              ? strings.voiceListeningNow
                              : micPreparing
                              ? strings.voicePreparing
                              : strings.voiceFillTransferButton,
                          icon: voiceSession.isListening
                              ? Icons.stop_rounded
                              : Icons.mic_rounded,
                          onPressed: micPreparing ? null : _onMicButtonPressed,
                        ),
                        if (micUnavailable && _voiceInfoMessage == null) ...[
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
                        if (_voiceInfoMessage != null) ...[
                          SizedBox(height: tokens.spacingUnit * 1.5),
                          Semantics(
                            liveRegion: true,
                            child: AdaptiveCard(
                              borderColor: _voiceHasError
                                  ? tokens.warning
                                  : scheme.primary,
                              backgroundColor: scheme.surfaceContainerHighest,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      ExcludeSemantics(
                                        child: Icon(
                                          _voiceHasError
                                              ? Icons.warning_amber_rounded
                                              : Icons.info_outline_rounded,
                                          color: _voiceHasError
                                              ? tokens.warning
                                              : tokens.accentText,
                                          size: tokens.iconSize,
                                        ),
                                      ),
                                      SizedBox(width: tokens.spacingUnit),
                                      Expanded(
                                        child: Text(
                                          _voiceInfoMessage!,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                          softWrap: true,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: tokens.spacingUnit * 1.25),
                                  Wrap(
                                    spacing: tokens.spacingUnit,
                                    runSpacing: tokens.spacingUnit,
                                    children: [
                                      if (_pendingPartialIntent != null)
                                        AdaptiveActionButton(
                                          label: strings.applyButton,
                                          icon: Icons.check_rounded,
                                          expandWidth: false,
                                          applyTremorSpacing: false,
                                          onPressed: () =>
                                              _applyPartialVoiceIntent(
                                                _pendingPartialIntent!,
                                              ),
                                        ),
                                      AdaptiveActionButton(
                                        label: strings.retryVoiceButton,
                                        icon: Icons.mic_rounded,
                                        variant:
                                            AdaptiveButtonVariant.outlined,
                                        expandWidth: false,
                                        applyTremorSpacing: false,
                                        onPressed: micPreparing
                                            ? null
                                            : _onMicButtonPressed,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
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
                  ],
                ),
              ),
              SizedBox(height: tokens.spacingUnit * 2),

              // 2. Trusted Contacts (Compact horizontal pills in standard vs vertical cards in adaptive)
              if (isCompactStandard)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: bankState.quickContacts.map((contact) {
                      final selected = _selectedContact?.id == contact.id;
                      final contactTitle = contact.localizedTitle(
                        profile.localeCode,
                      );
                      return Padding(
                        padding: EdgeInsets.only(right: tokens.spacingUnit),
                        child: AdaptiveCard(
                          selected: selected,
                          semanticLabel:
                              '$contactTitle, ${contact.phoneOrAccount}',
                          padding: EdgeInsets.symmetric(
                            horizontal: tokens.spacingUnit * 1.5,
                            vertical: tokens.spacingUnit * 1.25,
                          ),
                          onTap: () => _selectQuickContact(contact),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ExcludeSemantics(
                                child: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: selected
                                      ? scheme.primary
                                      : scheme.surfaceContainerHighest,
                                  child: Icon(
                                    selected
                                        ? Icons.check_rounded
                                        : (contact.category ==
                                                  QuickContactCategory.utilities
                                              ? Icons.receipt_long_rounded
                                              : Icons.person_rounded),
                                    size: 18,
                                    color: selected
                                        ? scheme.onPrimary
                                        : tokens.accentText,
                                  ),
                                ),
                              ),
                              SizedBox(width: tokens.spacingUnit),
                              Text(
                                contactTitle,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                )
              else
                ...bankState.quickContacts.map((contact) {
                  final selected = _selectedContact?.id == contact.id;
                  final contactTitle = contact.localizedTitle(
                    profile.localeCode,
                  );
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
                key: _draftKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_selectedContact?.category ==
                        QuickContactCategory.utilities) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: tokens.spacingUnit * 1.5,
                            vertical: tokens.spacingUnit * 0.6,
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
                                  Icons.receipt_long_rounded,
                                  size: tokens.iconSize * 0.85,
                                  color: tokens.accentText,
                                ),
                              ),
                              SizedBox(width: tokens.spacingUnit * 0.75),
                              Flexible(
                                child: Text(
                                  strings.prefilledBillBadge,
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
                      SizedBox(height: tokens.spacingUnit),
                    ],
                    if (_voiceBannerMessage != null) ...[
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _voiceBannerMessage!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: tokens.accentText,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      SizedBox(height: tokens.spacingUnit),
                    ] else if (selectedName != null) ...[
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          '${strings.recipientFieldLabel}: $selectedName',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: tokens.accentText,
                          ),
                        ),
                      ),
                      SizedBox(height: tokens.spacingUnit),
                    ],
                    KeyedSubtree(
                      key: _phoneFieldKey,
                      child: AdaptiveTextField(
                        controller: _phoneController,
                        focusNode: _phoneFocusNode,
                        label: selectedName == null
                            ? strings.otherPhoneRecipientLabel
                            : strings.differentPhoneRecipientLabel,
                        hint: selectedName == null ? strings.phoneFieldHint : '',
                        errorText: _phoneError,
                        externalLabel: externalLabels,
                        keyboardType: TextInputType.phone,
                        prefixIcon: Icons.phone_rounded,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9+ ()\u00A0\u202F-]'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            if (value.trim().isNotEmpty) {
                              _selectedContact = null;
                            }
                            _phoneError = null;
                            _amountError = null;
                            _earlyReleaseHint = null;
                            _voiceBannerMessage = null;
                            _reevaluateAntiFraud();
                          });
                        },
                      ),
                    ),
                    SizedBox(height: tokens.spacingUnit * 2),

                    if (!isCompactStandard) ...[
                      Text(
                        strings.transferStepAmount,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: tokens.accentText,
                        ),
                        softWrap: true,
                      ),
                      SizedBox(height: tokens.spacingUnit),
                    ],

                    // Live available balance strip
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${strings.availableOnCardLabel} '
                            '${MoneyFormatter.format(availableBalance, localeCode: profile.localeCode)}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            softWrap: true,
                          ),
                          if (hasValidRemaining) ...[
                            SizedBox(height: tokens.spacingUnit * 0.4),
                            Text(
                              '${strings.balanceAfterTransferLabel} '
                              '${MoneyFormatter.format(remainingBalance, localeCode: profile.localeCode)}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: tokens.accentText,
                                fontWeight: FontWeight.w700,
                              ),
                              softWrap: true,
                            ),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(height: tokens.spacingUnit * 1.25),

                    // Amount Input
                    KeyedSubtree(
                      key: _amountFieldKey,
                      child: AdaptiveTextField(
                        controller: _amountController,
                        focusNode: _amountFocusNode,
                        label: strings.amountFieldLabel,
                        hint: '',
                        errorText: _amountError,
                        externalLabel: externalLabels,
                        suffixText: '₸',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          TextInputFormatter.withFunction((oldValue, newValue) {
                            final ungrouped = newValue.text.replaceAll(
                              RegExp(r'[\s\u00A0\u202F]'),
                              '',
                            );
                            return RegExp(r'^\d{0,9}(?:[.,]\d{0,2})?$')
                                    .hasMatch(ungrouped)
                                ? newValue.copyWith(
                                    text: newValue.text.replaceAll('.', ','),
                                  )
                                : oldValue;
                          }),
                        ],
                        onChanged: (_) => setState(() {
                          _amountError = null;
                          _phoneError = null;
                          _earlyReleaseHint = null;
                          _voiceBannerMessage = null;
                          _reevaluateAntiFraud();
                        }),
                      ),
                    ),
                    // 3. Amount in words readout (calm non-clickable info callout)
                    if (amountWords != null) ...[
                      SizedBox(height: tokens.spacingUnit * 1.25),
                      Semantics(
                        liveRegion: true,
                        label: '${strings.amountInWordsPrefix} $amountWords',
                        excludeSemantics: true,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: EdgeInsets.all(tokens.spacingUnit * 1.25),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest,
                              border: Border(
                                left: BorderSide(
                                  color: profile.isHighContrast
                                      ? scheme.outline
                                      : tokens.accentText,
                                  width: 4,
                                ),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.spellcheck_rounded,
                                  color: tokens.accentText,
                                  size: tokens.iconSize * 0.9,
                                ),
                                SizedBox(width: tokens.spacingUnit),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        strings.amountInWordsPrefix,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color: scheme.onSurfaceVariant,
                                              fontWeight: FontWeight.w700,
                                            ),
                                        softWrap: true,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        amountWords,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              color: tokens.accentText,
                                              fontWeight: FontWeight.w800,
                                            ),
                                        softWrap: true,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                    SizedBox(height: tokens.spacingUnit * 1.5),

                    // Quick amount buttons (+1000, +5000, +10000)
                    Wrap(
                      spacing: tokens.spacingUnit,
                      runSpacing: tokens.spacingUnit,
                      children: [1000, 5000, 10000].map((delta) {
                        return OutlinedButton(
                          onPressed: () => _addAmount(delta),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              horizontal: tokens.spacingUnit,
                              vertical: tokens.spacingUnit * 0.5,
                            ),
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
                  ],
                ),
              ),

              // 4a. Anti-fraud warning + cooling-off countdown (or soft banner in standard < 150k)
              if (showAntiFraud || showSoftStrangerWarning) ...[
                SizedBox(height: tokens.spacingUnit * 2),
                Semantics(
                  liveRegion: true,
                  container: true,
                  label:
                      '${strings.antiFraudStrangerTitle}. ${strings.antiFraudStrangerBody}'
                      '${isCoolingComplete ? ' ${strings.antiFraudReadyToConfirm}' : ''}',
                  excludeSemantics: true,
                  child: AdaptiveCard(
                    backgroundColor: scheme.surfaceContainerHighest,
                    borderColor: tokens.warning,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.shield_outlined,
                              color: tokens.warning,
                              size: tokens.iconSize,
                            ),
                            SizedBox(width: tokens.spacingUnit),
                            Expanded(
                              child: Text(
                                strings.antiFraudStrangerTitle,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: scheme.onSurface,
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
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurface,
                          ),
                          softWrap: true,
                        ),
                        if (isCoolingComplete) ...[
                          SizedBox(height: tokens.spacingUnit * 1.25),
                          Row(
                            children: [
                              Icon(
                                Icons.verified_user_rounded,
                                color: tokens.success,
                                size: tokens.iconSize * 0.9,
                              ),
                              SizedBox(width: tokens.spacingUnit * 0.75),
                              Expanded(
                                child: Text(
                                  strings.antiFraudReadyToConfirm,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: tokens.success,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  softWrap: true,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (showAntiFraud) ...[
                  SizedBox(height: tokens.spacingUnit),
                  AdaptiveActionButton(
                    label: strings.cancelTransferButton,
                    variant: AdaptiveButtonVariant.outlined,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ],

              SizedBox(height: tokens.spacingUnit * 2.5),

              if (!isCompactStandard) ...[
                Text(
                  strings.transferStepReview,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: tokens.accentText,
                  ),
                  softWrap: true,
                ),
                SizedBox(height: tokens.spacingUnit),
              ],

              if (!isCompactStandard && recipientName != null && amount > 0) ...[
                AdaptiveCard(
                  padding: EdgeInsets.all(tokens.spacingUnit * 1.5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${strings.recipientFieldLabel}: $recipientName',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: tokens.spacingUnit * 0.5),
                      Text(
                        '${strings.transferReviewAmountLabel}: '
                        '${MoneyFormatter.format(amount, localeCode: profile.localeCode)}',
                        style: theme.textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: tokens.spacingUnit),
              ],

              // 4b. Confirmation button: Cooling-off block OR Hold-to-confirm OR Standard
              if (_coolingSecondsRemaining > 0)
                Semantics(
                  liveRegion: true,
                  child: AdaptiveActionButton(
                    label: strings.antiFraudWaitTemplate(
                      _coolingSecondsRemaining,
                    ),
                    icon: Icons.hourglass_top_rounded,
                    onPressed: null,
                  ),
                )
              else if (profile.requiresHoldToConfirm)
                Column(
                  key: _holdControlsKey,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _HoldToConfirmButton(
                      key: ValueKey(_draft),
                      idleLabel: strings.sendTransferButton,
                      instruction: strings.holdToConfirmHint,
                      activeLabel: strings.holdToConfirmActiveLabel,
                      duration: profile.holdToConfirmDuration,
                      isHighContrast: profile.isHighContrast,
                      onBeforeHoldStart: _validateDraft,
                      onEarlyRelease: () {
                        HapticFeedback.lightImpact();
                        HapticFeedback.lightImpact();
                        setState(() {
                          _earlyReleaseHint = strings.holdReleasedTooEarlyHint;
                        });
                        _scrollToKey(_holdControlsKey, showWholeTarget: true);
                        if (profile.voiceAssistantEnabled) {
                          ref
                              .read(voiceSessionProvider.notifier)
                              .speak(
                                strings.holdReleasedTooEarlyHint,
                                context: context,
                              );
                        }
                      },
                      onConfirmed: _executeTransfer,
                      onAccessibleConfirm: _confirmWithAssistiveInput,
                    ),
                    if (_earlyReleaseHint != null) ...[
                      SizedBox(height: tokens.spacingUnit),
                      Semantics(
                        liveRegion: true,
                        child: Container(
                          padding: EdgeInsets.all(tokens.spacingUnit * 1.25),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: tokens.warning),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ExcludeSemantics(
                                child: Icon(
                                  Icons.touch_app_rounded,
                                  color: tokens.warning,
                                  size: tokens.iconSize,
                                ),
                              ),
                              SizedBox(width: tokens.spacingUnit),
                              Expanded(
                                child: Text(
                                  _earlyReleaseHint!,
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
                    ],
                    SizedBox(height: tokens.spacingUnit),
                    Center(
                      child: TextButton.icon(
                        onPressed: _confirmWithCodeDialog,
                        icon: const Icon(Icons.password_rounded),
                        label: Text(
                          strings.confirmWithoutHoldButton,
                          softWrap: true,
                        ),
                      ),
                    ),
                  ],
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
  const _DemoVoiceChip({required this.label, required this.onTap});

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
    super.key,
    required this.idleLabel,
    required this.instruction,
    required this.activeLabel,
    required this.duration,
    required this.isHighContrast,
    required this.onConfirmed,
    required this.onAccessibleConfirm,
    this.onBeforeHoldStart,
    this.onEarlyRelease,
  });

  final String idleLabel;
  final String instruction;
  final String activeLabel;
  final Duration duration;
  final bool isHighContrast;
  final VoidCallback onConfirmed;
  final VoidCallback onAccessibleConfirm;
  final bool Function()? onBeforeHoldStart;
  final VoidCallback? onEarlyRelease;

  @override
  State<_HoldToConfirmButton> createState() => _HoldToConfirmButtonState();
}

class _HoldToConfirmButtonState extends State<_HoldToConfirmButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _holdTimer;
  int? _pointer;
  Offset? _downPosition;
  Duration? _holdStartedAt;
  bool _holding = false;
  bool _completed = false;
  bool _showFocus = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      animationBehavior: AnimationBehavior.preserve,
    );
  }

  @override
  void dispose() {
    _pointer = null;
    _holdTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startHold(PointerDownEvent event) {
    if (_pointer != null || event.buttons != 1) return;
    if (widget.onBeforeHoldStart != null && !widget.onBeforeHoldStart!()) {
      return;
    }
    _pointer = event.pointer;
    _downPosition = event.position;
    _holdStartedAt = event.timeStamp;
    _completed = false;
    setState(() => _holding = true);
    HapticFeedback.mediumImpact();
    _controller.forward(from: 0);
    _holdTimer = Timer(widget.duration, _finishHold);
  }

  void _finishHold() {
    if (!_holding || _completed) return;
    _completed = true;
    setState(() => _holding = false);
    HapticFeedback.heavyImpact();
    widget.onConfirmed();
  }

  void _releaseHold(PointerUpEvent event) {
    if (_pointer != event.pointer) return;
    // A browser can defer the timer while still delivering the release event.
    if (event.timeStamp - _holdStartedAt! >= widget.duration) {
      _finishHold();
      _cancelHold(notifyEarly: false);
      return;
    }
    _cancelHold(notifyEarly: true);
  }

  void _cancelHold({bool notifyEarly = false}) {
    if (!mounted) return;
    final wasHoldingBeforeDone = _holding && !_completed;
    _pointer = null;
    _downPosition = null;
    _holdStartedAt = null;
    _holdTimer?.cancel();
    if (_holding) setState(() => _holding = false);
    _controller.reset();
    if (notifyEarly && wasHoldingBeforeDone) {
      widget.onEarlyRelease?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AdaptiveTokens.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final radius = BorderRadius.circular(tokens.cornerRadius);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: FocusableActionDetector(
        onShowFocusHighlight: (value) => setState(() => _showFocus = value),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onAccessibleConfirm();
              return null;
            },
          ),
        },
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Semantics(
              button: true,
              label: '${widget.idleLabel}. ${widget.instruction}',
              value: _holding ? widget.activeLabel : null,
              onTap: widget.onAccessibleConfirm,
              excludeSemantics: true,
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: _startHold,
                onPointerMove: (e) {
                  if (_pointer == e.pointer &&
                      _downPosition != null &&
                      (e.position - _downPosition!).distance > 28) {
                    _cancelHold(notifyEarly: true);
                  }
                },
                onPointerUp: _releaseHold,
                onPointerCancel: (e) {
                  if (_pointer == e.pointer) _cancelHold(notifyEarly: false);
                },
                child: Container(
                  constraints: const BoxConstraints(minHeight: 72),
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: radius,
                    border: Border.all(
                      color: _showFocus
                          ? tokens.emphasis
                          : (widget.isHighContrast
                                ? scheme.outline
                                : scheme.primary),
                      width: _showFocus
                          ? tokens.borderWidth.clamp(2.0, 4.0) + 1
                          : (widget.isHighContrast ? tokens.borderWidth : 1.5),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: _controller.value.clamp(0.0, 1.0),
                            heightFactor: 1.0,
                            child: Container(
                              color: scheme.onPrimary.withValues(alpha: 0.16),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: LinearProgressIndicator(
                          value: _controller.value,
                          minHeight: 8,
                          color: scheme.onPrimary,
                          backgroundColor: scheme.onPrimary.withValues(
                            alpha: 0.25,
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: tokens.spacingUnit * 1.5,
                          vertical: tokens.spacingUnit * 1.5 + 4,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.touch_app_rounded,
                                  color: scheme.onPrimary,
                                  size: tokens.iconSize,
                                ),
                                SizedBox(width: tokens.spacingUnit),
                                Flexible(
                                  child: Text(
                                    _holding
                                        ? widget.activeLabel
                                        : widget.idleLabel,
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: scheme.onPrimary,
                                    ),
                                    textAlign: TextAlign.center,
                                    softWrap: true,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: tokens.spacingUnit * 0.5),
                            Text(
                              widget.instruction,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                              softWrap: true,
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
    required this.screenTitle,
    required this.profile,
    required this.strings,
    required this.onDone,
  });

  final _TransferReceipt receipt;
  final String screenTitle;
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onDone();
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(screenTitle, softWrap: true),
        ),
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
      ),
    );
  }
}
