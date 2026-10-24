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

  /// سعر شراء الوحدة لحظة البيع، لحساب الربح حتى لو تغيّر سعر الشراء لاحقاً.
  /// null في الفواتير القديمة (يُستعمل سعر الشراء الحالي للصنف).
  final double? unitCost;

  const InvoiceLine({
    required this.productId,
    required this.qty,
    required this.unitPrice,
    this.unitCost,
  });

  double get total => qty * unitPrice;

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'qty': qty,
    'unitPrice': unitPrice,
    if (unitCost != null) 'unitCost': unitCost,
  };

  factory InvoiceLine.fromJson(Map<String, dynamic> j) => InvoiceLine(
    productId: j['productId'] as String,
    qty: (j['qty'] as num).toDouble(),
    unitPrice: (j['unitPrice'] as num).toDouble(),
    unitCost: (j['unitCost'] as num?)?.toDouble(),
  );
}

/// دفعة تسليم: ما أخذه الزبون من بضاعة فاتورة البيع في يوم معيّن.
class Delivery {
  final String id;
  final DateTime date;

  /// الكمية المأخوذة لكل صنف.
  final Map<String, double> items;
  final String note;

  const Delivery({
    required this.id,
    required this.date,
    required this.items,
    this.note = '',
  });

  double qtyOf(String productId) => items[productId] ?? 0;

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'items': items,
    'note': note,
  };

  factory Delivery.fromJson(Map<String, dynamic> j) => Delivery(
    id: j['id'] as String,
    date: parseDate(j['date']),
    items: {
      for (final e in (j['items'] as Map? ?? {}).entries)
        e.key as String: (e.value as num).toDouble(),
    },
    note: j['note'] as String? ?? '',
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
  final String notes;

  /// المعاملة المالية المرتبطة.
  final String? txId;

  /// المبلغ المؤجَّل (دين) عند إصدار الفاتورة؛ 0 إذا دُفعت كاملة.
  /// يُسجَّل ديناً مرتبطاً بالفاتورة في شاشة الديون.
  final double debt;

  /// الفاتورة المفتوحة التي سُحبت منها هذه الكمية، إن وُجدت.
  final String? openOrderId;

  /// الزبون دفع ثمن البضاعة كلها لكنه يأخذها على دفعات.
  /// عند تفعيله تُحسب الكمية المأخوذة من [deliveries]، وإلا فكلها مأخوذة.
  final bool partialDelivery;

  /// سجل دفعات التسليم بتواريخها.
  final List<Delivery> deliveries;

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
    this.notes = '',
    this.txId,
    this.debt = 0,
    this.openOrderId,
    this.partialDelivery = false,
    this.deliveries = const [],
  });

  /// الكمية الأصلية من صنف في الفاتورة.
  double qtyOf(String productId) =>
      lines.where((l) => l.productId == productId).fold(0, (s, l) => s + l.qty);

  /// ما أخذه الزبون من الصنف.
  double takenOf(String productId) => partialDelivery
      ? deliveries.fold(0, (s, d) => s + d.qtyOf(productId))
      : qtyOf(productId);

  /// ما بقي للزبون في المخزن ولم يأخذه.
  double leftOf(String productId) => qtyOf(productId) - takenOf(productId);

  /// أصناف الفاتورة بلا تكرار، بترتيبها.
  List<String> get productIds => {for (final l in lines) l.productId}.toList();

  /// بقي للزبون شيء لم يأخذه.
  bool get hasLeft =>
      partialDelivery && productIds.any((p) => leftOf(p) > 1e-9);

  double get subtotal => lines.fold(0, (s, l) => s + l.total);
  double get afterDiscount => subtotal - discount;

  /// لا ضريبة في النظام: الإجمالي هو المجموع بعد الخصم.
  double get total => afterDiscount;

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
    notes: notes,
    txId: txId,
    debt: debt,
    openOrderId: openOrderId,
    partialDelivery: partialDelivery,
    deliveries: deliveries,
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
    'notes': notes,
    'txId': txId,
    'debt': debt,
    if (openOrderId != null) 'openOrderId': openOrderId,
    if (partialDelivery) 'partialDelivery': true,
    if (deliveries.isNotEmpty)
      'deliveries': [for (final d in deliveries) d.toJson()],
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
    notes: j['notes'] as String? ?? '',
    txId: j['txId'] as String?,
    debt: (j['debt'] as num?)?.toDouble() ?? 0,
    openOrderId: j['openOrderId'] as String?,
    partialDelivery: j['partialDelivery'] as bool? ?? false,
    deliveries: [
      for (final d in j['deliveries'] as List? ?? [])
        Delivery.fromJson(d as Map<String, dynamic>),
    ],
  );
}

/// بيانات المنشأة التي تظهر في رأس الفاتورة.
/// حساب دفع للمنشأة (تطبيق بنكي أو حساب) يظهر في فواتير البيع.
class PaymentAccount {
  /// اسم التطبيق أو البنك، مثل Bankily أو Masrvi.
  final String name;
  final String number;

