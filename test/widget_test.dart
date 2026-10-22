import 'package:flutter_test/flutter_test.dart';
import 'package:venus_jmi_group/core/network/api_client.dart';
import 'package:venus_jmi_group/core/utils/format.dart';
import 'package:venus_jmi_group/data/models/models.dart';

void main() {
  test('REST result decodes Pref fields from JSON', () {
    final result = ApiClient.decodeResult(
      '{"Pref1":"BR01","Pref2":"Jakarta","Pref3":null,"Status":"1"}',
    );
    expect(result['Pref1'], 'BR01');
    expect(result['Pref2'], 'Jakarta');
    expect(result['Pref3'], '');
    expect(result['Status'], '1');
  });

  test('REST error payload raises ApiException', () {
    expect(
      () => ApiClient.decodeResult('{"error":"upstream boom"}'),
      throwsA(isA<ApiException>()),
    );
  });

  test('Product parses pipe-delimited Pref payload', () {
    final products = Product.fromPref({
      'Pref1': 'a.jpg',
      'Pref2': 'P001',
      'Pref3': 'Produk A',
      'Pref4': '10000',
      'Pref5': 'Deskripsi',
      'Pref6': 'PCS = 12',
      'Pref7': '24',
      'Pref8': 'CAT1',
      'Pref9': '0',
      'Pref10': 'Alias A',
    });
    expect(products, hasLength(1));
    expect(products.first.maxQty, 2);
    expect(formatRupiah(products.first.price), contains('10.000'));
  });
}
