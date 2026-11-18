import 'package:flutter/foundation.dart';

import '../../l10n/money_formatter.dart';
import 'amount_in_words.dart';
import 'number_lexicon.dart';

enum RecipientKind { none, phone, name }

/// Structured result of a spoken transfer command.
///
/// This is only a *draft* — the UI must always show [amountInWords] and the
/// recipient for explicit confirmation before any money moves.
@immutable
class VoiceTransferIntent {
  const VoiceTransferIntent({
    required this.rawText,
    this.amount,
    this.recipientQuery,
    this.recipientKind = RecipientKind.none,
    this.normalizedPhone,
    this.amountInWords,
    this.amountFormatted,
  });

  final String rawText;
  final double? amount;

  /// Phone in display format (`+7 707 123 45 67`) or name phrase (`Арману`).
  final String? recipientQuery;
  final RecipientKind recipientKind;

  /// E.164 phone (`+77071234567`) when [recipientKind] is phone.
  final String? normalizedPhone;

  /// "Сто тысяч тенге" / "Жүз мың теңге".
  final String? amountInWords;

  /// "100 000 ₸".
  final String? amountFormatted;

  bool get hasAmount => amount != null && amount! > 0;
  bool get hasRecipient => recipientKind != RecipientKind.none;
  bool get isComplete => hasAmount && hasRecipient;

  @override
  String toString() => 'VoiceTransferIntent(amount: $amount, '
      'recipient: $recipientQuery [$recipientKind], words: $amountInWords)';
}

/// Deterministic parser for spoken transfer commands in RU / KK.
///
/// Examples:
/// * «Перевести пять тысяч тенге на номер 8 707 123 45 67»
/// * «Отправить 15000 Арману»
/// * «Арманға екі мың бес жүз теңге жібер»
class VoiceTransferParser {
  const VoiceTransferParser();

  /// Upper bound protecting against misrecognised giant numbers.
  static const double maxAmount = 100000000;

  static final RegExp _phone = RegExp(
    r'(?<!\d)(?:(?:\+\s?7|8|7)[\s\-()]*)?(7\d{2})[\s\-()]*(\d{3})[\s\-]*(\d{2})[\s\-]*(\d{2})(?!\d)',
  );
  static final RegExp _thousandGroups =
      RegExp(r'(?<=\d)[\s\u00A0\u202F.,](?=\d{3}(?!\d))');
  static final RegExp _decimal = RegExp(r'(\d),(\d)');
  static final RegExp _kShortcut =
      RegExp(r'(\d)\s?[кkК](?![\p{L}])', unicode: true);
  static final RegExp _digitLetter = RegExp(r'(\d)(\p{L})', unicode: true);
  static final RegExp _letterDigit = RegExp(r'(\p{L})(\d)', unicode: true);
  static final RegExp _splitter = RegExp(r'[^\p{L}\d.]+', unicode: true);

  /// Words removed when extracting the recipient phrase.
  static const Set<String> _stopWords = {
    // RU verbs / fillers
    'перевести', 'переведи', 'переведите', 'перевод', 'переводить',
    'отправить', 'отправь', 'отправьте', 'отправка', 'скинуть', 'скинь',
    'кинь', 'кинуть', 'перекинь', 'перекинуть', 'закинь', 'закинуть',
    'хочу', 'хотел', 'хотела', 'надо', 'нужно', 'пожалуйста', 'пж',
    'сделать', 'сделай', 'можно', 'мне', 'деньги', 'денег',
    // RU prepositions / nouns
    'на', 'по', 'для', 'к', 'в', 'и', 'с', 'со', 'от',
    'номер', 'номеру', 'телефон', 'телефону', 'карту', 'карта', 'карте',
    'счет', 'счету', 'сумму', 'сумма', 'суммой',
    // Currency
    'тенге', 'теңге', 'теңгені', 'тг', 'тиын', 'тиынов', 'рублей',
    // KK verbs / fillers
    'аудар', 'аудару', 'аударыңыз', 'аударшы', 'жібер', 'жіберу',
    'жіберші', 'жіберіңіз', 'салу', 'сал', 'салшы', 'өтінемін', 'ақша',
    'ақшаны', 'маған', 'керек', 'нөмір', 'нөмірге', 'нөміріне',
    'картаға', 'шотқа',
  };

