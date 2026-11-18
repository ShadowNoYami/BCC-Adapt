/// Spoken-number parsing for Russian and Kazakh (pure Dart, no Flutter).
///
/// Handles digits ("15000", "15 000", "1,5"), attached shortcuts ("15к",
/// "2млн"), words ("пять тысяч", "две тысячи пятьсот", "полторы тысячи",
/// "бес мың", "екі мың бес жүз") and mixed forms ("5 тысяч", "2 мың").
library;

enum NumberTokenKind {
  /// 0..9 (and "полтора/полторы" = 1.5).
  unit,

  /// 10..19 in Russian ("десять", "пятнадцать").
  teen,

  /// 20..90 (and Kazakh "он" = 10, which can take a unit: "он бес").
  ten,

  /// Additive hundreds in Russian ("сто", "пятьсот").
  hundred,

  /// Multiplicative Kazakh hundred ("бес жүз" = 5 * 100).
  multiplicativeHundred,

  /// 1000 / 1e6 / 1e9 multipliers.
  scale,

  /// A digit literal.
  digits,
}

class NumberToken {
  const NumberToken(this.kind, this.value);
  final NumberTokenKind kind;
  final double value;
}

/// Result of parsing a number span inside a token list.
class NumberSpan {
  const NumberSpan({
    required this.value,
    required this.start,
    required this.endExclusive,
  });

  final double value;
  final int start;
  final int endExclusive;
}

