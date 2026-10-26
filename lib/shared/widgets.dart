import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/config/app_config.dart';
import '../core/theme/app_theme.dart';
import 'product_image_loader.dart';

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
}

class GradientHeader extends StatelessWidget {
  const GradientHeader({super.key, required this.child, this.padding});
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.fromLTRB(20, 20, 20, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: child,
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.title, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class InfoTile extends StatelessWidget {
  const InfoTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(
        label,
        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
      ),
      subtitle: Text(
        value.isEmpty ? '-' : value,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: Icon(icon, size: 36, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.cloud_off_outlined,
      title: 'Tidak dapat memuat data',
      message: message,
      action: FilledButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: const Text('Coba Lagi'),
      ),
    );
  }
}

class ProductImage extends StatefulWidget {
  const ProductImage({
    super.key,
    required this.company,
    required this.fileName,
    this.fit = BoxFit.cover,
  });
  final Company company;
  final String fileName;
  final BoxFit fit;

  @override
  State<ProductImage> createState() => _ProductImageState();
}

class _ProductImageState extends State<ProductImage> {
  late Future<Uint8List?> _bytes;

  @override
  void initState() {
    super.initState();
    _bytes = _startLoad();
  }

  @override
  void didUpdateWidget(covariant ProductImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.company.imageHost != widget.company.imageHost ||
        oldWidget.company.imageFolder != widget.company.imageFolder ||
        oldWidget.fileName != widget.fileName) {
      setState(() => _bytes = _startLoad());
    }
  }

  Future<Uint8List?> _startLoad() {
    debugPrint(
      '[IMG] ProductImage start fileName=${widget.fileName} '
      'imageHost=${widget.company.imageHost} imageFolder=${widget.company.imageFolder}',
    );
    final url = AppConfig.imageUrl(widget.company, widget.fileName);
    if (url.isEmpty) {
      debugPrint('[IMG] ProductImage skip empty url fileName=${widget.fileName}');
      return Future.value(null);
    }
    // Web: tampil via <img> (hindari CORS + BMP decode). Loader hanya mobile.
    if (kIsWeb) return Future.value(null);
    return ProductImageLoader.load(url);
  }

  @override
  Widget build(BuildContext context) {
    final url = AppConfig.imageUrl(widget.company, widget.fileName);
    if (url.isEmpty) return const _ImagePlaceholder();

    // Local/production web: browser <img> bisa render .bmp cross-origin.
    if (kIsWeb) {
      return Image.network(
        url,
        fit: widget.fit,
        width: double.infinity,
        height: double.infinity,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const _ImagePlaceholder(loading: true);
        },
        errorBuilder: (_, error, _) {
          debugPrint(
            '[IMG] ProductImage web error fileName=${widget.fileName} url=$url err=$error',
          );
          return const _ImagePlaceholder();
        },
      );
    }

    return FutureBuilder<Uint8List?>(
      future: _bytes,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _ImagePlaceholder(loading: true);
        }
        final data = snapshot.data;
        if (data == null || data.isEmpty) {
          debugPrint(
            '[IMG] ProductImage show placeholder fileName=${widget.fileName} '
            'error=${snapshot.error}',
          );
          return const _ImagePlaceholder();
        }
        return Image.memory(
          data,
          fit: widget.fit,
          width: double.infinity,
          height: double.infinity,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, error, _) {
            debugPrint(
              '[IMG] ProductImage Image.memory error fileName=${widget.fileName} err=$error',
            );
            return const _ImagePlaceholder();
          },
        );
      },
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({this.loading = false});
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade100,
      alignment: Alignment.center,
      child: loading
          ? const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.primary,
              ),
            )
          : Icon(
              Icons.inventory_2_outlined,
              size: 42,
              color: Colors.grey.shade400,
            ),
    );
  }
}

class QtyStepper extends StatelessWidget {
  const QtyStepper({
    super.key,
    required this.qty,
    required this.onChanged,
    this.maxQty,
  });
  final int qty;
  final ValueChanged<int> onChanged;
  final int? maxQty;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: qty > 0 ? () => onChanged(qty - 1) : null,
            icon: const Icon(Icons.remove),
          ),
          SizedBox(
            width: 36,
            child: Text(
              '$qty',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: maxQty == null || qty < maxQty!
                ? () => onChanged(qty + 1)
                : null,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

class StockBadge extends StatelessWidget {
  const StockBadge({super.key, required this.stock});
  final int stock;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (stock) {
      < 0 => ('Coming Soon', Colors.purple),
      0 => ('Sold Out', Colors.red),
      _ => ('In Stock', Colors.green),
    };
    return Chip(
      label: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      ),
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }
}

Future<DateTime?> pickDate(BuildContext context, DateTime initial) {
  return showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(2000),
    lastDate: DateTime(2100),
  );
}
