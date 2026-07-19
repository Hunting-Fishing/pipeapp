import 'package:intl/intl.dart';

final NumberFormat _cadMoney =
    NumberFormat.currency(locale: 'en_CA', symbol: r'$', decimalDigits: 2);

/// Consistent, readable marketplace currency such as `$100,000.00`.
String marketplaceMoney(num value) => _cadMoney.format(value);
