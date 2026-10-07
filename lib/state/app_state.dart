import 'package:flutter/foundation.dart';

import '../data/storage.dart';
import '../models/debt.dart';
import '../models/inventory.dart';
import '../models/invoice.dart';
import '../models/models.dart';
import '../utils/format.dart' as fmt;

/// فترة زمنية [start, end] شاملة لليومين.
class Period {
  final DateTime start;
  final DateTime end;
  const Period(this.start, this.end);

  factory Period.month(DateTime d) =>
      Period(DateTime(d.year, d.month), DateTime(d.year, d.month + 1, 0));

  factory Period.year(int year) =>
      Period(DateTime(year), DateTime(year, 12, 31));

  bool contains(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    return !day.isBefore(start) && !day.isAfter(end);
  }
}

class ProfitShare {
  final String id;
  final String name;
  final double percent;
  final double amount;
  final double withdrawn;
  const ProfitShare(
    this.id,
    this.name,
    this.percent,
    this.amount,
    this.withdrawn,
  );

  double get balance => amount - withdrawn;
}

/// نتيجة توزيع الأرباح لفترة معينة.
class ProfitReport {
  final double income;
  final double expenses;
  final List<ProfitShare> partners;
  const ProfitReport({
    required this.income,
    required this.expenses,
    required this.partners,
  });

  double get netProfit => income - expenses;
}

class AppState extends ChangeNotifier {
  static const _kPartners = 'partners';
  static const _kWorkers = 'workers';
  static const _kTx = 'transactions';
  static const _kWarehouses = 'warehouses';
  static const _kProducts = 'products';
  static const _kMoves = 'stock_moves';
  static const _kInvoices = 'invoices';
  static const _kCompany = 'company';
  static const _kDebts = 'debts';

  final Storage _storage;
  AppState(this._storage);

  List<Partner> _partners = [];
  List<Worker> _workers = [];
  List<Transaction> _transactions = [];
  List<Warehouse> _warehouses = [];
  List<Product> _products = [];
  List<StockMove> _moves = [];
  List<Invoice> _invoices = [];
  List<Debt> _debts = [];
  CompanyInfo _company = const CompanyInfo();
  bool loaded = false;

  List<Partner> get partners => List.unmodifiable(_partners);
  List<Worker> get workers => List.unmodifiable(_workers);
  List<Warehouse> get warehouses => List.unmodifiable(_warehouses);
  List<Product> get products => List.unmodifiable(_products);
  CompanyInfo get company => _company;

  /// الديون: غير المسددة أولاً، ثم الأحدث.
  List<Debt> get debts => List.unmodifiable(
    [..._debts]..sort((a, b) {
      if (a.isSettled != b.isSettled) return a.isSettled ? 1 : -1;
      return b.date.compareTo(a.date);
    }),
  );

  /// الفواتير مرتبة من الأحدث للأقدم.
  List<Invoice> get invoices => List.unmodifiable(
    [..._invoices]..sort((a, b) {
      final d = b.date.compareTo(a.date);
      return d != 0 ? d : b.number.compareTo(a.number);
    }),
  );

  /// المعاملات مرتبة من الأحدث للأقدم.
  List<Transaction> get transactions => List.unmodifiable(
    [..._transactions]..sort((a, b) => b.date.compareTo(a.date)),
  );

  /// حركات المخزون مرتبة من الأحدث للأقدم.
  List<StockMove> get moves =>
      List.unmodifiable([..._moves]..sort((a, b) => b.date.compareTo(a.date)));

