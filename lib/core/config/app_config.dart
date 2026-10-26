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

  static String _clean(String value) {
    final v = value.trim();
    if (v.isEmpty || v == '-') return '';
    return v;
  }

  static const _imageByBiz = <String, ({String folder, String host, String short})>{
    'venuserp10': (
      folder: 'JMI_Images',
      host: 'production2.sinergiteknologi.co.id',
      short: 'JMI',
    ),
    'venuserp21': (
      folder: 'MCC_Images',
      host: 'production2.sinergiteknologi.co.id',
      short: 'MCC',
    ),
    'venuserp25': (
      folder: 'MMI_Images',
      host: 'production3.sinergiteknologi.co.id',
      short: 'MMI',
    ),
  };

  static bool _isDbNameFolder(String folder, String businessCode) {
    if (folder.isEmpty) return true;
    if (RegExp(r'^VenusERP\d+_Images$', caseSensitive: false).hasMatch(folder)) {
      return true;
    }
    final code = businessCode.toLowerCase();
    return code.isNotEmpty && folder.toLowerCase() == '${code}_images';
  }

  /// Folder gambar: Pref5 / shortName_Images / Images.
  static String imageFolderOf(Company company) {
    final folder = _clean(company.imageFolder);
    final def = _imageByBiz[_clean(company.businessCode).toLowerCase()];
    if (def != null && _isDbNameFolder(folder, company.businessCode)) {
      return def.folder;
    }
    if (folder.isNotEmpty) return folder;
    final short = _clean(company.shortName);
    if (short.isNotEmpty && short.toLowerCase() != company.businessCode.toLowerCase()) {
      return '${short}_Images';
    }
    if (def != null) return def.folder;
    if (short.isNotEmpty) return '${short}_Images';
    return 'Images';
  }

  static String imageHostOf(Company company) {
    final host = _clean(company.imageHost);
    final def = _imageByBiz[_clean(company.businessCode).toLowerCase()];
    if (def != null &&
        (host.isEmpty ||
            host.toLowerCase() == 'production.sinergiteknologi.co.id')) {
      return def.host;
    }
    return host.isEmpty ? defaultHost : host;
  }

  static String imageUrl(Company company, String fileName) {
    final name = _clean(fileName);
    if (name.isEmpty) {
      debugPrint('[IMG] imageUrl empty fileName="$fileName"');
      return '';
    }
    final String path;
    if (name.startsWith('http://') || name.startsWith('https://')) {
      path = Uri.parse(name).path;
    } else {
      final folder = imageFolderOf(company);
      final encoded = name.split('/').map(Uri.encodeComponent).join('/');
      path = '/VenusERPJMIGroupClientMServices/$folder/$encoded';
    }
    final host = imageHostOf(company);
    final direct = 'http://$host$path';
    // Web di HTTPS (Vercel) wajib proxy. Local flutter web (http://localhost)
    // tidak punya /api/proxy — pakai host gambar langsung.
    final url = kIsWeb && _needsImageProxy ? proxiedUrl(host, path) : direct;
    debugPrint(
      '[IMG] build fileName=$name host=$host folder=${imageFolderOf(company)} '
      'shortName=${company.shortName} biz=${company.businessCode} '
      'proxy=$_needsImageProxy url=$url',
    );
    return url;
  }

  static bool get _needsImageProxy {
    if (!kIsWeb) return false;
    final base = Uri.base;
    if (base.scheme != 'https') return false;
    final host = base.host.toLowerCase();
    if (host == 'localhost' || host == '127.0.0.1') return false;
    return true;
  }
}
