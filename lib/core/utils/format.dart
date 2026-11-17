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

/// Angka setelah `=` di UOM1, mis. `QTY/SET = 143 PACK` → 143
/// atau `QTY/PACK = 0.0769231 SET` → 0.0769231
double? parseUomNumber(String descUom) {
  final match = RegExp(r'=\s*([0-9]+(?:[.,][0-9]+)?)').firstMatch(descUom);
  if (match == null) return null;
  return parseDouble(match.group(1));
}

/// Pack per 1 SET.
/// - Format baru `QTY/SET = 143 PACK` + stok 11 → 143/11 = 13
/// - Format lama `QTY/PACK = 0.0769231 SET` → 1/0.0769231 ≈ 13
double packsPerSet(String descUom, [int stock = 0]) {
  final n = parseUomNumber(descUom);
  if (n == null || n <= 0) return 1;
  final upper = descUom.toUpperCase();
  final isSetEqualsPack =
      upper.contains('QTY/SET') || RegExp(r'QTY/\s*SET').hasMatch(upper);
  if (isSetEqualsPack && stock > 0) return n / stock;
  if (n < 1) return 1 / n;
  return n;
}

/// Qty order (SET) maksimum = stok SET.
int maxOrderQty(int stock, String descUom) {
  if (stock <= 0) return 0;
  return stock;
}

/// Factor harga baris: qty sudah dalam UOM order (SET), harga per SET → 1.
/// Jangan pakai angka PACK dari UOM1 (bisa 143) sebagai pengali harga.
int uomFactor(String descUom) {
  final n = parseUomNumber(descUom);
  if (n == null) return 1;
  // Format lama kadang dipakai sebagai pengali kecil; int factor harga = 1.
  return 1;
}

String formatPacks(num value) {
  if (value == value.roundToDouble()) return formatNumber(value.round());
  return formatNumber(double.parse(value.toStringAsFixed(4)));
}

List<String> splitPref(String? value) {
  if (value == null || value.isEmpty || value == '-') return const [];
  return value.split('|');
}

String at(List<String> values, int index) =>
    index >= 0 && index < values.length ? values[index].trim() : '';
