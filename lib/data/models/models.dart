import '../../core/utils/format.dart';

class CodeName {
  const CodeName(this.code, this.name);
  final String code;
  final String name;

  static List<CodeName> fromPref(Map<String, String> r) {
    final codes = splitPref(r['Code']);
    final names = splitPref(r['Name']);
    return [
      for (var i = 0; i < codes.length; i++)
        CodeName(codes[i], i < names.length ? names[i] : codes[i]),
    ];
  }
}

class BusinessServer {
  const BusinessServer({
    required this.businessCode,
    required this.businessName,
    required this.host,
  });
  final String businessCode;
  final String businessName;
  final String host;

  static List<BusinessServer> fromPref(Map<String, String> r) {
    final codes = splitPref(r['Pref1']);
    final names = splitPref(r['Pref2']);
    final hosts = splitPref(r['Pref3']);
    return [
      for (var i = 0; i < codes.length; i++)
        BusinessServer(
          businessCode: codes[i],
          businessName: at(names, i),
          host: at(hosts, i),
        ),
    ];
  }
}

class UserSession {
  const UserSession({
    required this.busCode,
    required this.busName,
    required this.username,
    required this.custCode,
    required this.custName,
    required this.displayName,
    required this.phone,
    required this.email,
    required this.address,
    required this.top,
    required this.groupLimit,
    required this.indLimit,
    required this.arLimit,
    required this.salesCode,
    required this.arOverdue,
  });

  final String busCode;
  final String busName;
  final String username;
  final String custCode;
  final String custName;
  final String displayName;
  final String phone;
  final String email;
  final String address;
  final String top;
  final String groupLimit;
  final String indLimit;
  final String arLimit;
  final String salesCode;
  final String arOverdue;

  factory UserSession.fromLogin(Map<String, String> r, String username) {
    String pref(int i) => r['Pref$i'] ?? '';
    return UserSession(
      busCode: pref(1),
      busName: pref(2),
      username: username,
      custCode: pref(4),
      custName: pref(5),
      displayName: pref(6),
      phone: pref(7),
      email: pref(8),
      address: pref(9),
      top: pref(10),
      groupLimit: pref(11),
      indLimit: pref(12),
      arLimit: pref(13),
      salesCode: pref(14),
      arOverdue: pref(15),
    );
  }

  bool get isValid => busCode.isNotEmpty && username.isNotEmpty;

  Map<String, String> toJson() => {
    'busCode': busCode,
    'busName': busName,
    'username': username,
    'custCode': custCode,
    'custName': custName,
    'displayName': displayName,
    'phone': phone,
    'email': email,
    'address': address,
    'top': top,
    'groupLimit': groupLimit,
    'indLimit': indLimit,
    'arLimit': arLimit,
    'salesCode': salesCode,
    'arOverdue': arOverdue,
  };

  factory UserSession.fromJson(Map<String, String> j) => UserSession(
    busCode: j['busCode'] ?? '',
    busName: j['busName'] ?? '',
    username: j['username'] ?? '',
    custCode: j['custCode'] ?? '',
    custName: j['custName'] ?? '',
    displayName: j['displayName'] ?? '',
    phone: j['phone'] ?? '',
    email: j['email'] ?? '',
    address: j['address'] ?? '',
    top: j['top'] ?? '',
    groupLimit: j['groupLimit'] ?? '0',
    indLimit: j['indLimit'] ?? '0',
    arLimit: j['arLimit'] ?? '0',
    salesCode: j['salesCode'] ?? '',
    arOverdue: j['arOverdue'] ?? '0',
  );

  UserSession copyWith({
    String? groupLimit,
    String? indLimit,
    String? arOverdue,
  }) => UserSession(
    busCode: busCode,
    busName: busName,
    username: username,
    custCode: custCode,
    custName: custName,
    displayName: displayName,
    phone: phone,
    email: email,
    address: address,
    top: top,
    groupLimit: groupLimit ?? this.groupLimit,
    indLimit: indLimit ?? this.indLimit,
    arLimit: arLimit,
    salesCode: salesCode,
    arOverdue: arOverdue ?? this.arOverdue,
  );
}

class ArLimit {
  const ArLimit({
    required this.global,
    required this.limit,
    required this.overdue,
  });
  final double global;
  final double limit;
  final double overdue;

  double get remaining => (global != 0 ? global : limit) - overdue;

  factory ArLimit.fromPref(Map<String, String> r) => ArLimit(
    global: parseDouble(r['Pref1']),
    limit: parseDouble(r['Pref2']),
    overdue: parseDouble(r['Pref3']),
  );
}

class Product {
  const Product({
    required this.code,
    required this.name,
    required this.price,
    required this.description,
    required this.descUom,
    required this.stock,
    required this.imageUrl,
    required this.category,
    required this.specialPrice,
    required this.alias,
  });