abstract final class NumberLexicon {
  static const Map<String, NumberToken> _words = {
    // ---- Russian units ----------------------------------------------------
    'ноль': NumberToken(NumberTokenKind.unit, 0),
    'один': NumberToken(NumberTokenKind.unit, 1),
    'одна': NumberToken(NumberTokenKind.unit, 1),
    'одну': NumberToken(NumberTokenKind.unit, 1),
    'одно': NumberToken(NumberTokenKind.unit, 1),
    'одного': NumberToken(NumberTokenKind.unit, 1),
    'два': NumberToken(NumberTokenKind.unit, 2),
    'две': NumberToken(NumberTokenKind.unit, 2),
    'двух': NumberToken(NumberTokenKind.unit, 2),
    'три': NumberToken(NumberTokenKind.unit, 3),
    'трех': NumberToken(NumberTokenKind.unit, 3),
    'четыре': NumberToken(NumberTokenKind.unit, 4),
    'четырех': NumberToken(NumberTokenKind.unit, 4),
    'пять': NumberToken(NumberTokenKind.unit, 5),
    'пяти': NumberToken(NumberTokenKind.unit, 5),
    'шесть': NumberToken(NumberTokenKind.unit, 6),
    'шести': NumberToken(NumberTokenKind.unit, 6),
    'семь': NumberToken(NumberTokenKind.unit, 7),
    'семи': NumberToken(NumberTokenKind.unit, 7),
    'восемь': NumberToken(NumberTokenKind.unit, 8),
    'восьми': NumberToken(NumberTokenKind.unit, 8),
    'девять': NumberToken(NumberTokenKind.unit, 9),
    'девяти': NumberToken(NumberTokenKind.unit, 9),
    'полтора': NumberToken(NumberTokenKind.unit, 1.5),
    'полторы': NumberToken(NumberTokenKind.unit, 1.5),
    // ---- Russian teens ----------------------------------------------------
    'десять': NumberToken(NumberTokenKind.teen, 10),
    'одиннадцать': NumberToken(NumberTokenKind.teen, 11),
    'двенадцать': NumberToken(NumberTokenKind.teen, 12),
    'тринадцать': NumberToken(NumberTokenKind.teen, 13),
    'четырнадцать': NumberToken(NumberTokenKind.teen, 14),
    'пятнадцать': NumberToken(NumberTokenKind.teen, 15),
    'шестнадцать': NumberToken(NumberTokenKind.teen, 16),
    'семнадцать': NumberToken(NumberTokenKind.teen, 17),
    'восемнадцать': NumberToken(NumberTokenKind.teen, 18),
    'девятнадцать': NumberToken(NumberTokenKind.teen, 19),
    // ---- Russian tens -----------------------------------------------------
    'двадцать': NumberToken(NumberTokenKind.ten, 20),
    'тридцать': NumberToken(NumberTokenKind.ten, 30),
    'сорок': NumberToken(NumberTokenKind.ten, 40),
    'пятьдесят': NumberToken(NumberTokenKind.ten, 50),
    'шестьдесят': NumberToken(NumberTokenKind.ten, 60),
    'семьдесят': NumberToken(NumberTokenKind.ten, 70),
    'восемьдесят': NumberToken(NumberTokenKind.ten, 80),
    'девяносто': NumberToken(NumberTokenKind.ten, 90),
    // ---- Russian hundreds -------------------------------------------------
    'сто': NumberToken(NumberTokenKind.hundred, 100),
    'двести': NumberToken(NumberTokenKind.hundred, 200),
    'триста': NumberToken(NumberTokenKind.hundred, 300),
    'четыреста': NumberToken(NumberTokenKind.hundred, 400),
    'пятьсот': NumberToken(NumberTokenKind.hundred, 500),
    'шестьсот': NumberToken(NumberTokenKind.hundred, 600),
    'семьсот': NumberToken(NumberTokenKind.hundred, 700),
    'восемьсот': NumberToken(NumberTokenKind.hundred, 800),
    'девятьсот': NumberToken(NumberTokenKind.hundred, 900),
    // ---- Russian scales ---------------------------------------------------
    'тысяча': NumberToken(NumberTokenKind.scale, 1e3),
    'тысячи': NumberToken(NumberTokenKind.scale, 1e3),
    'тысяч': NumberToken(NumberTokenKind.scale, 1e3),
    'тысячу': NumberToken(NumberTokenKind.scale, 1e3),
    'тыс': NumberToken(NumberTokenKind.scale, 1e3),
    'косарь': NumberToken(NumberTokenKind.scale, 1e3),
    'миллион': NumberToken(NumberTokenKind.scale, 1e6),
    'миллиона': NumberToken(NumberTokenKind.scale, 1e6),
    'миллионов': NumberToken(NumberTokenKind.scale, 1e6),
    'млн': NumberToken(NumberTokenKind.scale, 1e6),
    'миллиард': NumberToken(NumberTokenKind.scale, 1e9),
    'миллиарда': NumberToken(NumberTokenKind.scale, 1e9),
    'миллиардов': NumberToken(NumberTokenKind.scale, 1e9),
    'млрд': NumberToken(NumberTokenKind.scale, 1e9),
    // ---- Kazakh -----------------------------------------------------------
    'нөл': NumberToken(NumberTokenKind.unit, 0),
    'бір': NumberToken(NumberTokenKind.unit, 1),
    'екі': NumberToken(NumberTokenKind.unit, 2),
    'үш': NumberToken(NumberTokenKind.unit, 3),
    'төрт': NumberToken(NumberTokenKind.unit, 4),
    'бес': NumberToken(NumberTokenKind.unit, 5),
    'алты': NumberToken(NumberTokenKind.unit, 6),
    'жеті': NumberToken(NumberTokenKind.unit, 7),
    'сегіз': NumberToken(NumberTokenKind.unit, 8),
    'тоғыз': NumberToken(NumberTokenKind.unit, 9),
    'он': NumberToken(NumberTokenKind.ten, 10),
    'жиырма': NumberToken(NumberTokenKind.ten, 20),
    'отыз': NumberToken(NumberTokenKind.ten, 30),
    'қырық': NumberToken(NumberTokenKind.ten, 40),
    'елу': NumberToken(NumberTokenKind.ten, 50),
    'алпыс': NumberToken(NumberTokenKind.ten, 60),
    'жетпіс': NumberToken(NumberTokenKind.ten, 70),
    'сексен': NumberToken(NumberTokenKind.ten, 80),
    'тоқсан': NumberToken(NumberTokenKind.ten, 90),
    'жүз': NumberToken(NumberTokenKind.multiplicativeHundred, 100),
    'мың': NumberToken(NumberTokenKind.scale, 1e3),
  };

