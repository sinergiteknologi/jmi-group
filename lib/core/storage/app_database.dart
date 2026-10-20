import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../data/models/models.dart';

class AppDatabase {
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final dir = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dir, 'VenusERPJMGroup_Client.db'),
      version: 1,
      onCreate: (db, _) async {
        await db.execute('CREATE TABLE IF NOT EXISTS M_VERSION (Version TEXT)');
        await db.execute(
          'CREATE TABLE IF NOT EXISTS M_LOGIN (Login TEXT, BusCode TEXT, BusName TEXT, '
          'UserName TEXT, CustCode TEXT, CustName TEXT, SName TEXT, Phone TEXT, Email TEXT, '
          'Address TEXT, TOP TEXT, UserAut TEXT, BranchAut TEXT, Password TEXT)',
        );
        await db.execute(
          'CREATE TABLE IF NOT EXISTS H_CART (Code TEXT PRIMARY KEY, Name TEXT, Price TEXT, '
          '"Desc" TEXT, QTY TEXT, ImageURL TEXT, UOM TEXT, Stock TEXT, Alias TEXT)',
        );
        await db.execute(
          'CREATE TABLE IF NOT EXISTS T_DETAILORDER (EONumber TEXT, Code TEXT, Name TEXT, '
          'Price TEXT, "Desc" TEXT, QTY TEXT, ImageURL TEXT, UOM TEXT)',
        );
        await db.execute(
          'CREATE TABLE IF NOT EXISTS M_PRODUCT (Code TEXT PRIMARY KEY, Name TEXT, Price TEXT, '
          '"Desc" TEXT, DescUOM TEXT, Stock TEXT, ImageUrl TEXT, Category TEXT, '
          'SpecialPrice TEXT, Alias TEXT)',
        );
        await db.execute(
          'CREATE TABLE IF NOT EXISTS M_TOP (TOPCode TEXT, TOPName TEXT)',
        );
        await db.execute(
          'CREATE TABLE IF NOT EXISTS M_CATEGORY (CatCode TEXT PRIMARY KEY, CatName TEXT, '
          'IsFavorite INTEGER)',
        );
      },
    );
    return _db!;
  }

  // --- Cart (H_CART) ---
  Future<List<CartItem>> cartItems() async {
    final db = await database;
    final rows = await db.query('H_CART', orderBy: 'Name ASC');
    return rows.map(CartItem.fromDb).toList();
  }

  Future<void> upsertCart(CartItem item) async {
    final db = await database;
    await db.insert(
      'H_CART',
      item.toDb(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateCartQty(String code, int qty) async {
    final db = await database;
    if (qty <= 0) {
      await db.delete('H_CART', where: 'Code = ?', whereArgs: [code]);
    } else {
      await db.update(
        'H_CART',
        {'QTY': qty.toString()},
        where: 'Code = ?',
        whereArgs: [code],
      );
    }
  }

  Future<void> removeCart(String code) async {
    final db = await database;
    await db.delete('H_CART', where: 'Code = ?', whereArgs: [code]);
  }

  Future<void> clearCart() async {
    final db = await database;
    await db.delete('H_CART');
  }

  Future<int> cartCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) AS c FROM H_CART');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> cartQtyFor(String code) async {
    final db = await database;
    final rows = await db.query(
      'H_CART',
      columns: ['QTY'],
      where: 'Code = ?',
      whereArgs: [code],
      limit: 1,
    );
    if (rows.isEmpty) return 0;
    return int.tryParse(rows.first['QTY'].toString()) ?? 0;
  }

  // --- Product cache (M_PRODUCT) ---
  Future<List<Product>> cachedProducts({
    String search = '',
    Set<String> favoriteCategories = const {},
    Set<int> stockFilters = const {},
  }) async {
    final db = await database;
    final where = <String>[];
    final args = <Object?>[];
    if (search.isNotEmpty) {
      where.add('(Name LIKE ? OR Code LIKE ? OR Alias LIKE ?)');
      args.addAll(['%$search%', '%$search%', '%$search%']);
    }
    if (favoriteCategories.isNotEmpty) {
      where.add(
        'Category IN (${List.filled(favoriteCategories.length, '?').join(',')})',
      );
      args.addAll(favoriteCategories);
    }
    if (stockFilters.isNotEmpty) {
      final stockWhere = <String>[];
      if (stockFilters.contains(1)) stockWhere.add('CAST(Stock AS REAL) > 0');
      if (stockFilters.contains(0)) stockWhere.add('CAST(Stock AS REAL) = 0');
      if (stockFilters.contains(-1)) stockWhere.add('CAST(Stock AS REAL) = -1');
      if (stockWhere.isNotEmpty) where.add('(${stockWhere.join(' OR ')})');
    }
    final rows = await db.query(
      'M_PRODUCT',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'Name ASC',
    );
    return rows.map(Product.fromDb).toList();
  }

  Future<void> cacheProducts(List<Product> products) async {
    final db = await database;
    final batch = db.batch();
    for (final product in products) {
      batch.insert(
        'M_PRODUCT',
        product.toDb(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> clearProducts() async {
    final db = await database;
    await db.delete('M_PRODUCT');
  }

  // --- Categories (M_CATEGORY) ---
  Future<List<CategoryItem>> categories() async {
    final db = await database;
    final hasLocal = await db.query('M_CATEGORY', limit: 1);
    if (hasLocal.isEmpty) return const [];
    final rows = await db.query('M_CATEGORY', orderBy: 'CatName ASC');
    return rows.map(CategoryItem.fromDb).toList();
  }

  Future<void> cacheCategories(List<CategoryItem> items) async {
    final db = await database;
    final batch = db.batch();
    for (final item in items) {
      batch.insert('M_CATEGORY', {
        'CatCode': item.code,
        'CatName': item.name,
        'IsFavorite': item.isFavorite ? 1 : 0,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  Future<void> setCategoryFavorite(String code, bool favorite) async {
    final db = await database;
    await db.update(
      'M_CATEGORY',
      {'IsFavorite': favorite ? 1 : 0},
      where: 'CatCode = ?',
      whereArgs: [code],
    );
  }

  // --- TOP cache (M_TOP) ---
  Future<void> cacheTops(List<CodeName> items) async {
    final db = await database;
    await db.delete('M_TOP');
    final batch = db.batch();
    for (final item in items) {
      batch.insert('M_TOP', {'TOPCode': item.code, 'TOPName': item.name});
    }
    await batch.commit(noResult: true);
  }

  Future<List<CodeName>> tops() async {
    final db = await database;
    final rows = await db.query('M_TOP', orderBy: 'TOPName ASC');
    return rows
        .map((r) => CodeName(r['TOPCode'].toString(), r['TOPName'].toString()))
        .toList();
  }

  Future<void> clearAll() async {
    final db = await database;
    for (final table in [
      'M_VERSION',
      'M_LOGIN',
      'H_CART',
      'T_DETAILORDER',
      'M_PRODUCT',
      'M_TOP',
      'M_CATEGORY',
    ]) {
      await db.delete(table);
    }
  }
}
