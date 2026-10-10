import '../models/invoice.dart';
import '../utils/format.dart' as fmt;

/// لغات فاتورة PDF. العربية من اليمين لليسار، والفرنسية والإنجليزية من اليسار.
enum InvoiceLanguage {
  ar('العربية', rtl: true),
  fr('Français', rtl: false),
  en('English', rtl: false);

  final String label;
  final bool rtl;
  const InvoiceLanguage(this.label, {required this.rtl});

  InvoiceStrings get strings => switch (this) {
    InvoiceLanguage.ar => InvoiceStrings.ar,
    InvoiceLanguage.fr => InvoiceStrings.fr,
    InvoiceLanguage.en => InvoiceStrings.en,
  };
}

/// نصوص الفاتورة بكل لغة. بيانات المستخدم (الأسماء، الأصناف، الوحدات) تبقى كما كُتبت.
class InvoiceStrings {
  final String saleTitle;
  final String purchaseTitle;
  final String sale;
  final String purchase;
  final String customer;
  final String supplier;
  final String address;
  final String phone;
  final String invoiceNumber;
  final String date;
  final String createdAt;
  final String warehouse;
  final String itemCount;
  final String total;
  final String debt;
  final String item;
  final String quantity;
  final String unitPrice;
  final String lineTotal;
  final String summary;
  final String type;
  final String description;
  final String amount;
  final String subtotalBadge;
  final String Function(int) subtotalLabel;
  final String discountBadge;
  final String discount;
  final String totalBadge;
  final String totalDue;
  final String paidBadge;
  final String paid;
  final String debtBadge;
  final String remainingDebt;
  final String noDebt;
  final String notes;
  final String paymentMethods;
  final String accountNumber;
  final String paymentReference;
  final String thanks;
  final String Function(int page, int pages) page;
  final String currency;

  const InvoiceStrings({
    required this.saleTitle,
    required this.purchaseTitle,
    required this.sale,
    required this.purchase,
    required this.customer,
    required this.supplier,
    required this.address,
    required this.phone,
    required this.invoiceNumber,
    required this.date,
    required this.createdAt,
    required this.warehouse,
    required this.itemCount,
    required this.total,
    required this.debt,
    required this.item,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    required this.summary,
    required this.type,
    required this.description,
    required this.amount,
    required this.subtotalBadge,
    required this.subtotalLabel,
    required this.discountBadge,
    required this.discount,
    required this.totalBadge,
    required this.totalDue,
    required this.paidBadge,
    required this.paid,
    required this.debtBadge,
    required this.remainingDebt,
    required this.noDebt,
    required this.notes,
    required this.paymentMethods,
    required this.accountNumber,
    required this.paymentReference,
    required this.thanks,
    required this.page,
    required this.currency,
  });

  String title(InvoiceType t) =>
      t == InvoiceType.sale ? saleTitle : purchaseTitle;
  String kind(InvoiceType t) => t == InvoiceType.sale ? sale : purchase;
  String party(InvoiceType t) => t == InvoiceType.sale ? customer : supplier;

  /// المبلغ بعملة الفاتورة: «أوقية» بالعربية و MRU باللغات الأخرى.
  String money(num v) => '${fmt.number(v)} $currency';