  final String code;
  final String name;
  final double price;
  final String description;
  final String descUom;
  final int stock;
  final String imageUrl;
  final String category;
  final double specialPrice;
  final String alias;

  bool get isComingSoon => stock < 0;
  bool get isSoldOut => stock == 0;
  bool get isAvailable => stock > 0;
  int get maxQty => uomFactor(descUom) == 0 ? 0 : stock ~/ uomFactor(descUom);
  double get effectivePrice => specialPrice > 0 ? specialPrice : price;

  List<String> get imageFiles => imageUrl
      .split('|')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty && e != '-')
      .toList();

  static List<Product> fromPref(Map<String, String> r) {
    final images = splitPref(r['Pref1']);
    final codes = splitPref(r['Pref2']);
    final names = splitPref(r['Pref3']);
    final prices = splitPref(r['Pref4']);
    final descs = splitPref(r['Pref5']);
    final uoms = splitPref(r['Pref6']);
    final stocks = splitPref(r['Pref7']);
    final categories = splitPref(r['Pref8']);
    final specials = splitPref(r['Pref9']);
    final aliases = splitPref(r['Pref10']);
    return [
      for (var i = 0; i < codes.length; i++)
        Product(
          code: codes[i],
          name: at(names, i),
          price: parseDouble(at(prices, i)),
          description: at(descs, i),
          descUom: at(uoms, i),
          stock: parseInt(at(stocks, i)),
          imageUrl: at(images, i),
          category: at(categories, i),
          specialPrice: parseDouble(at(specials, i)),
          alias: at(aliases, i),
        ),
    ];
  }

  Map<String, Object?> toDb() => {
    'Code': code,
    'Name': name,
    'Price': price.toString(),
    'Desc': description,
    'DescUOM': descUom,
    'Stock': stock.toString(),
    'ImageUrl': imageUrl,
    'Category': category,
    'SpecialPrice': specialPrice.toString(),
    'Alias': alias,
  };

  factory Product.fromDb(Map<String, Object?> r) => Product(
    code: r['Code'].toString(),
    name: r['Name'].toString(),
    price: parseDouble(r['Price'].toString()),
    description: r['Desc'].toString(),
    descUom: r['DescUOM'].toString(),
    stock: parseInt(r['Stock'].toString()),
    imageUrl: r['ImageUrl'].toString(),
    category: r['Category'].toString(),
    specialPrice: parseDouble(r['SpecialPrice'].toString()),
    alias: r['Alias'].toString(),
  );

  CartItem toCart(int qty) => CartItem(
    code: code,
    name: name,
    price: effectivePrice,
    description: description,
    qty: qty,
    imageUrl: imageFiles.firstOrNull ?? '',
    uom: descUom,
    stock: stock,
    alias: alias,
  );
}

class ProductDetail {
  const ProductDetail({
    required this.dimension,
    required this.cubication,
    required this.primaryUom,
    required this.listPrice,
    required this.stock,
  });
  final String dimension;
  final String cubication;
  final String primaryUom;
  final double listPrice;
  final int stock;

  factory ProductDetail.fromPref(Map<String, String> r) => ProductDetail(
    dimension: r['Pref1'] ?? '',
    cubication: r['Pref2'] ?? '',
    primaryUom: r['Pref3'] ?? '',
    listPrice: parseDouble(r['Pref4']),
    stock: parseInt(r['Pref5']),
  );
}

class CartItem {
  const CartItem({
    required this.code,
    required this.name,
    required this.price,
    required this.description,
    required this.qty,
    required this.imageUrl,
    required this.uom,
    required this.stock,
    required this.alias,
  });

  final String code;
  final String name;
  final double price;
  final String description;
  final int qty;
  final String imageUrl;
  final String uom;
  final int stock;
  final String alias;

  double get lineTotal => qty * uomFactor(uom) * price;

  CartItem copyWith({int? qty}) => CartItem(
    code: code,
    name: name,
    price: price,
    description: description,
    qty: qty ?? this.qty,
    imageUrl: imageUrl,
    uom: uom,
    stock: stock,
    alias: alias,
  );

  Map<String, Object?> toDb() => {
    'Code': code,
    'Name': name,
    'Price': price.toString(),
    'Desc': description,
    'QTY': qty.toString(),
    'ImageURL': imageUrl,
    'UOM': uom,
    'Stock': stock.toString(),
    'Alias': alias,
  };

  factory CartItem.fromDb(Map<String, Object?> r) => CartItem(
    code: r['Code'].toString(),
    name: r['Name'].toString(),
    price: parseDouble(r['Price'].toString()),
    description: r['Desc'].toString(),
    qty: parseInt(r['QTY'].toString()),
    imageUrl: r['ImageURL'].toString(),
    uom: r['UOM'].toString(),
    stock: parseInt(r['Stock'].toString()),
    alias: r['Alias'].toString(),
  );
}

