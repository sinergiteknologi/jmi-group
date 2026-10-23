import 'package:flutter/foundation.dart';

class Company {
  const Company({
    required this.businessCode,
    required this.name,
    required this.shortName,
    required this.imageFolder,
    required this.imageHost,
    required this.tagline,
  });

  final String businessCode;
  final String name;
  final String shortName;
  final String imageFolder;
  final String imageHost;
  final String tagline;

  static const empty = Company(
    businessCode: '',
    name: '',
    shortName: '',
    imageFolder: '',
    imageHost: '',
    tagline: '',
  );

  bool get isEmpty => businessCode.isEmpty;

  Map<String, String> toJson() => {
    'businessCode': businessCode,
    'name': name,
    'shortName': shortName,
    'imageFolder': imageFolder,
    'imageHost': imageHost,
    'tagline': tagline,
  };

  factory Company.fromJson(Map<String, String> json) => Company(
    businessCode: json['businessCode'] ?? '',
    name: json['name'] ?? '',
    shortName: json['shortName'] ?? '',
    imageFolder: json['imageFolder'] ?? '',
    imageHost: json['imageHost'] ?? '',
    tagline: json['tagline'] ?? '',
  );
}

abstract final class AppConfig {
  static const packageName = 'com.Sinergi.VenusERPJMGroup_Client';
  static const defaultHost = 'api.sinergiteknologi.co.id';
  static const servicePath =
      '/VenusERPJMIGroupClientMServices/mobileservices.asmx';
  static const soapNamespace = 'http://VenusERPJMIGroupClientMServices.org/';

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

  /// When non-empty, sent as `ImplementServer` on every request so the
  /// backend routes all databases to the implementation server.
  /// Set with `--dart-define=IMPLEMENT_SERVER=true` (or a host/IP).
  static const implementServer = String.fromEnvironment('IMPLEMENT_SERVER');

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
    final path = name.startsWith('http://') || name.startsWith('https://')
        ? Uri.parse(name).path
        : '/VenusERPJMIGroupClientMServices/${company.imageFolder}/$name';
    final host = company.imageHost.isEmpty ? defaultHost : company.imageHost;
    if (kIsWeb) return proxiedUrl(host, path);
    return 'http://$host$path';
  }
}
