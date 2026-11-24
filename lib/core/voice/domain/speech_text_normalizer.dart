import 'amount_in_words.dart';
import 'number_lexicon.dart';

/// Pure-Dart TTS text normalizer for Russian (`ru`) and Kazakh (`kk`).
///
/// Guarantees that:
/// 1. When speaking Kazakh (`kk`), every raw ASCII digit (`0-9`), amount in
///    tenge (`245 800 ₸`, `100,50 ₸`), percentage (`200%`), fractional/whole
///    second (`1,5 сек`, `5 сек`), step progress (`Шаг 1 из 3`, `1 / 3`,
///    `1-қадам, барлығы 3`), and phone number (`+7 707 999 88 77`) is converted
///    into natural Kazakh words using [AmountInWords] and [NumberLexicon].
/// 2. When speaking Russian (`ru`), currency symbols, percentages, abbreviations
///    and phone prefixes are expanded into natural spoken Russian.
/// 3. Line breaks (`\n`), bullet markers (`•`) and spaced slashes (` / `) are
///    turned into clean punctuation pauses so TTS sounds human and unhurried.
class SpeechTextNormalizer {
  const SpeechTextNormalizer();

  static const String _cyrillicAndLatin =
      r'A-Za-zА-Яа-яЁёӘәҒғҚқҢңӨөҰұҮүҺһІі';

  /// Matches `#bcc` / `#BCC` so TTS does not read out "решётка" / "хэштег".
  static final RegExp _hashTagWord = RegExp(
    r'#([' + _cyrillicAndLatin + r']+)',
  );

  /// Matches tenge amounts such as `245 800 ₸`, `245\u00A0800\u00A0₸`,
  /// `100,50 ₸`, `15 000 ₸`, `−100,50 ₸`.
  static final RegExp _tengeAmountPattern = RegExp(
    r'(?<![\d' +
        _cyrillicAndLatin +
        r'])([+−-])?(\d{1,3}(?:[ \u00A0\u202F]\d{3})+|\d+)(?:[.,](\d{1,2}))?[ \u00A0\u202F]*₸',
  );

  /// Matches KZ/RU 11-digit phone numbers like `+7 707 999 88 77`,
  /// `+7 (707) 123-45-67`, `8 777 999 88 77`, `+77079998877`.
  static final RegExp _kzPhonePattern = RegExp(
    r'(?<!\d)(\+7|8)[ \u00A0\-]?\(?(\d{3})\)?[ \u00A0\-]?(\d{3})[ \u00A0\-]?(\d{2})[ \u00A0\-]?(\d{2})(?!\d)',
  );

  /// Matches generic international phone numbers starting with `+` and >= 7 digits.
  static final RegExp _intlPhonePattern = RegExp(
    r'(?<!\d)\+(\d(?:[ \u00A0\-()]?\d){6,14})(?!\d)',
  );

  /// Matches percentages like `200%`, `150%`, `14.5%`, `100 %`.
  static final RegExp _percentPattern = RegExp(
    r'(?<!\d)([+−-])?(\d{1,3}(?:[ \u00A0\u202F]\d{3})+|\d+)(?:[.,](\d+))?[ \u00A0\u202F]*%',
  );

  /// Matches Russian step progress `Шаг 1 из 3` (case-insensitive).
  static final RegExp _ruStepPattern = RegExp(
    r'шаг[ \u00A0]+(\d+)[ \u00A0]+из[ \u00A0]+(\d+)',
    caseSensitive: false,
  );

  /// Matches Kazakh `1-қадам, барлығы 3`.
  static final RegExp _kkStepTotalPattern = RegExp(
    r'(\d+)[ \u00A0]*-[ \u00A0]*қадам[ \u00A0]*,[ \u00A0]*барлығы[ \u00A0]+(\d+)',
    caseSensitive: false,
  );

  /// Matches Kazakh `1-қадам`.
  static final RegExp _kkSingleStepPattern = RegExp(
    r'(\d+)[ \u00A0]*-[ \u00A0]*қадам',
    caseSensitive: false,
  );

  /// Matches compact step fractions like `1 / 3` or `2/3` (not dates `01/02/2026`).
  static final RegExp _slashStepPattern = RegExp(
    r'(?<![\d/])(\d{1,2})[ \u00A0]*/[ \u00A0]*(\d{1,2})(?![\d/])',
  );

