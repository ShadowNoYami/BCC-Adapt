import 'package:flutter/foundation.dart';

enum QuickContactCategory { family, utilities, other }

enum BankTransactionType { incoming, transfer, utilityPayment, cardPurchase }

/// Bank account / card entity (e.g., `#bcc карта`).
@immutable
class BankAccount {
  const BankAccount({
    required this.id,
    required this.titleRu,
    required this.titleKk,
    required this.maskedPan,
    required this.iban,
    required this.balanceTenge,
    this.currencySymbol = '₸',
    this.cashbackTenge = 0,
  });

  final String id;
  final String titleRu;
  final String titleKk;
  final String maskedPan;
  final String iban;
  final double balanceTenge;
  final String currencySymbol;
  final double cashbackTenge;

  String localizedTitle(String localeCode) =>
      localeCode == 'kk' ? titleKk : titleRu;

  BankAccount copyWith({double? balanceTenge, double? cashbackTenge}) {
    return BankAccount(
      id: id,
      titleRu: titleRu,
      titleKk: titleKk,
      maskedPan: maskedPan,
      iban: iban,
      balanceTenge: balanceTenge ?? this.balanceTenge,
      currencySymbol: currencySymbol,
      cashbackTenge: cashbackTenge ?? this.cashbackTenge,
    );
  }
}

/// Quick transfer / utility recipient template.
@immutable
class QuickContact {
  const QuickContact({
    required this.id,
    required this.titleRu,
    required this.titleKk,
    required this.phoneOrAccount,
    required this.category,
    this.aliases = const [],
    this.defaultAmountTenge,
  });

  final String id;
  final String titleRu;
  final String titleKk;
  final String phoneOrAccount;
  final QuickContactCategory category;

  /// Spoken aliases for voice matching ("Алия", "Дочь", "Арман", "Коммуналка").
  final List<String> aliases;
  final double? defaultAmountTenge;

  String localizedTitle(String localeCode) =>
      localeCode == 'kk' ? titleKk : titleRu;

  List<String> get allSearchCandidates => [titleRu, titleKk, ...aliases];
}

/// Single operation in the account history.
@immutable
class BankTransaction {
  const BankTransaction({
    required this.id,
    required this.titleRu,
    required this.titleKk,
    required this.subtitleRu,
    required this.subtitleKk,
    required this.amountTenge,
    required this.timestamp,
    required this.type,
  });

  final String id;
  final String titleRu;
  final String titleKk;
  final String subtitleRu;
  final String subtitleKk;

  /// Negative for outgoing debits, positive for incoming credits.
  final double amountTenge;
  final DateTime timestamp;
  final BankTransactionType type;

  bool get isCredit => amountTenge > 0;

  String localizedTitle(String localeCode) =>
      localeCode == 'kk' ? titleKk : titleRu;

  String localizedSubtitle(String localeCode) =>
      localeCode == 'kk' ? subtitleKk : subtitleRu;
}

/// Immutable snapshot of the user's BCC banking state.
@immutable
class BankDashboardState {
  const BankDashboardState({
    required this.primaryAccount,
    required this.quickContacts,
    required this.transactions,
  });

  final BankAccount primaryAccount;
  final List<QuickContact> quickContacts;
  final List<BankTransaction> transactions;

  BankDashboardState copyWith({
    BankAccount? primaryAccount,
    List<QuickContact>? quickContacts,
    List<BankTransaction>? transactions,
  }) {
    return BankDashboardState(
      primaryAccount: primaryAccount ?? this.primaryAccount,
      quickContacts: quickContacts ?? this.quickContacts,
      transactions: transactions ?? this.transactions,
    );
  }
}
