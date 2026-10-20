import 'package:flutter_test/flutter_test.dart';
import 'package:venus_jmi_group/core/network/soap_client.dart';
import 'package:venus_jmi_group/core/utils/format.dart';
import 'package:venus_jmi_group/data/models/models.dart';

void main() {
  test('SOAP result flattens Pref fields', () {
    final result = SoapClient.parseResult('''
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <LoginResponse xmlns="http://VenusERPJMIGroupClientMServices.org/">
      <LoginResult>
        <DatamReport>
          <Pref1>BR01</Pref1>
          <Pref2>Jakarta</Pref2>
        </DatamReport>
      </LoginResult>
    </LoginResponse>
  </soap:Body>
</soap:Envelope>
''');
    expect(result['Pref1'], 'BR01');
    expect(result['Pref2'], 'Jakarta');
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
