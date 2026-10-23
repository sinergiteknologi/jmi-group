import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/models.dart';
import '../config/app_config.dart';

class SessionStore {
  SessionStore({FlutterSecureStorage? secure})
    : _secure = secure ?? const FlutterSecureStorage();

  final FlutterSecureStorage _secure;

  static const _kCompany = 'company_code';
  static const _kCompanyJson = 'company_json';
  static const _kHost = 'app_server';
  static const _kBusinessName = 'app_business_name';
  static const _kSession = 'user_session';
  static const _kPassword = 'user_password';
  static const _kViewInStock = 'view_in_stock';
  static const _kViewSoldOut = 'view_sold_out';
  static const _kViewComingSoon = 'view_coming_soon';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<void> saveCompany(
    Company company, {
    String host = '',
    String businessName = '',
  }) async {
    final prefs = await _prefs;
    await prefs.setString(_kCompany, company.businessCode);
    await prefs.setString(_kCompanyJson, jsonEncode(company.toJson()));
    await prefs.setString(_kHost, host);
    await prefs.setString(_kBusinessName, businessName);
  }

  Future<Company> company() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_kCompanyJson);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = (jsonDecode(raw) as Map).map(
          (k, v) => MapEntry(k.toString(), v?.toString() ?? ''),
        );
        final company = Company.fromJson(decoded);
        if (!company.isEmpty) return company;
      } catch (_) {}
    }
    return Company.empty;
  }

  Future<String> host() async {
    final prefs = await _prefs;
    return prefs.getString(_kHost) ?? '';
  }

  Future<String> businessName() async {
    final prefs = await _prefs;
    return prefs.getString(_kBusinessName) ?? '';
  }

  Future<bool> hasCompanySelection() async {
    final prefs = await _prefs;
    return prefs.containsKey(_kCompany);
  }

  Future<void> saveSession(UserSession session, String password) async {
    final prefs = await _prefs;
    await prefs.setString(_kSession, jsonEncode(session.toJson()));
    await _secure.write(key: _kPassword, value: password);
  }

  Future<UserSession?> session() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_kSession);
    if (raw == null || raw.isEmpty) return null;
    final decoded = (jsonDecode(raw) as Map).map(
      (k, v) => MapEntry(k.toString(), v.toString()),
    );
    final session = UserSession.fromJson(decoded);
    return session.isValid ? session : null;
  }

  Future<String> password() async => await _secure.read(key: _kPassword) ?? '';

  Future<void> saveStockFilters({
    bool? inStock,
    bool? soldOut,
    bool? comingSoon,
  }) async {
    final prefs = await _prefs;
    if (inStock != null) await prefs.setBool(_kViewInStock, inStock);
    if (soldOut != null) await prefs.setBool(_kViewSoldOut, soldOut);
    if (comingSoon != null) await prefs.setBool(_kViewComingSoon, comingSoon);
  }

  Future<({bool inStock, bool soldOut, bool comingSoon})> stockFilters() async {
    final prefs = await _prefs;
    return (
      inStock: prefs.getBool(_kViewInStock) ?? false,
      soldOut: prefs.getBool(_kViewSoldOut) ?? false,
      comingSoon: prefs.getBool(_kViewComingSoon) ?? false,
    );
  }

  Future<void> clearSession() async {
    final prefs = await _prefs;
    await prefs.remove(_kSession);
    await _secure.delete(key: _kPassword);
  }

  Future<void> clearAll() async {
    final prefs = await _prefs;
    await prefs.clear();
    await _secure.deleteAll();
  }
}
