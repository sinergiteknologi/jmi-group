import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../data/models/models.dart';
import '../../shared/widgets.dart';
import '../../state/app_state.dart';
import '../auth/auth_pages.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  List<CategoryItem> _categories = const [];
  final _categorySearch = TextEditingController();
  final Set<String> _expandedGroups = {};
  bool _inStock = false;
  bool _soldOut = false;
  bool _comingSoon = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _categorySearch.dispose();
    super.dispose();
  }

  List<MapEntry<String, List<CategoryItem>>> get _groupedCategories {
    final query = _categorySearch.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? _categories
        : _categories
              .where(
                (c) =>
                    c.name.toLowerCase().contains(query) ||
                    c.code.toLowerCase().contains(query),
              )
              .toList();
    final map = <String, List<CategoryItem>>{};
    for (final item in filtered) {
      map.putIfAbsent(item.name, () => []).add(item);
    }
    final entries = map.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));
    for (final entry in entries) {
      entry.value.sort((a, b) => a.code.compareTo(b.code));
    }
    return entries;
  }

  int get _favoriteCount => _categories.where((c) => c.isFavorite).length;

  Future<void> _load() async {
    final state = context.read<AppState>();
    final filters = await state.store.stockFilters();
    try {
      final categories = await state.repository.getCategories();
      if (mounted) {
        setState(() {
          _categories = categories;
          _inStock = filters.inStock;
          _soldOut = filters.soldOut;
          _comingSoon = filters.comingSoon;
        });
      }
    } catch (e) {
      if (mounted) {
        showMessage(
          context,
          e is ApiException ? e.message : 'Gagal memuat kategori.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final session = state.session;
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (session != null)
                  Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          _initials(
                            session.displayName.isEmpty
                                ? session.username
                                : session.displayName,
                          ),
                        ),
                      ),
                      title: Text(
                        session.displayName.isEmpty
                            ? session.username
                            : session.displayName,
                      ),
                      subtitle: Text(
                        '${session.custName} • ${state.company.name}',
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                const SectionTitle(title: 'Tampilkan Produk Berdasarkan Stok'),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('In Stock'),
                        subtitle: const Text('Stok tersedia (> 0)'),
                        value: _inStock,
                        onChanged: (v) => _saveFilters(inStock: v),
                      ),
                      SwitchListTile(
                        title: const Text('Sold Out'),
                        subtitle: const Text('Stok habis (= 0)'),
                        value: _soldOut,
                        onChanged: (v) => _saveFilters(soldOut: v),
                      ),
                      SwitchListTile(
                        title: const Text('Coming Soon'),
                        subtitle: const Text('Segera datang / indent (= -1)'),
                        value: _comingSoon,
                        onChanged: (v) => _saveFilters(comingSoon: v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Expanded(
                      child: SectionTitle(title: 'Kategori Favorit'),
                    ),
                    if (_favoriteCount > 0)
                      TextButton(
                        onPressed: _clearFavorites,
                        child: Text('Hapus ($_favoriteCount)'),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Hanya produk dari kategori favorit yang tampil di katalog. Kosongkan semua untuk menampilkan semua kategori.',
                  style: TextStyle(color: Colors.grey.shade600, height: 1.35),
                ),
                const SizedBox(height: 10),
                if (_categories.isEmpty)
                  const Card(
                    child: ListTile(title: Text('Kategori belum tersedia')),
                  )
                else
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                          child: TextField(
                            controller: _categorySearch,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              hintText: 'Cari nama atau kode…',
                              prefixIcon: const Icon(Icons.search, size: 20),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              suffixIcon: _categorySearch.text.isEmpty
                                  ? null
                                  : IconButton(
                                      onPressed: () {
                                        _categorySearch.clear();
                                        setState(() {});
                                      },
                                      icon: const Icon(Icons.close, size: 18),
                                    ),
                            ),
                          ),
                        ),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 320),
                          child: _groupedCategories.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.all(20),
                                  child: Text(
                                    'Tidak ada kategori yang cocok.',
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              : ListView.separated(
                                  shrinkWrap: true,
                                  padding: const EdgeInsets.only(bottom: 8),
                                  itemCount: _groupedCategories.length,
                                  separatorBuilder: (_, _) => Divider(
                                    height: 1,
                                    color: Colors.black.withValues(alpha: 0.06),
                                  ),
                                  itemBuilder: (context, index) {
                                    final group = _groupedCategories[index];
                                    return _CategoryGroupTile(
                                      name: group.key,
                                      items: group.value,
                                      expanded: _expandedGroups.contains(
                                        group.key,
                                      ),
                                      onToggleExpanded: () {
                                        setState(() {
                                          if (_expandedGroups.contains(
                                            group.key,
                                          )) {
                                            _expandedGroups.remove(group.key);
                                          } else {
                                            _expandedGroups.add(group.key);
                                          }
                                        });
                                      },
                                      onToggleGroup: (value) =>
                                          _toggleGroup(group.value, value),
                                      onToggleItem: _toggleCategory,
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.lock_reset_outlined),
                        title: const Text('Ganti Password'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 18),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ChangePasswordPage(),
                          ),
                        ),
                      ),
                      ListTile(
                        leading: const Icon(Icons.description_outlined),
                        title: const Text('Syarat & Ketentuan'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 18),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const TermsPage()),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout, color: Colors.red),
                  label: const Text(
                    'Logout',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
    );
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    return parts.take(2).map((e) => e[0].toUpperCase()).join();
  }

  Future<void> _saveFilters({
    bool? inStock,
    bool? soldOut,
    bool? comingSoon,
  }) async {
    setState(() {
      if (inStock != null) _inStock = inStock;
      if (soldOut != null) _soldOut = soldOut;
      if (comingSoon != null) _comingSoon = comingSoon;
    });
    await context.read<AppState>().store.saveStockFilters(
      inStock: _inStock,
      soldOut: _soldOut,
      comingSoon: _comingSoon,
    );
  }

  Future<void> _toggleCategory(CategoryItem category, bool value) async {
    final state = context.read<AppState>();
    await state.db.setCategoryFavorite(category.code, value);
    setState(() {
      _categories = _categories
          .map(
            (c) => c.code == category.code ? c.copyWith(isFavorite: value) : c,
          )
          .toList();
    });
  }

  Future<void> _toggleGroup(List<CategoryItem> items, bool value) async {
    final state = context.read<AppState>();
    for (final item in items) {
      if (item.isFavorite == value) continue;
      await state.db.setCategoryFavorite(item.code, value);
    }
    final codes = items.map((e) => e.code).toSet();
    setState(() {
      _categories = _categories
          .map(
            (c) => codes.contains(c.code) ? c.copyWith(isFavorite: value) : c,
          )
          .toList();
    });
  }

  Future<void> _clearFavorites() async {
    final favorites = _categories.where((c) => c.isFavorite).toList();
    if (favorites.isEmpty) return;
    await _toggleGroup(favorites, false);
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout?'),
        content: const Text(
          'Cart dan data lokal akan dihapus dari perangkat ini.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<AppState>().logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const SplashPage()),
      (_) => false,
    );
  }
}

