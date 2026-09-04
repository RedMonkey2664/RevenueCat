/// Number formatting shared by all three pillars.
///
/// Hand-rolled rather than taken from `intl`'s locale data because the app
/// shows ₹ with Indian digit grouping (1,00,000 — not 100,000) regardless of
/// the device's locale.
library;

/// Formats [value] as rupees with Indian grouping. Always unsigned — callers
/// that need a +/- prefix (P&L) supply it themselves so they control the
/// colour and the sign together.
String formatRupees(num value) {
  final String digits = value.round().abs().toString();
  if (digits.length <= 3) return '₹$digits';

  final String last3 = digits.substring(digits.length - 3);
  String head = digits.substring(0, digits.length - 3);

  final List<String> groups = <String>[];
  while (head.length > 2) {
    groups.insert(0, head.substring(head.length - 2));
    head = head.substring(0, head.length - 2);
  }
  if (head.isNotEmpty) groups.insert(0, head);

  return '₹${groups.join(',')},$last3';
}

/// Signed percentage, e.g. `-24.3%`.
String formatSignedPercent(double value, {int decimals = 1}) {
  final String sign = value >= 0 ? '+' : '-';
  return '$sign${value.abs().toStringAsFixed(decimals)}%';
}