  const PaymentAccount(this.name, this.number);

  Map<String, dynamic> toJson() => {'name': name, 'number': number};

  factory PaymentAccount.fromJson(Map<String, dynamic> j) =>
      PaymentAccount(j['name'] as String? ?? '', j['number'] as String? ?? '');
}

class CompanyInfo {
  final String name;
  final String phone;
  final String address;

  /// اسم مستخدم النظام ودوره، ويظهران أعلى الشاشة.
  final String ownerName;
  final String ownerRole;

  /// اسم قسم المخزون كما يريده المدير (يظهر في القائمة وعنوان الصفحة).
  final String inventoryLabel;

  /// حسابات الدفع التي تظهر أسفل فواتير البيع.
  final List<PaymentAccount> paymentAccounts;

  /// أُنشئت المخازن الأربعة الافتراضية (مرة واحدة، ثم يعدّلها المدير بحرية).
  final bool warehousesSet;

  /// أُضيفت أصناف البضاعة الأساسية (مرة واحدة).
  final bool productsSet;

  /// حسابات المدير، وتُستخدم حتى يغيّرها من الإعدادات.
  static const defaultPaymentAccounts = [
    PaymentAccount('Click', '36933636'),
    PaymentAccount('Masrvi', '36933636'),
    PaymentAccount('Sedad', '36933636'),
    PaymentAccount('BPM', '10020364'),
  ];

  static const defaultName = 'طيبة للتجارة العامة';
  static const defaultAddress = 'انواكشوط - تفرغ زينة';
  static const defaultOwnerName = 'أحمد طالب';
  static const defaultOwnerRole = 'مدير النظام';
  static const defaultInventoryLabel = 'المخزون';

  /// أسماء وعناوين مؤقتة من النسخ السابقة تُستبدل ببيانات المؤسسة.
  static const _oldNames = {'مدبّر', 'مؤسسة مدبّر لمواد البناء'};
  static const _oldAddresses = {
    'نواكشوط - تفرغ زينة',
    'الرياض - المنطقة الصناعية',
  };

  /// هاتف المؤسسة على الفواتير.
  static const defaultPhone = '36 93 36 36';

  const CompanyInfo({
    this.name = defaultName,
    this.phone = defaultPhone,
    this.address = defaultAddress,
    this.ownerName = defaultOwnerName,
    this.ownerRole = defaultOwnerRole,
    this.inventoryLabel = defaultInventoryLabel,
    this.paymentAccounts = defaultPaymentAccounts,
    this.warehousesSet = false,
    this.productsSet = false,
  });

  CompanyInfo copyWith({
    String? inventoryLabel,
    bool? warehousesSet,
    bool? productsSet,
  }) => CompanyInfo(
    name: name,
    phone: phone,
    address: address,
    ownerName: ownerName,
    ownerRole: ownerRole,
    inventoryLabel: inventoryLabel ?? this.inventoryLabel,
    paymentAccounts: paymentAccounts,
    warehousesSet: warehousesSet ?? this.warehousesSet,
    productsSet: productsSet ?? this.productsSet,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'phone': phone,
    'phoneSet': true,
    'address': address,
    'ownerName': ownerName,
    'ownerRole': ownerRole,
    'inventoryLabel': inventoryLabel,
    'paymentAccounts': [for (final a in paymentAccounts) a.toJson()],
    'warehousesSet': warehousesSet,
    'productsSet': productsSet,
  };

  factory CompanyInfo.fromJson(Map<String, dynamic> j) => CompanyInfo(
    name: switch (j['name'] as String?) {
      final n? when !_oldNames.contains(n) => n,
      _ => defaultName,
    },
    // الأرقام المحفوظة قبل اعتماد رقم المؤسسة (تجريبية أو قديمة) تُستبدل به
    // مرة واحدة؛ بعدها يبقى ما يكتبه المدير في الإعدادات.
    phone: j['phoneSet'] == true ? j['phone'] as String? ?? '' : defaultPhone,
    address: switch (j['address'] as String?) {
      final a? when !_oldAddresses.contains(a) => a,
      _ => defaultAddress,
    },
    ownerName: j['ownerName'] as String? ?? defaultOwnerName,
    ownerRole: j['ownerRole'] as String? ?? defaultOwnerRole,
    inventoryLabel: switch ((j['inventoryLabel'] as String?)?.trim()) {
      final l? when l.isNotEmpty => l,
      _ => defaultInventoryLabel,
    },
    // البيانات المحفوظة قبل إضافة الحسابات تأخذ الحسابات الافتراضية.
    paymentAccounts: j['paymentAccounts'] == null
        ? defaultPaymentAccounts
        : [
            for (final a in j['paymentAccounts'] as List)
              PaymentAccount.fromJson(a as Map<String, dynamic>),
          ],
    warehousesSet: j['warehousesSet'] == true,
    productsSet: j['productsSet'] == true,
  );
}
