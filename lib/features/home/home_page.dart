import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/format.dart';
import '../../data/models/models.dart';
import '../../shared/widgets.dart';
import '../../state/app_state.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.onGoCatalog});
  final VoidCallback onGoCatalog;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  ArLimit? _arLimit;
  bool _loadingAr = true;

  @override
  void initState() {
    super.initState();
    _loadAr();
  }

  Future<void> _loadAr() async {
    try {
      final limit = await context.read<AppState>().repository.getArLimit();
      if (mounted) setState(() => _arLimit = limit);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingAr = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final session = state.session;
    if (session == null) return const SizedBox.shrink();
    final remaining =
        _arLimit?.remaining ??
        parseDouble(
              (parseDouble(session.groupLimit) != 0
                  ? session.groupLimit
                  : session.indLimit),
            ) -
            parseDouble(session.arOverdue);

    return RefreshIndicator(
      onRefresh: _loadAr,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          GradientHeader(
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        child: Text(
                          state.company.shortName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          state.businessName.isEmpty
                              ? state.company.name
                              : state.businessName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Selamat datang,',
                    style: TextStyle(color: Colors.white70),
                  ),
                  Text(
                    session.displayName.isEmpty
                        ? session.username
                        : session.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    session.custName,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Limit Piutang (AR)',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            if (_loadingAr)
                              const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            else
                              IconButton(
                                onPressed: _loadAr,
                                icon: const Icon(Icons.refresh),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Sisa Limit',
                          style: TextStyle(color: Colors.grey),
                        ),
                        Text(
                          formatRupiah(remaining),
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Divider(height: 28),
                        _moneyRow(
                          'AR Global',
                          _arLimit?.global ?? parseDouble(session.groupLimit),
                        ),
                        _moneyRow(
                          'AR Limit',
                          _arLimit?.limit ?? parseDouble(session.indLimit),
                        ),
                        _moneyRow(
                          'AR Overdue',
                          _arLimit?.overdue ?? parseDouble(session.arOverdue),
                          danger: true,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SectionTitle(
                  title: 'Mulai Pesan',
                  trailing: TextButton(
                    onPressed: widget.onGoCatalog,
                    child: const Text('Lihat Katalog'),
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.shopping_bag_outlined),
                    ),
                    title: const Text(
                      'Katalog Produk',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text(
                      'Telusuri produk dan buat pesanan baru',
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 18),
                    onTap: widget.onGoCatalog,
                  ),
                ),
                const SizedBox(height: 20),
                const SectionTitle(title: 'Profil Customer'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Column(
                      children: [
                        InfoTile(
                          icon: Icons.person_outline,
                          label: 'Username',
                          value: session.username,
                        ),
                        InfoTile(
                          icon: Icons.badge_outlined,
                          label: 'Kode Customer',
                          value: session.custCode,
                        ),
                        InfoTile(
                          icon: Icons.store_outlined,
                          label: 'Cabang',
                          value: '${session.busName} (${session.busCode})',
                        ),
                        InfoTile(
                          icon: Icons.phone_outlined,
                          label: 'Telepon',
                          value: session.phone,
                        ),
                        InfoTile(
                          icon: Icons.email_outlined,
                          label: 'Email',
                          value: session.email,
                        ),
                        InfoTile(
                          icon: Icons.location_on_outlined,
                          label: 'Alamat',
                          value: session.address,
                        ),
                        InfoTile(
                          icon: Icons.payments_outlined,
                          label: 'TOP',
                          value: session.top,
                        ),
                        InfoTile(
                          icon: Icons.support_agent_outlined,
                          label: 'Kode Sales',
                          value: session.salesCode,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _moneyRow(String label, double value, {bool danger = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(color: Colors.grey.shade700)),
          ),
          Text(
            formatRupiah(value),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: danger && value > 0 ? Colors.red : null,
            ),
          ),
        ],
      ),
    );
  }
}
