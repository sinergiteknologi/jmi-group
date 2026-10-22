import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../core/utils/format.dart';
import '../../data/models/models.dart';
import '../../shared/widgets.dart';
import '../../state/app_state.dart';
import '../cart/cart_pages.dart';

class OrderStatusPage extends StatelessWidget {
  const OrderStatusPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: OrderStage.values.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Status Pemesanan'),
          bottom: TabBar(
            isScrollable: true,
            tabs: OrderStage.values.map((e) => Tab(text: e.label)).toList(),
          ),
        ),
        body: TabBarView(
          children: OrderStage.values
              .map((stage) => _OrderList(stage: stage))
              .toList(),
        ),
      ),
    );
  }
}

class _OrderList extends StatefulWidget {
  const _OrderList({required this.stage});
  final OrderStage stage;

  @override
  State<_OrderList> createState() => _OrderListState();
}

class _OrderListState extends State<_OrderList>
    with AutomaticKeepAliveClientMixin {
  List<OrderHeader> _orders = const [];
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final orders = await context.read<AppState>().repository.getOrderHeaders(
        widget.stage,
      );
      if (mounted) setState(() => _orders = orders);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is ApiException
              ? e.message
              : 'Gagal memuat status pesanan.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);
    if (_orders.isEmpty) {
      return EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'Belum ada pesanan',
        message:
            'Pesanan pada tahap "${widget.stage.label}" akan tampil di sini.',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _orders.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final order = _orders[index];
          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(child: Icon(_stageIcon(order.stage))),
              title: Text(
                order.eoNumber,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (order.date.isNotEmpty) Text('Tanggal: ${order.date}'),
                  Text('Qty: ${order.qty} • Kirim: ${order.deliveryDate}'),
                  if (order.status.isNotEmpty &&
                      widget.stage == OrderStage.history)
                    Text('Status: ${order.status}'),
                ],
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatRupiah(order.total),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Colors.blue,
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 16),
                ],
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OrderDetailPage(order: order),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  IconData _stageIcon(OrderStage stage) => switch (stage) {
    OrderStage.received => Icons.inbox_outlined,
    OrderStage.processed => Icons.autorenew_outlined,
    OrderStage.delivered => Icons.local_shipping_outlined,
    OrderStage.history => Icons.history_outlined,
  };
}

class OrderDetailPage extends StatefulWidget {
  const OrderDetailPage({super.key, required this.order});
  final OrderHeader order;

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  List<OrderLine> _lines = const [];
  bool _loading = true;
  String? _error;

  OrderHeader get order => widget.order;
  double get _total => _lines.fold(0, (sum, e) => sum + e.lineTotal);
  bool get _editable => order.stage == OrderStage.received;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final lines = await context.read<AppState>().repository.getOrderLines(
        order.stage,
        order.eoNumber,
      );
      if (mounted) setState(() => _lines = lines);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is ApiException
              ? e.message
              : 'Gagal memuat detail pesanan.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Pesanan')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? ErrorState(message: _error!, onRetry: _load)
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                GradientHeader(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'EO Number',
                        style: TextStyle(color: Colors.white70),
                      ),
                      Text(
                        order.eoNumber,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Chip(
                        label: Text(
                          order.status.isEmpty
                              ? order.stage.label
                              : order.status,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Column(
                      children: [
                        InfoTile(
                          icon: Icons.calendar_today_outlined,
                          label: 'Tanggal Order',
                          value: order.date,
                        ),
                        InfoTile(
                          icon: Icons.local_shipping_outlined,
                          label: 'Tanggal Kirim',
                          value: order.deliveryDate,
                        ),
                        InfoTile(
                          icon: Icons.schedule_outlined,
                          label: 'Periode / Interval',
                          value: '${order.period} / ${order.interval}',
                        ),
                        if (order.top.isNotEmpty)
                          InfoTile(
                            icon: Icons.payments_outlined,
                            label: 'TOP',
                            value: order.top,
                          ),
                        InfoTile(
                          icon: Icons.notes_outlined,
                          label: 'Catatan',
                          value: order.notes,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const SectionTitle(title: 'Item Pesanan'),
                const SizedBox(height: 8),
                ..._lines.map(
                  (line) => Card(
                    child: ListTile(
                      leading: SizedBox(
                        width: 48,
                        height: 48,
                        child: ProductImage(
                          company: state.company,
                          fileName: line.imageUrl,
                        ),
                      ),
                      title: Text(
                        line.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${line.code} • ${line.qty} × ${formatRupiah(line.price)}\n${line.uom}',
                      ),
                      isThreeLine: true,
                      trailing: Text(
                        formatRupiah(line.lineTotal),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
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
                      formatRupiah(_total == 0 ? order.total : _total),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                if (_editable) ...[
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () async {
                      final updated = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CheckoutPage(existingOrder: order),
                        ),
                      );
                      if (updated == true && mounted) _load();
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Ubah Pesanan'),
                  ),
                ],
              ],
            ),
    );
  }
}
