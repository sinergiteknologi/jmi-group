import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/soap_client.dart';
import '../../core/utils/format.dart';
import '../../data/models/models.dart';
import '../../shared/widgets.dart';
import '../../state/app_state.dart';
import '../catalog/catalog_pages.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  List<CartItem> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await context.read<AppState>().db.cartItems();
    if (mounted) {
      setState(() {
        _items = items;
        _loading = false;
      });
    }
  }

  double get _total => _items.fold(0, (sum, e) => sum + e.lineTotal);

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final session = state.session;
    return Scaffold(
      appBar: AppBar(title: const Text('Cart List')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? const EmptyState(
              icon: Icons.shopping_cart_outlined,
              title: 'Cart masih kosong',
              message: 'Tambahkan produk dari katalog untuk mulai memesan.',
            )
          : Column(
              children: [
                if (session != null)
                  Card(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Column(
                        children: [
                          InfoTile(
                            icon: Icons.person_outline,
                            label: 'Customer',
                            value: session.custName,
                          ),
                          InfoTile(
                            icon: Icons.location_on_outlined,
                            label: 'Alamat',
                            value: session.address,
                          ),
                        ],
                      ),
                    ),
                  ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: SizedBox(
                                  width: 64,
                                  height: 64,
                                  child: ProductImage(
                                    company: state.company,
                                    fileName: item.imageUrl,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      item.code,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    Text(
                                      formatRupiah(item.lineTotal),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                children: [
                                  IconButton(
                                    onPressed: () => _remove(item),
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                    ),
                                  ),
                                  QtyStepper(
                                    qty: item.qty,
                                    onChanged: (qty) => _updateQty(item, qty),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                _checkoutBar(context),
              ],
            ),
    );
  }

  Widget _checkoutBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Total', style: TextStyle(color: Colors.grey)),
                  Text(
                    formatRupiah(_total),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton(
              onPressed: _total > 0
                  ? () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CheckoutPage()),
                    )
                  : null,
              child: const Text('Checkout'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateQty(CartItem item, int qty) async {
    final state = context.read<AppState>();
    await state.db.updateCartQty(item.code, qty);
    await state.refreshCart();
    await _load();
  }

  Future<void> _remove(CartItem item) async {
    final state = context.read<AppState>();
    await state.db.removeCart(item.code);
    await state.refreshCart();
    await _load();
  }
}

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key, this.directItem, this.existingOrder});
  final CartItem? directItem;
  final OrderHeader? existingOrder;

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final _notes = TextEditingController();
  final _deliveryDate = TextEditingController();
  List<CartItem> _items = const [];
  List<CodeName> _tops = const [];
  CodeName? _selectedTop;
  String _period = 'Pagi';
  String _interval = '1x';
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  bool _loading = true;
  bool _submitting = false;

  static const _periods = ['Pagi', 'Siang', 'Sore'];
  static const _intervals = ['1x', '2x', '3x', 'Titip dengan proforma Inv'];

  bool get _isEdit => widget.existingOrder != null;
  double get _total => _items.fold(0, (sum, e) => sum + e.lineTotal);

  @override
  void initState() {
    super.initState();
    final order = widget.existingOrder;
    if (order != null) {
      _notes.text = order.notes;
      _date = _tryParse(order.deliveryDate) ?? _date;
      if (_periods.contains(order.period)) _period = order.period;
      if (_intervals.contains(order.interval)) _interval = order.interval;
    }
    _deliveryDate.text = formatDate(_date);
    _load();
  }

  DateTime? _tryParse(String value) {
    final parts = value.split('/');
    if (parts.length != 3) return null;
    final month = int.tryParse(parts[0]);
    final day = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (month == null || day == null || year == null) return null;
    return DateTime(year, month, day);
  }

  Future<void> _load() async {
    final state = context.read<AppState>();
    try {
      if (widget.directItem != null) {
        _items = [widget.directItem!];
      } else if (_isEdit) {
        final lines = await state.repository.getOrderLines(
          widget.existingOrder!.stage,
          widget.existingOrder!.eoNumber,
        );
        _items = lines.map((e) => e.toCart()).toList();
      } else {
        _items = await state.db.cartItems();
      }
      _tops = await state.repository.getTops();
      final session = state.session;
      _selectedTop =
          _tops
              .where(
                (t) =>
                    t.code == widget.existingOrder?.top ||
                    t.name == session?.top,
              )
              .firstOrNull ??
          _tops.firstOrNull;
    } catch (e) {
      if (mounted) {
        showMessage(
          context,
          e is SoapException ? e.message : 'Gagal memuat checkout.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (_items.isEmpty) {
      showMessage(context, 'Pilih item terlebih dahulu.');
      return;
    }
    setState(() => _submitting = true);
    final state = context.read<AppState>();
    try {
      final stocks = await state.repository.getStock(
        _items.map((e) => e.code).toList(),
      );
      final invalid = stocks.where((s) => s.stock <= 0).toList();
      if (invalid.isNotEmpty && !_isEdit) {
        if (mounted) {
          showMessage(
            context,
            'Invalid stock untuk: ${invalid.map((e) => e.code).join(', ')}',
          );
        }
        return;
      }
      await state.repository.uploadPo(
        items: _items,
        period: _period,
        interval: _interval,
        deliveryDate: _deliveryDate.text,
        notes: _notes.text.trim(),
        topCode: _selectedTop?.code ?? '',
        eoNumber: widget.existingOrder?.eoNumber ?? '',
      );
      if (!_isEdit && widget.directItem == null) {
        await state.db.clearCart();
        await state.refreshCart();
      }
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
          title: Text(_isEdit ? 'Order diperbarui' : 'Order terkirim'),
          content: const Text(
            'Pesanan Anda telah diterima dan dapat dipantau di menu Status Pemesanan.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        showMessage(
          context,
          e is SoapException ? e.message : 'Gagal mengirim pesanan.',
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _notes.dispose();
    _deliveryDate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEdit
              ? 'Ubah Order ${widget.existingOrder!.eoNumber}'
              : 'Submit Order',
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (_isEdit)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.receipt_long_outlined),
                      title: Text(
                        'EO Number: ${widget.existingOrder!.eoNumber}',
                      ),
                      subtitle: Text(widget.existingOrder!.stage.label),
                    ),
                  ),
                const SectionTitle(title: 'Item Pesanan'),
                const SizedBox(height: 8),
                ..._items.map(
                  (item) => Card(
                    child: ListTile(
                      leading: SizedBox(
                        width: 48,
                        height: 48,
                        child: ProductImage(
                          company: state.company,
                          fileName: item.imageUrl,
                        ),
                      ),
                      title: Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${item.qty} × ${formatRupiah(item.price)} • ${item.uom}',
                      ),
                      trailing: Text(
                        formatRupiah(item.lineTotal),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      onTap: _isEdit ? null : () => _openProduct(item),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Total',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      formatRupiah(_total),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const SectionTitle(title: 'Pengiriman & Pembayaran'),
                const SizedBox(height: 12),
                TextField(
                  controller: _deliveryDate,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Tanggal Pengiriman',
                    prefixIcon: Icon(Icons.calendar_month_outlined),
                  ),
                  onTap: () async {
                    final picked = await pickDate(context, _date);
                    if (picked != null) {
                      _date = picked;
                      _deliveryDate.text = formatDate(picked);
                    }
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _period,
                  decoration: const InputDecoration(
                    labelText: 'Periode Pengiriman',
                    prefixIcon: Icon(Icons.schedule_outlined),
                  ),
                  items: _periods
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => _period = v ?? _period),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _interval,
                  decoration: const InputDecoration(
                    labelText: 'Interval Pengiriman',
                    prefixIcon: Icon(Icons.repeat_outlined),
                  ),
                  items: _intervals
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => _interval = v ?? _interval),
                ),
                const SizedBox(height: 16),
                if (_tops.isNotEmpty)
                  DropdownButtonFormField<CodeName>(
                    initialValue: _selectedTop,
                    decoration: const InputDecoration(
                      labelText: 'TOP (Term of Payment)',
                      prefixIcon: Icon(Icons.payments_outlined),
                    ),
                    items: _tops
                        .map(
                          (e) =>
                              DropdownMenuItem(value: e, child: Text(e.name)),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _selectedTop = v),
                  ),
                const SizedBox(height: 16),
                TextField(
                  controller: _notes,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Catatan',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_outlined),
                  label: Text(_isEdit ? 'Simpan Perubahan' : 'Kirim Pesanan'),
                ),
              ],
            ),
    );
  }

  void _openProduct(CartItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailPage(
          product: Product(
            code: item.code,
            name: item.name,
            price: item.price,
            description: item.description,
            descUom: item.uom,
            stock: item.stock,
            imageUrl: item.imageUrl,
            category: '',
            specialPrice: 0,
            alias: item.alias,
          ),
          fromCart: true,
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
