class Company {
  final String id;
  final String name;

  Company({required this.id, required this.name});

  factory Company.fromJson(Map<String, dynamic> json) =>
      Company(id: json['id'] as String, name: json['name'] as String);

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

class Store {
  final String id;
  final String companyId;
  final String name;
  final double commissionRate;
  final double rent;

  Store({
    required this.id,
    required this.companyId,
    required this.name,
    required this.commissionRate,
    required this.rent,
  });

  factory Store.fromJson(Map<String, dynamic> json) => Store(
        id: json['id'] as String,
        companyId: json['company_id'] as String,
        name: json['name'] as String,
        commissionRate: (json['commission_rate'] as num).toDouble(),
        rent: (json['rent'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'company_id': companyId,
        'name': name,
        'commission_rate': commissionRate,
        'rent': rent,
      };

  Store copyWith({
    String? id,
    String? companyId,
    String? name,
    double? commissionRate,
    double? rent,
  }) =>
      Store(
        id: id ?? this.id,
        companyId: companyId ?? this.companyId,
        name: name ?? this.name,
        commissionRate: commissionRate ?? this.commissionRate,
        rent: rent ?? this.rent,
      );
}

/// A seller/maker person within a company (e.g. Julie — prefix LHDE).
/// Not necessarily an app user — this represents people whose items are tracked.
class CompanyPersonnel {
  final String id;
  final String companyId;
  final String name;
  final String codePrefix; // e.g. 'LHDE', 'LHDM'
  final String? email;

  CompanyPersonnel({
    required this.id,
    required this.companyId,
    required this.name,
    required this.codePrefix,
    this.email,
  });

  factory CompanyPersonnel.fromJson(Map<String, dynamic> json) =>
      CompanyPersonnel(
        id: json['id'] as String,
        companyId: json['company_id'] as String,
        name: json['name'] as String,
        codePrefix: json['code_prefix'] as String,
        email: json['email'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'company_id': companyId,
        'name': name,
        'code_prefix': codePrefix,
        if (email != null) 'email': email,
      };
}

/// Company-wide product catalogue. Not store-specific.
class CatalogueItem {
  final String id;
  final String companyId;
  final String itemCode;
  final String itemName;
  final double costPrice;
  final double sellPrice;

  CatalogueItem({
    required this.id,
    required this.companyId,
    required this.itemCode,
    required this.itemName,
    required this.costPrice,
    required this.sellPrice,
  });

  factory CatalogueItem.fromJson(Map<String, dynamic> json) => CatalogueItem(
        id: json['id'] as String,
        companyId: json['company_id'] as String,
        itemCode: json['item_code'] as String,
        itemName: json['item_name'] as String,
        costPrice: (json['cost_price'] as num).toDouble(),
        sellPrice: (json['sell_price'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'company_id': companyId,
        'item_code': itemCode,
        'item_name': itemName,
        'cost_price': costPrice,
        'sell_price': sellPrice,
      };

  CatalogueItem copyWith({
    String? id,
    String? companyId,
    String? itemCode,
    String? itemName,
    double? costPrice,
    double? sellPrice,
  }) =>
      CatalogueItem(
        id: id ?? this.id,
        companyId: companyId ?? this.companyId,
        itemCode: itemCode ?? this.itemCode,
        itemName: itemName ?? this.itemName,
        costPrice: costPrice ?? this.costPrice,
        sellPrice: sellPrice ?? this.sellPrice,
      );
}

/// Per-store sales data populated by PDF uploads.
class StoreSale {
  final String id;
  final String storeId;
  final String itemCode;
  final int quantitySold;

  StoreSale({
    required this.id,
    required this.storeId,
    required this.itemCode,
    required this.quantitySold,
  });

  factory StoreSale.fromJson(Map<String, dynamic> json) => StoreSale(
        id: json['id'] as String,
        storeId: json['store_id'] as String,
        itemCode: json['item_code'] as String,
        quantitySold: json['quantity_sold'] as int,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'store_id': storeId,
        'item_code': itemCode,
        'quantity_sold': quantitySold,
      };
}

/// Merged view of a StoreSale with its CatalogueItem data — used for display.
class SaleLineItem {
  final StoreSale sale;
  final CatalogueItem catalogueItem;

  SaleLineItem({required this.sale, required this.catalogueItem});

  String get itemCode => sale.itemCode;
  String get itemName => catalogueItem.itemName;
  double get costPrice => catalogueItem.costPrice;
  double get sellPrice => catalogueItem.sellPrice;
  int get quantitySold => sale.quantitySold;

  double get totalSales => quantitySold * sellPrice;
  double commission(double rate) => totalSales * (rate / 100);
  double profitBeforeRent(double rate) =>
      totalSales - commission(rate) - (quantitySold * costPrice);
}
