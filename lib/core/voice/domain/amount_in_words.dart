/// Converts monetary amounts into words (RU / KK) for visual and spoken
/// double-checking before a transfer: `100000` -> "Сто тысяч тенге".
abstract final class AmountInWords {
  static String format(num amount, {String localeCode = 'ru'}) {
    final safe = amount.isFinite && amount >= 0 ? amount : 0;
    final totalTiyn = (safe * 100).round();
    final whole = totalTiyn ~/ 100;
    final tiyn = totalTiyn % 100;
    final isKk = localeCode == 'kk';

    final words = isKk ? _kk(whole) : _ru(whole);
    final currency = isKk ? 'теңге' : 'тенге';
    final buffer = StringBuffer('${_capitalize(words)} $currency');
    if (tiyn > 0) buffer.write(' $tiyn тиын');
    return buffer.toString();
  }

  // ---------------------------------------------------------------------------
  // Russian
  // ---------------------------------------------------------------------------
  static const _ruUnitsMale = [
    '', 'один', 'два', 'три', 'четыре', 'пять', 'шесть', 'семь', 'восемь',
    'девять', //
  ];
  static const _ruUnitsFemale = [
    '', 'одна', 'две', 'три', 'четыре', 'пять', 'шесть', 'семь', 'восемь',
    'девять', //
  ];
  static const _ruTeens = [
    'десять', 'одиннадцать', 'двенадцать', 'тринадцать', 'четырнадцать',
    'пятнадцать', 'шестнадцать', 'семнадцать', 'восемнадцать',
    'девятнадцать', //
  ];
  static const _ruTens = [
    '', '', 'двадцать', 'тридцать', 'сорок', 'пятьдесят', 'шестьдесят',
    'семьдесят', 'восемьдесят', 'девяносто', //
  ];
  static const _ruHundreds = [
    '', 'сто', 'двести', 'триста', 'четыреста', 'пятьсот', 'шестьсот',
    'семьсот', 'восемьсот', 'девятьсот', //
  ];

  static const _ruScales = [
    // (forms one / few / many, female?)
    (['', '', ''], false),
    (['тысяча', 'тысячи', 'тысяч'], true),
    (['миллион', 'миллиона', 'миллионов'], false),
    (['миллиард', 'миллиарда', 'миллиардов'], false),
  ];

  static String _ru(int n) {
    if (n == 0) return 'ноль';
    final parts = <String>[];
    final groups = _splitTriads(n);
    for (var i = groups.length - 1; i >= 0; i--) {
      final g = groups[i];
      if (g == 0) continue;
      final (forms, female) = _ruScales[i.clamp(0, _ruScales.length - 1)];
      parts.add(_ruTriad(g, female));
      if (i > 0) parts.add(_ruPlural(g, forms[0], forms[1], forms[2]));
    }
    return parts.where((p) => p.isNotEmpty).join(' ');
  }

  static String _ruTriad(int n, bool female) {
    final h = n ~/ 100;
    final rest = n % 100;
    final t = rest ~/ 10;
    final u = rest % 10;
    final out = <String>[_ruHundreds[h]];
    if (rest >= 10 && rest < 20) {
      out.add(_ruTeens[rest - 10]);
    } else {
      out
        ..add(_ruTens[t])
        ..add(female ? _ruUnitsFemale[u] : _ruUnitsMale[u]);
    }
    return out.where((p) => p.isNotEmpty).join(' ');
  }

  static String _ruPlural(int n, String one, String few, String many) {
    final mod100 = n % 100;
    final mod10 = n % 10;
    if (mod100 >= 11 && mod100 <= 14) return many;
    if (mod10 == 1) return one;
    if (mod10 >= 2 && mod10 <= 4) return few;
    return many;
  }

  // ---------------------------------------------------------------------------
  // Kazakh
  // ---------------------------------------------------------------------------
  static const _kkUnits = [
    '', 'бір', 'екі', 'үш', 'төрт', 'бес', 'алты', 'жеті', 'сегіз', 'тоғыз',
  ];
  static const _kkTens = [
    '', 'он', 'жиырма', 'отыз', 'қырық', 'елу', 'алпыс', 'жетпіс', 'сексен',
    'тоқсан', //
  ];
  static const _kkScales = ['', 'мың', 'миллион', 'миллиард'];

  static String _kk(int n) {
    if (n == 0) return 'нөл';
    final parts = <String>[];
    final groups = _splitTriads(n);
    for (var i = groups.length - 1; i >= 0; i--) {
      final g = groups[i];
      if (g == 0) continue;
      // "мың" alone for exactly one thousand reads naturally ("мың теңге").
      if (!(i == 1 && g == 1)) parts.add(_kkTriad(g));
      if (i > 0) parts.add(_kkScales[i.clamp(0, _kkScales.length - 1)]);
    }
    return parts.where((p) => p.isNotEmpty).join(' ');
  }

  static String _kkTriad(int n) {
    final h = n ~/ 100;
    final t = (n % 100) ~/ 10;
    final u = n % 10;
    final out = <String>[];
    if (h > 0) {
      if (h > 1) out.add(_kkUnits[h]);
      out.add('жүз');
    }
    out
      ..add(_kkTens[t])
      ..add(_kkUnits[u]);
    return out.where((p) => p.isNotEmpty).join(' ');
  }

  // ---------------------------------------------------------------------------
  static List<int> _splitTriads(int n) {
    final groups = <int>[];
    var rest = n;
    while (rest > 0) {
      groups.add(rest % 1000);
      rest ~/= 1000;
    }
    return groups;
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
