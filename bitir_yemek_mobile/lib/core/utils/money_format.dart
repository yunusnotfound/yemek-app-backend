import 'package:intl/intl.dart';

/// TL is supported by the brand font on every device; retain kurus at checkout.
String formatMoney(num value, {bool compact = false}) =>
    '${NumberFormat.currency(locale: 'tr_TR', symbol: '', decimalDigits: compact && value == value.round() ? 0 : 2).format(value).trim()} TL';
