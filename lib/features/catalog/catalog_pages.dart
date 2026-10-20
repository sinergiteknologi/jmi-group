import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/network/soap_client.dart';
import '../../core/utils/format.dart';
import '../../data/models/models.dart';
import '../../shared/widgets.dart';
import '../../state/app_state.dart';
import '../cart/cart_pages.dart';

class ProductListPage extends StatefulWidget {
  const ProductListPage({super.key});

  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  List<Product> _products = const [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  Set<String> _favoriteCategories = const {};
  Set<int> _stockFilters = const {};

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load(initial: true);
  }

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 320) {
      _loadMore();
    }
  }

  String get _categoryFilter =>
      _favoriteCategories.map((c) => "'$c'").join(',');

  String get _serverWhere {
    final query = _search.text.trim().replaceAll("'", "''");
    if (query.isEmpty) return '';
    return " AND ((IV.ProdName LIKE '%$query%') OR (IV.ProdCode LIKE '%$query%') OR (IV.AliasName LIKE '%$query%')) ";
  }

  String get _having {
    if (_stockFilters.isEmpty) {
      return '(Stock > 0) OR (Stock = 0) OR (Stock = -1)';
    }
    final parts = <String>[];
    if (_stockFilters.contains(1)) parts.add('(Stock > 0)');
    if (_stockFilters.contains(0)) parts.add('(Stock = 0)');
    if (_stockFilters.contains(-1)) parts.add('(Stock = -1)');
    return parts.join(' OR ');
  }

  Future<void> _load({bool initial = false}) async {
    final state = context.read<AppState>();
    setState(() {
      _loading = true;
      _error = null;
      _hasMore = true;
    });
    try {
      final filters = await state.store.stockFilters();
      _stockFilters = {
        if (filters.inStock) 1,
        if (filters.soldOut) 0,
        if (filters.comingSoon) -1,
      };
      final categories = await state.db.categories();
      _favoriteCategories = categories
          .where((c) => c.isFavorite)
          .map((c) => c.code)
          .toSet();

      final cached = await state.db.cachedProducts(
        search: _search.text.trim(),
        favoriteCategories: _favoriteCategories,
        stockFilters: _stockFilters,
      );
      if (cached.isNotEmpty && mounted) setState(() => _products = cached);

      final fetched = await state.repository.getProducts(
        lastCode: '',
        categoryFilter: _categoryFilter,
        where: _serverWhere,
        having: _having,
      );
      _hasMore = fetched.isNotEmpty;
      final refreshed = await state.db.cachedProducts(
        search: _search.text.trim(),
        favoriteCategories: _favoriteCategories,
        stockFilters: _stockFilters,
      );
      if (mounted) {
        setState(() => _products = refreshed.isNotEmpty ? refreshed : fetched);
      }
    } catch (e) {
      if (_products.isEmpty) {
        if (mounted) {
          setState(
            () => _error = e is SoapException
                ? e.message
                : 'Gagal memuat produk.',
          );
        }
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore || _products.isEmpty) return;
    setState(() => _loadingMore = true);
    final state = context.read<AppState>();
    try {
      final fetched = await state.repository.getProducts(
        lastCode: _products.last.code,
        categoryFilter: _categoryFilter,
        where: _serverWhere,
        having: _having,
      );
      if (fetched.isEmpty) _hasMore = false;
      final refreshed = await state.db.cachedProducts(
        search: _search.text.trim(),
        favoriteCategories: _favoriteCategories,
        stockFilters: _stockFilters,
      );
      if (mounted && refreshed.length != _products.length) {
        setState(() => _products = refreshed);
      } else if (fetched.isEmpty && mounted) {
        setState(() {});
      }
    } catch (_) {
      _hasMore = false;
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final company = context.watch<AppState>().company;
    return Scaffold(
      appBar: AppBar(title: const Text('Katalog Produk')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Cari nama, kode, atau alias produk…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _search.clear();
                          _load();
                        },
                        icon: const Icon(Icons.close),
                      ),
              ),
              onSubmitted: (_) => _load(),
              onChanged: (_) => setState(() {}),
            ),
          ),
          if (_favoriteCategories.isNotEmpty || _stockFilters.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.filter_alt_outlined, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      [
                        if (_favoriteCategories.isNotEmpty)
                          '${_favoriteCategories.length} kategori favorit',
                        if (_stockFilters.isNotEmpty) 'filter stok aktif',
                      ].join(' • '),
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ),
                  TextButton(
                    onPressed: _load,
                    child: const Text('Terapkan ulang'),
                  ),
                ],
              ),
            ),
          Expanded(child: _body(company)),
        ],
      ),
    );
  }

  Widget _body(Company company) {
    if (_loading && _products.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _products.isEmpty) {
      return ErrorState(message: _error!, onRetry: _load);
    }
    if (_products.isEmpty) {
      return const EmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'Produk tidak ditemukan',
        message: 'Coba ubah kata kunci atau filter di Pengaturan.',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: GridView.builder(
        controller: _scroll,
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.68,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: _products.length + (_loadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _products.length) {
            return const Center(child: CircularProgressIndicator());
          }
          final product = _products[index];
          return _ProductCard(
            product: product,
            company: company,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProductDetailPage(product: product),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.company,
    required this.onTap,
  });
  final Product product;
  final Company company;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: ProductImage(
                  company: company,
                  fileName: product.imageFiles.firstOrNull ?? '',
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.code,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  if (product.specialPrice > 0)
                    Text(
                      formatRupiah(product.price),
                      style: const TextStyle(
                        fontSize: 11,
                        decoration: TextDecoration.lineThrough,
                        color: Colors.grey,
                      ),
                    ),
                  Text(
                    formatRupiah(product.effectivePrice),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 6),
                  StockBadge(stock: product.stock),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({
    super.key,
    required this.product,
    this.fromCart = false,
  });
  final Product product;
  final bool fromCart;

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  ProductDetail? _detail;
  int _qty = 1;
  bool _loading = true;

  Product get product => widget.product;
  int get _stock => _detail?.stock ?? product.stock;
  int get _maxQty {
    final factor = uomFactor(product.descUom);
    if (factor <= 0 || _stock <= 0) return 0;
    return _stock ~/ factor;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final state = context.read<AppState>();
    final existingQty = await state.db.cartQtyFor(product.code);
    if (existingQty > 0) _qty = existingQty;
    try {
      final detail = await state.repository.getProductDetail(product.code);
      if (mounted) setState(() => _detail = detail);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final images = product.imageFiles;
    final canOrder = _maxQty > 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Produk')),
      body: ListView(
        children: [
          SizedBox(
            height: 300,
            child: images.isEmpty
                ? ProductImage(company: state.company, fileName: '')
                : CarouselSlider(
                    options: CarouselOptions(
                      height: 300,
                      viewportFraction: 1,
                      enableInfiniteScroll: images.length > 1,
                    ),
                    items: images
                        .map(
                          (file) => GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ImageZoomPage(
                                  company: state.company,
                                  fileName: file,
                                ),
                              ),
                            ),
                            child: SizedBox(
                              width: double.infinity,
                              child: ProductImage(
                                company: state.company,
                                fileName: file,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.code,
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          Text(
                            product.name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (product.alias.isNotEmpty)
                            Text(
                              product.alias,
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                        ],
                      ),
                    ),
                    StockBadge(stock: _stock),
                  ],
                ),
                const SizedBox(height: 12),
                if (product.specialPrice > 0)
                  Text(
                    formatRupiah(product.price),
                    style: const TextStyle(
                      decoration: TextDecoration.lineThrough,
                      color: Colors.grey,
                    ),
                  ),
                Text(
                  formatRupiah(product.effectivePrice),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 16),
                if (_loading) const LinearProgressIndicator(),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        InfoTile(
                          icon: Icons.straighten_outlined,
                          label: 'Dimensi',
                          value: _detail?.dimension ?? '-',
                        ),
                        InfoTile(
                          icon: Icons.view_in_ar_outlined,
                          label: 'Kubikasi',
                          value: _detail?.cubication ?? '-',
                        ),
                        InfoTile(
                          icon: Icons.scale_outlined,
                          label: 'UOM Primer',
                          value: _detail?.primaryUom ?? '-',
                        ),
                        InfoTile(
                          icon: Icons.price_change_outlined,
                          label: 'List Price',
                          value: _detail == null
                              ? '-'
                              : formatRupiah(_detail!.listPrice),
                        ),
                        InfoTile(
                          icon: Icons.inventory_outlined,
                          label: 'Stok',
                          value: '$_stock (${product.descUom})',
                        ),
                      ],
                    ),
                  ),
                ),
                if (product.description.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const SectionTitle(title: 'Deskripsi'),
                  const SizedBox(height: 6),
                  Text(
                    product.description,
                    style: const TextStyle(height: 1.5),
                  ),
                ],
                const SizedBox(height: 20),
                if (!canOrder)
                  Card(
                    color: Colors.orange.shade50,
                    child: ListTile(
                      leading: const Icon(
                        Icons.info_outline,
                        color: Colors.orange,
                      ),
                      title: Text(
                        _stock < 0
                            ? 'Coming Soon — request indent by phone'
                            : 'Sold Out — request indent by phone',
                      ),
                    ),
                  )
                else
                  Row(
                    children: [
                      const Text(
                        'Jumlah',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      QtyStepper(
                        qty: _qty,
                        maxQty: _maxQty,
                        onChanged: (v) =>
                            setState(() => _qty = v.clamp(1, _maxQty)),
                      ),
                    ],
                  ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: canOrder ? _addToCart : null,
                        icon: const Icon(Icons.shopping_cart_outlined),
                        label: Text(
                          widget.fromCart ? 'Update Cart' : 'Add to Cart',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: canOrder ? _buyNow : null,
                        child: const Text('Buy Now'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addToCart() async {
    if (_qty <= 0) {
      showMessage(context, 'Isi jumlah terlebih dahulu.');
      return;
    }
    await context.read<AppState>().addToCart(product, _qty);
    if (mounted) {
      showMessage(
        context,
        widget.fromCart ? 'Cart diperbarui.' : 'Ditambahkan ke cart.',
      );
    }
  }

  void _buyNow() {
    if (_qty <= 0) {
      showMessage(context, 'Isi jumlah terlebih dahulu.');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CheckoutPage(directItem: product.toCart(_qty)),
      ),
    );
  }
}

class ImageZoomPage extends StatelessWidget {
  const ImageZoomPage({
    super.key,
    required this.company,
    required this.fileName,
  });
  final Company company;
  final String fileName;

  @override
  Widget build(BuildContext context) {
    final url = AppConfig.imageUrl(company, fileName);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: PhotoView(
        imageProvider: NetworkImage(url),
        backgroundDecoration: const BoxDecoration(color: Colors.black),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
