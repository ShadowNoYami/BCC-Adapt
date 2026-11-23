import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/money_formatter.dart';
import '../../../core/voice/domain/recipient_matcher.dart';
import '../domain/bank_models.dart';

/// Mock repository & state notifier for BCC Bank (`#bcc карта` with 245 800 ₸,
/// quick contacts: Дочь Алия, Сын Арман, Коммунальные услуги, and history).
class MockBankRepository extends Notifier<BankDashboardState> {
  static const BankAccount initialPrimaryAccount = BankAccount(
    id: 'bcc_card_primary',
    titleRu: '#bcc карта',
    titleKk: '#bcc карта',
    maskedPan: '• 4890',
    iban: 'KZ868562204115894890',
    balanceTenge: 245800,
    cashbackTenge: 3420,
  );

  static const List<QuickContact> initialQuickContacts = [
    QuickContact(
      id: 'contact_aliya',
      titleRu: 'Дочь Алия',
      titleKk: 'Қызым Әлия',
      phoneOrAccount: '+7 701 234 56 78',
      category: QuickContactCategory.family,
      aliases: ['Алия', 'Алие', 'Әлия', 'Дочь', 'Дочке', 'Қызым'],
      defaultAmountTenge: 10000,
    ),
    QuickContact(
      id: 'contact_arman',
      titleRu: 'Сын Арман',
      titleKk: 'Ұлым Арман',
      phoneOrAccount: '+7 707 123 45 67',
      category: QuickContactCategory.family,
      aliases: ['Арман', 'Арману', 'Арманға', 'Сын', 'Сыну', 'Ұлым'],
      defaultAmountTenge: 15000,
    ),
    QuickContact(
      id: 'contact_utilities',
      titleRu: 'Коммунальные услуги',
      titleKk: 'Коммуналдық қызметтер',
      phoneOrAccount: 'ЕРЦ Алматы • Л/С 0491823',
      category: QuickContactCategory.utilities,
      aliases: [
        'Коммунальные',
        'Коммуналка',
        'Квитанция',
        'Свет',
        'Вода',
        'Коммуналдық',
      ],
      defaultAmountTenge: 18500,
    ),
  ];

  static final List<BankTransaction> initialTransactions = [
    BankTransaction(
      id: 'tx_1',
      titleRu: 'Пенсионная выплата ГЦВП',
      titleKk: 'Зейнетақы төлемі МЗТО',
      subtitleRu: 'Пополнение #bcc карта',
      subtitleKk: '#bcc картасын толтыру',
      amountTenge: 142000,
      timestamp: DateTime.utc(2026, 11, 14, 9, 15),
      type: BankTransactionType.incoming,
    ),
    BankTransaction(
      id: 'tx_2',
      titleRu: 'Сын Арман',
      titleKk: 'Ұлым Арман',
      subtitleRu: 'Перевод по номеру +7 707 123 45 67',
      subtitleKk: '+7 707 123 45 67 нөміріне аударым',
      amountTenge: -15000,
      timestamp: DateTime.utc(2026, 11, 12, 16, 40),
      type: BankTransactionType.transfer,
    ),
    BankTransaction(
      id: 'tx_3',
      titleRu: 'Коммунальные услуги (Алсеко)',
      titleKk: 'Коммуналдық қызметтер (Алсеко)',
      subtitleRu: 'Платеж без комиссии BCC',
      subtitleKk: 'Комиссиясыз BCC төлемі',
      amountTenge: -18450,
      timestamp: DateTime.utc(2026, 11, 10, 11, 20),
      type: BankTransactionType.utilityPayment,
    ),
    BankTransaction(
      id: 'tx_4',
      titleRu: 'Аптека «Биосфера»',
      titleKk: '«Биосфера» дәріханасы',
      subtitleRu: 'Покупка по карте • Кешбэк 5%',
      subtitleKk: 'Картамен сатып алу • Кешбэк 5%',
      amountTenge: -4800,
      timestamp: DateTime.utc(2026, 11, 8, 14, 5),
      type: BankTransactionType.cardPurchase,
    ),
    BankTransaction(
      id: 'tx_5',
      titleRu: 'Дочь Алия',
      titleKk: 'Қызым Әлия',
      subtitleRu: 'Перевод от близких',
      subtitleKk: 'Жақындардан аударым',
      amountTenge: 25000,
      timestamp: DateTime.utc(2026, 11, 5, 19, 30),
      type: BankTransactionType.incoming,
    ),
  ];

  @override
  BankDashboardState build() {
    return BankDashboardState(
      primaryAccount: initialPrimaryAccount,
      quickContacts: initialQuickContacts,
      transactions: initialTransactions,
    );
  }

  /// Resolves a quick contact by spoken name or phone query.
  QuickContact? findContact(String? query) {
    if (query == null || query.trim().isEmpty) return null;
    final digits = query.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 10) {
      final tail = digits.substring(digits.length - 10);
      for (final c in state.quickContacts) {
        final cDigits = c.phoneOrAccount.replaceAll(RegExp(r'\D'), '');
        if (cDigits.endsWith(tail)) return c;
      }
    }
    for (final c in state.quickContacts) {
      if (RecipientMatcher.matches(query, c.allSearchCandidates)) {
        return c;
      }
    }
    return null;
  }

  /// Executes a mock transfer, deducting from `#bcc карта` using exact tiyn
  /// math and appending a transaction entry. Returns `true` if successful.
  bool executeTransfer({
    required double amountTenge,
    required String recipientTitleRu,
    String? recipientTitleKk,
    String? details,
  }) {
    final amountTiyn = MoneyFormatter.toTiyn(amountTenge);
    final balanceTiyn = MoneyFormatter.toTiyn(state.primaryAccount.balanceTenge);
    if (amountTiyn <= 0 || amountTiyn > balanceTiyn) {
      return false;
    }

    final remainingTiyn = balanceTiyn - amountTiyn;
    final updatedAccount = state.primaryAccount.copyWith(
      balanceTenge: remainingTiyn / 100.0,
    );

    final newTx = BankTransaction(
      id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
      titleRu: recipientTitleRu,
      titleKk: recipientTitleKk ?? recipientTitleRu,
      subtitleRu: details ?? 'Перевод с #bcc карта',
      subtitleKk: details ?? '#bcc картасынан аударым',
      amountTenge: -amountTiyn / 100.0,
      timestamp: DateTime.now().toUtc(),
      type: BankTransactionType.transfer,
    );

    state = state.copyWith(
      primaryAccount: updatedAccount,
      transactions: [newTx, ...state.transactions],
    );
    return true;
  }

  void resetDemoData() {
    state = build();
  }
}

final mockBankRepositoryProvider =
    NotifierProvider<MockBankRepository, BankDashboardState>(
  MockBankRepository.new,
);
