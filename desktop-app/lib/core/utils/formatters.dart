import 'package:intl/intl.dart';

class Formatters {
  static final NumberFormat _currencyFormat = NumberFormat.currency(
    symbol: 'KES ',
    decimalDigits: 2,
  );

  static final NumberFormat _compactCurrencyFormat = NumberFormat.currency(
    symbol: 'KES ',
    decimalDigits: 0,
  );

  static final DateFormat _dateTimeFormat = DateFormat('dd MMM yyyy, HH:mm');
  static final DateFormat _dateFormat = DateFormat('dd MMM yyyy');
  static final DateFormat _timeFormat = DateFormat('HH:mm');

  static String formatCurrency(num amount) {
    return _currencyFormat.format(amount);
  }

  static String formatCompactCurrency(num amount) {
    return _compactCurrencyFormat.format(amount);
  }

  static String formatDateTime(DateTime dateTime) {
    return _dateTimeFormat.format(dateTime);
  }

  static String formatDate(DateTime dateTime) {
    return _dateFormat.format(dateTime);
  }

  static String formatTime(DateTime dateTime) {
    return _timeFormat.format(dateTime);
  }

  static String generateReceiptNumber(String branchCode) {
    final now = DateTime.now();
    final dateStr = DateFormat('yyMMdd').format(now);
    final timeStr = DateFormat('HHmmss').format(now);
    return '$branchCode-$dateStr-$timeStr';
  }
}
