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
  final String notes;

  /// المعاملة المالية المرتبطة.
  final String? txId;

  /// المبلغ المؤجَّل (دين) عند إصدار الفاتورة؛ 0 إذا دُفعت كاملة.
  /// يُسجَّل ديناً مرتبطاً بالفاتورة في شاشة الديون.
  final double debt;

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
  });

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

  /// حسابات الدفع التي تظهر أسفل فواتير البيع.
  final List<PaymentAccount> paymentAccounts;

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

  /// أسماء وعناوين مؤقتة من النسخ السابقة تُستبدل ببيانات المؤسسة.
  static const _oldNames = {'مدبّر', 'مؤسسة مدبّر لمواد البناء'};
  static const _oldAddresses = {
    'نواكشوط - تفرغ زينة',
    'الرياض - المنطقة الصناعية',
  };

  /// هاتف تجريبي من نسخة قديمة؛ يُمسح ليكتب المدير بياناته.
  static const _oldPhones = {'0500000000'};

  const CompanyInfo({
    this.name = defaultName,
    this.phone = '',
    this.address = defaultAddress,
    this.ownerName = defaultOwnerName,
    this.ownerRole = defaultOwnerRole,
    this.paymentAccounts = defaultPaymentAccounts,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'phone': phone,
    'address': address,
    'ownerName': ownerName,
    'ownerRole': ownerRole,
    'paymentAccounts': [for (final a in paymentAccounts) a.toJson()],
  };

  factory CompanyInfo.fromJson(Map<String, dynamic> j) => CompanyInfo(
    name: switch (j['name'] as String?) {
      final n? when !_oldNames.contains(n) => n,
      _ => defaultName,
    },
    phone: switch (j['phone'] as String?) {
      final p? when !_oldPhones.contains(p) => p,
      _ => '',
    },
    address: switch (j['address'] as String?) {
      final a? when !_oldAddresses.contains(a) => a,
      _ => defaultAddress,
    },
    ownerName: j['ownerName'] as String? ?? defaultOwnerName,
    ownerRole: j['ownerRole'] as String? ?? defaultOwnerRole,
    // البيانات المحفوظة قبل إضافة الحسابات تأخذ الحسابات الافتراضية.
    paymentAccounts: j['paymentAccounts'] == null
        ? defaultPaymentAccounts
        : [
            for (final a in j['paymentAccounts'] as List)
              PaymentAccount.fromJson(a as Map<String, dynamic>),
          ],
  );
}