  /// Matches seconds expressions in Kazakh/Russian text: `1,5 сек`, `5 сек`,
  /// `1,5 секунд`, `1.5с`.
  static final RegExp _kkSecondsPattern = RegExp(
    r'(?<!\d)(\d+)(?:[.,](\d+))?[ \u00A0]*(?:секунд(?:а|ы)?|сек\.?|с)(?![' +
        _cyrillicAndLatin +
        r'])',
    caseSensitive: false,
  );

  /// Matches Russian `1,5 сек` / `1.5 секунд` / `1.5с`.
  static final RegExp _ruOneAndHalfSecondsPattern = RegExp(
    r'(?<!\d)1[.,]5[ \u00A0]*(?:секунд(?:а|ы)?|сек\.?|с)(?![' +
        _cyrillicAndLatin +
        r'])',
    caseSensitive: false,
  );

  /// Matches Russian `сек` / `сек.` abbreviation.
  static final RegExp _ruSecAbbrevPattern = RegExp(
    r'(?<![' + _cyrillicAndLatin + r'])сек\.?(?![' + _cyrillicAndLatin + r'])',
    caseSensitive: false,
  );

  /// Matches compact Russian seconds like `5с` or `10с`.
  static final RegExp _ruCompactSecondsPattern = RegExp(
    r'(?<!\d)(\d+)[ \u00A0]*с(?![' + _cyrillicAndLatin + r'])',
    caseSensitive: false,
  );

  /// Matches scale multipliers like `1.5×` or `2×`.
  static final RegExp _multiplierPattern = RegExp(
    r'(?<!\d)(\d+)(?:[.,](\d+))?[ \u00A0]*[×]',
  );

  /// Matches remaining decimal numbers like `1,5` or `14.5` (not `12.05.2026`).
  static final RegExp _decimalPattern = RegExp(
    r'(?<![\d.,])([+−-])?(\d+)[.,](\d+)(?![\d.,])',
  );

  /// Matches grouped integers (`245 800`, `15 000`) or plain integers (`4829`).
  static final RegExp _integerPattern = RegExp(
    r'(\d{1,3}(?:[ \u00A0\u202F]\d{3})+|\d+)',
  );

  /// Matches Russian `+7` phone prefix.
  static final RegExp _ruPlusSevenPattern = RegExp(
    r'(?<!\d)\+7(?=[ \u00A0\-\(\d]|$)',
  );

  /// Matches Russian `ЖКХ` abbreviation.
  static final RegExp _zhkhPattern = RegExp(
    r'(?<![' + _cyrillicAndLatin + r'])ЖКХ(?![' + _cyrillicAndLatin + r'])',
    caseSensitive: false,
  );

  /// Matches immediately repeated identical Kazakh amount sentences produced by
  /// templates that show both formatted digits and spelled-out words, e.g.
  /// `екі жүз ... теңге. Екі жүз ... теңге.`.
  static final RegExp _duplicateKkAmountSentence = RegExp(
    r'([а-яёәғқңөұүһі ]+(?:теңге|тиын))\.\s+([А-ЯЁӘҒҚҢӨҰҮҺІа-яёәғқңөұүһі ]+(?:теңге|тиын))(?=[.!?,;:]|$)',
  );

  /// Normalizes [text] for natural TTS playback in [localeCode] (`'kk'` or `'ru'`).
  String normalize(String text, {required String localeCode}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return '';

    var result = trimmed
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll('…', '.');

    // Remove '#' before brand tags such as `#bcc`.
    result = result.replaceAllMapped(_hashTagWord, (m) {
      final word = m.group(1)!;
      return word.toLowerCase() == 'bcc' ? 'BCC' : word;
    });

    if (localeCode == 'kk') {
      result = _normalizeKazakh(result);
    } else {
      result = _normalizeRussian(result);
    }

    result = _applyNaturalPauses(result);

    if (localeCode == 'kk') {
      // Absolute safety invariant: no raw ASCII digits may ever reach TTS in KK.
      result = _replaceRemainingDigitsKk(result);
      result = _deduplicateKkAmountEcho(result);
    }

    return _cleanupWhitespaceAndPunctuation(result);
  }

