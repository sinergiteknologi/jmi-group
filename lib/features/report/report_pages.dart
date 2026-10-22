import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../core/utils/format.dart';
import '../../data/models/models.dart';
import '../../shared/widgets.dart';
import '../../state/app_state.dart';

class MutationPage extends StatefulWidget {
  const MutationPage({super.key});

  @override
  State<MutationPage> createState() => _MutationPageState();
}

class _MutationPageState extends State<MutationPage> {
  bool _isHistory = true;
  late DateTime _from;
  late DateTime _to;
  MutationReport? _report;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month, 1);
    _to = DateTime(now.year, now.month + 1, 0);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final report = await context.read<AppState>().repository.getMutation(
        isHistory: _isHistory,
        from: _from,
        to: _to,
      );
      if (mounted) setState(() => _report = report);
    } catch (e) {
      if (mounted) {
        setState(
          () =>
              _error = e is ApiException ? e.message : 'Gagal memuat laporan.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mutasi Rekening')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: true,
                        label: Text('AR History'),
                        icon: Icon(Icons.history),
                      ),
                      ButtonSegment(
                        value: false,
                        label: Text('AR Aging'),
                        icon: Icon(Icons.pie_chart_outline),
                      ),
                    ],
                    selected: {_isHistory},
                    onSelectionChanged: (v) =>
                        setState(() => _isHistory = v.first),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _dateField('Dari', _from, (d) => _from = d),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _dateField('Sampai', _to, (d) => _to = d),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _loading ? null : _load,
                    icon: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.search),
                    label: const Text('Tampilkan Laporan'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_error != null) ErrorState(message: _error!, onRetry: _load),
          if (_report != null) _reportView(_report!),
          if (_report == null && _error == null && !_loading)
            const EmptyState(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Mutasi piutang Anda',
              message:
                  'Pilih jenis laporan dan rentang tanggal, lalu tampilkan laporan.',
            ),
        ],
      ),
    );
  }

  Widget _dateField(
    String label,
    DateTime value,
    ValueChanged<DateTime> onPicked,
  ) {
    return TextFormField(
      key: ValueKey('$label-${value.toIso8601String()}'),
      initialValue: displayDate(value),
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.calendar_month_outlined),
      ),
      onTap: () async {
        final picked = await pickDate(context, value);
        if (picked != null) setState(() => onPicked(picked));
      },
    );
  }

  Widget _reportView(MutationReport report) {
    if (report.rowCount == 0) {
      return const EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'Tidak ada data',
        message: 'Tidak ada mutasi pada rentang tanggal ini.',
      );
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report.title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'Periode: ${report.period}',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
              columns: [
                const DataColumn(label: Text('No')),
                for (var i = 0; i < report.columns.length; i++)
                  DataColumn(label: Text('Data ${i + 1}')),
              ],
              rows: [
                for (var row = 0; row < report.rowCount; row++)
                  DataRow(
                    cells: [
                      DataCell(Text('${row + 1}')),
                      for (final column in report.columns)
                        DataCell(Text(row < column.length ? column[row] : '-')),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
