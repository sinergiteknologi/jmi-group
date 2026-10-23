import 'package:flutter/foundation.dart';

import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../core/storage/app_database.dart';
import '../core/storage/session_store.dart';
import '../data/models/models.dart';
import '../data/repositories/erp_repository.dart';

class AppState extends ChangeNotifier {
  AppState({required this.repository, required this.store, required this.db});

  final ErpRepository repository;
  final SessionStore store;
  final AppDatabase db;

  bool initialized = false;
  Company company = Company.empty;
  String businessName = '';
  UserSession? session;
  int cartCount = 0;
  List<BusinessServer> businesses = const [];
  String? versionInfo;
  String? bootstrapError;

  bool get isLoggedIn => session != null;

  static Company companyFromBusiness(BusinessServer b) => Company(
    businessCode: b.businessCode,
    name: b.businessName,
    shortName: b.shortName.isEmpty ? b.businessCode : b.shortName,
    imageFolder: b.imageFolder,
    imageHost: b.imageHost.isEmpty ? b.host : b.imageHost,
    tagline: b.tagline,
  );

  Future<void> bootstrap() async {
    try {
      company = await store.company();
      businessName = await store.businessName();
      session = await store.session();
      cartCount = await db.cartCount();
      try {
        versionInfo = await repository.getVersion();
      } catch (_) {}
      try {
        businesses = await repository.getBusinesses();
        if (company.isEmpty && businesses.isNotEmpty) {
          company = companyFromBusiness(businesses.first);
          businessName = businesses.first.businessName;
        } else if (!company.isEmpty && businesses.isNotEmpty) {
          final match = businesses.where(
            (b) => b.businessCode == company.businessCode,
          );
          if (match.isNotEmpty) {
            company = companyFromBusiness(match.first);
            businessName = match.first.businessName;
          }
        }
      } catch (e) {
        bootstrapError = e is ApiException ? e.message : null;
      }
    } catch (e) {
      bootstrapError = 'Gagal memuat data awal.';
    }
    initialized = true;
    notifyListeners();
  }

  Future<void> selectCompany(Company selected) async {
    final match = businesses.where(
      (b) => b.businessCode == selected.businessCode,
    );
    final server = match.isEmpty ? null : match.first;
    await store.clearSession();
    await db.clearAll();
    session = null;
    cartCount = 0;
    company = selected;
    businessName = server?.businessName ?? selected.name;
    await store.saveCompany(
      selected,
      host: server?.host ?? '',
      businessName: businessName,
    );
    notifyListeners();
  }

  Future<void> applySession(UserSession value) async {
    session = value;
    cartCount = await db.cartCount();
    notifyListeners();
  }

  Future<void> refreshCart() async {
    cartCount = await db.cartCount();
    notifyListeners();
  }

  Future<void> addToCart(Product product, int qty) async {
    await db.upsertCart(product.toCart(qty));
    await refreshCart();
  }

  Future<void> logout() async {
    await store.clearAll();
    await db.clearAll();
    session = null;
    cartCount = 0;
    notifyListeners();
  }

  Future<void> expireSession() async {
    await store.clearSession();
    session = null;
    notifyListeners();
  }
}
