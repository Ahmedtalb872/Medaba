/// نماذج الفواتير وبيانات المنشأة.
library;

import 'models.dart';

enum InvoiceType {
  sale('فاتورة بيع', 'S', 'العميل'),
  purchase('فاتورة شراء', 'P', 'المورد');

  final String label;

  /// بادئة رقم الفاتورة (S-0001 / P-0001).
  final String prefix;

  /// اسم الطرف الآخر (عميل أو مورد).
  final String partyLabel;
  const InvoiceType(this.label, this.prefix, this.partyLabel);
}

/// سطر واحد في الفاتورة.
class InvoiceLine {
  final String productId;
  final double qty;
  final double unitPrice;

  const InvoiceLine({
    required this.productId,
    required this.qty,
    required this.unitPrice,
  });

  double get total => qty * unitPrice;

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'qty': qty,
    'unitPrice': unitPrice,
  };

  factory InvoiceLine.fromJson(Map<String, dynamic> j) => InvoiceLine(
    productId: j['productId'] as String,
    qty: (j['qty'] as num).toDouble(),
    unitPrice: (j['unitPrice'] as num).toDouble(),
  );
}

/// فاتورة بيع أو شراء بعدة أصناف. حفظها يحرّك المخزون ويسجّل المبلغ في الحسابات.
class Invoice {
  final String id;
  final InvoiceType type;
  final String number;
  final DateTime date;
  final String partyName;
  final String partyPhone;
  final String warehouseId;
  final List<InvoiceLine> lines;
  final double discount;

  /// نسبة ضريبة القيمة المضافة (0 - 100).
  final double taxPercent;
  final String notes;

  /// المعاملة المالية المرتبطة.
  final String? txId;

  const Invoice({
    required this.id,
    required this.type,
    required this.number,
    required this.date,
    this.partyName = '',
    this.partyPhone = '',
    required this.warehouseId,
    required this.lines,
    this.discount = 0,
    this.taxPercent = 0,
    this.notes = '',
    this.txId,
  });

  double get subtotal => lines.fold(0, (s, l) => s + l.total);
  double get afterDiscount => subtotal - discount;
  double get tax => afterDiscount * taxPercent / 100;
  double get total => afterDiscount + tax;

  Invoice withTx(String txId) => Invoice(
    id: id,
    type: type,
    number: number,
    date: date,
    partyName: partyName,
    partyPhone: partyPhone,
    warehouseId: warehouseId,
    lines: lines,
    discount: discount,
    taxPercent: taxPercent,
    notes: notes,
    txId: txId,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'number': number,
    'date': date.toIso8601String(),
    'partyName': partyName,
    'partyPhone': partyPhone,
    'warehouseId': warehouseId,
    'lines': [for (final l in lines) l.toJson()],
    'discount': discount,
    'taxPercent': taxPercent,
    'notes': notes,
    'txId': txId,
  };

  factory Invoice.fromJson(Map<String, dynamic> j) => Invoice(
    id: j['id'] as String,
    type: InvoiceType.values.byName(j['type'] as String),
    number: j['number'] as String,
    date: parseDate(j['date']),
    partyName: j['partyName'] as String? ?? '',
    partyPhone: j['partyPhone'] as String? ?? '',
    warehouseId: j['warehouseId'] as String,
    lines: [
      for (final l in j['lines'] as List)
        InvoiceLine.fromJson(l as Map<String, dynamic>),
    ],
    discount: (j['discount'] as num?)?.toDouble() ?? 0,
    taxPercent: (j['taxPercent'] as num?)?.toDouble() ?? 0,
    notes: j['notes'] as String? ?? '',
    txId: j['txId'] as String?,
  );
}

/// بيانات المنشأة التي تظهر في رأس الفاتورة.
class CompanyInfo {
  final String name;
  final String phone;
  final String address;
  final String taxNumber;

  /// نسبة الضريبة الافتراضية للفواتير الجديدة.
  final double defaultTaxPercent;

  const CompanyInfo({
    this.name = 'مدبّر',
    this.phone = '',
    this.address = '',
    this.taxNumber = '',
    this.defaultTaxPercent = 0,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'phone': phone,
    'address': address,
    'taxNumber': taxNumber,
    'defaultTaxPercent': defaultTaxPercent,
  };

  factory CompanyInfo.fromJson(Map<String, dynamic> j) => CompanyInfo(
    name: j['name'] as String? ?? 'مدبّر',
    phone: j['phone'] as String? ?? '',
    address: j['address'] as String? ?? '',
    taxNumber: j['taxNumber'] as String? ?? '',
    defaultTaxPercent: (j['defaultTaxPercent'] as num?)?.toDouble() ?? 0,
  );
}
