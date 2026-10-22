import 'package:flutter/foundation.dart';

class Company {
  const Company({
    required this.businessCode,
    required this.name,
    required this.shortName,
    required this.imageFolder,
    required this.tagline,
  });

  final String businessCode;
  final String name;
  final String shortName;
  final String imageFolder;
  final String tagline;

  static const jmi = Company(
    businessCode: 'VenusERP10',
    name: 'PT Jaya Makmur Indonesia',
    shortName: 'JMI',
    imageFolder: 'JMI_Images',
    tagline: 'Distribusi & perdagangan umum',
  );
  static const mcc = Company(
    businessCode: 'VenusERP21',
    name: 'PT Mega Cahaya Cilacap',
    shortName: 'MCC',
    imageFolder: 'MCC_Images',
    tagline: 'Distribusi wilayah Cilacap',
  );
  static const mmi = Company(
    businessCode: 'VenusERP25',
    name: 'PT Mainan Mandiri Indonesia',
    shortName: 'MMI',
    imageFolder: 'MMI_Images',
    tagline: 'Mainan & produk anak',
  );

  static const all = [jmi, mcc, mmi];

  static Company byCode(String? code) =>
      all.firstWhere((c) => c.businessCode == code, orElse: () => jmi);

  static Company byShortName(String? value) =>
      all.firstWhere((c) => c.shortName == value, orElse: () => jmi);
}

abstract final class AppConfig {
  static const packageName = 'com.Sinergi.VenusERPJMGroup_Client';
  static const defaultHost = 'production2.sinergiteknologi.co.id';
  static const servicePath =
      '/VenusERPJMIGroupClientMServices/mobileservices.asmx';
  static const soapNamespace = 'http://VenusERPJMIGroupClientMServices.org/';
  static const mediaBase =
      'http://$defaultHost/VenusERPJMIGroupClientMServices';

  /// Optional CORS proxy prefix for web builds, e.g.
  /// `--dart-define=CORS_PROXY=http://localhost:8898/`.
  /// The target URL is appended verbatim: `<proxy><full service URL>`.
  /// Leave empty when the web app is hosted on the same origin as the
  /// ASMX service or the server already sends CORS headers.
  static const corsProxy = String.fromEnvironment('CORS_PROXY');

  /// Base URL of the Node.js REST API (NewAPIVenusERPJMGroup).
  /// Override with `--dart-define=API_BASE=https://...` when needed.
  static const apiBase = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'https://api.sinergiteknologi.co.id/NewAPIVenusERPJMGroup',
  );

  /// Same-origin serverless proxy (see `api/proxy.js`) used by web builds
  /// when no [corsProxy] is given. Keeps HTTPS pages from calling the
  /// HTTP-only ASMX backend directly (mixed content + CORS).
  static const webProxyPath = '/api/proxy';

  static String resolvedHost(String host) =>
      host.isEmpty ? defaultHost : host;

  static String serviceUrl(String host) =>
      'http://${resolvedHost(host)}$servicePath';

  static String proxiedUrl(String host, String path) =>
      '$webProxyPath?host=${resolvedHost(host)}&path=${Uri.encodeComponent(path)}';

  static String imageUrl(Company company, String fileName) {
    final name = fileName.trim();
    if (name.isEmpty || name == '-') return '';
    if (name.startsWith('https://')) return name;
    if (name.startsWith('http://')) {
      if (!kIsWeb) return name;
      final uri = Uri.parse(name);
      return proxiedUrl(uri.host, uri.path);
    }
    if (kIsWeb) {
      return proxiedUrl(
        defaultHost,
        '/VenusERPJMIGroupClientMServices/${company.imageFolder}/$name',
      );
    }
    return '$mediaBase/${company.imageFolder}/$name';
  }
}