class CategoryItem {
  const CategoryItem({
    required this.code,
    required this.name,
    required this.isFavorite,
  });
  final String code;
  final String name;
  final bool isFavorite;

  CategoryItem copyWith({bool? isFavorite}) => CategoryItem(
    code: code,
    name: name,
    isFavorite: isFavorite ?? this.isFavorite,
  );

  factory CategoryItem.fromDb(Map<String, Object?> r) => CategoryItem(
    code: r['CatCode'].toString(),
    name: r['CatName'].toString(),
    isFavorite: (int.tryParse(r['IsFavorite'].toString()) ?? 0) == 1,
  );
}

enum OrderStage {
  received('Order Received'),
  processed('Order on Process'),
  delivered('Order has been sent'),
  history('Order History');

  const OrderStage(this.label);
  final String label;
}

class OrderHeader {
  const OrderHeader({
    required this.stage,
    required this.eoNumber,
    required this.date,
    required this.qty,
    required this.total,
    required this.period,
    required this.interval,
    required this.deliveryDate,
    required this.notes,
    required this.top,
    required this.status,
  });

  final OrderStage stage;
  final String eoNumber;
  final String date;
  final String qty;
  final double total;
  final String period;
  final String interval;
  final String deliveryDate;
  final String notes;
  final String top;
  final String status;

  static List<OrderHeader> fromPref(Map<String, String> r, OrderStage stage) {
    final eo = splitPref(r['Pref1']);
    final dates = splitPref(r['Pref2']);
    final qtys = splitPref(r['Pref3']);
    final totals = splitPref(r['Pref4']);
    final periods = splitPref(r['Pref5']);
    final intervals = splitPref(r['Pref6']);
    final delDates = splitPref(r['Pref7']);
    final notes = splitPref(r['Pref8']);
    final pref9 = splitPref(r['Pref9']);
    final pref10 = splitPref(r['Pref10']);
    return [
      for (var i = 0; i < eo.length; i++)
        OrderHeader(
          stage: stage,
          eoNumber: eo[i],
          // Legacy list shows Pref2 for Received, Pref9 (SO date) for later stages.
          date: stage == OrderStage.received ? at(dates, i) : at(pref9, i),
          qty: at(qtys, i),
          total: parseDouble(at(totals, i)),
          period: at(periods, i),
          interval: at(intervals, i),
          deliveryDate: at(delDates, i),
          notes: at(notes, i),
          top: stage == OrderStage.received ? at(pref9, i) : '',
          status: stage == OrderStage.history ? at(pref10, i) : stage.label,
        ),
    ];
  }
}

class OrderLine {
  const OrderLine({
    required this.imageUrl,
    required this.code,
    required this.name,
    required this.price,
    required this.description,
    required this.uom,
    required this.qty,
    required this.stock,
  });
  final String imageUrl;
  final String code;
  final String name;
  final double price;
  final String description;
  final String uom;
  final int qty;
  final String stock;

  double get lineTotal => qty * uomFactor(uom) * price;

  static List<OrderLine> fromPref(Map<String, String> r) {
    final images = splitPref(r['Pref1']);
    final codes = splitPref(r['Pref2']);
    final names = splitPref(r['Pref3']);
    final prices = splitPref(r['Pref4']);
    final descs = splitPref(r['Pref5']);
    final uoms = splitPref(r['Pref6']);
    final qtys = splitPref(r['Pref7']);
    final stocks = splitPref(r['Pref8']);
    return [
      for (var i = 0; i < codes.length; i++)
        OrderLine(
          imageUrl: at(images, i),
          code: codes[i],
          name: at(names, i),
          price: parseDouble(at(prices, i)),
          description: at(descs, i),
          uom: at(uoms, i),
          qty: parseInt(at(qtys, i)),
          stock: at(stocks, i),
        ),
    ];
  }

  CartItem toCart() => CartItem(
    code: code,
    name: name,
    price: price,
    description: description,
    qty: qty,
    imageUrl: imageUrl,
    uom: uom,
    stock: parseInt(stock),
    alias: '',
  );
}

class StockCheck {
  const StockCheck(this.code, this.stock);
  final String code;
  final int stock;

  static List<StockCheck> fromResult(Map<String, String> r) {
    final codes = splitPref(r['ProdCode']);
    final stocks = splitPref(r['Stock']);
    return [
      for (var i = 0; i < codes.length; i++)
        StockCheck(codes[i].replaceAll("'", ''), parseInt(at(stocks, i))),
    ];
  }
}

class MutationReport {
  const MutationReport({
    required this.title,
    required this.period,
    required this.columns,
  });
  final String title;
  final String period;
  final List<List<String>> columns;

  int get rowCount => columns.isEmpty
      ? 0
      : columns.map((c) => c.length).reduce((a, b) => a > b ? a : b);
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
