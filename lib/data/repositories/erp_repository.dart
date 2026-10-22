import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/app_database.dart';
import '../../core/storage/session_store.dart';
import '../../core/utils/format.dart';
import '../models/models.dart';

class ErpRepository {
  ErpRepository({required this.api, required this.store, required this.db});

  final ApiClient api;
  final SessionStore store;
  final AppDatabase db;

  Future<String> _host() async {
    final host = await store.host();
    return host.isEmpty ? AppConfig.defaultHost : host;
  }

  Future<String> _business() async => (await store.company()).businessCode;

  Future<UserSession> _session() async {
    final session = await store.session();
    if (session == null) {
      throw ApiException('Sesi berakhir. Silakan login kembali.');
    }
    return session;
  }

  Future<Map<String, String>> _invoke(
    String operation,
    Map<String, String> params, {
    bool withBusiness = true,
  }) async {
    return api.call(
      host: await _host(),
      operation: operation,
      parameters: {if (withBusiness) 'sBisnis': await _business(), ...params},
    );
  }

  // --- Splash ---
  Future<String> getVersion() async {
    final result = await api.call(
      host: AppConfig.defaultHost,
      operation: 'Versi',
      parameters: {'sAppName': AppConfig.packageName},
    );
    return result['Versi'] ?? '';
  }

  Future<List<BusinessServer>> getBusinesses() async {
    final result = await api.call(
      host: AppConfig.defaultHost,
      operation: 'GetDataBisnis',
      parameters: {'sAppName': AppConfig.packageName},
    );
    return BusinessServer.fromPref(result);
  }

  // --- Auth ---
  Future<List<CategoryItem>> getCategories() async {
    final cached = await db.categories();
    if (cached.isNotEmpty) return cached;
    final result = await _invoke('GetDataProdCat', {});
    final items = CodeName.fromPref(result)
        .map((e) => CategoryItem(code: e.code, name: e.name, isFavorite: false))
        .toList();
    await db.cacheCategories(items);
    return db.categories();
  }

  Future<List<CodeName>> getTops({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await db.tops();
      if (cached.isNotEmpty) return cached;
    }
    final result = await _invoke('GetDataTOP', {});
    final items = CodeName.fromPref(result);
    await db.cacheTops(items);
    return items;
  }

  Future<UserSession> login(String username, String password) async {
    await getCategories();
    final result = await _invoke('Login', {
      'sUser': username,
      'sPwd': password,
    });
    final session = UserSession.fromLogin(result, username);
    if (!session.isValid) {
      throw ApiException('Login gagal. Periksa username/password Anda.');
    }
    await store.saveSession(session, password);
    return session;
  }

  Future<void> register({
    required String username,
    required String password,
    required String idNumber,
    required String customerName,
    required String phone,
    required String email,
    required String birthDay,
    required String address,
    required String top,
  }) async {
    final result = await _invoke('UploadUserReg', {
      'prmUserNam': username,
      'prmUserPwd': password,
      'prmIDNumber': idNumber,
      'prmCustName': customerName,
      'prmPhone': phone,
      'prmEmail': email,
      'prmBDay': birthDay,
      'prmAddress': address,
      'prmTOP': top,
    });
    if ((result['Pref1'] ?? '').isEmpty) {
      throw ApiException('Registrasi gagal. Coba lagi.');
    }
  }

  Future<void> changePassword(String newPassword) async {
    final session = await _session();
    final result = await _invoke('UploadNewPassword', {
      'prmUser': session.username,
      'prmNewPassword': newPassword,
    });
    if ((result['Status'] ?? '').toLowerCase() == 'false') {
      throw ApiException('Gagal mengganti password.');
    }
    await store.saveSession(session, newPassword);
  }

  // --- Profile ---
  Future<ArLimit> getArLimit() async {
    final session = await _session();
    final result = await _invoke('GetDataARLimit', {
      'prmBranchCode': session.busCode,
      'prmCustCode': session.custCode,
    });
    return ArLimit.fromPref(result);
  }

