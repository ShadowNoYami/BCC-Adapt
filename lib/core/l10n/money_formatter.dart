import 'package:intl/intl.dart';

/// Tenge formatting: `245800` -> `245 800 ₸` (non-breaking spaces, so the
/// amount never wraps across lines at large text scales).
abstract final class MoneyFormatter {
  static const String tengeSign = '₸';
  static const String _nbsp = '\u00A0';

  static String format(
    num amount, {
    String localeCode = 'ru',
    bool withSign = false,
    bool showTiyn = false,
  }) {
    final pattern = showTiyn ? '#,##0.00' : '#,##0';
    final formatter = NumberFormat(pattern, _intlLocale(localeCode));
    final body = formatter
        .format(amount.abs())
        // Normalise any grouping char (space, NNBSP) to a plain NBSP.
        .replaceAll(RegExp(r'[\s\u202F]'), _nbsp);
    final sign = amount < 0 ? '−' : (withSign && amount > 0 ? '+' : '');
    return '$sign$body$_nbsp$tengeSign';
  }

  static String _intlLocale(String code) => code == 'kk' ? 'kk' : 'ru';
}
