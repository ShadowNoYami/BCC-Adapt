import 'package:intl/intl.dart';

/// Tenge & tiyn formatting with integer-tiyn precision:
/// * `245800` -> `245 800 ₸` (whole numbers omit `.00`)
/// * `100.50` -> `100,50 ₸` (non-zero tiyns keep exact 2 decimals)
///
/// Uses non-breaking spaces so amounts never wrap across lines at large scales.
abstract final class MoneyFormatter {
  static const String tengeSign = '₸';
  static const String _nbsp = '\u00A0';

  /// Converts a numeric tenge [amount] to exact integer tiyns (`* 100`).
  static int toTiyn(num amount) => amount.isFinite ? (amount * 100).round() : 0;

  /// Normalizes a numeric tenge [amount] to exact 2-decimal precision.
  static double normalizeAmount(num amount) => toTiyn(amount) / 100.0;

  /// Whether [amount] has a non-zero tiyn fraction.
  static bool hasTiyn(num amount) => toTiyn(amount).abs() % 100 != 0;

  static String format(
    num amount, {
    String localeCode = 'ru',
    bool withSign = false,
    bool? showTiyn,
  }) {
    final totalTiyn = toTiyn(amount);
    final absTiyn = totalTiyn.abs();
    final whole = absTiyn ~/ 100;
    final tiyn = absTiyn % 100;
    final includeTiyn = showTiyn ?? (tiyn != 0);

    final formatter = NumberFormat('#,##0', _intlLocale(localeCode));
    final wholeBody = formatter
        .format(whole)
        // Normalise any grouping char (space, NNBSP) to a plain NBSP.
        .replaceAll(RegExp(r'[\s\u202F]'), _nbsp);
    final body = includeTiyn
        ? '$wholeBody,${tiyn.toString().padLeft(2, '0')}'
        : wholeBody;
    final sign = totalTiyn < 0 ? '−' : (withSign && totalTiyn > 0 ? '+' : '');
    return '$sign$body$_nbsp$tengeSign';
  }

  static String _intlLocale(String code) => code == 'kk' ? 'kk' : 'ru';
}
