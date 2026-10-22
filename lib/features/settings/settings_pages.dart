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
  bool _inStock = false;
  bool _soldOut = false;
  bool _comingSoon = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

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
                const SectionTitle(title: 'Kategori Favorit'),
                const SizedBox(height: 4),
                Text(
                  'Hanya produk dari kategori favorit yang tampil di katalog. Kosongkan semua untuk menampilkan semua kategori.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                if (_categories.isEmpty)
                  const Card(
                    child: ListTile(title: Text('Kategori belum tersedia')),
                  )
                else
                  Card(
                    child: Column(
                      children: _categories
                          .map(
                            (category) => CheckboxListTile(
                              title: Text(category.name),
                              subtitle: Text(category.code),
                              value: category.isFavorite,
                              onChanged: (v) =>
                                  _toggleCategory(category, v ?? false),
                            ),
                          )
                          .toList(),
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