  Future<List<T>> _read<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) async => (await _storage.readList(key)).map(fromJson).toList();

  Future<void> load() async {
    _partners = await _read(_kPartners, Partner.fromJson);
    _workers = await _read(_kWorkers, Worker.fromJson);
    _transactions = await _read(_kTx, Transaction.fromJson);
    _warehouses = await _read(_kWarehouses, Warehouse.fromJson);
    _products = await _read(_kProducts, Product.fromJson);
    _moves = await _read(_kMoves, StockMove.fromJson);
    _invoices = await _read(_kInvoices, Invoice.fromJson);
    _debts = await _read(_kDebts, Debt.fromJson);
    final company = await _storage.readList(_kCompany);
    if (company.isNotEmpty) _company = CompanyInfo.fromJson(company.first);
    loaded = true;
    notifyListeners();
  }

  // ---------- عمليات الحفظ ----------

  Future<void> _savePartners() =>
      _storage.writeList(_kPartners, _partners.map((e) => e.toJson()).toList());
  Future<void> _saveWorkers() =>
      _storage.writeList(_kWorkers, _workers.map((e) => e.toJson()).toList());
  Future<void> _saveTx() =>
      _storage.writeList(_kTx, _transactions.map((e) => e.toJson()).toList());
  Future<void> _saveWarehouses() => _storage.writeList(
    _kWarehouses,
    _warehouses.map((e) => e.toJson()).toList(),
  );
  Future<void> _saveProducts() =>
      _storage.writeList(_kProducts, _products.map((e) => e.toJson()).toList());
  Future<void> _saveMoves() =>
      _storage.writeList(_kMoves, _moves.map((e) => e.toJson()).toList());

  Future<void> _saveInvoices() =>
      _storage.writeList(_kInvoices, _invoices.map((e) => e.toJson()).toList());

  Future<void> _saveDebts() =>
      _storage.writeList(_kDebts, _debts.map((e) => e.toJson()).toList());

  Future<void> _saveAll() => Future.wait([
    _saveInvoices(),
    _saveDebts(),
    _savePartners(),
    _saveWorkers(),
    _saveTx(),
    _saveWarehouses(),
    _saveProducts(),
    _saveMoves(),
  ]);

  static void _upsert<T>(List<T> list, T item, String Function(T) id) {
    final i = list.indexWhere((e) => id(e) == id(item));
    if (i == -1) {
      list.add(item);
    } else {
      list[i] = item;
    }
  }

  // ---------- الشركاء ----------

  /// مجموع نسب الشركاء باستثناء شريك معيّن (للتحقق عند التعديل).
  double partnersShareTotal({String? excludeId}) => _partners
      .where((p) => p.id != excludeId)
      .fold(0, (s, p) => s + p.sharePercent);

  Future<void> savePartner(Partner p) async {
    _upsert(_partners, p, (e) => e.id);
    notifyListeners();
    await _savePartners();
  }

  Future<void> deletePartner(String id) async {
    _partners.removeWhere((e) => e.id == id);
    notifyListeners();
    await _savePartners();
  }

  // ---------- العمال ----------

  Future<void> saveWorker(Worker w) async {
    _upsert(_workers, w, (e) => e.id);
    notifyListeners();
    await _saveWorkers();
  }

  Future<void> deleteWorker(String id) async {
    _workers.removeWhere((e) => e.id == id);
    notifyListeners();
    await _saveWorkers();
  }

  double get monthlyPayroll =>
      _workers.where((w) => w.active).fold(0, (s, w) => s + w.monthlySalary);

  /// يسجّل صرف راتب الشهر لعامل كمعاملة مصروف.
  Future<void> paySalary(Worker w, DateTime date) => saveTransaction(
    Transaction(
      id: newId(),
      category: TxCategory.salary,
      amount: w.monthlySalary,
      date: date,
      note: 'راتب ${w.name}',
      personId: w.id,
    ),
  );

  // ---------- المعاملات ----------

  Future<void> saveTransaction(Transaction t) async {
    _upsert(_transactions, t, (e) => e.id);
    notifyListeners();
    await _saveTx();
  }

  Future<void> deleteTransaction(String id) async {
    _transactions.removeWhere((e) => e.id == id);
    notifyListeners();
    await _saveTx();
  }

  /// هل المعاملة مُنشأة تلقائياً من حركة مخزون أو فاتورة؟
  /// (تُعدَّل من شاشتها فقط حتى تبقى المبالغ مطابقة للكميات)
  bool isLinkedTransaction(String txId) =>
      _moves.any((m) => m.txId == txId) || _invoices.any((i) => i.txId == txId);

  String? personName(String? id) {
    if (id == null) return null;
    for (final p in _partners) {
      if (p.id == id) return p.name;
    }
    for (final w in _workers) {
      if (w.id == id) return w.name;
    }
    return null;
  }

  Iterable<Transaction> inPeriod(Period? p) => p == null
      ? _transactions
      : _transactions.where((t) => p.contains(t.date));

  double totalIncome([Period? p]) =>
      inPeriod(p)
          .where((t) => t.type == TxType.income)
          .fold(0, (s, t) => s + t.amount);

  /// المصروفات التشغيلية (بدون المسحوبات).
  double totalExpenses([Period? p]) =>
      inPeriod(p)
          .where((t) => t.type == TxType.expense && t.category.affectsProfit)
          .fold(0, (s, t) => s + t.amount);

  double withdrawnBy(String personId, [Period? p]) => inPeriod(p)
      .where(
        (t) => t.category == TxCategory.withdrawal && t.personId == personId,
      )
      .fold(0, (s, t) => s + t.amount);

  double get totalCapital => _partners.fold<double>(0, (s, p) => s + p.capital);

  /// الرصيد النقدي = رأس المال + كل الإيرادات - كل المصروفات (بما فيها المسحوبات).
  double get cashBalance =>
      totalCapital +
      totalIncome() -
      _transactions
          .where((t) => t.type == TxType.expense)
          .fold<double>(0, (s, t) => s + t.amount);

  /// توزيع الأرباح: يوزَّع صافي الربح (أو الخسارة) على الشركاء حسب نسبهم.
  ProfitReport profitReport([Period? p]) {
    final income = totalIncome(p);
    final expenses = totalExpenses(p);
    final net = income - expenses;
    final sharesTotal = partnersShareTotal();
    return ProfitReport(
      income: income,
      expenses: expenses,
      partners: [
        for (final x in _partners)
          ProfitShare(
            x.id,
            x.name,
            x.sharePercent,
            sharesTotal == 0 ? 0 : net * x.sharePercent / sharesTotal,
            withdrawnBy(x.id, p),
          ),
      ],
    );
  }

  /// إجمالي الإيرادات والمصروفات لكل شهر من آخر [months] شهراً (الأقدم أولاً).
  List<({DateTime month, double income, double expenses})> monthlySeries({
    int months = 6,
    DateTime? now,
  }) {
    final n = now ?? DateTime.now();
    return List.generate(months, (i) {
      final m = DateTime(n.year, n.month - (months - 1 - i));
      final p = Period.month(m);
      return (month: m, income: totalIncome(p), expenses: totalExpenses(p));
    });
  }

  // ---------- المخازن ----------

  Warehouse? warehouseById(String? id) {
    for (final w in _warehouses) {
      if (w.id == id) return w;
    }
    return null;
  }

  Product? productById(String? id) {
    for (final p in _products) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<void> saveWarehouse(Warehouse w) async {
    _upsert(_warehouses, w, (e) => e.id);
    notifyListeners();
    await _saveWarehouses();
  }

  /// لا يُحذف مخزن عليه حركات، ويُرجع false في هذه الحالة.
  Future<bool> deleteWarehouse(String id) async {
    if (_moves.any((m) => m.warehouseId == id || m.toWarehouseId == id)) {
      return false;
    }
    _warehouses.removeWhere((e) => e.id == id);
    notifyListeners();
    await _saveWarehouses();
    return true;
  }

  Future<void> saveProduct(Product p) async {
    _upsert(_products, p, (e) => e.id);
    notifyListeners();
    await _saveProducts();
  }

  /// لا يُحذف صنف عليه حركات، ويُرجع false في هذه الحالة.
  Future<bool> deleteProduct(String id) async {
    if (_moves.any((m) => m.productId == id)) return false;
    _products.removeWhere((e) => e.id == id);
    notifyListeners();
    await _saveProducts();
    return true;
  }

  /// رصيد صنف في مخزن معيّن، أو في كل المخازن إن لم يُحدَّد المخزن.
  /// [excludeMoveId] يستثني حركة (لحساب المتاح عند تعديلها).
  double stockOf(
    String productId, {
    String? warehouseId,
    String? excludeMoveId,
    String? excludeInvoiceId,
  }) => _moves
      .where(
        (m) =>
            m.productId == productId &&
            m.id != excludeMoveId &&
            (excludeInvoiceId == null || m.invoiceId != excludeInvoiceId),
      )
      .fold(0, (s, m) => s + m.effectOn(warehouseId));

  /// قيمة المخزون بسعر التكلفة.
  double stockValue({String? warehouseId}) => _products.fold(
    0,
    (s, p) => s + stockOf(p.id, warehouseId: warehouseId) * p.costPrice,
  );

  /// الأصناف التي وصل رصيدها الإجمالي إلى الحد الأدنى أو أقل.
  List<Product> get lowStockProducts => _products
      .where((p) => p.minQty > 0 && stockOf(p.id) <= p.minQty)
      .toList();

  /// يحفظ حركة مخزون، وينشئ/يحدّث/يحذف المعاملة المالية المرتبطة بها.
  /// يرمي [StateError] إذا كانت الكمية الصادرة أكبر من المتاح.
  Future<void> saveMove(StockMove m) async {
    if (m.type.decreasesSource) {
      final available = stockOf(
        m.productId,
        warehouseId: m.warehouseId,
        excludeMoveId: m.id,
      );
      if (m.qty > available + 1e-9) {
        throw StateError(
          'الكمية المتاحة في المخزن هي ${fmt.number(available)} فقط',
        );
      }
    }

    var move = m;
    final category = m.type.financial;
    if (category != null) {
      final product = productById(m.productId);
      final tx = Transaction(
        id: m.txId ?? newId(),
        category: category,
        amount: m.total,
        date: m.date,
        note: '${m.type.label}: ${product?.name ?? ''} × ${fmt.number(m.qty)}',
      );
      _upsert(_transactions, tx, (e) => e.id);
      move = m.copyWith(txId: tx.id);
    } else if (m.txId != null) {
      _transactions.removeWhere((t) => t.id == m.txId);
      move = m.copyWith(clearTx: true);
    }

    _upsert(_moves, move, (e) => e.id);
    notifyListeners();
    await Future.wait([_saveMoves(), _saveTx()]);
  }

  Future<void> deleteMove(String id) async {
    final m = _moves.where((e) => e.id == id).firstOrNull;
    if (m == null) return;
    _moves.remove(m);
    if (m.txId != null) _transactions.removeWhere((t) => t.id == m.txId);
    notifyListeners();
    await Future.wait([_saveMoves(), _saveTx()]);
  }

  // ---------- الفواتير ----------

  Invoice? invoiceById(String? id) =>
      _invoices.where((e) => e.id == id).firstOrNull;

  /// الرقم التالي للفاتورة حسب نوعها، مثل S-0001.
  String nextInvoiceNumber(InvoiceType type) {
    var max = 0;
    for (final i in _invoices.where((i) => i.type == type)) {
      final n = int.tryParse(i.number.split('-').last) ?? 0;
      if (n > max) max = n;
    }
    return '${type.prefix}-${(max + 1).toString().padLeft(4, '0')}';
  }

  /// يحفظ الفاتورة: يستبدل حركات المخزون الخاصة بها، ويحدّث معاملتها المالية.
  /// يرمي [StateError] إذا كانت الفاتورة فارغة أو الكمية المباعة أكبر من المتاح.
  Future<void> saveInvoice(Invoice inv) async {
    if (inv.lines.isEmpty) throw StateError('أضف صنفاً واحداً على الأقل');
    if (inv.type == InvoiceType.sale) {
      final needed = <String, double>{};
      for (final l in inv.lines) {
        needed[l.productId] = (needed[l.productId] ?? 0) + l.qty;
      }
      for (final e in needed.entries) {
        final available = stockOf(
          e.key,
          warehouseId: inv.warehouseId,
          excludeInvoiceId: inv.id,
        );
        if (e.value > available + 1e-9) {
          throw StateError(
            'الكمية المتاحة من "${productById(e.key)?.name}" '
            'هي ${fmt.number(available)} فقط',
          );
        }
      }
    }

    _moves.removeWhere((m) => m.invoiceId == inv.id);
    for (final l in inv.lines) {
      _moves.add(
        StockMove(
          id: newId(),
          type: inv.type == InvoiceType.sale
              ? MoveType.sale
              : MoveType.purchase,
          productId: l.productId,
          warehouseId: inv.warehouseId,
          qty: l.qty,
          unitPrice: l.unitPrice,
          date: inv.date,
          note: '${inv.type.label} ${inv.number}',
          invoiceId: inv.id,
        ),
      );
    }

    final tx = Transaction(
      id: inv.txId ?? newId(),
      category: inv.type == InvoiceType.sale
          ? TxCategory.sales
          : TxCategory.supplies,
      amount: inv.total,
      date: inv.date,
      note: [
        '${inv.type.label} ${inv.number}',
        if (inv.partyName.isNotEmpty) inv.partyName,
      ].join(' - '),
    );
    _upsert(_transactions, tx, (e) => e.id);
    _upsert(_invoices, inv.withTx(tx.id), (e) => e.id);

    notifyListeners();
    await Future.wait([_saveInvoices(), _saveMoves(), _saveTx()]);
  }

  /// يحذف الفاتورة مع حركات المخزون والمعاملة المالية المرتبطة بها.
  /// حذف فاتورة شراء يُرفض إذا كانت كمياتها قد بيعت أو حُوّلت.
  Future<void> deleteInvoice(String id) async {
    final inv = invoiceById(id);
    if (inv == null) return;
    if (inv.type == InvoiceType.purchase) {
      for (final p in {for (final l in inv.lines) l.productId}) {
        for (final w in _warehouses) {
          if (stockOf(p, warehouseId: w.id, excludeInvoiceId: id) < -1e-9) {
            throw StateError(
              'لا يمكن حذف الفاتورة: كمية "${productById(p)?.name}" '
              'صُرفت أو بيعت بعد شرائها',
            );
          }
        }
      }
    }
    _invoices.removeWhere((e) => e.id == id);
    _moves.removeWhere((m) => m.invoiceId == id);
    if (inv.txId != null) _transactions.removeWhere((t) => t.id == inv.txId);
    notifyListeners();
    await Future.wait([_saveInvoices(), _saveMoves(), _saveTx()]);
  }

  Future<void> saveCompany(CompanyInfo c) async {
    _company = c;
    notifyListeners();
    await _storage.writeList(_kCompany, [c.toJson()]);
  }

  // ---------- الديون ----------

  Debt? debtById(String id) => _debts.where((d) => d.id == id).firstOrNull;

  /// يحفظ الدين. يرمي [StateError] إذا صار المبلغ أقل مما سُدِّد منه.
  Future<void> saveDebt(Debt d) async {
    if (d.amount + 0.0001 < d.paid) {
      throw StateError('المبلغ أقل من المسدَّد (${fmt.number(d.paid)})');
    }
    _upsert(_debts, d, (e) => e.id);
    notifyListeners();
    await _saveDebts();
  }

  Future<void> deleteDebt(String id) async {
    _debts.removeWhere((d) => d.id == id);
    notifyListeners();
    await _saveDebts();
  }

  /// يسجّل دفعة. يرمي [StateError] إذا تجاوزت الدفعة المتبقي.
  Future<void> addDebtPayment(String debtId, DebtPayment payment) async {
    final d = debtById(debtId);
    if (d == null) return;
    if (payment.amount > d.remaining + 0.0001) {
      throw StateError('المتبقي ${fmt.number(d.remaining)} فقط');
    }
    _upsert(
      _debts,
      d.copyWith(payments: [...d.payments, payment]),
      (e) => e.id,
    );
    notifyListeners();
    await _saveDebts();
  }

  /// مجموع المتبقي من الديون في اتجاه معيّن.
  double debtsRemaining(DebtDirection direction) => _debts
      .where((d) => d.direction == direction)
      .fold(0, (s, d) => s + d.remaining);

  int overdueDebts(DateTime now) =>
      _debts.where((d) => d.isOverdue(now)).length;

  // ---------- بيانات تجريبية ----------

  /// يملأ التطبيق ببيانات تجريبية للعرض على الزبون.
  Future<void> seedDemoData() async {
    final now = DateTime.now();
    final p1 = Partner(
      id: newId(),
      name: 'أحمد علي',
      phone: '22 45 67 01',
      sharePercent: 50,
      capital: 1500000,
      joinedAt: DateTime(now.year - 1),
    );
    final p2 = Partner(
      id: newId(),
      name: 'محمد حسن',
      phone: '36 45 67 02',
      sharePercent: 30,
      capital: 900000,
      joinedAt: DateTime(now.year - 1),
    );
    final p3 = Partner(
      id: newId(),
      name: 'خالد سعيد',
      phone: '46 45 67 03',
      sharePercent: 20,
      capital: 600000,
      joinedAt: DateTime(now.year - 1),
    );
    final workers = [
      Worker(
        id: newId(),
        name: 'سالم يوسف',
        jobTitle: 'مدير عمليات',
        monthlySalary: 30000,
        hiredAt: DateTime(now.year - 1),
      ),
      Worker(
        id: newId(),
        name: 'يوسف إبراهيم',
        jobTitle: 'أمين مخزن',
        monthlySalary: 22000,
        hiredAt: DateTime(now.year - 1),
      ),
      Worker(
        id: newId(),
        name: 'عمر فاروق',
        jobTitle: 'فني',
        monthlySalary: 16000,
        hiredAt: DateTime(now.year - 1, 3),
      ),
    ];
    _partners.addAll([p1, p2, p3]);
    _workers.addAll(workers);

    for (var i = 5; i >= 0; i--) {
      final d = DateTime(now.year, now.month - i, 5);
      _transactions.addAll([
        Transaction(
          id: newId(),
          category: TxCategory.sales,
          amount: 600000 + i * 40000.0,
          date: d,
          note: 'مبيعات الشهر',
        ),
        Transaction(
          id: newId(),
          category: TxCategory.rent,
          amount: 60000,
          date: d,
          note: 'إيجار المقر',
        ),
        for (final w in workers)
          Transaction(
            id: newId(),
            category: TxCategory.salary,
            amount: w.monthlySalary,
            date: d,
            note: 'راتب ${w.name}',
            personId: w.id,
          ),
      ]);
    }
    _transactions.add(
      Transaction(
        id: newId(),
        category: TxCategory.withdrawal,
        amount: 100000,
        date: DateTime(now.year, now.month, 1),
        note: 'سحب أرباح',
        personId: p1.id,
      ),
    );

    final main = Warehouse(
      id: newId(),
      name: 'المخزن الرئيسي',
      location: 'نواكشوط - المنطقة الصناعية',
    );
    final branch = Warehouse(
      id: newId(),
      name: 'مخزن الفرع',
      location: 'نواذيبو - وسط المدينة',
    );
    _warehouses.addAll([main, branch]);

    final items = [
      Product(
        id: newId(),
        name: 'أسمنت',
        code: 'C-01',
        unit: 'كيس',
        costPrice: 230,
        salePrice: 280,
        minQty: 100,
      ),
      Product(
        id: newId(),
        name: 'حديد تسليح 12مم',
        code: 'S-12',
        unit: 'طن',
        costPrice: 34000,
        salePrice: 38500,
        minQty: 5,
      ),
      Product(
        id: newId(),
        name: 'بلاط سيراميك',
        code: 'T-60',
        unit: 'متر',
        costPrice: 320,
        salePrice: 420,
        minQty: 200,
      ),
      Product(
        id: newId(),
        name: 'دهان أبيض',
        code: 'P-W',
        unit: 'جالون',
        costPrice: 950,
        salePrice: 1200,
        minQty: 40,
      ),
      Product(
        id: newId(),
        name: 'أنابيب PVC',
        code: 'PVC-4',
        unit: 'قطعة',
        costPrice: 260,
        salePrice: 340,
        minQty: 50,
      ),
    ];
    _products.addAll(items);

    final opening = DateTime(now.year, now.month - 2, 1);
    const qtys = [600.0, 20.0, 900.0, 60.0, 300.0];
    for (var i = 0; i < items.length; i++) {
      _moves.add(
        StockMove(
          id: newId(),
          type: MoveType.stockIn,
          productId: items[i].id,
          warehouseId: main.id,
          qty: qtys[i],
          date: opening,
          note: 'رصيد افتتاحي',
        ),
      );
    }
    notifyListeners();

    final thisMonth = DateTime(now.year, now.month, 2);
    await saveMove(
      StockMove(
        id: newId(),
        type: MoveType.transfer,
        productId: items[0].id,
        warehouseId: main.id,
        toWarehouseId: branch.id,
        qty: 150,
        date: thisMonth,
      ),
    );
    await saveInvoice(
      Invoice(
        id: newId(),
        type: InvoiceType.purchase,
        number: nextInvoiceNumber(InvoiceType.purchase),
        date: thisMonth,
        partyName: 'مؤسسة الحديد المتحدة',
        partyPhone: '45 25 10 10',
        warehouseId: main.id,
        lines: [
          InvoiceLine(
            productId: items[1].id,
            qty: 4,
            unitPrice: items[1].costPrice,
          ),
          InvoiceLine(
            productId: items[4].id,
            qty: 100,
            unitPrice: items[4].costPrice,
          ),
        ],
        taxPercent: 16,
      ),
    );
    await saveInvoice(
      Invoice(
        id: newId(),
        type: InvoiceType.sale,
        number: nextInvoiceNumber(InvoiceType.sale),
        date: DateTime(now.year, now.month, 3),
        partyName: 'شركة البناء الحديث',
        partyPhone: '22 12 34 56',
        warehouseId: main.id,
        lines: [
          InvoiceLine(
            productId: items[0].id,
            qty: 380,
            unitPrice: items[0].salePrice,
          ),
          InvoiceLine(
            productId: items[2].id,
            qty: 120,
            unitPrice: items[2].salePrice,
          ),
          InvoiceLine(
            productId: items[3].id,
            qty: 30,
            unitPrice: items[3].salePrice,
          ),
        ],
        discount: 5000,
        taxPercent: 16,
        notes: 'التسليم في موقع العميل',
      ),
    );
    await saveInvoice(
      Invoice(
        id: newId(),
        type: InvoiceType.sale,
        number: nextInvoiceNumber(InvoiceType.sale),
        date: DateTime(now.year, now.month, 4),
        partyName: 'عميل نقدي',
        warehouseId: main.id,
        lines: [
          InvoiceLine(
            productId: items[4].id,
            qty: 40,
            unitPrice: items[4].salePrice,
          ),
        ],
        taxPercent: 16,
      ),
    );
    _debts.addAll([
      Debt(
        id: newId(),
        direction: DebtDirection.theyOwe,
        personName: 'سيدي محمد',
        phone: '22 33 44 55',
        amount: 85000,
        date: DateTime(now.year, now.month - 1, 12),
        dueDate: DateTime(now.year, now.month, 1),
        note: 'أسمنت وحديد بالآجل',
        payments: [
          DebtPayment(
            amount: 30000,
            date: DateTime(now.year, now.month - 1, 25),
          ),
        ],
      ),
      Debt(
        id: newId(),
        direction: DebtDirection.theyOwe,
        personName: 'مقاولات الأمل',
        phone: '36 10 20 30',
        amount: 140000,
        date: DateTime(now.year, now.month, 2),
        dueDate: DateTime(now.year, now.month + 1, 2),
      ),
      Debt(
        id: newId(),
        direction: DebtDirection.weOwe,
        personName: 'مؤسسة الحديد المتحدة',
        phone: '45 25 10 10',
        amount: 120000,
        date: DateTime(now.year, now.month, 2),
        dueDate: DateTime(now.year, now.month + 1, 15),
        note: 'باقي فاتورة الحديد',
        payments: [
          DebtPayment(amount: 50000, date: DateTime(now.year, now.month, 4)),
        ],
      ),
    ]);
    if (_company.phone.isEmpty) {
      _company = const CompanyInfo(
        name: 'مؤسسة مدبّر لمواد البناء',
        phone: '45 25 00 00',
        address: 'نواكشوط - تفرغ زينة',
        taxNumber: '00123456',
        defaultTaxPercent: 16,
      );
      await _storage.writeList(_kCompany, [_company.toJson()]);
    }

    notifyListeners();
    await _saveAll();
  }

  Future<void> clearAll() async {
    _partners.clear();
    _workers.clear();
    _transactions.clear();
    _warehouses.clear();
    _products.clear();
    _moves.clear();
    _invoices.clear();
    _debts.clear();
    notifyListeners();
    await _saveAll();
  }
}