class _CategoryGroupTile extends StatelessWidget {
  const _CategoryGroupTile({
    required this.name,
    required this.items,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onToggleGroup,
    required this.onToggleItem,
  });

  final String name;
  final List<CategoryItem> items;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final ValueChanged<bool> onToggleGroup;
  final void Function(CategoryItem category, bool value) onToggleItem;

  bool get _allSelected => items.every((e) => e.isFavorite);
  bool get _someSelected => items.any((e) => e.isFavorite);
  int get _selectedCount => items.where((e) => e.isFavorite).length;

  @override
  Widget build(BuildContext context) {
    final single = items.length == 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: single
              ? () => onToggleItem(items.first, !items.first.isFavorite)
              : onToggleExpanded,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Checkbox(
                  tristate: !single,
                  value: single
                      ? items.first.isFavorite
                      : _allSelected
                      ? true
                      : _someSelected
                      ? null
                      : false,
                  onChanged: (v) => onToggleGroup(v ?? false),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        single
                            ? items.first.code
                            : _selectedCount > 0
                            ? '$_selectedCount/${items.length} dipilih'
                            : '${items.length} kode',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!single)
                  Icon(
                    expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: Colors.grey.shade600,
                  ),
              ],
            ),
          ),
        ),
        if (!single && expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 12, 10),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final item in items)
                  FilterChip(
                    label: Text(item.code, style: const TextStyle(fontSize: 12)),
                    selected: item.isFavorite,
                    showCheckmark: false,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    onSelected: (v) => onToggleItem(item, v),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_password.text != _confirm.text) {
      showMessage(context, 'Konfirmasi password tidak sama.');
      return;
    }
    setState(() => _loading = true);
    try {
      await context.read<AppState>().repository.changePassword(_password.text);
      if (!mounted) return;
      showMessage(context, 'Password berhasil diganti.');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        showMessage(
          context,
          e is ApiException ? e.message : 'Gagal mengganti password.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ganti Password')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Password Baru',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: (v) =>
                    (v == null || v.length < 6) ? 'Minimal 6 karakter' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirm,
                obscureText: _obscure,
                decoration: const InputDecoration(
                  labelText: 'Konfirmasi Password Baru',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Simpan Password'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
