/// الفاتورة المفتوحة: زبون يشتري كمية كبيرة (مثل 1000 قطعة) ويتركها في المخزن،
/// ثم يأخذ منها على دفعات ويدفع عن كل دفعة حتى يكتمل ما اشتراه.
library;

import 'invoice.dart';
import 'models.dart';

class OpenOrder {
  final String id;

  /// رقم الفاتورة المفتوحة، مثل O-0001.
  final String number;
  final DateTime date;
  final String partyName;
  final String partyPhone;

  /// المخزن الذي تبقى فيه البضاعة محجوزة للزبون.
  final String warehouseId;

  /// الأصناف بكمياتها الكاملة وسعرها المتفق عليه.
  final List<InvoiceLine> lines;
  final String notes;

  const OpenOrder({
    required this.id,
    required this.number,
    required this.date,
    required this.partyName,
    this.partyPhone = '',
    required this.warehouseId,
    required this.lines,
    this.notes = '',
  });

  /// القيمة الكاملة لما اشتراه الزبون.
  double get total => lines.fold(0, (s, l) => s + l.total);

  double get totalQty => lines.fold(0, (s, l) => s + l.qty);

  /// الكمية المتفق عليها من صنف.
  double qtyOf(String productId) =>
      lines.where((l) => l.productId == productId).fold(0, (s, l) => s + l.qty);

  /// السعر المتفق عليه لصنف.
  double priceOf(String productId) =>
      lines.where((l) => l.productId == productId).firstOrNull?.unitPrice ?? 0;

  Map<String, dynamic> toJson() => {
    'id': id,
    'number': number,
    'date': date.toIso8601String(),
    'partyName': partyName,
    'partyPhone': partyPhone,
    'warehouseId': warehouseId,
    'lines': [for (final l in lines) l.toJson()],
    'notes': notes,
  };

  factory OpenOrder.fromJson(Map<String, dynamic> j) => OpenOrder(
    id: j['id'] as String,
    number: j['number'] as String? ?? '',
    date: parseDate(j['date']),
    partyName: j['partyName'] as String? ?? '',
    partyPhone: j['partyPhone'] as String? ?? '',
    warehouseId: j['warehouseId'] as String,
    lines: [
      for (final l in (j['lines'] as List? ?? const []))
        InvoiceLine.fromJson(Map<String, dynamic>.from(l as Map)),
    ],
    notes: j['notes'] as String? ?? '',
  );
}