  static final ar = InvoiceStrings(
    saleTitle: 'فاتورة مبيعات',
    purchaseTitle: 'فاتورة مشتريات',
    sale: 'بيع',
    purchase: 'شراء',
    customer: 'العميل',
    supplier: 'المورد',
    address: 'المقر',
    phone: 'الهاتف',
    invoiceNumber: 'رقم الفاتورة',
    date: 'التاريخ',
    createdAt: 'أُنشئت في',
    warehouse: 'المخزن',
    itemCount: 'عدد الأصناف',
    total: 'الإجمالي',
    debt: 'الدين',
    item: 'الصنف',
    quantity: 'الكمية',
    unitPrice: 'سعر الفرد',
    lineTotal: 'الإجمالي',
    summary: 'الإجماليات / الملخص',
    type: 'النوع',
    description: 'البيان',
    amount: 'المبلغ',
    subtotalBadge: 'المجموع',
    subtotalLabel: (n) => 'مجموع الأصناف ($n)',
    discountBadge: 'خصم',
    discount: 'الخصم',
    totalBadge: 'الإجمالي',
    totalDue: 'الإجمالي المستحق',
    paidBadge: 'مدفوع',
    paid: 'المدفوع',
    debtBadge: 'دين',
    remainingDebt: 'الدين المتبقي',
    noDebt: 'الدين المتبقي (لا يوجد)',
    notes: 'ملاحظات',
    paymentMethods: 'طرق الدفع والحسابات البنكية',
    accountNumber: 'رقم الحساب',
    paymentReference: 'مرجع الدفع',
    thanks: 'شكرًا لتعاملكم معنا',
    page: (p, n) => 'صفحة $p من $n',
    currency: fmt.currencySymbol,
  );

  static final fr = InvoiceStrings(
    saleTitle: 'Facture de vente',
    purchaseTitle: "Facture d'achat",
    sale: 'Vente',
    purchase: 'Achat',
    customer: 'Client',
    supplier: 'Fournisseur',
    address: 'Siège',
    phone: 'Tél',
    invoiceNumber: 'N° de facture',
    date: 'Date',
    createdAt: 'Générée le',
    warehouse: 'Entrepôt',
    itemCount: "Nombre d'articles",
    total: 'Total',
    debt: 'Dette',
    item: 'Article',
    quantity: 'Quantité',
    unitPrice: 'Prix unitaire',
    lineTotal: 'Total',
    summary: 'Totaux / Récapitulatif',
    type: 'Type',
    description: 'Libellé',
    amount: 'Montant',
    subtotalBadge: 'Sous-total',
    subtotalLabel: (n) => 'Total des articles ($n)',
    discountBadge: 'Remise',
    discount: 'Remise',
    totalBadge: 'Total',
    totalDue: 'Total à payer',
    paidBadge: 'Payé',
    paid: 'Montant payé',
    debtBadge: 'Dette',
    remainingDebt: 'Reste à payer',
    noDebt: 'Reste à payer (aucun)',
    notes: 'Remarques',
    paymentMethods: 'Moyens de paiement et coordonnées bancaires',
    accountNumber: 'N° de compte',
    paymentReference: 'Référence',
    thanks: 'Merci pour votre confiance',
    page: (p, n) => 'Page $p / $n',
    currency: 'MRU',
  );

  static final en = InvoiceStrings(
    saleTitle: 'Sales invoice',
    purchaseTitle: 'Purchase invoice',
    sale: 'Sale',
    purchase: 'Purchase',
    customer: 'Customer',
    supplier: 'Supplier',
    address: 'Address',
    phone: 'Phone',
    invoiceNumber: 'Invoice no.',
    date: 'Date',
    createdAt: 'Generated',
    warehouse: 'Warehouse',
    itemCount: 'Items',
    total: 'Total',
    debt: 'Debt',
    item: 'Item',
    quantity: 'Quantity',
    unitPrice: 'Unit price',
    lineTotal: 'Total',
    summary: 'Totals / Summary',
    type: 'Type',
    description: 'Description',
    amount: 'Amount',
    subtotalBadge: 'Subtotal',
    subtotalLabel: (n) => 'Items total ($n)',
    discountBadge: 'Discount',
    discount: 'Discount',
    totalBadge: 'Total',
    totalDue: 'Total due',
    paidBadge: 'Paid',
    paid: 'Amount paid',
    debtBadge: 'Debt',
    remainingDebt: 'Balance due',
    noDebt: 'Balance due (none)',
    notes: 'Notes',
    paymentMethods: 'Payment methods and bank details',
    accountNumber: 'Account no.',
    paymentReference: 'Reference',
    thanks: 'Thank you for your business',
    page: (p, n) => 'Page $p of $n',
    currency: 'MRU',
  );
}
