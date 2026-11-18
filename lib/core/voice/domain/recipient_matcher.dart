/// Normalises spoken recipient names for fuzzy, case-insensitive matching
/// across Russian / Kazakh grammatical cases:
/// "Арману" / "Арманға" -> "арман", "Алие" / "Алияға" -> "али".
abstract final class RecipientMatcher {
  static const List<String> _kkCaseSuffixes = [
    'ның', 'нің', 'дың', 'дің', 'тың', 'тің', //
    'ға', 'ге', 'қа', 'ке', 'на', 'не', //
    'ым', 'ім', 'ма', 'ме', //
  ];
  static const List<String> _ruCaseSuffixes = ['ой', 'ей', 'ом', 'ем'];
  static final RegExp _trailingVowels = RegExp('[аяеиоуюыіэ]+\$');
  static final RegExp _nonLetters = RegExp(r'[^\p{L}\d]+', unicode: true);

  static String normalizeWord(String word) {
    var w = word.toLowerCase().replaceAll('ё', 'е').trim();
    for (final s in _kkCaseSuffixes) {
      if (w.length > s.length + 2 && w.endsWith(s)) {
        w = w.substring(0, w.length - s.length);
        break;
      }
    }
    for (final s in _ruCaseSuffixes) {
      if (w.length > s.length + 2 && w.endsWith(s)) {
        w = w.substring(0, w.length - s.length);
        break;
      }
    }
    final stripped = w.replaceAll(_trailingVowels, '');
    return stripped.length >= 2 ? stripped : w;
  }

  static List<String> keys(String phrase) => phrase
      .split(_nonLetters)
      .where((p) => p.isNotEmpty)
      .map(normalizeWord)
      .toList();

  /// `true` when every word of [query] matches some word of any [candidates].
  static bool matches(String query, Iterable<String> candidates) {
    final q = keys(query);
    if (q.isEmpty) return false;
    final c = candidates.expand(keys).toSet();
    return q.every((qw) => c.any((cw) => _wordMatch(qw, cw)));
  }

  static bool _wordMatch(String a, String b) {
    if (a == b) return true;
    final shorter = a.length <= b.length ? a : b;
    final longer = identical(shorter, a) ? b : a;
    return shorter.length >= 4 && longer.startsWith(shorter);
  }
}
