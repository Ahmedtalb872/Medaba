/// نماذج إدارة المخازن: المخازن، الأصناف، وحركات المخزون.
library;

import 'models.dart';

/// مخزن/مستودع.
class Warehouse {
  final String id;
  final String name;
  final String location;
  final String notes;

  const Warehouse({
    required this.id,
    required this.name,
    this.location = '',
    this.notes = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'location': location,
    'notes': notes,
  };

  factory Warehouse.fromJson(Map<String, dynamic> j) => Warehouse(
    id: j['id'] as String,
    name: j['name'] as String,
    location: j['location'] as String? ?? '',
    notes: j['notes'] as String? ?? '',
  );
}

/// صنف/منتج يُخزَّن.
class Product {
  final String id;
  final String name;
  final String code;

  /// وحدة القياس (قطعة، كرتون، كيلو...).
  final String unit;
  final double costPrice;
  final double salePrice;

  /// الحد الأدنى للكمية؛ عند الوصول إليه يظهر تنبيه نقص المخزون.
  final double minQty;

  const Product({
    required this.id,
    required this.name,
    this.code = '',
    this.unit = 'قطعة',
    this.costPrice = 0,
    this.salePrice = 0,
    this.minQty = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'code': code,
    'unit': unit,
    'costPrice': costPrice,
    'salePrice': salePrice,
    'minQty': minQty,
  };

  factory Product.fromJson(Map<String, dynamic> j) => Product(
    id: j['id'] as String,
    name: j['name'] as String,
    code: j['code'] as String? ?? '',
    unit: j['unit'] as String? ?? 'قطعة',
    costPrice: (j['costPrice'] as num?)?.toDouble() ?? 0,
    salePrice: (j['salePrice'] as num?)?.toDouble() ?? 0,
    minQty: (j['minQty'] as num?)?.toDouble() ?? 0,
  );
}

enum MoveType {
  /// وارد بالشراء: يُسجَّل تلقائياً كمصروف مشتريات.
  purchase('وارد - شراء', isIn: true, financial: TxCategory.supplies),

  /// وارد بدون تكلفة: رصيد افتتاحي، مرتجع، إلخ.
  stockIn('وارد - إضافة', isIn: true),

  /// صادر بالبيع: يُسجَّل تلقائياً كإيراد مبيعات.
  sale('صادر - بيع', isIn: false, financial: TxCategory.sales),

  /// صادر بدون بيع: استهلاك، تالف، إلخ.
  stockOut('صادر - صرف/تالف', isIn: false),

  /// تحويل كمية من مخزن إلى آخر.
  transfer('تحويل بين المخازن', isIn: false);

  final String label;
  final bool isIn;

  /// تصنيف المعاملة المالية التي تُنشأ تلقائياً مع هذه الحركة (إن وجد).
  final TxCategory? financial;
  const MoveType(this.label, {required this.isIn, this.financial});

  /// هل تُنقص هذه الحركة من رصيد المخزن المصدر؟
  bool get decreasesSource => !isIn;
  bool get hasPrice => financial != null;
}

/// حركة مخزون واحدة.
class StockMove {
  final String id;
  final MoveType type;
  final String productId;

  /// المخزن (أو المخزن المصدر في حالة التحويل).
  final String warehouseId;

  /// المخزن الهدف في حالة التحويل فقط.
  final String? toWarehouseId;
  final double qty;

  /// سعر الوحدة للشراء والبيع.
  final double unitPrice;
  final DateTime date;
  final String note;

  /// المعاملة المالية المرتبطة (للشراء والبيع خارج الفواتير).
  final String? txId;

  /// الفاتورة التي أنشأت هذه الحركة؛ تُعدَّل وتُحذف من شاشة الفواتير فقط.
  final String? invoiceId;

  const StockMove({
    required this.id,
    required this.type,
    required this.productId,
    required this.warehouseId,
    this.toWarehouseId,
    required this.qty,
    this.unitPrice = 0,
    required this.date,
    this.note = '',
    this.txId,
    this.invoiceId,
  });

  double get total => qty * unitPrice;

  /// أثر الحركة على رصيد صنفها في مخزن معيّن، أو على الإجمالي إن كان [warehouseId] فارغاً.
  double effectOn(String? warehouseId) {
    if (type == MoveType.transfer) {
      if (warehouseId == null) return 0;
      if (warehouseId == this.warehouseId) return -qty;
      if (warehouseId == toWarehouseId) return qty;
      return 0;
    }
    if (warehouseId != null && warehouseId != this.warehouseId) return 0;
    return type.isIn ? qty : -qty;
  }

  StockMove copyWith({String? txId, bool clearTx = false}) => StockMove(
    id: id,
    type: type,
    productId: productId,
    warehouseId: warehouseId,
    toWarehouseId: toWarehouseId,
    qty: qty,
    unitPrice: unitPrice,
    date: date,
    note: note,
    txId: clearTx ? null : (txId ?? this.txId),
    invoiceId: invoiceId,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'productId': productId,
    'warehouseId': warehouseId,
    'toWarehouseId': toWarehouseId,
    'qty': qty,
    'unitPrice': unitPrice,
    'date': date.toIso8601String(),
    'note': note,
    'txId': txId,
    'invoiceId': invoiceId,
  };

  factory StockMove.fromJson(Map<String, dynamic> j) => StockMove(
    id: j['id'] as String,
    type: MoveType.values.byName(j['type'] as String),
    productId: j['productId'] as String,
    warehouseId: j['warehouseId'] as String,
    toWarehouseId: j['toWarehouseId'] as String?,
    qty: (j['qty'] as num).toDouble(),
    unitPrice: (j['unitPrice'] as num?)?.toDouble() ?? 0,
    date: parseDate(j['date']),
    note: j['note'] as String? ?? '',
    txId: j['txId'] as String?,
    invoiceId: j['invoiceId'] as String?,
  );
}
