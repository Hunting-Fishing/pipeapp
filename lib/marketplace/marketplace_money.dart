import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

final NumberFormat _cadMoney =
    NumberFormat.currency(locale: 'en_CA', symbol: r'$', decimalDigits: 2);
final NumberFormat _moneyInputWhole = NumberFormat.decimalPattern('en_CA');

/// Consistent, readable marketplace currency such as `$100,000.00`.
String marketplaceMoney(num value) => _cadMoney.format(value);

/// Reads a user-entered monetary value whether or not it contains separators.
num? marketplaceMoneyValue(String value) {
  final clean = value.replaceAll(RegExp(r'[^0-9.]'), '');
  if (clean.isEmpty) return null;
  return num.tryParse(clean);
}

/// Adds thousands separators while preserving up to two decimal places.
///
/// Currency symbols belong in the field decoration, so persisted values stay
/// numeric and calculations never depend on a localized display string.
class MarketplaceMoneyInputFormatter extends TextInputFormatter {
  const MarketplaceMoneyInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final raw = newValue.text.replaceAll(RegExp(r'[^0-9.]'), '');
    if (raw.isEmpty) return const TextEditingValue();

    final firstDecimal = raw.indexOf('.');
    final wholeRaw = firstDecimal < 0 ? raw : raw.substring(0, firstDecimal);
    final fractionRaw = firstDecimal < 0 ? '' : raw.substring(firstDecimal + 1);
    final whole = int.tryParse(wholeRaw.isEmpty ? '0' : wholeRaw) ?? 0;
    final formattedWhole = _moneyInputWhole.format(whole);
    final hasDecimal = firstDecimal >= 0;
    final fraction = fractionRaw.substring(0, fractionRaw.length.clamp(0, 2));
    final formatted = '$formattedWhole${hasDecimal ? '.$fraction' : ''}';
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