  VoiceTransferIntent parse(String text, {String localeCode = 'ru'}) {
    final raw = text.trim();
    if (raw.isEmpty) return VoiceTransferIntent(rawText: text);

    // 1. Phone first — so its digits never leak into the amount.
    String? phone;
    var rest = raw;
    final phoneMatch = _phone.firstMatch(raw);
    if (phoneMatch != null) {
      phone = '+7${phoneMatch.group(1)}${phoneMatch.group(2)}'
          '${phoneMatch.group(3)}${phoneMatch.group(4)}';
      rest = raw.replaceRange(phoneMatch.start, phoneMatch.end, ' ');
    }

    // 2. Tokenise (keeping original casing for names).
    final original = tokenize(rest);
    final normalized =
        original.map((t) => t.toLowerCase().replaceAll('ё', 'е')).toList();

    // 3. Amount.
    final span = NumberLexicon.findFirst(normalized);
    double? amount = span?.value;
    if (amount != null && (amount <= 0 || amount > maxAmount)) amount = null;

    // 4. Recipient.
    RecipientKind kind = RecipientKind.none;
    String? recipient;
    if (phone != null) {
      kind = RecipientKind.phone;
      recipient = formatPhone(phone);
    } else {
      final words = <String>[];
      for (var i = 0; i < original.length; i++) {
        if (span != null && i >= span.start && i < span.endExclusive) continue;
        final n = normalized[i];
        if (_stopWords.contains(n) || NumberLexicon.isNumeric(n)) continue;
        if (n.length < 2) continue;
        words.add(original[i]);
      }
      if (words.isNotEmpty) {
        kind = RecipientKind.name;
        recipient = words.join(' ');
      }
    }

    return VoiceTransferIntent(
      rawText: text,
      amount: amount,
      recipientQuery: recipient,
      recipientKind: kind,
      normalizedPhone: phone,
      amountInWords: amount == null
          ? null
          : AmountInWords.format(amount, localeCode: localeCode),
      amountFormatted: amount == null
          ? null
          : MoneyFormatter.format(amount,
              localeCode: localeCode, showTiyn: amount % 1 != 0),
    );
  }

  /// Splits text into tokens, merging "15 000" -> "15000", "1,5" -> "1.5",
  /// "15к" -> "15 тыс", "5тысяч" -> "5 тысяч".
  @visibleForTesting
  static List<String> tokenize(String text) {
    final s = text
        .replaceAll('₸', ' тенге ')
        .replaceAll(_thousandGroups, '')
        .replaceAllMapped(_decimal, (m) => '${m[1]}.${m[2]}')
        .replaceAllMapped(_kShortcut, (m) => '${m[1]} тыс')
        .replaceAllMapped(_digitLetter, (m) => '${m[1]} ${m[2]}')
        .replaceAllMapped(_letterDigit, (m) => '${m[1]} ${m[2]}');
    return s
        .split(_splitter)
        .map((t) => t.replaceAll(RegExp(r'^\.+|\.+$'), ''))
        .where((t) => t.isNotEmpty)
        .toList();
  }

  /// `+77071234567` -> `+7 707 123 45 67`.
  static String formatPhone(String e164) {
    final d = e164.replaceAll(RegExp(r'\D'), '');
    if (d.length != 11) return e164;
    return '+${d[0]} ${d.substring(1, 4)} ${d.substring(4, 7)} '
        '${d.substring(7, 9)} ${d.substring(9, 11)}';
  }
}