  // --- Catalog ---
  Future<List<Product>> getProducts({
    required String lastCode,
    required String categoryFilter,
    required String where,
    required String having,
  }) async {
    final session = await _session();
    final result = await _invoke('GetDataProductList200902', {
      'prmUser': session.username,
      'prmLastCode': lastCode,
      'prmParam': categoryFilter,
      'prmOrderBy': '',
      'prmWhere': where,
      'prmHaving': having,
    });
    final products = Product.fromPref(result);
    await db.cacheProducts(products);
    return products;
  }

  Future<ProductDetail> getProductDetail(String code) async {
    final session = await _session();
    final result = await _invoke('GetDataProductDetail', {
      'prmUser': session.username,
      'prmBranchCode': session.busCode,
      'prmCode': code,
    });
    return ProductDetail.fromPref(result);
  }

  Future<List<StockCheck>> getStock(List<String> codes) async {
    final result = await _invoke('GetDataStock', {
      'prmProdCode': codes.map((c) => "'$c'").join(','),
    });
    return StockCheck.fromResult(result);
  }

  // --- Order ---
  Future<void> uploadPo({
    required List<CartItem> items,
    required String period,
    required String interval,
    required String deliveryDate,
    required String notes,
    required String topCode,
    required String eoNumber,
  }) async {
    final session = await _session();
    final result = await _invoke('UploadPOCustomer', {
      'prmUserNam': session.username,
      'prmBranchCode': session.busCode,
      'prmCustCode': session.custCode,
      'prmSendingPeriode': period,
      'prmSendingInterval': interval,
      'prmDelDate': deliveryDate,
      'prmNotes': notes,
      'prmProdCode': items.map((e) => "'${e.code}'").join(','),
      'prmQTY2': items.map((e) => e.qty.toString()).join('|'),
      'prmPrice': items.map((e) => e.price.toStringAsFixed(0)).join('|'),
      'prmEONumber': eoNumber,
      'prmTOP': topCode,
      'prmSalesCode': session.salesCode,
    });
    if ((result['Status'] ?? '').toLowerCase() == 'false') {
      throw ApiException('Gagal mengirim pesanan. Coba lagi.');
    }
  }

  Future<List<OrderHeader>> getOrderHeaders(OrderStage stage) async {
    final session = await _session();
    final operation = switch (stage) {
      OrderStage.received => 'GetDataStatusOrder',
      OrderStage.processed => 'GetDataStatusProses',
      OrderStage.delivered => 'GetDataStatusDelivery',
      OrderStage.history => 'GetDataStatusHistory',
    };
    final result = await _invoke(operation, {
      'prmUserNam': session.username,
      'prmBranchCode': session.busCode,
      'prmCustCode': session.custCode,
    });
    return OrderHeader.fromPref(result, stage);
  }

  Future<List<OrderLine>> getOrderLines(
    OrderStage stage,
    String eoNumber,
  ) async {
    final session = await _session();
    final operation = switch (stage) {
      OrderStage.received => 'GetDataOrder',
      OrderStage.processed => 'GetDataProses',
      OrderStage.delivered => 'GetDataDelivery',
      OrderStage.history => 'GetDataHistory',
    };
    final result = await _invoke(operation, {
      'prmUserNam': session.username,
      'prmBranchCode': session.busCode,
      'prmEONumber': eoNumber,
    });
    return OrderLine.fromPref(result);
  }

  // --- Mutation / AR report ---
  Future<MutationReport> getMutation({
    required bool isHistory,
    required DateTime from,
    required DateTime to,
  }) async {
    final session = await _session();
    final result = await _invoke(isHistory ? 'GetRpt6Pref' : 'GetRpt3Pref', {
      'prmType': isHistory ? 'AR History' : 'AR Aging',
      'prmDate1': formatDate(from),
      'prmDate2': formatDate(to),
      'prm1': session.busCode,
      'prm2': session.custCode,
      'prm3': '1',
    });
    final keys = isHistory
        ? ['Pref1', 'Pref2', 'Pref3', 'Pref4', 'Pref5', 'Pref6']
        : ['Pref1', 'Pref2', 'Pref3'];
    return MutationReport(
      title: isHistory ? 'AR History' : 'AR Aging',
      period: '${formatDate(from)} - ${formatDate(to)}',
      columns: [for (final key in keys) splitPref(result[key])],
    );
  }
}
