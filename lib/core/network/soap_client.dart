import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../config/app_config.dart';

class SoapException implements Exception {
  SoapException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Minimal SOAP 1.1 client compatible with the legacy IceSOAP envelopes.
///
/// Every legacy operation returns a single result node (`DatamReport`,
/// `Login`, `DataStock`, ...) whose child elements (`Pref1`, `Code`, ...)
/// are flattened into a [Map].
class SoapClient {
  SoapClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<Map<String, String>> call({
    required String host,
    required String operation,
    required Map<String, String> parameters,
  }) async {
    final envelope = XmlBuilder()
      ..processing('xml', 'version="1.0" encoding="utf-8"')
      ..element(
        'soap:Envelope',
        attributes: {
          'xmlns:soap': 'http://schemas.xmlsoap.org/soap/envelope/',
          'xmlns:xsi': 'http://www.w3.org/2001/XMLSchema-instance',
          'xmlns:xsd': 'http://www.w3.org/2001/XMLSchema',
        },
        nest: () {
          XmlBuilder().element(
            'soap:Body',
            nest: () {
              XmlBuilder().element(
                operation,
                attributes: {'xmlns': AppConfig.soapNamespace},
                nest: () {
                  parameters.forEach((key, value) {
                    XmlBuilder().element(key, nest: value);
                  });
                },
              );
            },
          );
        },
      );

    http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse(AppConfig.serviceUrl(host)),
            headers: {
              'Content-Type': 'text/xml; charset=utf-8',
              'SOAPAction': '${AppConfig.soapNamespace}$operation',
            },
            body: utf8.encode(envelope.buildDocument().toXmlString()),
          )
          .timeout(const Duration(seconds: 45));
    } on TimeoutException {
      throw SoapException('Koneksi ke server timeout. Coba lagi.');
    } catch (_) {
      throw SoapException(
        'Gagal terhubung ke server. Periksa koneksi internet Anda.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SoapException('Server merespons ${response.statusCode}.');
    }
    return parseResult(response.body);
  }

  static Map<String, String> parseResult(String xmlBody) {
    XmlDocument document;
    try {
      document = XmlDocument.parse(xmlBody);
    } catch (_) {
      throw SoapException('Respons server tidak valid.');
    }

    final fault = document.findAllElements('faultstring').firstOrNull;
    if (fault != null && fault.innerText.trim().isNotEmpty) {
      throw SoapException(fault.innerText.trim());
    }

    final result = <String, String>{};
    for (final element in document.descendants.whereType<XmlElement>()) {
      if (element.children.any((c) => c is XmlElement)) continue;
      result.putIfAbsent(element.localName, () => element.innerText.trim());
    }
    return result;
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
