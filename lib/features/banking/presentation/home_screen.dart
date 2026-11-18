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
import '../../../shared/widgets/adaptive_action_button.dart';
import '../../../shared/widgets/adaptive_card.dart';
import '../../../shared/widgets/bcc_logo.dart';
import '../../../shared/widgets/voice_guide_header.dart';
import '../data/mock_bank_repository.dart';
import '../domain/bank_models.dart';

/// Screen 4: Adaptive BCC Bank Home Screen with **Adaptive Layout Reflow**.
///
/// * When `textScaleFactor < 1.4 && cognitiveMode == fullBanking`: renders a
///   multi-column action grid (`Переводы`, `Платежи`, `Мой банк`, `Кэшбэк`,
///   `Депозиты`) plus promo/analytics blocks.
/// * When `textScaleFactor >= 1.4 || cognitiveMode != fullBanking`: reflows into
///   a strict single-column vertical list (`Column`) of large 64–72 dp cards
///   with only **Переводы**, **Платежи**, and **История операций**, hiding all
///   promotional banners and secondary analytics.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _historySectionKey = GlobalKey();
  late final VoiceAccessibilityService _voiceService;

  @override
  void initState() {
    super.initState();
    _voiceService = ref.read(voiceAccessibilityServiceProvider);
  }

  @override
  void dispose() {
    _voiceService.stopAll();
    super.dispose();
  }

  void _scrollToHistory() {
    final ctx = _historySectionKey.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  QuickContact? _findUtilitiesContact(List<QuickContact> contacts) {
    for (final c in contacts) {
      if (c.category == QuickContactCategory.utilities) return c;
    }
    return null;
  }

  Future<void> _openTransfers({QuickContact? initialContact}) async {
    await ref.read(voiceSessionProvider.notifier).stopAll();
    if (!mounted) return;
    await Navigator.of(context).pushNamed(
      AppRoutes.transfer,
      arguments: initialContact,
    );
  }

  void _showSimpleInfoSheet({
    required String title,
    required String body,
  }) {
    final tokens = AdaptiveTokens.of(context);
    final strings = ref.read(appStringsProvider);
    final theme = Theme.of(context);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.all(tokens.spacingUnit * 2.5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                softWrap: true,
              ),
              SizedBox(height: tokens.spacingUnit * 1.5),
              Text(
                body,
                style: theme.textTheme.bodyLarge,
                softWrap: true,
              ),
              SizedBox(height: tokens.spacingUnit * 2.5),
              AdaptiveActionButton(
                label: strings.closeButton,
                onPressed: () => Navigator.of(sheetCtx).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentAccessibilityProfileProvider);
    final strings = ref.watch(appStringsProvider);
    final bank = ref.watch(mockBankRepositoryProvider);
    final tokens = AdaptiveTokens.of(context);
    final theme = Theme.of(context);

    final isReflowed = profile.textScaleFactor >= 1.4 ||
        profile.cognitiveMode != CognitiveMode.fullBanking;

    final formattedBalance = MoneyFormatter.format(
      bank.primaryAccount.balanceTenge,
      localeCode: profile.localeCode,
    );
    final balanceWords = AmountInWords.format(
      bank.primaryAccount.balanceTenge,
      localeCode: profile.localeCode,
    );
    final utilitiesContact = _findUtilitiesContact(bank.quickContacts);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(tokens.spacingUnit * 2),
          children: [
            // Top Header: Greeting + Language Switcher + >= 48x48 Accessibility btn
            _HomeTopHeader(
              greeting: strings.homeGreeting,
              accessibilityLabel: strings.navAccessibility,
              onOpenAccessibility: () async {
                await ref.read(voiceSessionProvider.notifier).stopAll();
                if (!context.mounted) return;
                await Navigator.of(context)
                    .pushNamed(AppRoutes.accessibilitySettings);
              },
            ),
            SizedBox(height: tokens.spacingUnit * 2),

            VoiceGuideHeader(
              promptText: strings.speakBalanceTemplate(
                formattedBalance,
                balanceWords,
              ),
            ),
            if (profile.voiceAssistantEnabled)
              SizedBox(height: tokens.spacingUnit * 2),

            // #bcc card account summary (zero ellipsis on balance!)
            _AccountBalanceCard(
              accountTitle:
                  '${bank.primaryAccount.localizedTitle(profile.localeCode)} '
                  '${bank.primaryAccount.maskedPan}',
              availableLabel: strings.availableBalanceLabel,
              formattedBalance: formattedBalance,
              balanceWords: balanceWords,
              speakLabel: strings.speakBalanceButton,
              onSpeakBalance: () {
                ref.read(voiceSessionProvider.notifier).speak(
                      strings.speakBalanceTemplate(
                        formattedBalance,
                        balanceWords,
                      ),
                      context: context,
                    );
              },
            ),
            SizedBox(height: tokens.spacingUnit * 2.5),

            // Adaptive Layout Reflow: Grid/Row vs Strict Single-Column List
            if (isReflowed)
              _ReflowedActionsColumn(
                strings: strings,
                tokens: tokens,
                onTransfers: () => _openTransfers(),
                onPayments: () =>
                    _openTransfers(initialContact: utilitiesContact),
                onHistory: _scrollToHistory,
              )
            else ...[
              _FullBankingActionsGrid(
                strings: strings,
                tokens: tokens,
                onTransfers: () => _openTransfers(),
                onPayments: () =>
                    _openTransfers(initialContact: utilitiesContact),
                onMyBank: () => _showSimpleInfoSheet(
                  title: strings.actionMyBank,
                  body:
                      '${bank.primaryAccount.localizedTitle(profile.localeCode)} '
                      '(${bank.primaryAccount.maskedPan})\nIBAN: ${bank.primaryAccount.iban}',
                ),
                onCashback: () => _showSimpleInfoSheet(
                  title: strings.actionCashback,
                  body:
                      '${strings.cashbackBalanceLabel}: '
                      '${MoneyFormatter.format(bank.primaryAccount.cashbackTenge, localeCode: profile.localeCode)}',
                ),
                onDeposits: () => _showSimpleInfoSheet(
                  title: strings.actionDeposits,
                  body: strings.depositPromoText,
                ),
              ),
              SizedBox(height: tokens.spacingUnit * 2),
              _PromoAndAnalyticsBlock(
                strings: strings,
                tokens: tokens,
                localeCode: profile.localeCode,
                cashbackTenge: bank.primaryAccount.cashbackTenge,
              ),
            ],

            SizedBox(height: tokens.spacingUnit * 3),

            // Transaction History
            Container(
              key: _historySectionKey,
              child: Text(
                strings.recentTransactionsTitle,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                softWrap: true,
              ),
            ),
            SizedBox(height: tokens.spacingUnit * 1.5),

            ...bank.transactions.map(
              (tx) => Padding(
                padding: EdgeInsets.only(bottom: tokens.spacingUnit * 1.25),
                child: _TransactionCard(
                  transaction: tx,
                  localeCode: profile.localeCode,
                  twoLineReflow: isReflowed,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeTopHeader extends ConsumerWidget {
  const _HomeTopHeader({
    required this.greeting,
    required this.accessibilityLabel,
    required this.onOpenAccessibility,
  });

  final String greeting;
  final String accessibilityLabel;
  final VoidCallback onOpenAccessibility;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentAccessibilityProfileProvider);
    final tokens = AdaptiveTokens.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final minSide = math.max(48.0, tokens.minTouchTarget);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: double.infinity,
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: tokens.spacingUnit * 1.25,
            runSpacing: tokens.spacingUnit * 1.25,
            children: [
              const BccLogo(),
              Wrap(
                spacing: tokens.spacingUnit,
                runSpacing: tokens.spacingUnit,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const LanguageSwitchButton(),
                  Semantics(
                    button: true,
                    label: accessibilityLabel,
                    excludeSemantics: true,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (tokens.hapticFeedback) {
                          HapticFeedback.selectionClick();
                        }
                        onOpenAccessibility();
                      },
                      icon: ExcludeSemantics(
                        child: Icon(
                          Icons.accessibility_new_rounded,
                          size: tokens.iconSize,
                        ),
                      ),
                      label: Text(
                        accessibilityLabel,
                        softWrap: true,
                      ),
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(minSide, minSide),
                        padding: EdgeInsets.symmetric(
                          horizontal: tokens.spacingUnit * 1.75,
                          vertical: tokens.spacingUnit,
                        ),
                        backgroundColor: profile.isHighContrast
                            ? scheme.primary
                            : scheme.surfaceContainerHighest,
                        foregroundColor: profile.isHighContrast
                            ? scheme.onPrimary
                            : scheme.onSurface,
                        side: BorderSide(
                          color: profile.isHighContrast
                              ? scheme.outline
                              : scheme.primary,
                          width: profile.isHighContrast
                              ? tokens.borderWidth
                              : 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: tokens.spacingUnit * 1.5),
        Text(
          greeting,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
          softWrap: true,
        ),
      ],
    );
  }
}

class _AccountBalanceCard extends StatelessWidget {
  const _AccountBalanceCard({
    required this.accountTitle,
    required this.availableLabel,
    required this.formattedBalance,
    required this.balanceWords,
    required this.speakLabel,
    required this.onSpeakBalance,
  });

  final String accountTitle;
  final String availableLabel;
  final String formattedBalance;
  final String balanceWords;
  final String speakLabel;
  final VoidCallback onSpeakBalance;

  @override
  Widget build(BuildContext context) {
    final tokens = AdaptiveTokens.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AdaptiveCard(
      semanticLabel: '$accountTitle. $availableLabel: $formattedBalance. $balanceWords',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ExcludeSemantics(
                child: Icon(
                  Icons.credit_card_rounded,
                  color: tokens.accentText,
                  size: tokens.iconSize,
                ),
              ),
              SizedBox(width: tokens.spacingUnit),
              Expanded(
                child: Text(
                  accountTitle,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  softWrap: true,
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.spacingUnit * 1.5),
          Text(
            availableLabel,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
            softWrap: true,
          ),
          SizedBox(height: tokens.spacingUnit * 0.5),
          // Strictly NO TextOverflow.ellipsis on balance!
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formattedBalance,
              style: theme.textTheme.displaySmall?.copyWith(
                color: tokens.accentText,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          SizedBox(height: tokens.spacingUnit * 0.75),
          Text(
            balanceWords,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
            softWrap: true,
          ),
          SizedBox(height: tokens.spacingUnit * 2),
          AdaptiveActionButton(
            label: speakLabel,
            icon: Icons.volume_up_rounded,
            variant: AdaptiveButtonVariant.outlined,
            onPressed: onSpeakBalance,
          ),
        ],
      ),
    );
  }
}

/// Strict single-column vertical list for enlarged text (>= 1.4) or simplified /
/// guided cognitive modes.
class _ReflowedActionsColumn extends StatelessWidget {
  const _ReflowedActionsColumn({
    required this.strings,
    required this.tokens,
    required this.onTransfers,
    required this.onPayments,
    required this.onHistory,
  });

  final AppStrings strings;
  final AdaptiveTokens tokens;
  final VoidCallback onTransfers;
  final VoidCallback onPayments;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdaptiveActionButton(
          label: strings.actionTransfers,
          icon: Icons.swap_horiz_rounded,
          minHeightOverride: 64,
          onPressed: onTransfers,
        ),
        SizedBox(height: tokens.spacingUnit * 1.5),
        AdaptiveActionButton(
          label: strings.actionPayments,
          icon: Icons.receipt_long_rounded,
          minHeightOverride: 64,
          variant: AdaptiveButtonVariant.outlined,
          onPressed: onPayments,
        ),
        SizedBox(height: tokens.spacingUnit * 1.5),
        AdaptiveActionButton(
          label: strings.actionHistory,
          icon: Icons.history_rounded,
          minHeightOverride: 64,
          variant: AdaptiveButtonVariant.secondary,
          onPressed: onHistory,
        ),
      ],
    );
  }
}

/// Compact multi-column grid shown only when textScaleFactor < 1.4 and
/// cognitiveMode == fullBanking.
class _FullBankingActionsGrid extends StatelessWidget {
  const _FullBankingActionsGrid({
    required this.strings,
    required this.tokens,
    required this.onTransfers,
    required this.onPayments,
    required this.onMyBank,
    required this.onCashback,
    required this.onDeposits,
  });

  final AppStrings strings;
  final AdaptiveTokens tokens;
  final VoidCallback onTransfers;
  final VoidCallback onPayments;
  final VoidCallback onMyBank;
  final VoidCallback onCashback;
  final VoidCallback onDeposits;

  @override
  Widget build(BuildContext context) {
    final items = [
      (strings.actionTransfers, Icons.swap_horiz_rounded, onTransfers),
      (strings.actionPayments, Icons.receipt_long_rounded, onPayments),
      (strings.actionMyBank, Icons.account_balance_rounded, onMyBank),
      (strings.actionCashback, Icons.percent_rounded, onCashback),
      (strings.actionDeposits, Icons.savings_rounded, onDeposits),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = tokens.spacingUnit * 1.5;
        final cols = constraints.maxWidth >= 480 ? 3 : 2;
        final tileWidth = (constraints.maxWidth - gap * (cols - 1)) / cols;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: items
              .map(
                (item) => SizedBox(
                  width: tileWidth,
                  child: AdaptiveCard(
                    semanticLabel: item.$1,
                    onTap: item.$3,
                    padding: EdgeInsets.all(tokens.spacingUnit * 1.75),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ExcludeSemantics(
                          child: Icon(
                            item.$2,
                            size: tokens.iconSize * 1.15,
                            color: tokens.accentText,
                          ),
                        ),
                        SizedBox(height: tokens.spacingUnit),
                        Text(
                          item.$1,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                          softWrap: true,
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _PromoAndAnalyticsBlock extends StatelessWidget {
  const _PromoAndAnalyticsBlock({
    required this.strings,
    required this.tokens,
    required this.localeCode,
    required this.cashbackTenge,
  });

  final AppStrings strings;
  final AdaptiveTokens tokens;
  final String localeCode;
  final double cashbackTenge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AdaptiveCard(
      backgroundColor: scheme.surfaceContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ExcludeSemantics(
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: tokens.accentText,
                  size: tokens.iconSize,
                ),
              ),
              SizedBox(width: tokens.spacingUnit),
              Expanded(
                child: Text(
                  strings.promoBannerTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  softWrap: true,
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.spacingUnit * 0.75),
          Text(
            strings.promoBannerSubtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
            softWrap: true,
          ),
          SizedBox(height: tokens.spacingUnit * 1.5),
          Wrap(
            spacing: tokens.spacingUnit * 2,
            runSpacing: tokens.spacingUnit,
            children: [
              Text(
                '${strings.analyticsMonthlySpentLabel}: '
                '${MoneyFormatter.format(38250, localeCode: localeCode)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${strings.cashbackBalanceLabel}: '
                '${MoneyFormatter.format(cashbackTenge, localeCode: localeCode)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: tokens.accentText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({
    required this.transaction,
    required this.localeCode,
    required this.twoLineReflow,
  });

  final BankTransaction transaction;
  final String localeCode;
  final bool twoLineReflow;

  @override
  Widget build(BuildContext context) {
    final tokens = AdaptiveTokens.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final title = transaction.localizedTitle(localeCode);
    final subtitle = transaction.localizedSubtitle(localeCode);
    final localDt = transaction.timestamp.toLocal();
    final dateStr = '${localDt.day.toString().padLeft(2, '0')}.'
        '${localDt.month.toString().padLeft(2, '0')}.'
        '${localDt.year}';
    final amountStr = MoneyFormatter.format(
      transaction.amountTenge,
      localeCode: localeCode,
      withSign: true,
    );
    final amountColor =
        transaction.isCredit ? tokens.success : scheme.onSurface;

    if (twoLineReflow) {
      // Strictly 2-row stacked layout: top = title + date, bottom = large amount.
      return AdaptiveCard(
        semanticLabel: '$title, $dateStr, $amountStr',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '$title • $dateStr',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              softWrap: true,
            ),
            SizedBox(height: tokens.spacingUnit),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                amountStr,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: amountColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return AdaptiveCard(
      semanticLabel: '$title, $dateStr, $amountStr',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
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
                SizedBox(height: tokens.spacingUnit * 0.25),
                Text(
                  '$subtitle • $dateStr',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  softWrap: true,
                ),
              ],
            ),
          ),
          SizedBox(width: tokens.spacingUnit * 1.5),
          Text(
            amountStr,
            style: theme.textTheme.titleMedium?.copyWith(
              color: amountColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
