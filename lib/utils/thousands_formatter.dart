import 'package:flutter/services.dart';

// Live-formats a numeric field with thousands separators as the user
// types (28000 -> 28,000). Cursor always lands at the end after a
// reformat — the standard, low-risk approach banking/finance apps use for
// amount fields, since people type/backspace from the end almost always.
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;

    final raw = newValue.text.replaceAll(',', '');
    final parts = raw.split('.');
    String integerPart = parts[0].replaceAll(RegExp(r'[^0-9]'), '');
    final String decimalPart = parts.length > 1 ? '.${parts[1].replaceAll(RegExp(r'[^0-9]'), '')}' : (raw.endsWith('.') ? '.' : '');

    integerPart = integerPart.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    if (integerPart.isEmpty) integerPart = '0';

    final buffer = StringBuffer();
    final reversedDigits = integerPart.split('').reversed.toList();
    for (int i = 0; i < reversedDigits.length; i++) {
      if (i != 0 && i % 3 == 0) buffer.write(',');
      buffer.write(reversedDigits[i]);
    }
    final formattedInt = buffer.toString().split('').reversed.join();
    final newText = formattedInt + decimalPart;

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}