  // ---------------------------------------------------------------------------
  // Kazakh (kk)
  // ---------------------------------------------------------------------------

  String _normalizeKazakh(String input) {
    var s = input;

    // 1. Tenge amounts (`245 800 ₸`, `100,50 ₸`, `15 000 ₸`).
    s = s.replaceAllMapped(_tengeAmountPattern, (m) {
      final sign = m.group(1);
      final wholeRaw = _stripSpaces(m.group(2)!);
      final fracRaw = m.group(3);

      final whole = int.tryParse(wholeRaw);
      final tiyn = fracRaw == null
          ? 0
          : (fracRaw.length == 1
                ? int.parse(fracRaw) * 10
                : int.parse(fracRaw));

      final signPrefix = switch (sign) {
        '-' || '−' => 'минус ',
        '+' => 'плюс ',
        _ => '',
      };

      if (whole != null && whole < 1000000000000) {
        final amount = whole + tiyn / 100.0;
        final spoken = AmountInWords.format(
          amount,
          localeCode: 'kk',
          tiynInWords: true,
        ).toLowerCase();
        return '$signPrefix$spoken';
      }

      // Fallback for huge numbers beyond 999 billion.
      final wholeWords = NumberLexicon.digitsToWords(wholeRaw, localeCode: 'kk');
      if (tiyn > 0) {
        final tiynWords = NumberLexicon.intToWords(tiyn, localeCode: 'kk');
        return '$signPrefix$wholeWords теңге $tiynWords тиын';
      }
      return '$signPrefix$wholeWords теңге';
    });

    // 2. Phone numbers (`+7 707 999 88 77`, `8 777 999 88 77`, `+7 (707) 123-45-67`).
    s = s.replaceAllMapped(_kzPhonePattern, (m) {
      final prefix = m.group(1)!;
      final g1 = m.group(2)!;
      final g2 = m.group(3)!;
      final g3 = m.group(4)!;
      final g4 = m.group(5)!;

      final head = prefix == '+7'
          ? 'плюс ${NumberLexicon.digitToWord(7, localeCode: 'kk')}'
          : NumberLexicon.digitToWord(8, localeCode: 'kk');

      return '$head, '
          '${NumberLexicon.digitsToWords(g1, localeCode: 'kk')}, '
          '${NumberLexicon.digitsToWords(g2, localeCode: 'kk')}, '
          '${NumberLexicon.digitsToWords(g3, localeCode: 'kk')}, '
          '${NumberLexicon.digitsToWords(g4, localeCode: 'kk')}';
    });

    s = s.replaceAllMapped(_intlPhonePattern, (m) {
      final raw = m.group(1)!;
      final groups = raw
          .split(RegExp(r'[ \u00A0\-()]+'))
          .where((g) => g.isNotEmpty)
          .map((g) => NumberLexicon.digitsToWords(g, localeCode: 'kk'))
          .where((g) => g.isNotEmpty)
          .toList();
      return 'плюс ${groups.join(', ')}';
    });

    // 3. Percentages (`200%`, `150%`, `14.5%`).
    s = s.replaceAllMapped(_percentPattern, (m) {
      final sign = m.group(1);
      final wholeRaw = _stripSpaces(m.group(2)!);
      final fracRaw = m.group(3);
      final signPrefix = switch (sign) {
        '-' || '−' => 'минус ',
        '+' => 'плюс ',
        _ => '',
      };
      final numWords = _kkNumberPhrase(wholeRaw, fracRaw);
      return '$signPrefix$numWords пайыз';
    });

    // 4. Steps (`Шаг 1 из 3`, `1-қадам, барлығы 3`, `1 / 3`, `1-қадам`).
    s = s.replaceAllMapped(_ruStepPattern, (m) {
      final current = int.parse(m.group(1)!);
      final total = int.parse(m.group(2)!);
      return '${NumberLexicon.kkAblative(total)} ${NumberLexicon.kkOrdinal(current)} қадам';
    });

    s = s.replaceAllMapped(_kkStepTotalPattern, (m) {
      final current = int.parse(m.group(1)!);
      final total = int.parse(m.group(2)!);
      return '${NumberLexicon.kkAblative(total)} ${NumberLexicon.kkOrdinal(current)} қадам';
    });

    s = s.replaceAllMapped(_kkSingleStepPattern, (m) {
      final current = int.parse(m.group(1)!);
      return '${NumberLexicon.kkOrdinal(current)} қадам';
    });

    s = s.replaceAllMapped(_slashStepPattern, (m) {
      final current = int.parse(m.group(1)!);
      final total = int.parse(m.group(2)!);
      if (total > 0 && current > 0 && current <= total) {
        return '${NumberLexicon.kkAblative(total)} ${NumberLexicon.kkOrdinal(current)} қадам';
      }
      return '${NumberLexicon.intToWords(current, localeCode: 'kk')}, '
          '${NumberLexicon.intToWords(total, localeCode: 'kk')}';
    });

    // 5. Fractional and whole seconds (`1,5 сек`, `5 сек`, `1.5с`).
    s = s.replaceAllMapped(_kkSecondsPattern, (m) {
      final wholeRaw = m.group(1)!;
      final fracRaw = m.group(2);
      return '${_kkNumberPhrase(wholeRaw, fracRaw)} секунд';
    });

    // 6. Scale multipliers (`1.5×`).
    s = s.replaceAllMapped(_multiplierPattern, (m) {
      return '${_kkNumberPhrase(m.group(1)!, m.group(2))} есе';
    });

    // 7. Remaining decimals (`1,5`, `14.5`).
    s = s.replaceAllMapped(_decimalPattern, (m) {
      final sign = m.group(1);
      final signPrefix = switch (sign) {
        '-' || '−' => 'минус ',
        '+' => 'плюс ',
        _ => '',
      };
      return '$signPrefix${_kkNumberPhrase(m.group(2)!, m.group(3))}';
    });

    // 8. Remaining integers (`245 800`, `4829`, `50`, `0`).
    s = _replaceRemainingDigitsKk(s);

    // 9. Standalone currency/percent/utility symbols.
    s = s
        .replaceAll(_zhkhPattern, 'коммуналдық қызметтер')
        .replaceAll('₸', ' теңге')
        .replaceAll('%', ' пайыз')
        .replaceAll('−', 'минус ');

    return s;
  }

