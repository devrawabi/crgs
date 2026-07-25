import 'package:intl/intl.dart';

abstract final class CurrencyFormatter {
  static const symbol = 'QAR';

  static String format(num amount, {int decimalDigits = 0}) {
    return NumberFormat.currency(
      locale: 'en_QA',
      symbol: '$symbol ',
      decimalDigits: decimalDigits,
    ).format(amount);
  }

  static String compact(num amount) {
    return NumberFormat.compactCurrency(
      locale: 'en_QA',
      symbol: '$symbol ',
    ).format(amount);
  }

  static String shorthand(num amount) {
    if (amount >= 1000000) {
      return '$symbol ${(amount / 1000000).toStringAsFixed(1)}M';
    }
    if (amount >= 1000) {
      return '$symbol ${(amount / 1000).toStringAsFixed(1)}K';
    }
    return format(amount);
  }
}
