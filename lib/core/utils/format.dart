import 'package:intl/intl.dart';

final _rupiah = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
);
final _number = NumberFormat.decimalPattern('id_ID');

double parseDouble(String? value) {
  if (value == null) return 0;
  var text = value
      .replaceAll('Rp.', '')
      .replaceAll('Rp', '')
      .trim()
      .replaceAll(' ', '');
  if (text.isEmpty || text == '-') return 0;
  // Server mixes id_ID (1.000,50) and en_US (1,000.50) formats.
  if (text.contains(',') && text.contains('.')) {
    text = text.lastIndexOf(',') > text.lastIndexOf('.')
        ? text.replaceAll('.', '').replaceAll(',', '.')
        : text.replaceAll(',', '');
  } else if (text.contains(',')) {
    text = text.replaceAll(',', '.');
  }
  return double.tryParse(text) ?? 0;
}

int parseInt(String? value) => parseDouble(value).round();

String formatRupiah(num value) => _rupiah.format(value);
String formatNumber(num value) => _number.format(value);

String formatDate(DateTime date) => '${date.month}/${date.day}/${date.year}';

String displayDate(DateTime date) =>
    DateFormat('dd MMM yyyy', 'id_ID').format(date);

int uomFactor(String descUom) {
  final parts = descUom
      .split(RegExp(r'[=\s]+'))
      .where((e) => e.isNotEmpty)
      .toList();
  for (final part in parts.reversed) {
    final value = int.tryParse(part);
    if (value != null && value > 0) return value;
  }
  return 1;
}

List<String> splitPref(String? value) {
  if (value == null || value.isEmpty || value == '-') return const [];
  return value.split('|');
}

String at(List<String> values, int index) =>
    index >= 0 && index < values.length ? values[index].trim() : '';