  String _replaceRemainingDigitsKk(String input) {
    return input.replaceAllMapped(_integerPattern, (m) {
      final raw = _stripSpaces(m.group(1)!);
      final parsed = int.tryParse(raw);
      if (parsed == null) {
        return NumberLexicon.digitsToWords(raw, localeCode: 'kk');
      }
      return NumberLexicon.intToWords(parsed, localeCode: 'kk');
    });
  }

  String _kkNumberPhrase(String wholeRaw, String? fracRaw) {
    final wholeParsed = int.tryParse(wholeRaw);
    final wholeWords = wholeParsed != null
        ? NumberLexicon.intToWords(wholeParsed, localeCode: 'kk')
        : NumberLexicon.digitsToWords(wholeRaw, localeCode: 'kk');

    if (fracRaw == null || fracRaw.isEmpty) {
      return wholeWords;
    }

    // Handle leading zeros in fractional part (e.g. `1,05` -> `бір бүтін нөл бес`),
    // while keeping `1,5` -> `бір бүтін бес`, `1,25` -> `бір бүтін жиырма бес`.
    var leadingZeros = 0;
    while (leadingZeros < fracRaw.length && fracRaw[leadingZeros] == '0') {
      leadingZeros++;
    }
    final parts = <String>[];
    for (var i = 0; i < leadingZeros; i++) {
      parts.add(NumberLexicon.digitToWord(0, localeCode: 'kk'));
    }
    final rest = fracRaw.substring(leadingZeros);
    if (rest.isNotEmpty) {
      final restParsed = int.tryParse(rest);
      parts.add(
        restParsed != null
            ? NumberLexicon.intToWords(restParsed, localeCode: 'kk')
            : NumberLexicon.digitsToWords(rest, localeCode: 'kk'),
      );
    }

    return '$wholeWords бүтін ${parts.join(' ')}';
  }

