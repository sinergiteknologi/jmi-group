import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/network/soap_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../data/models/models.dart';
import '../../shared/widgets.dart';
import '../../state/app_state.dart';
import '../shell/main_shell.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 28),
            const Icon(
              Icons.storefront_rounded,
              size: 56,
              color: AppColors.primary,
            ),
            const SizedBox(height: 12),
            const Text(
              'Venus JMI Group',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              'Pesan produk, pantau pengiriman,\ndan kelola piutang dalam satu aplikasi.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, height: 1.4),
            ),
            if (state.versionInfo != null && state.versionInfo!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Chip(label: Text('Versi server ${state.versionInfo}')),
            ],
            const SizedBox(height: 28),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Pilih perusahaan',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: Company.all.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final company = Company.all[index];
                  return Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: CircleAvatar(
                        radius: 28,
                        backgroundColor: AppColors.primary.withValues(
                          alpha: 0.1,
                        ),
                        child: Text(
                          company.shortName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      title: Text(
                        company.name,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(company.tagline),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 18),
                      onTap: () => _select(context, company),
                    ),
                  );
                },
              ),
            ),
            if (state.bootstrapError != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  state.bootstrapError!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.orange.shade800),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _select(BuildContext context, Company company) async {
    final state = context.read<AppState>();
    await state.selectCompany(company);
    if (!context.mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _user = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _user.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final state = context.read<AppState>();
    try {
      final session = await state.repository.login(
        _user.text.trim(),
        _password.text,
      );
      await state.applySession(session);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    } catch (e) {
      if (mounted) {
        showMessage(context, e is SoapException ? e.message : 'Login gagal.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const SplashPage()),
                    ),
                    icon: const Icon(Icons.arrow_back),
                  ),
                ),
                const SizedBox(height: 12),
                CircleAvatar(
                  radius: 36,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: Text(
                    state.company.shortName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  state.company.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Masuk untuk melanjutkan pemesanan',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _user,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Username wajib diisi'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Password',
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
                      (v == null || v.isEmpty) ? 'Password wajib diisi' : null,
                  onFieldSubmitted: (_) => _login(),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _loading ? null : _login,
                  child: _loading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Masuk'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RegisterPage()),
                  ),
                  child: const Text('Registrasi Akun Baru'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _idNumber = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _birthDay = TextEditingController();
  final _address = TextEditingController();
  List<CodeName> _tops = const [];
  CodeName? _selectedTop;
  bool _agree = false;
  bool _loading = false;
  DateTime? _birthDate;

  @override
  void initState() {
    super.initState();
    _loadTops();
  }

  Future<void> _loadTops() async {
    try {
      final tops = await context.read<AppState>().repository.getTops();
      if (mounted) {
        setState(() {
          _tops = tops;
          _selectedTop = tops.firstOrNull;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    for (final c in [
      _idNumber,
      _username,
      _password,
      _confirm,
      _name,
      _phone,
      _email,
      _birthDay,
      _address,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_password.text != _confirm.text) {
      showMessage(context, 'Konfirmasi password tidak sama.');
      return;
    }
    if (!_agree) {
      showMessage(context, 'Anda harus menyetujui Syarat & Ketentuan.');
      return;
    }
    setState(() => _loading = true);
    try {
      await context.read<AppState>().repository.register(
        username: _username.text.trim(),
        password: _password.text,
        idNumber: _idNumber.text.trim(),
        customerName: _name.text.trim(),
        phone: _phone.text.trim(),
        email: _email.text.trim(),
        birthDay: _birthDay.text.trim(),
        address: _address.text.trim(),
        top: _selectedTop?.code ?? '',
      );
      if (!mounted) return;
      showMessage(
        context,
        'Registrasi terkirim. Menunggu verifikasi 1x24 jam kerja.',
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        showMessage(
          context,
          e is SoapException ? e.message : 'Registrasi gagal.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registrasi')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _field(_idNumber, 'Nomor ID (KTP/NPWP)', Icons.badge_outlined),
              _field(_username, 'Username', Icons.person_outline),
              _field(_password, 'Password', Icons.lock_outline, obscure: true),
              _field(
                _confirm,
                'Konfirmasi Password',
                Icons.lock_outline,
                obscure: true,
              ),
              _field(_name, 'Nama Customer', Icons.store_outlined),
              _field(
                _phone,
                'Nomor Telepon',
                Icons.phone_outlined,
                keyboard: TextInputType.phone,
              ),
              _field(
                _email,
                'Email',
                Icons.email_outlined,
                keyboard: TextInputType.emailAddress,
              ),
              TextFormField(
                controller: _birthDay,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Tanggal Lahir',
                  prefixIcon: Icon(Icons.cake_outlined),
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Wajib diisi' : null,
                onTap: () async {
                  final picked = await pickDate(
                    context,
                    _birthDate ?? DateTime(1990),
                  );
                  if (picked != null) {
                    _birthDate = picked;
                    _birthDay.text = formatDate(picked);
                  }
                },
              ),
              const SizedBox(height: 16),
              _field(
                _address,
                'Alamat',
                Icons.location_on_outlined,
                maxLines: 3,
              ),
              if (_tops.isNotEmpty) ...[
                DropdownButtonFormField<CodeName>(
                  initialValue: _selectedTop,
                  decoration: const InputDecoration(
                    labelText: 'TOP (Term of Payment)',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                  items: _tops
                      .map(
                        (t) => DropdownMenuItem(value: t, child: Text(t.name)),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _selectedTop = v),
                ),
                const SizedBox(height: 8),
              ],
              CheckboxListTile(
                value: _agree,
                onChanged: (v) => setState(() => _agree = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                title: Wrap(
                  children: [
                    const Text('Saya menyetujui '),
                    InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const TermsPage()),
                      ),
                      child: const Text(
                        'Syarat & Ketentuan',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Daftar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool obscure = false,
    int maxLines = 1,
    TextInputType? keyboard,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        maxLines: maxLines,
        keyboardType: keyboard,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
        validator: (v) =>
            (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
      ),
    );
  }
}

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final company = context.watch<AppState>().company.name;
    return Scaffold(
      appBar: AppBar(title: const Text('Syarat & Ketentuan')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Dokumen Persyaratan Registrasi',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Terdapat dua tipe pendaftaran akun: Individu (Non PKP) dan PKP (Pengusaha Kena Pajak). '
            'Perbedaan keduanya hanya pada dokumen persyaratan registrasi. Setelah data diajukan, '
            'tim kami akan melakukan verifikasi akun dalam 1x24 jam kerja.',
            style: TextStyle(height: 1.5),
          ),
          const SizedBox(height: 20),
          const Text(
            'Ketentuan Akun',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Pelanggan wajib membaca, menyetujui, dan menerima seluruh aturan ini. Registrasi tidak dikenakan biaya. '
            'Semua data harus diisi lengkap dan benar serta tidak menggunakan data milik orang lain. '
            'Anda bertanggung jawab menjaga kerahasiaan akun & password, serta seluruh aktivitas atas akun Anda — '
            'termasuk data hutang piutang, PO, dan riwayat pengiriman di dalamnya. Selalu logout setelah selesai menggunakan aplikasi. '
            '$company berhak membatalkan order apabila terdapat ketidaksesuaian/system error. '
            'Syarat & Ketentuan dapat diubah sewaktu-waktu dan dianggap telah dipahami setelah perubahan.',
            style: const TextStyle(height: 1.5),
          ),
          const SizedBox(height: 20),
          const Text(
            'Transaksi & Pembayaran',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Customer wajib bertransaksi melalui prosedur yang ditetapkan $company dan membayar sesuai metode yang dipilih '
            'dengan nominal sesuai nota/invoice. Sebelum menyelesaikan transaksi, Customer bertanggung jawab membaca deskripsi barang '
            '(harga, dimensi, isi per carton) dan memeriksa kembali keranjang order. '
            'Foto produk telah diupayakan seakurat mungkin, namun tampilan dapat berbeda tergantung layar perangkat.\n\n'
            'Pembayaran ready stock: CBD (sebelum barang dikirim), COD (saat barang tiba), Cash Keras (maks. 6 hari dalam kota / 10 hari luar kota), '
            'Cash Regular (maks. 14 hari dalam kota / 21 hari luar kota), TOP/tempo 30 hari setelah barang dikirim.\n\n'
            'Pembayaran indent/pre-order: Cash Advanced — DP 30% saat PO dan pelunasan 70% saat barang loading ke kontainer (diskon cash 5%), '
            'atau Cash Regular — DP 30% saat PO dan pelunasan 70% saat barang tiba di Indonesia (maks. tempo 7 hari).\n\n'
            'Konfirmasi pengiriman dilakukan tim Delivery H-1 sebelum barang dikirim.',
            style: const TextStyle(height: 1.5),
          ),
          const SizedBox(height: 20),
          const Text(
            'Refund & Pengembalian Barang',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Refund hanya berlaku untuk kelebihan pembayaran, atau ketidaksesuaian jenis/jumlah/warna barang yang disebabkan oleh pabrik. '
            'Batas komplain barang maksimal 7 hari setelah barang diterima. Pengembalian di luar ketentuan tersebut tidak dapat dilayani. '
            'Pengembalian dana dilakukan melalui potong nota pada invoice berikutnya atau transfer ke rekening yang terdaftar saat registrasi. '
            'Keputusan perusahaan atas permasalahan transaksi yang belum tercapai kesepakatan bersifat final.',
            style: TextStyle(height: 1.5),
          ),
          const SizedBox(height: 20),
          const Text(
            'Metode Bisnis Perusahaan',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            '$company adalah perusahaan importir dan trading. Barang yang dicari namun tidak ada di katalog dapat diajukan melalui Sales/Marketing kami; '
            'barang request bersifat eksklusif untuk Customer pemesan dengan ketentuan MOQ. '
            'Produk impor telah memiliki SNI, petunjuk penggunaan Bahasa Indonesia/Inggris, label Bahasa Indonesia, dan sesuai regulasi yang berlaku. '
            'Harga barang sudah termasuk PPN.',
            style: const TextStyle(height: 1.5),
          ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
