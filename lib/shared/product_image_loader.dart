import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

/// Downloads product image bytes and converts BMP (and other formats) to JPEG
/// so Flutter can paint them reliably across web/mobile.
class ProductImageLoader {
  ProductImageLoader._();

  static const _tag = 'IMG';

  static final Map<String, Uint8List> _cache = {};
  static final Map<String, Future<Uint8List?>> _inflight = {};

  static void _log(String message) {
    debugPrint('[$_tag] $message');
  }

  static Uri absoluteUri(String url) {
    final parsed = Uri.parse(url);
    if (parsed.hasScheme) return parsed;
    return Uri.base.resolve(url);
  }

  static Future<Uint8List?> load(String url) {
    final key = url;
    final cached = _cache[key];
    if (cached != null) {
      _log('cache hit url=$url bytes=${cached.length}');
      return Future.value(cached);
    }
    return _inflight.putIfAbsent(key, () async {
      final started = DateTime.now();
      _log('load start url=$url');
      try {
        final bytes = await _fetchAndConvert(url);
        final ms = DateTime.now().difference(started).inMilliseconds;
        if (bytes != null) {
          _cache[key] = bytes;
          _log('load ok url=$url jpegBytes=${bytes.length} duration=${ms}ms');
        } else {
          _log('load fail url=$url duration=${ms}ms');
        }
        return bytes;
      } finally {
        _inflight.remove(key);
      }
    });
  }

  static Future<Uint8List?> _fetchAndConvert(String url) async {
    final candidates = <Uri>[absoluteUri(url)];
    final direct = _directFromProxy(url);
    if (direct != null) candidates.add(direct);

    final primaryPath = candidates.first.path.toLowerCase();
    if (primaryPath.endsWith('.bmp') || (direct?.path.toLowerCase().endsWith('.bmp') ?? false)) {
      final bmpUri = direct ?? candidates.first;
      final bmpUrl = bmpUri.toString();
      if (bmpUrl.toLowerCase().endsWith('.bmp')) {
        final base = bmpUrl.substring(0, bmpUrl.length - 4);
        candidates.addAll([
          absoluteUri('$base.jpg'),
          absoluteUri('$base.jpeg'),
          absoluteUri('$base.png'),
        ]);
      }
    }

    _log('candidates=${candidates.map((u) => u.toString()).join(' | ')}');

    for (final uri in candidates) {
      try {
        _log('GET $uri');
        final response =
            await http.get(uri).timeout(const Duration(seconds: 45));
        final contentType = response.headers['content-type'] ?? '-';
        _log(
          'response status=${response.statusCode} contentType=$contentType rawBytes=${response.bodyBytes.length} uri=$uri',
        );
        if (response.statusCode < 200 || response.statusCode >= 300) {
          _log('skip status=${response.statusCode} uri=$uri');
          continue;
        }
        final raw = response.bodyBytes;
        if (raw.isEmpty) {
          _log('skip empty body uri=$uri');
          continue;
        }
        if (_looksLikeHtml(contentType, raw)) {
          _log('skip html body uri=$uri');
          continue;
        }
        final converted = await compute(_convertToJpeg, raw);
        if (converted != null && converted.isNotEmpty) {
          _log(
            'convert ok rawBytes=${raw.length} jpegBytes=${converted.length} uri=$uri',
          );
          return converted;
        }
        _log('convert fail uri=$uri');
      } catch (e) {
        _log('error uri=$uri err=$e');
        continue;
      }
    }
    return null;
  }

  /// /api/proxy?host=...&path=... → http://host/path (untuk fallback lokal).
  static Uri? _directFromProxy(String url) {
    try {
      final uri = absoluteUri(url);
      if (!uri.path.contains('/api/proxy')) return null;
      final host = uri.queryParameters['host'];
      final path = uri.queryParameters['path'];
      if (host == null || host.isEmpty || path == null || path.isEmpty) {
        return null;
      }
      return Uri.parse('http://$host$path');
    } catch (_) {
      return null;
    }
  }

  static bool _looksLikeHtml(String contentType, Uint8List raw) {
    if (contentType.toLowerCase().contains('text/html')) return true;
    if (raw.length < 16) return false;
    final head = String.fromCharCodes(raw.take(64)).trimLeft().toLowerCase();
    return head.startsWith('<!doctype') || head.startsWith('<html');
  }
}

Uint8List? _convertToJpeg(Uint8List raw) {
  try {
    final decoded = img.decodeImage(raw);
    if (decoded == null) return null;
    img.Image frame = decoded;
    const maxSide = 900;
    if (frame.width > maxSide || frame.height > maxSide) {
      frame = img.copyResize(
        frame,
        width: frame.width >= frame.height ? maxSide : null,
        height: frame.height > frame.width ? maxSide : null,
      );
    }
    return Uint8List.fromList(img.encodeJpg(frame, quality: 82));
  } catch (_) {
    return null;
  }
}