  String _deduplicateKkAmountEcho(String input) {
    return input.replaceAllMapped(_duplicateKkAmountSentence, (m) {
      final first = m.group(1)!.trim();
      final second = m.group(2)!.trim();
      if (first.toLowerCase() == second.toLowerCase()) {
        return first;
      }
      return m.group(0)!;
    });
  }

  // ---------------------------------------------------------------------------
  // Russian (ru)
  // ---------------------------------------------------------------------------

  String _normalizeRussian(String input) {
    var s = input;

    // 1. Natural Russian `1,5 сек` / `1.5 секунд` -> `полторы секунды`.
    s = s.replaceAll(_ruOneAndHalfSecondsPattern, 'полторы секунды');

    // 2. Remaining `сек` / `сек.` -> `секунд`, and compact `5с` -> `5 секунд`.
    s = s.replaceAll(_ruSecAbbrevPattern, 'секунд');
    s = s.replaceAllMapped(_ruCompactSecondsPattern, (m) => '${m.group(1)} секунд');

    // 3. Phone prefix `+7` -> `плюс семь`.
    s = s.replaceAllMapped(_ruPlusSevenPattern, (m) {
      final nextIndex = m.end;
      final needsSpace =
          nextIndex < s.length &&
          RegExp(r'[\d\(]').hasMatch(s[nextIndex]);
      return needsSpace ? 'плюс семь ' : 'плюс семь';
    });

    // 4. Utility abbreviation `ЖКХ` -> `коммунальные услуги`.
    s = s.replaceAll(_zhkhPattern, 'коммунальные услуги');

    // 5. Currency & percent symbols.
    s = s
        .replaceAllMapped(RegExp(r'(\d)[ \u00A0\u202F]*₸'), (m) => '${m.group(1)} тенге')
        .replaceAll('₸', 'тенге')
        .replaceAllMapped(RegExp(r'(\d)[ \u00A0\u202F]*%'), (m) => '${m.group(1)} процентов')
        .replaceAll('%', 'процентов')
        .replaceAll('−', 'минус ');

    return s;
  }

  // ---------------------------------------------------------------------------
  // Natural pauses & punctuation cleanup
  // ---------------------------------------------------------------------------

  String _applyNaturalPauses(String input) {
    var s = input;

    // Normalize non-breaking spaces to regular spaces.
    s = s.replaceAll(RegExp(r'[\u00A0\u202F]'), ' ');

    // Line breaks -> sentence pauses (avoid doubling existing punctuation).
    s = s.replaceAllMapped(RegExp(r'[ \t]*\n+[ \t]*'), (m) {
      final before = s.substring(0, m.start).trimRight();
      if (before.isEmpty) return '';
      final lastChar = before[before.length - 1];
      if (const {'.', '!', '?', ';', ':', ','}.contains(lastChar)) {
        return ' ';
      }
      return '. ';
    });

    // Bullet markers (`•` or masked runs like `••••`) -> clean comma pauses.
    s = s.replaceAllMapped(RegExp(r'[ \t]*•+[ \t]*'), (m) {
      final before = s.substring(0, m.start).trimRight();
      if (before.isEmpty) return '';
      final lastChar = before[before.length - 1];
      if (const {'.', '!', '?', ';', ':', ','}.contains(lastChar)) {
        return ' ';
      }
      return ', ';
    });

    // Spaced slashes (` / `) -> natural comma pause.
    s = s.replaceAll(RegExp(r'[ \t]+/[ \t]+'), ', ');

    return s;
  }

  String _cleanupWhitespaceAndPunctuation(String input) {
    var s = input;
    s = s.replaceAll(RegExp(r'[ \t]+'), ' ');
    s = s.replaceAll(RegExp(r' ([.,!?;:])'), r'$1');
    s = s.replaceAll(RegExp(r',{2,}'), ',');
    s = s.replaceAll(RegExp(r'\.{2,}'), '.');
    s = s.replaceAll(RegExp(r'([.!?]),'), r'$1');
    s = s.replaceAll(RegExp(r',([.!?])'), r'$1');
    s = s.replaceAll(RegExp(r'^[,;:\s]+'), '');
    return s.trim();
  }

  static String _stripSpaces(String raw) =>
      raw.replaceAll(RegExp(r'[ \u00A0\u202F]'), '');
}