  /// Kazakh case / possessive endings that can be glued to numerals
  /// ("мыңды", "жүзді", "мыңнан").
  static const List<String> _kkSuffixes = [
    'дан', 'ден', 'тан', 'тен', 'нан', 'нен', //
    'ды', 'ді', 'ты', 'ті', 'ны', 'ні', //
    'ға', 'ге', 'қа', 'ке', //
  ];

  static final RegExp _digits = RegExp(r'^\d+(?:\.\d+)?$');

  /// Resolves a single normalised token to a [NumberToken], or `null`.
  static NumberToken? lookup(String token) {
    if (_digits.hasMatch(token)) {
      return NumberToken(NumberTokenKind.digits, double.parse(token));
    }
    final direct = _words[token];
    if (direct != null) return direct;
    for (final suffix in _kkSuffixes) {
      if (token.length > suffix.length + 1 && token.endsWith(suffix)) {
        final stem = token.substring(0, token.length - suffix.length);
        final hit = _words[stem];
        if (hit != null &&
            (hit.kind == NumberTokenKind.scale ||
                hit.kind == NumberTokenKind.multiplicativeHundred)) {
          return hit;
        }
      }
    }
    return null;
  }

  static bool isNumeric(String token) => lookup(token) != null;

  /// Finds the first valid number span in [tokens] (already normalised).
  static NumberSpan? findFirst(List<String> tokens) {
    for (var i = 0; i < tokens.length; i++) {
      if (lookup(tokens[i]) == null) continue;
      final span = parseAt(tokens, i);
      if (span != null && span.value > 0) return span;
    }
    return null;
  }

  /// Greedily parses a number starting at [start] using a strict
  /// grammar-transition table, so "пять пять" or "сто сто" are NOT merged.
  static NumberSpan? parseAt(List<String> tokens, int start) {
    double total = 0;
    double group = 0;
    double? lastScale;
    NumberTokenKind? last;
    var i = start;

    bool allowed(NumberTokenKind next) {
      if (last == null) return true;
      switch (last) {
        case NumberTokenKind.unit:
          return next == NumberTokenKind.multiplicativeHundred ||
              next == NumberTokenKind.scale;
        case NumberTokenKind.teen:
        case NumberTokenKind.digits:
          return next == NumberTokenKind.scale;
        case NumberTokenKind.ten:
          return next == NumberTokenKind.unit || next == NumberTokenKind.scale;
        case NumberTokenKind.hundred:
          return next == NumberTokenKind.unit ||
              next == NumberTokenKind.teen ||
              next == NumberTokenKind.ten ||
              next == NumberTokenKind.scale;
        case NumberTokenKind.multiplicativeHundred:
          return next == NumberTokenKind.unit ||
              next == NumberTokenKind.ten ||
              next == NumberTokenKind.scale;
        case NumberTokenKind.scale:
          return next != NumberTokenKind.scale;
      }
    }

    for (; i < tokens.length; i++) {
      final t = lookup(tokens[i]);
      if (t == null || !allowed(t.kind)) break;

      switch (t.kind) {
        case NumberTokenKind.unit:
        case NumberTokenKind.teen:
        case NumberTokenKind.ten:
        case NumberTokenKind.hundred:
        case NumberTokenKind.digits:
          group += t.value;
        case NumberTokenKind.multiplicativeHundred:
          if (group >= 10) return _finish(total, group, start, i);
          group = (group == 0 ? 1 : group) * 100;
        case NumberTokenKind.scale:
          if (lastScale != null && t.value >= lastScale) {
            return _finish(total, group, start, i);
          }
          total += (group == 0 ? 1 : group) * t.value;
          group = 0;
          lastScale = t.value;
      }
      last = t.kind;
    }
    return _finish(total, group, start, i);
  }

  static NumberSpan? _finish(double total, double group, int start, int end) {
    if (end == start) return null;
    return NumberSpan(value: total + group, start: start, endExclusive: end);
  }
}
