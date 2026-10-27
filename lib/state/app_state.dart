import 'package:flutter/foundation.dart';

import '../data/storage.dart';
import '../models/debt.dart';
import '../models/open_order.dart';
import '../models/plot.dart';
import '../models/shipment.dart';
import '../models/car.dart';
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

/// عملية بيع واحدة وربحها.
typedef ProfitEntry = ({
  DateTime date,
  String kind,
  String title,
  double sale,
  double cost,
  List<String> details,
  bool missingCost,
});

/// عارية لم تُرجع: من أخذها، الصنف، المخزن، الكمية الباقية ومنذ متى.
/// سطر في كشف صفقة: تاريخه (إن وُجد) وبيانه ومبلغه.
typedef DealLine = ({DateTime? date, String label, double amount});

typedef DealStatement = ({
  String title,
  List<DealLine> expenses,
  List<DealLine> income,
  double expensesTotal,
  double? profit,
  List<Partner> partners,
});

/// دفعة مالية من زبون فاتورة مفتوحة.
/// [advanceId] للدفعة المقدمة (يمكن حذفها)، و null لما دُفع عند الأخذ.
typedef OrderPayment = ({
  DateTime date,
  double amount,
  String source,
  String? advanceId,
});

typedef LoanBalance = ({
  bool ours,
  String person,
  String productId,
  String warehouseId,
  double qty,
  DateTime since,
});

/// دين جديد ([payment] = null) أو تسديد دفعة منه.
typedef DebtEvent = ({DateTime date, Debt debt, DebtPayment? payment});

/// أين عمل العمال اليوميون.
enum LaborPlace {
  warehouse('مخزن'),
  container('حاوية'),
  car('سيارة'),
  plot('قطعة أرضية'),
  other('أخرى');

  final String label;
  const LaborPlace(this.label);
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
  static const _kCars = 'cars';
  static const _kShipments = 'shipments';
  static const _kOrders = 'open_orders';
  static const _kPlots = 'plots';

  /// كل مفاتيح التخزين، لمزامنتها مع قاعدة البيانات.
  static const storageKeys = [
    _kPartners,
    _kWorkers,
    _kTx,
    _kWarehouses,
    _kProducts,
    _kMoves,
    _kInvoices,
    _kCompany,
    _kDebts,
    _kCars,
    _kPlots,
    _kShipments,
    _kOrders,
  ];

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
  List<Car> _cars = [];
  List<Shipment> _shipments = [];
  List<OpenOrder> _orders = [];
  List<Plot> _plots = [];
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

  /// السيارات: غير المباعة أولاً بحسب مرحلتها، ثم المباعة من الأحدث.
  List<Car> get cars => List.unmodifiable(
    [..._cars]..sort((a, b) {
      if (a.isSold != b.isSold) return a.isSold ? 1 : -1;
      if (a.isSold) {
        return (b.saleDate ?? b.purchaseDate).compareTo(
          a.saleDate ?? a.purchaseDate,
        );
      }
      final byStage = a.status.index.compareTo(b.status.index);
      return byStage != 0 ? byStage : b.purchaseDate.compareTo(a.purchaseDate);
    }),
  );

  /// حاويات البضاعة: غير المستلمة أولاً بحسب أقرب وصول، ثم المستلمة من الأحدث.
  List<Shipment> get shipments => List.unmodifiable(
    [..._shipments]..sort((a, b) {
      if (a.isReceived != b.isReceived) return a.isReceived ? 1 : -1;
      return a.isReceived
          ? b.expectedArrival.compareTo(a.expectedArrival)
          : a.expectedArrival.compareTo(b.expectedArrival);
    }),
  );

  /// أسماء شركات الشحن المستخدمة (للسيارات والحاويات)، مرتبة أبجدياً.
  List<String> get shippingCompanies => {
    for (final x in _cars)
      if (x.shippingCompany.isNotEmpty) x.shippingCompany,
    for (final x in _shipments)
      if (x.company.isNotEmpty) x.company,
  }.toList()..sort();

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
    _cars = await _read(_kCars, Car.fromJson);
    _shipments = await _read(_kShipments, Shipment.fromJson);
    _orders = await _read(_kOrders, OpenOrder.fromJson);
    _plots = await _read(_kPlots, Plot.fromJson);
    final company = await _storage.readList(_kCompany);
    if (company.isNotEmpty) _company = CompanyInfo.fromJson(company.first);
    loaded = true;
    notifyListeners();
    await _dropOldInvoiceTax();
  }

  /// أُزيلت الضريبة من النظام: الفواتير المحفوظة بضريبة تُقرأ بدونها، فنحدّث
  /// مبلغ معاملتها المالية ونقصر دينها على الإجمالي الجديد حتى تبقى الحسابات متطابقة.
  Future<void> _dropOldInvoiceTax() async {
    var changed = false;
    for (final inv in [..._invoices]) {
      final i = _transactions.indexWhere((t) => t.id == inv.txId);
      if (i != -1 && (_transactions[i].amount - inv.total).abs() > 0.0001) {
        _transactions[i] = Transaction.fromJson({
          ..._transactions[i].toJson(),
          'amount': inv.total,
        });
        changed = true;
      }
      if (inv.debt > inv.total + 0.0001) {
        _upsert(
          _invoices,
          Invoice.fromJson({...inv.toJson(), 'debt': inv.total}),
          (e) => e.id,
        );
        final d = debtForInvoice(inv.id);
        if (d != null) {
          _upsert(
            _debts,
            Debt.fromJson({
              ...d.toJson(),
              'amount': inv.total < d.paid ? d.paid : inv.total,
            }),
            (e) => e.id,
          );
        }
        changed = true;
      }
    }
    if (!changed) return;
    notifyListeners();
    await Future.wait([_saveTx(), _saveInvoices(), _saveDebts()]);
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

  Future<void> _saveCars() =>
      _storage.writeList(_kCars, _cars.map((e) => e.toJson()).toList());

  Future<void> _saveShipments() => _storage.writeList(
    _kShipments,
    _shipments.map((e) => e.toJson()).toList(),
  );

  Future<void> _saveOrders() =>
      _storage.writeList(_kOrders, _orders.map((e) => e.toJson()).toList());

  Future<void> _savePlots() =>
      _storage.writeList(_kPlots, _plots.map((e) => e.toJson()).toList());

  Future<void> _saveAll() => Future.wait([
    _savePlots(),
    _saveInvoices(),
    _saveDebts(),
    _saveCars(),
    _saveShipments(),
    _saveOrders(),
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

  /// شركاء الشركة كلها (يتقاسمون صافي ربح الشركة).
  List<Partner> get companyPartners =>
      _partners.where((p) => p.isCompanyPartner).toList();

  /// المستثمرون في صفقات محددة (سيارة، قطعة، حاوية...).
  List<Partner> get dealPartners =>
      _partners.where((p) => !p.isCompanyPartner).toList();

  /// مجموع نسب شركاء الشركة باستثناء شريك معيّن (للتحقق عند التعديل).
  double partnersShareTotal({String? excludeId}) => _partners
      .where((p) => p.isCompanyPartner && p.id != excludeId)
      .fold(0, (s, p) => s + p.sharePercent);

  /// مجموع نسب المستثمرين في نفس الصفقة باستثناء شريك معيّن.
  double dealShareTotal(String dealKey, {String? excludeId}) => _partners
      .where((p) => p.dealKey == dealKey && p.id != excludeId)
      .fold(0, (s, p) => s + p.sharePercent);

  /// المستثمرون في سيارة أو قطعة معيّنة.
  List<Partner> investorsIn(PartnerScope scope, String dealId) => [
    for (final p in _partners)
      if (p.scope == scope && p.dealId == dealId) p,
  ];

  /// اسم الصفقة كما يظهر في جدول الشركاء.
  String dealLabel(Partner p) => switch (p.scope) {
    PartnerScope.company => PartnerScope.company.label,
    PartnerScope.car =>
      'سيارة: ${carById(p.dealId ?? '')?.title ?? '(محذوفة)'}',
    PartnerScope.plot =>
      'قطعة: ${plotById(p.dealId ?? '')?.name ?? '(محذوفة)'}',
    PartnerScope.warehouse =>
      'مخزن: ${warehouseById(p.dealId)?.name ?? '(محذوف)'}',
    PartnerScope.container => switch (shipmentById(p.dealId ?? '')) {
      final x? =>
        'حاوية: ${[if (x.containerNumber.isNotEmpty) x.containerNumber, x.contents].join(' - ')}',
      _ => 'حاوية${p.dealTitle.isEmpty ? '' : ': ${p.dealTitle}'}',
    },
    PartnerScope.other => p.dealTitle.isEmpty ? 'صفقة' : p.dealTitle,
  };

  /// ربح الصفقة كلها، أو null قبل انتهائها (السيارة أو القطعة لم تُبع).
  double? dealProfitOf(Partner p) => switch (p.scope) {
    PartnerScope.company => null,
    PartnerScope.car => carById(p.dealId ?? '')?.profit,
    PartnerScope.plot => plotById(p.dealId ?? '')?.profit,
    // ربح المخزن: مجموع ربح مبيعاته (البيع - الشراء) منذ البداية.
    PartnerScope.warehouse =>
      p.dealId == null ? null : warehouseProfit(p.dealId!),
    PartnerScope.container || PartnerScope.other => p.dealProfit,
  };

  /// كشف الصفقة التي فيها المستثمر: مصروفاتها ومداخيلها وشركاؤها،
  /// ليرسله المدير للشريك.
  DealStatement dealStatement(Partner p) {
    final expenses = <DealLine>[];
    final income = <DealLine>[];
    final id = p.dealId ?? '';
    switch (p.scope) {
      case PartnerScope.car:
        final c = carById(id);
        if (c != null) {
          expenses.add((
            date: c.purchaseDate,
            label: 'سعر شراء السيارة',
            amount: c.purchasePrice,
          ));
          for (final x in c.costs) {
            expenses.add((date: x.date, label: x.label, amount: x.amount));
          }
          if (c.isSold) {
            income.add((
              date: c.saleDate,
              label: 'بيع السيارة${c.buyer.isEmpty ? '' : ' لـ ${c.buyer}'}',
              amount: c.salePrice,
            ));
          }
        }
      case PartnerScope.plot:
        final x = plotById(id);
        if (x != null) {
          expenses.add((
            date: x.purchaseDate,
            label: 'سعر شراء القطعة',
            amount: x.purchasePrice,
          ));
          for (final c in x.costs) {
            expenses.add((date: c.date, label: c.label, amount: c.amount));
          }
          if (x.status == PlotStatus.sold) {
            income.add((
              date: x.saleDate,
              label: 'بيع القطعة${x.buyer.isEmpty ? '' : ' لـ ${x.buyer}'}',
              amount: x.salePrice,
            ));
          }
        }
      case PartnerScope.container:
        final x = shipmentById(id);
        if (x != null) {
          for (final (label, amount) in [
            ('قيمة البضاعة', x.goodsValue),
            ('الشحن', x.freightCost),
            ('الجمارك', x.customsCost),
          ]) {
            if (amount > 0) {
              expenses.add((
                date: x.departureDate,
                label: label,
                amount: amount,
              ));
            }
          }
          for (final c in x.extraCosts) {
            expenses.add((date: null, label: c.label, amount: c.amount));
          }
        }
      case PartnerScope.warehouse:
        for (final t in _transactions) {
          if (t.type == TxType.expense &&
              (t.refId == id ||
                  (t.category == TxCategory.rent && t.personId == id))) {
            expenses.add((date: t.date, label: t.note, amount: t.amount));
          }
        }
        if (id.isNotEmpty) {
          income.add((
            date: null,
            label: 'ربح المبيعات (البيع - الشراء)',
            amount: warehouseProfit(id),
          ));
        }
      case PartnerScope.other || PartnerScope.company:
        break;
    }
    // مصروفات أُضيفت للصفقة يدوياً من صفحة الكشف.
    if (p.scope == PartnerScope.other) {
      for (final t in _transactions) {
        if (t.refId == p.dealKey && t.type == TxType.expense) {
          expenses.add((date: t.date, label: t.note, amount: t.amount));
        }
      }
    }
    int byDate(DealLine a, DealLine b) =>
        (a.date ?? DateTime(9999)).compareTo(b.date ?? DateTime(9999));
    expenses.sort(byDate);
    final partners = _partners.where((x) => x.dealKey == p.dealKey).toList();
    return (
      title: dealLabel(p),
      expenses: expenses,
      income: income,
      expensesTotal: expenses.fold(0, (a, e) => a + e.amount),
      profit: dealProfitOf(p),
      partners: partners,
    );
  }

  /// يضيف مصروفاً للصفقة: في تكاليف السيارة أو القطعة أو الحاوية،
  /// أو معاملة مصروف مرتبطة بالمخزن أو الصفقة الأخرى.
  Future<void> addDealExpense(
    Partner p, {
    required String label,
    required double amount,
    required DateTime date,
  }) async {
    final id = p.dealId ?? '';
    switch (p.scope) {
      case PartnerScope.car:
        final c = carById(id);
        if (c == null) throw StateError('السيارة محذوفة');
        _upsert(
          _cars,
          c.copyWith(costs: [...c.costs, CarCost(label, amount, date)]),
          (e) => e.id,
        );
      case PartnerScope.plot:
        final x = plotById(id);
        if (x == null) throw StateError('القطعة محذوفة');
        _upsert(
          _plots,
          x.copyWith(costs: [...x.costs, PlotCost(label, amount, date)]),
          (e) => e.id,
        );
      case PartnerScope.container:
        final x = shipmentById(id);
        if (x == null) throw StateError('الحاوية محذوفة');
        _upsert(
          _shipments,
          Shipment.fromJson({
            ...x.toJson(),
            'extraCosts': [
              ...x.extraCosts.map((c) => c.toJson()),
              ShipmentExtraCost('$label ${fmt.date(date)}', amount).toJson(),
            ],
          }),
          (e) => e.id,
        );
      case PartnerScope.warehouse || PartnerScope.other:
        _transactions.add(
          Transaction(
            id: newId(),
            category: TxCategory.otherExpense,
            amount: amount,
            date: date,
            note: '$label - ${dealLabel(p)}',
            refId: p.scope == PartnerScope.warehouse ? id : p.dealKey,
          ),
        );
      case PartnerScope.company:
        return;
    }
    notifyListeners();
    await Future.wait([_saveTx(), _saveShipments(), _saveCars(), _savePlots()]);
  }

  /// نصيب المستثمر من ربح صفقته، أو null قبل انتهائها.
  double? dealShareOf(Partner p) {
    final profit = dealProfitOf(p);
    return profit == null ? null : profit * p.sharePercent / 100;
  }

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

  /// مجموع الرواتب الشهرية (بدون عمال اليومية).
  double get monthlyPayroll => _workers
      .where((w) => w.active && !w.daily && !w.contract)
      .fold(0, (s, w) => s + w.monthlySalary);

  /// يسجّل صرف راتب الشهر (أو أجرة يوم للعامل اليومي) كمعاملة مصروف.
  Future<void> paySalary(Worker w, DateTime date) => saveTransaction(
    Transaction(
      id: newId(),
      category: TxCategory.salary,
      amount: w.monthlySalary,
      date: date,
      note: '${w.daily ? 'يومية' : 'راتب'} ${w.name}',
      personId: w.id,
    ),
  );

  // ---------- عمال المقاولة ----------

  /// مراحل عمل مدفوعة، بالترتيب.
  List<Transaction> jobPayments(String jobId) =>
      _transactions
          .where((t) => t.refId == jobId && t.category == TxCategory.salary)
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));

  double jobPaid(String jobId) =>
      jobPayments(jobId).fold(0, (s, t) => s + t.amount);

  double jobLeft(WorkJob j) => j.agreed - jobPaid(j.id);

  /// الباقي لعامل المقاولة في كل أعماله.
  double workerJobsLeft(Worker w) =>
      w.jobs.fold(0, (s, j) => s + jobLeft(j).clamp(0, double.infinity));

  /// اسم مكان العمل (قطعة، سيارة) أو null.
  String? jobPlaceName(WorkJob j) => laborPlaceName(
    LaborPlace.values.where((p) => p.name == j.place).firstOrNull ??
        LaborPlace.other,
    j.refId,
  );

  /// يضيف عملاً لعامل المقاولة أو يعدّله.
  Future<void> saveJob(String workerId, WorkJob job) async {
    final w = _workers.where((x) => x.id == workerId).firstOrNull;
    if (w == null) throw StateError('العامل غير موجود');
    if (job.title.trim().isEmpty) throw StateError('اكتب اسم العمل');
    final paid = jobPaid(job.id);
    if (job.agreed + 1e-9 < paid) {
      throw StateError(
        'دُفع ${fmt.money(paid)} لهذا العمل، فلا يمكن أن يقل المبلغ عن ذلك',
      );
    }
    final old = w.jobById(job.id);
    if (old != null &&
        (old.place != job.place || old.refId != job.refId) &&
        paid > 0) {
      throw StateError('لا يمكن تغيير مكان العمل بعد دفع مراحل منه');
    }
    _upsert(
      _workers,
      w.withJobs(
        [
          for (final x in w.jobs)
            if (x.id != job.id) x,
          job,
        ]..sort((a, b) => a.start.compareTo(b.start)),
      ),
      (e) => e.id,
    );
    notifyListeners();
    await _saveWorkers();
  }

  /// يحذف عملاً لم تُدفع منه أي مرحلة.
  Future<void> deleteJob(String workerId, String jobId) async {
    final w = _workers.where((x) => x.id == workerId).firstOrNull;
    if (w == null) return;
    if (jobPayments(jobId).isNotEmpty) {
      throw StateError('دُفعت مراحل من هذا العمل؛ احذفها أولاً');
    }
    _upsert(
      _workers,
      w.withJobs([
        for (final x in w.jobs)
          if (x.id != jobId) x,
      ]),
      (e) => e.id,
    );
    notifyListeners();
    await _saveWorkers();
  }

  /// يدفع لعامل المقاولة مبلغ مرحلة انتهت من العمل.
  Future<void> payJobStage(
    Worker w,
    WorkJob j, {
    required String stage,
    required double amount,
    required DateTime date,
  }) async {
    if (amount <= 0) throw StateError('اكتب المبلغ');
    final left = jobLeft(j);
    if (amount > left + 1e-9) {
      throw StateError('الباقي من المبلغ المتفق عليه ${fmt.money(left)} فقط');
    }
    final label = 'مرحلة ${stage.trim()} - ${j.title} - ${w.name}';
    _transactions.add(
      Transaction(
        id: newId(),
        category: TxCategory.salary,
        amount: amount,
        date: date,
        note: label,
        personId: w.id,
        refId: j.id,
      ),
    );
    _placeCost(j, label, amount, date, add: true);
    notifyListeners();
    await Future.wait([_saveTx(), _saveCars(), _savePlots()]);
  }

  /// يحذف مرحلة مدفوعة، ويزيلها من تكاليف القطعة أو السيارة.
  Future<void> deleteJobStage(WorkJob j, String txId) async {
    final t = jobPayments(j.id).where((t) => t.id == txId).firstOrNull;
    if (t == null) return;
    _transactions.removeWhere((x) => x.id == txId);
    _placeCost(j, t.note, t.amount, t.date, add: false);
    notifyListeners();
    await Future.wait([_saveTx(), _saveCars(), _savePlots()]);
  }

  /// يضيف مبلغ المرحلة لتكاليف القطعة أو السيارة، أو يزيله منها.
  void _placeCost(
    WorkJob j,
    String label,
    double amount,
    DateTime date, {
    required bool add,
  }) {
    bool same(String l, double a, DateTime d) =>
        l == label && a == amount && d == date;
    switch (j.place) {
      case 'car':
        final car = carById(j.refId ?? '');
        if (car == null) return;
        final costs = [...car.costs];
        if (add) {
          costs.add(CarCost(label, amount, date));
        } else {
          final i = costs.indexWhere((c) => same(c.label, c.amount, c.date));
          if (i < 0) return;
          costs.removeAt(i);
        }
        _upsert(_cars, car.copyWith(costs: costs), (e) => e.id);
      case 'plot':
        final plot = plotById(j.refId ?? '');
        if (plot == null) return;
        final costs = [...plot.costs];
        if (add) {
          costs.add(PlotCost(label, amount, date));
        } else {
          final i = costs.indexWhere((c) => same(c.label, c.amount, c.date));
          if (i < 0) return;
          costs.removeAt(i);
        }
        _upsert(_plots, plot.copyWith(costs: costs), (e) => e.id);
    }
  }

  /// أعمال عمال اليومية.
  static const workTasks = ['تنزيل البضاعة', 'رفع البضاعة', 'ترتيب المخزن'];

  /// أنواع مصاريف العمال غير الراتب واليومية.
  static const workerExpenseKinds = [
    'سلفة',
    'أكل',
    'نقل',
    'علاج',
    'مكافأة',
    'أخرى',
  ];

  /// كل ما صُرف على عامل (رواتب، يوميات، سلف ومصاريف)، الأحدث أولاً.
  List<Transaction> workerExpenses(String workerId, [Period? p]) =>
      inPeriod(p)
          .where((t) => t.personId == workerId && t.type == TxType.expense)
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  double paidToWorker(String workerId, [Period? p]) =>
      workerExpenses(workerId, p).fold(0, (a, t) => a + t.amount);

  /// مجموع ما صُرف على كل العمال في فترة.
  double paidToWorkers([Period? p]) {
    final ids = {for (final w in _workers) w.id};
    return inPeriod(p)
        .where((t) => t.type == TxType.expense && ids.contains(t.personId))
        .fold(0, (a, t) => a + t.amount);
  }

  /// مصروف على عامل غير الراتب (سلفة، أكل، نقل...).
  Future<void> addWorkerExpense(
    Worker w, {
    required String kind,
    required double amount,
    required DateTime date,
    String note = '',
  }) => saveTransaction(
    Transaction(
      id: newId(),
      category: TxCategory.otherExpense,
      amount: amount,
      date: date,
      note: [
        '$kind ${w.name}',
        if (note.trim().isNotEmpty) note.trim(),
      ].join(' - '),
      personId: w.id,
    ),
  );

  /// أجرة عمال يوميين غير مسجلين (عمال عشوائيون): مبلغ واحد للعمل، مع من
  /// دفعه، والمكان الذي عملوا فيه. تُسجَّل مصروفاً، وتُضاف إلى تكاليف
  /// الحاوية أو السيارة أو القطعة إذا كان العمل فيها.
  Future<void> recordLabor({
    required DateTime date,
    required double amount,
    required String task,
    LaborPlace place = LaborPlace.other,
    String? refId,
    int workers = 0,
    String payer = '',
    String note = '',
  }) async {
    final where = laborPlaceName(place, refId);
    final label = [
      'أجرة عمال${workers > 0 ? ' ($workers)' : ''}',
      task,
      ?where,
    ].join(' - ');
    _transactions.add(
      Transaction(
        id: newId(),
        category: TxCategory.salary,
        amount: amount,
        date: date,
        note: [
          label,
          if (payer.trim().isNotEmpty) 'دفعها: ${payer.trim()}',
          if (note.trim().isNotEmpty) note.trim(),
        ].join(' - '),
        refId: refId,
      ),
    );
    final costLabel =
        'عمال $task${workers > 0 ? ' ($workers)' : ''} ${fmt.date(date)}';
    switch (place) {
      case LaborPlace.container:
        final ship = shipmentById(refId ?? '');
        if (ship != null) {
          _upsert(
            _shipments,
            Shipment.fromJson({
              ...ship.toJson(),
              'extraCosts': [
                ...ship.extraCosts.map((c) => c.toJson()),
                ShipmentExtraCost(costLabel, amount).toJson(),
              ],
            }),
            (e) => e.id,
          );
        }
      case LaborPlace.car:
        final car = carById(refId ?? '');
        if (car != null) {
          _upsert(
            _cars,
            car.copyWith(
              costs: [...car.costs, CarCost(costLabel, amount, date)],
            ),
            (e) => e.id,
          );
        }
      case LaborPlace.plot:
        final plot = plotById(refId ?? '');
        if (plot != null) {
          _upsert(
            _plots,
            plot.copyWith(
              costs: [...plot.costs, PlotCost(costLabel, amount, date)],
            ),
            (e) => e.id,
          );
        }
      case LaborPlace.warehouse || LaborPlace.other:
        break;
    }
    notifyListeners();
    await Future.wait([_saveTx(), _saveShipments(), _saveCars(), _savePlots()]);
  }

  /// اسم المكان الذي عمل فيه العمال (مخزن 1، سيارة تويوتا...).
  String? laborPlaceName(LaborPlace place, String? refId) => switch (place) {
    LaborPlace.warehouse => warehouseById(refId)?.name,
    LaborPlace.car => switch (carById(refId ?? '')) {
      final c? => 'سيارة ${c.title}',
      _ => null,
    },
    LaborPlace.plot => switch (plotById(refId ?? '')) {
      final p? => p.name,
      _ => null,
    },
    LaborPlace.container => switch (shipmentById(refId ?? '')) {
      final x? =>
        'حاوية ${x.containerNumber.isEmpty ? x.contents : x.containerNumber}',
      _ => null,
    },
    LaborPlace.other => null,
  };

  /// أجور العمال اليوميين المسجلة، الأحدث أولاً.
  List<Transaction> laborPayments([Period? p]) =>
      inPeriod(p)
          .where(
            (t) =>
                t.category == TxCategory.salary &&
                (t.note.startsWith('أجرة عمال') || t.note.startsWith('يومية')),
          )
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  /// أجور عمال اليومية المسجلة على مخزن أو حاوية في فترة.
  double laborCost(String refId, [Period? p]) =>
      inPeriod(p)
          .where((t) => t.category == TxCategory.salary && t.refId == refId)
          .fold(0, (a, t) => a + t.amount);

  /// أيام عمل العامل اليومي في فترة (عدد أجور اليومية المسجلة له).
  int workDays(String workerId, [Period? p]) => inPeriod(p)
      .where(
        (t) =>
            t.personId == workerId &&
            t.category == TxCategory.salary &&
            t.note.startsWith('يومية'),
      )
      .length;

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
    for (final w in _warehouses) {
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
        for (final x in companyPartners)
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

  /// أرقام الفواتير التي فيها هذا الصنف (تمنع حذفه).
  List<String> invoicesUsingProduct(String id) => {
    for (final m in _moves)
      if (m.productId == id && m.invoiceId != null)
        invoiceById(m.invoiceId)?.number ?? '?',
  }.toList()..sort();

  /// عدد حركات المخزون اليدوية (غير الفواتير) على الصنف.
  int manualMovesOf(String id) =>
      _moves.where((m) => m.productId == id && m.invoiceId == null).length;

  /// يحذف الصنف مع حركاته اليدوية وقيودها المالية.
  /// الصنف المستخدم في فواتير لا يُحذف (ويُرجع false) إلا مع
  /// [withInvoices]، فتُحذف تلك الفواتير كاملة مع معاملاتها وديونها.
  Future<bool> deleteProduct(String id, {bool withInvoices = false}) async {
    final invoiceIds = {
      for (final m in _moves)
        if (m.productId == id && m.invoiceId != null) m.invoiceId!,
      for (final inv in _invoices)
        if (inv.lines.any((l) => l.productId == id)) inv.id,
    };
    if (invoiceIds.isNotEmpty && !withInvoices) return false;
    final invoiceTx = {
      for (final inv in _invoices)
        if (invoiceIds.contains(inv.id)) inv.txId,
    };
    _invoices.removeWhere((inv) => invoiceIds.contains(inv.id));
    _moves.removeWhere((m) => invoiceIds.contains(m.invoiceId));
    _transactions.removeWhere((t) => invoiceTx.contains(t.id));
    _debts.removeWhere((d) => invoiceIds.contains(d.invoiceId));
    final txIds = {
      for (final m in _moves)
        if (m.productId == id && m.txId != null) m.txId,
    };
    _moves.removeWhere((m) => m.productId == id);
    _transactions.removeWhere((t) => txIds.contains(t.id));
    _products.removeWhere((e) => e.id == id);
    notifyListeners();
    await Future.wait([
      _saveProducts(),
      _saveMoves(),
      _saveTx(),
      _saveInvoices(),
      _saveDebts(),
    ]);
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

  /// ما دخل المخزن من الصنف (الكمية الأصلية) وما خرج منه.
  /// المتوفر = [received] − [issued] = [stockOf].
  /// في كل المخازن معاً لا يُحسب التحويل بينها دخولاً ولا خروجاً.
  ({double received, double issued}) stockFlow(
    String productId, {
    String? warehouseId,
  }) {
    var received = 0.0, issued = 0.0;
    for (final m in _moves) {
      if (m.productId != productId) continue;
      final e = m.effectOn(warehouseId);
      if (e > 0) {
        received += e;
      } else {
        issued -= e;
      }
    }
    return (received: received, issued: issued);
  }

  /// مجموع كميات كل الأصناف في كل المخازن حتى تاريخ معيّن (اليوم إن لم يُحدَّد).
  double totalStockQty({DateTime? at}) {
    final end = at == null ? null : DateTime(at.year, at.month, at.day + 1);
    return _moves
        .where((m) => end == null || m.date.isBefore(end))
        .fold(0.0, (s, m) => s + m.effectOn(null));
  }

  /// قيمة المخزون بسعر الشراء.
  double stockValue({String? warehouseId}) => _products.fold(
    0,
    (s, p) => s + stockOf(p.id, warehouseId: warehouseId) * p.costPrice,
  );

  /// ربح مبيعات مخزن معيّن (البيع - الشراء): فواتير البيع منه والبيع اليدوي.
  double warehouseProfit(String warehouseId, [Period? p]) {
    var profit = 0.0;
    for (final inv in _invoices) {
      if (inv.type != InvoiceType.sale ||
          inv.warehouseId != warehouseId ||
          !inPeriodDate(inv.date, p)) {
        continue;
      }
      final cost = inv.lines.fold<double>(
        0,
        (a, l) =>
            a +
            (l.unitCost ?? productById(l.productId)?.costPrice ?? 0) * l.qty,
      );
      profit += inv.total - cost;
    }
    for (final m in _moves) {
      if (m.type == MoveType.sale &&
          m.invoiceId == null &&
          m.warehouseId == warehouseId &&
          inPeriodDate(m.date, p)) {
        final cost = productById(m.productId)?.costPrice ?? 0;
        profit += m.qty * (m.unitPrice - cost);
      }
    }
    return profit;
  }

  /// الإيجار المدفوع لمخزن في فترة.
  double rentPaid(String warehouseId, [Period? p]) => inPeriod(p)
      .where((t) => t.category == TxCategory.rent && t.personId == warehouseId)
      .fold(0, (a, t) => a + t.amount);

  /// يسجّل دفع إيجار مخزن كمصروف إيجار.
  Future<void> payWarehouseRent(Warehouse w, double amount, DateTime date) =>
      saveTransaction(
        Transaction(
          id: newId(),
          category: TxCategory.rent,
          amount: amount,
          date: date,
          note: 'إيجار ${w.name}',
          personId: w.id,
        ),
      );

  /// الأصناف التي وصل رصيدها الإجمالي إلى الحد الأدنى أو أقل.
  List<Product> get lowStockProducts => _products
      .where((p) => p.minQty > 0 && stockOf(p.id) <= p.minQty)
      .toList();

  /// يضبط الكمية المتوفرة من صنف في مخزن (جرد): الفرق يُسجَّل حركة إضافة أو
  /// صرف باسم المسؤول، فيبقى سجل الحركات صحيحاً. لا يُسجَّل شيء إذا لم تتغير.
  Future<void> adjustStock({
    required String productId,
    required String warehouseId,
    required double newQty,
    required String person,
    String note = '',
    DateTime? date,
  }) async {
    if (newQty < 0) throw StateError('الكمية لا تكون سالبة');
    final diff = newQty - stockOf(productId, warehouseId: warehouseId);
    if (diff.abs() < 1e-9) return;
    await saveMove(
      StockMove(
        id: newId(),
        type: diff > 0 ? MoveType.stockIn : MoveType.stockOut,
        productId: productId,
        warehouseId: warehouseId,
        qty: diff.abs(),
        unitPrice: productById(productId)?.costPrice ?? 0,
        date: date ?? DateTime.now(),
        note: [
          'تعديل الكمية المتوفرة',
          if (note.trim().isNotEmpty) note.trim(),
        ].join(' - '),
        person: person.trim(),
      ),
    );
  }

  // ---------- العارية ----------

  /// العارية التي لم تُرجع بعد. [LoanBalance.ours]: بضاعتنا عند شخص (لنا)،
  /// وإلا بضاعة شخص عندنا (علينا).
  List<LoanBalance> outstandingLoans({bool? ours}) {
    final map = <(bool, String, String, String), LoanBalance>{};
    final sorted = [..._moves]..sort((a, b) => a.date.compareTo(b.date));
    for (final m in sorted) {
      if (!m.type.isLoan) continue;
      final mine = m.type == MoveType.loanOut || m.type == MoveType.loanReturn;
      final key = (mine, m.person.trim(), m.productId, m.warehouseId);
      final cur = map[key];
      final adds = m.type == MoveType.loanOut || m.type == MoveType.borrowIn;
      final qty = (cur?.qty ?? 0) + (adds ? m.qty : -m.qty);
      map[key] = (
        ours: mine,
        person: key.$2,
        productId: m.productId,
        warehouseId: m.warehouseId,
        qty: qty,
        since: cur == null || cur.qty <= 1e-9 ? m.date : cur.since,
      );
    }
    return map.values
        .where((l) => l.qty > 1e-9 && (ours == null || l.ours == ours))
        .toList()
      ..sort((a, b) => a.since.compareTo(b.since));
  }

  /// الباقي من عارية صنف مع شخص في مخزن (لنا أو علينا).
  double loanedTo(
    String person,
    String productId,
    String warehouseId, {
    bool ours = true,
  }) => outstandingLoans(ours: ours)
      .where(
        (l) =>
            l.person == person.trim() &&
            l.productId == productId &&
            l.warehouseId == warehouseId,
      )
      .fold(0, (s, l) => s + l.qty);

  /// عارية جديدة بعدة أصناف: [ours] بضاعتنا تخرج إلى الشخص، وإلا بضاعته
  /// تدخل مخزننا.
  Future<void> recordLoan({
    required String person,
    required String warehouseId,
    required Map<String, double> items,
    bool ours = true,
    DateTime? date,
    String note = '',
  }) async {
    if (person.trim().isEmpty) throw StateError('اكتب اسم صاحب العارية');
    final lines = {
      for (final e in items.entries)
        if (e.value > 0) e.key: e.value,
    };
    if (lines.isEmpty) throw StateError('أضف صنفاً واحداً على الأقل');
    if (ours) {
      for (final e in lines.entries) {
        final available = stockOf(e.key, warehouseId: warehouseId);
        if (e.value > available + 1e-9) {
          throw StateError(
            'المتوفر من "${productById(e.key)?.name}" ${fmt.number(available)} فقط',
          );
        }
      }
    }
    for (final e in lines.entries) {
      _moves.add(
        StockMove(
          id: newId(),
          type: ours ? MoveType.loanOut : MoveType.borrowIn,
          productId: e.key,
          warehouseId: warehouseId,
          qty: e.value,
          unitPrice: productById(e.key)?.costPrice ?? 0,
          date: date ?? DateTime.now(),
          note: note.trim(),
          person: person.trim(),
        ),
      );
    }
    notifyListeners();
    await _saveMoves();
  }

  /// عارية لنا بصنف واحد.
  Future<void> lendStock({
    required String person,
    required String productId,
    required String warehouseId,
    required double qty,
    DateTime? date,
    String note = '',
  }) => recordLoan(
    person: person,
    warehouseId: warehouseId,
    items: {productId: qty},
    date: date,
    note: note,
  );

  /// إرجاع العارية (كلها أو جزء منها): لنا تعود إلى المخزن، وعلينا تخرج
  /// إلى صاحبها.
  Future<void> returnLoan({
    required String person,
    required String productId,
    required String warehouseId,
    required double qty,
    bool ours = true,
    DateTime? date,
    String note = '',
  }) {
    final owed = loanedTo(person, productId, warehouseId, ours: ours);
    if (qty > owed + 1e-9) {
      throw StateError('الباقي من العارية ${fmt.number(owed)} فقط');
    }
    return saveMove(
      StockMove(
        id: newId(),
        type: ours ? MoveType.loanReturn : MoveType.borrowReturn,
        productId: productId,
        warehouseId: warehouseId,
        qty: qty,
        unitPrice: productById(productId)?.costPrice ?? 0,
        date: date ?? DateTime.now(),
        note: note.trim(),
        person: person.trim(),
      ),
    );
  }

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
      // يُثبَّت سعر الشراء لحظة البيع حتى يبقى ربح الفاتورة صحيحاً.
      final old = invoiceById(inv.id);
      inv = Invoice.fromJson({
        ...inv.toJson(),
        'lines': [
          for (final l in inv.lines)
            InvoiceLine(
              productId: l.productId,
              qty: l.qty,
              unitPrice: l.unitPrice,
              unitCost:
                  l.unitCost ??
                  old?.lines
                      .where((o) => o.productId == l.productId)
                      .firstOrNull
                      ?.unitCost ??
                  productById(l.productId)?.costPrice ??
                  0,
            ).toJson(),
        ],
      });
    }
    if (inv.debt < 0 || inv.debt > inv.total + 0.0001) {
      throw StateError('مبلغ الدين يجب أن يكون بين 0 وإجمالي الفاتورة');
    }
    if (inv.debt + inv.prepaid > inv.total + 0.0001) {
      throw StateError(
        'دُفع ${fmt.number(inv.prepaid)} من هذه الفاتورة مقدماً، '
        'فلا يمكن أن يقل المدفوع عن ذلك',
      );
    }
    final linked = debtForInvoice(inv.id);
    if (linked != null && linked.paid > inv.debt + 0.0001) {
      throw StateError(
        'سُدِّد ${fmt.number(linked.paid)} من دين هذه الفاتورة، '
        'فلا يمكن أن يقل الدين عن ذلك',
      );
    }
    if (inv.type == InvoiceType.sale && inv.partialDelivery) {
      for (final d in inv.deliveries) {
        for (final pid in d.items.keys) {
          if (inv.qtyOf(pid) <= 0) {
            throw StateError(
              'سُلِّم للزبون من "${productById(pid)?.name}" ولم يعد في الفاتورة',
            );
          }
        }
      }
      for (final pid in inv.productIds) {
        if (inv.leftOf(pid) < -1e-9) {
          throw StateError(
            'أخذ الزبون ${fmt.number(inv.takenOf(pid))} من '
            '"${productById(pid)?.name}"، فلا يمكن أن تقل الكمية عن ذلك',
          );
        }
      }
    }
    if (inv.type == InvoiceType.sale) {
      final needed = <String, double>{};
      for (final l in inv.lines) {
        needed[l.productId] = (needed[l.productId] ?? 0) + l.qty;
      }
      final order = orderById(inv.openOrderId);
      if (order != null) {
        for (final e in needed.entries) {
          final left =
              order.qtyOf(e.key, at: inv.warehouseId) -
              takenFromOrder(
                order.id,
                e.key,
                at: inv.warehouseId,
                excludeInvoiceId: inv.id,
              );
          if (e.value > left + 1e-9) {
            throw StateError(
              'المتبقي للزبون من "${productById(e.key)?.name}" '
              'في ${warehouseById(inv.warehouseId)?.name ?? 'هذا المخزن'} '
              'من ${order.number} هو ${fmt.number(left)} فقط',
            );
          }
        }
      }
      for (final e in needed.entries) {
        // الكميات المحجوزة لزبائن الفواتير المفتوحة لا تُباع لغيرهم.
        final available =
            stockOf(
              e.key,
              warehouseId: inv.warehouseId,
              excludeInvoiceId: inv.id,
            ) -
            reservedQty(
              e.key,
              warehouseId: inv.warehouseId,
              excludeOrderId: inv.openOrderId,
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
      // المدفوع مقدماً دخل الحسابات يوم دُفع.
      amount: inv.total - inv.prepaid,
      date: inv.date,
      note: [
        '${inv.type.label} ${inv.number}',
        if (inv.partyName.isNotEmpty) inv.partyName,
        if (inv.prepaid > 0) 'منها ${fmt.number(inv.prepaid)} مدفوعة مقدماً',
      ].join(' - '),
    );
    _upsert(_transactions, tx, (e) => e.id);
    _upsert(_invoices, inv.withTx(tx.id), (e) => e.id);

    // الدين المرتبط بالفاتورة: يُنشأ أو يُحدَّث أو يُحذف حسب مبلغه.
    if (inv.debt > 0.0001) {
      final sale = inv.type == InvoiceType.sale;
      _upsert(
        _debts,
        Debt(
          id: linked?.id ?? newId(),
          direction: sale ? DebtDirection.theyOwe : DebtDirection.weOwe,
          personName: inv.partyName.isNotEmpty
              ? inv.partyName
              : (sale ? 'عميل' : 'مورد'),
          phone: inv.partyPhone,
          amount: inv.debt,
          date: inv.date,
          dueDate: linked?.dueDate,
          note: '${inv.type.label} ${inv.number}',
          payments: linked?.payments ?? const [],
          invoiceId: inv.id,
        ),
        (e) => e.id,
      );
    } else if (linked != null) {
      _debts.remove(linked);
    }

    notifyListeners();
    await Future.wait([_saveInvoices(), _saveMoves(), _saveTx(), _saveDebts()]);
  }

  // ---------- الفواتير المفتوحة ----------

  OpenOrder? orderById(String? id) =>
      id == null ? null : _orders.where((o) => o.id == id).firstOrNull;

  /// الفواتير المفتوحة: غير المكتملة أولاً، ثم الأحدث.
  List<OpenOrder> get openOrders => List.unmodifiable(
    [..._orders]..sort((a, b) {
      final ad = isOrderComplete(a), bd = isOrderComplete(b);
      if (ad != bd) return ad ? 1 : -1;
      return b.date.compareTo(a.date);
    }),
  );

  /// الرقم التالي للفاتورة المفتوحة، مثل O-0001.
  String nextOrderNumber() {
    var max = 0;
    for (final o in _orders) {
      final n = int.tryParse(o.number.replaceAll(RegExp(r'[^0-9]'), ''));
      if (n != null && n > max) max = n;
    }
    return 'O-${(max + 1).toString().padLeft(4, '0')}';
  }

  /// فواتير البيع (الدفعات) المسحوبة من فاتورة مفتوحة، الأقدم أولاً.
  List<Invoice> pickupsOf(String orderId) =>
      _invoices.where((i) => i.openOrderId == orderId).toList()..sort(
        (a, b) => a.date != b.date
            ? a.date.compareTo(b.date)
            : a.number.compareTo(b.number),
      );

  /// كل ما دفعه الزبون في فاتورة مفتوحة، بالترتيب: ما دفعه عند أخذ كل دفعة،
  /// ثم ما سدّده لاحقاً من دين تلك الدفعات.
  List<OrderPayment> orderPayments(OpenOrder o) {
    final out = <OrderPayment>[
      for (final t in orderAdvances(o.id))
        (
          date: t.date,
          amount: t.amount,
          source: t.note.replaceFirst(' - ${o.partyName}', ''),
          advanceId: t.id,
        ),
    ];
    for (final i in pickupsOf(o.id)) {
      final debt = debtForInvoice(i.id);
      final atPickup = i.total - i.prepaid - (debt?.amount ?? 0);
      if (atPickup > 1e-9) {
        out.add((
          date: i.date,
          amount: atPickup,
          source: 'عند أخذ ${i.number}',
          advanceId: null,
        ));
      }
      for (final p in debt?.payments ?? const <DebtPayment>[]) {
        out.add((
          date: p.date,
          amount: p.amount,
          source:
              'تسديد دين ${i.number}${p.note.isEmpty ? '' : ' • ${p.note}'}',
          advanceId: null,
        ));
      }
    }
    return out..sort((a, b) => a.date.compareTo(b.date));
  }

  /// ما أخذه الزبون من صنف في فاتورة مفتوحة، من مخزن [at] أو من كلها.
  double takenFromOrder(
    String orderId,
    String productId, {
    String? at,
    String? excludeInvoiceId,
  }) => _invoices
      .where(
        (i) =>
            i.openOrderId == orderId &&
            i.id != excludeInvoiceId &&
            (at == null || i.warehouseId == at),
      )
      .expand((i) => i.lines)
      .where((l) => l.productId == productId)
      .fold(0, (s, l) => s + l.qty);

  /// الباقي للزبون من صنف، في مخزن [at] أو في كل المخازن.
  double remainingInOrder(OpenOrder o, String productId, {String? at}) {
    final whs = at == null ? o.warehouseIds : [at];
    var total = 0.0;
    for (final w in whs) {
      final left =
          o.qtyOf(productId, at: w) - takenFromOrder(o.id, productId, at: w);
      if (left > 0) total += left;
    }
    return total;
  }

  bool isOrderComplete(OpenOrder o) => o.lines.every(
    (l) => remainingInOrder(o, l.productId, at: o.whOf(l)) <= 1e-9,
  );

  /// المدفوع من قيمة الفاتورة المفتوحة (مجموع الدفعات بعد ديونها).
  double orderPaid(OpenOrder o) =>
      orderAdvances(o.id).fold<double>(0, (s, t) => s + t.amount) +
      pickupsOf(o.id).fold(
        0,
        (s, i) =>
            s + i.total - i.prepaid - (debtForInvoice(i.id)?.remaining ?? 0),
      );

  /// المبالغ التي دفعها الزبون مقدماً في فاتورة مفتوحة (قبل أن يأخذ).
  List<Transaction> orderAdvances(String orderId) =>
      _transactions
          .where((t) => t.refId == orderId && t.category == TxCategory.sales)
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));

  /// رصيد الزبون من المدفوع مقدماً الذي لم يُستعمل بعد في أخذ بضاعة.
  double orderCredit(String orderId) =>
      orderAdvances(orderId).fold<double>(0, (s, t) => s + t.amount) -
      pickupsOf(orderId).fold<double>(0, (s, i) => s + i.prepaid);

  /// يسجّل مبلغاً دفعه الزبون مقدماً، ويُخصم من قيمة ما يأخذه لاحقاً.
  Future<void> addOrderAdvance(
    String orderId, {
    required double amount,
    required DateTime date,
    String note = '',
  }) async {
    final o = orderById(orderId);
    if (o == null) throw StateError('الفاتورة المفتوحة غير موجودة');
    if (amount <= 0) throw StateError('اكتب المبلغ المدفوع');
    final left = o.total - orderPaid(o);
    if (amount > left + 1e-9) {
      throw StateError('الباقي من مبلغ الفاتورة ${fmt.money(left)} فقط');
    }
    _transactions.add(
      Transaction(
        id: newId(),
        category: TxCategory.sales,
        amount: amount,
        date: date,
        note: [
          'دفعة مقدمة ${o.number} - ${o.partyName}',
          if (note.trim().isNotEmpty) note.trim(),
        ].join(' - '),
        refId: o.id,
      ),
    );
    notifyListeners();
    await _saveTx();
  }

  /// يحذف دفعة مقدمة، إلا إذا استُعملت في بضاعة أخذها الزبون.
  Future<void> deleteOrderAdvance(String orderId, String txId) async {
    final t = orderAdvances(orderId).where((t) => t.id == txId).firstOrNull;
    if (t == null) return;
    if (orderCredit(orderId) < t.amount - 1e-9) {
      throw StateError(
        'استُعمل هذا المبلغ في بضاعة أخذها الزبون؛ احذف تلك الفاتورة أولاً',
      );
    }
    _transactions.removeWhere((x) => x.id == txId);
    notifyListeners();
    await _saveTx();
  }

  /// قيمة ما أخذه الزبون حتى الآن.
  double orderTakenValue(OpenOrder o) =>
      pickupsOf(o.id).fold(0, (s, i) => s + i.total);

  /// بضاعة بيعت ودُفع ثمنها لكن الزبون تركها في المخزن ولم يأخذها بعد.
  /// خُصمت من المتوفر عند البيع، لكنها ما زالت موجودة في المخزن.
  double undeliveredQty(String productId, {String? warehouseId}) => _invoices
      .where(
        (i) =>
            i.partialDelivery &&
            (warehouseId == null || i.warehouseId == warehouseId),
      )
      .fold(0, (s, i) => s + i.leftOf(productId).clamp(0, double.infinity));

  /// فواتير البيع التي بقي لأصحابها بضاعة لم يأخذوها.
  List<Invoice> get invoicesWithLeft =>
      _invoices.where((i) => i.hasLeft).toList();

  /// الكمية المحجوزة من صنف في مخزن لزبائن الفواتير المفتوحة (ما لم يأخذوه).
  double reservedQty(
    String productId, {
    String? warehouseId,
    String? excludeOrderId,
    String? excludeInvoiceId,
  }) {
    var total = 0.0;
    for (final o in _orders) {
      if (o.id == excludeOrderId) continue;
      for (final w in o.warehouseIds) {
        if (warehouseId != null && w != warehouseId) continue;
        final left =
            o.qtyOf(productId, at: w) -
            takenFromOrder(
              o.id,
              productId,
              at: w,
              excludeInvoiceId: excludeInvoiceId,
            );
        if (left > 0) total += left;
      }
    }
    return total;
  }

  /// يحفظ الفاتورة المفتوحة. يتحقق أن البضاعة متوفرة لحجزها وأن الكميات
  /// لا تقل عمّا أخذه الزبون.
  Future<void> saveOpenOrder(OpenOrder o) async {
    if (o.lines.isEmpty) throw StateError('أضف صنفاً واحداً على الأقل');
    if (o.partyName.trim().isEmpty) throw StateError('اكتب اسم الزبون');
    // كل صنف في كل مخزن: الأسطر الجديدة، وما أخذ منه الزبون سابقاً
    // (حتى لا يُحذف أو يُنقل لمخزن آخر بعد أن أخذ منه).
    final pairs = <(String, String)>{
      for (final l in o.lines) (l.productId, o.whOf(l)),
      for (final i in pickupsOf(o.id))
        for (final l in i.lines) (l.productId, i.warehouseId),
    };
    for (final (pid, w) in pairs) {
      final name = productById(pid)?.name;
      final whName = warehouseById(w)?.name ?? '';
      final taken = takenFromOrder(o.id, pid, at: w);
      final want = o.qtyOf(pid, at: w);
      if (want + 1e-9 < taken) {
        throw StateError(
          'أخذ الزبون ${fmt.number(taken)} من "$name" من $whName، '
          'فلا يمكن أن تقل كميته في هذا المخزن عن ذلك',
        );
      }
      final free =
          stockOf(pid, warehouseId: w) -
          reservedQty(pid, warehouseId: w, excludeOrderId: o.id);
      if (want - taken > free + 1e-9) {
        throw StateError(
          'المتوفر من "$name" في $whName ${fmt.number(free)} فقط',
        );
      }
    }
    _upsert(_orders, o, (e) => e.id);
    notifyListeners();
    await _saveOrders();
  }

  /// يُرفض حذف فاتورة مفتوحة أخذ الزبون منها (احذف دفعاتها أولاً).
  Future<bool> deleteOpenOrder(String id) async {
    if (pickupsOf(id).isNotEmpty || orderAdvances(id).isNotEmpty) return false;
    _orders.removeWhere((o) => o.id == id);
    notifyListeners();
    await _saveOrders();
    return true;
  }

  /// يأخذ الزبون دفعة من فاتورته المفتوحة: تُنشأ فاتورة بيع بالكميات المأخوذة
  /// وسعرها المتفق عليه، وما لم يُدفع منها يصبح ديناً. تُرجع فاتورة البيع.
  Future<Invoice> pickupFromOrder(
    String orderId, {
    required Map<String, double> quantities,
    required double paid,
    DateTime? date,
    String notes = '',
    String? warehouseId,
  }) async {
    final o = orderById(orderId);
    if (o == null) throw StateError('الفاتورة المفتوحة غير موجودة');
    // كل دفعة تُؤخذ من مخزن واحد من مخازن الفاتورة المفتوحة.
    final wh = warehouseId ?? o.warehouseIds.first;
    if (!o.warehouseIds.contains(wh)) {
      throw StateError('هذا المخزن ليس في الفاتورة المفتوحة');
    }
    final lines = [
      for (final e in quantities.entries)
        if (e.value > 0)
          InvoiceLine(
            productId: e.key,
            qty: e.value,
            unitPrice: o.priceOf(e.key, at: wh),
          ),
    ];
    if (lines.isEmpty) throw StateError('اكتب الكمية التي أخذها الزبون');
    final total = lines.fold<double>(0, (s, l) => s + l.total);
    // يُخصم أولاً من المدفوع مقدماً، ثم يُدفع الباقي أو يصبح ديناً.
    final prepaid = orderCredit(o.id).clamp(0.0, total);
    final inv = Invoice(
      id: newId(),
      type: InvoiceType.sale,
      number: nextInvoiceNumber(InvoiceType.sale),
      date: date ?? DateTime.now(),
      partyName: o.partyName,
      partyPhone: o.partyPhone,
      warehouseId: wh,
      lines: lines,
      notes: [
        'دفعة من الفاتورة المفتوحة ${o.number}',
        if (notes.trim().isNotEmpty) notes.trim(),
      ].join(' - '),
      debt: (total - prepaid - paid).clamp(0.0, total - prepaid),
      openOrderId: o.id,
      prepaid: prepaid,
    );
    await saveInvoice(inv);
    return invoiceById(inv.id)!;
  }

  // ---------- الأرباح ----------

  /// كل عمليات البيع وربحها (سعر البيع - سعر الشراء)، الأحدث أولاً:
  /// فواتير البيع، البيع من المخزون، السيارات والقطع المباعة.
  List<ProfitEntry> profitEntries([Period? p]) {
    bool inP(DateTime d) => p == null || p.contains(d);
    String name(String id) => productById(id)?.name ?? 'صنف محذوف';
    double cost(String productId) => productById(productId)?.costPrice ?? 0;
    final out = <ProfitEntry>[];
    for (final inv in _invoices) {
      if (inv.type != InvoiceType.sale || !inPeriodDate(inv.date, p)) continue;
      var c = 0.0;
      var missing = false;
      final details = <String>[];
      for (final l in inv.lines) {
        final unit = l.unitCost ?? cost(l.productId);
        if (unit <= 0) missing = true;
        c += unit * l.qty;
        details.add(
          '${name(l.productId)}: ${fmt.number(l.qty)} × ${fmt.money(l.unitPrice)}'
          ' • شراء ${fmt.money(unit)} • ربح ${fmt.money((l.unitPrice - unit) * l.qty)}',
        );
      }
      if (inv.discount > 0) details.add('خصم: ${fmt.money(inv.discount)}');
      out.add((
        date: inv.date,
        kind: 'فاتورة بيع',
        title:
            '${inv.number}${inv.partyName.isEmpty ? '' : ' • ${inv.partyName}'}',
        sale: inv.total,
        cost: c,
        details: details,
        missingCost: missing,
      ));
    }
    for (final m in _moves) {
      if (m.type != MoveType.sale || m.invoiceId != null || !inP(m.date)) {
        continue;
      }
      final unit = cost(m.productId);
      out.add((
        date: m.date,
        kind: 'بيع من المخزون',
        title: name(m.productId),
        sale: m.qty * m.unitPrice,
        cost: m.qty * unit,
        details: [
          '${fmt.number(m.qty)} × ${fmt.money(m.unitPrice)} • شراء ${fmt.money(unit)}',
          if (m.person.isNotEmpty) 'العميل: ${m.person}',
          if (m.note.isNotEmpty) m.note,
        ],
        missingCost: unit <= 0,
      ));
    }
    for (final x in _cars) {
      final d = x.saleDate;
      if (!x.isSold || d == null || !inP(d)) continue;
      out.add((
        date: d,
        kind: 'سيارة',
        title: '${x.title}${x.buyer.isEmpty ? '' : ' • ${x.buyer}'}',
        sale: x.salePrice,
        cost: x.totalCost,
        details: [
          'سعر الشراء: ${fmt.money(x.purchasePrice)}',
          for (final c in x.costs) '${c.label}: ${fmt.money(c.amount)}',
        ],
        missingCost: x.purchasePrice <= 0,
      ));
    }
    for (final x in _plots) {
      final d = x.saleDate;
      if (!x.isSold || d == null || !inP(d)) continue;
      out.add((
        date: d,
        kind: 'قطعة أرضية',
        title: '${x.name}${x.buyer.isEmpty ? '' : ' • ${x.buyer}'}',
        sale: x.salePrice,
        cost: x.totalCost,
        details: [
          'سعر الشراء: ${fmt.money(x.purchasePrice)}',
          for (final c in x.costs) '${c.label}: ${fmt.money(c.amount)}',
        ],
        missingCost: x.purchasePrice <= 0,
      ));
    }
    out.sort((a, b) => b.date.compareTo(a.date));
    return out;
  }

  static bool inPeriodDate(DateTime d, Period? p) => p == null || p.contains(d);

  /// الأصناف التي ليس لها سعر شراء (ربح بيعها غير دقيق).
  List<Product> get productsWithoutCost =>
      _products.where((p) => p.costPrice <= 0).toList();

  /// أحداث الديون يوماً بيوم: دين جديد أو تسديد، الأحدث أولاً.
  List<DebtEvent> debtEvents([Period? p]) {
    final out = <DebtEvent>[];
    for (final d in _debts) {
      if (inPeriodDate(d.date, p)) {
        out.add((date: d.date, debt: d, payment: null));
      }
      for (final pay in d.payments) {
        if (inPeriodDate(pay.date, p)) {
          out.add((date: pay.date, debt: d, payment: pay));
        }
      }
    }
    out.sort((a, b) => b.date.compareTo(a.date));
    return out;
  }

  /// الدين المرتبط بفاتورة، إن وُجد.
  Debt? debtForInvoice(String invoiceId) =>
      _debts.where((d) => d.invoiceId == invoiceId).firstOrNull;

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
    _debts.removeWhere((d) => d.invoiceId == id);
    notifyListeners();
    await Future.wait([_saveInvoices(), _saveMoves(), _saveTx(), _saveDebts()]);
  }

  /// يغيّر اسم قسم المخزون؛ الاسم الفارغ يعيده إلى «المخزون».
  Future<void> renameInventory(String label) {
    final l = label.trim();
    return saveCompany(
      _company.copyWith(
        inventoryLabel: l.isEmpty ? CompanyInfo.defaultInventoryLabel : l,
      ),
    );
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
    final inv = invoiceById(d.invoiceId);
    if (inv != null && (d.amount - inv.debt).abs() > 0.0001) {
      throw StateError(
        'مبلغ هذا الدين يُعدَّل من ${inv.type.label} ${inv.number}',
      );
    }
    if (d.amount + 0.0001 < d.paid) {
      throw StateError('المبلغ أقل من المسدَّد (${fmt.number(d.paid)})');
    }
    _upsert(_debts, d, (e) => e.id);
    notifyListeners();
    await _saveDebts();
  }

  /// يرمي [StateError] لدين مرتبط بفاتورة؛ يُلغى من الفاتورة نفسها.
  Future<void> deleteDebt(String id) async {
    final inv = invoiceById(debtById(id)?.invoiceId);
    if (inv != null) {
      throw StateError(
        'هذا الدين من ${inv.type.label} ${inv.number}؛ احذفه من الفاتورة',
      );
    }
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

  // ---------- القطع الأرضية ----------

  /// القطع غير المباعة أولاً، ثم الأحدث شراءً.
  List<Plot> get plots => List.unmodifiable(
    [..._plots]..sort((a, b) {
      if (a.isSold != b.isSold) return a.isSold ? 1 : -1;
      return b.purchaseDate.compareTo(a.purchaseDate);
    }),
  );

  Plot? plotById(String id) => _plots.where((x) => x.id == id).firstOrNull;

  /// يحفظ القطعة. يرمي [StateError] إذا بيعت قبل شرائها.
  Future<void> savePlot(Plot x) async {
    final sold = x.saleDate;
    if (x.isSold && sold != null && sold.isBefore(x.purchaseDate)) {
      throw StateError('تاريخ البيع قبل تاريخ الشراء');
    }
    _upsert(_plots, x, (e) => e.id);
    notifyListeners();
    await _savePlots();
  }

  Future<void> deletePlot(String id) async {
    _plots.removeWhere((x) => x.id == id);
    notifyListeners();
    await _savePlots();
  }

  /// يضيف تكلفة (بناء، رسوم...) إلى قطعة.
  Future<void> addPlotCost(String id, PlotCost cost) async {
    final x = plotById(id);
    if (x == null) return;
    await savePlot(x.copyWith(costs: [...x.costs, cost]));
  }

  // ---------- السيارات ----------

  Car? carById(String id) => _cars.where((x) => x.id == id).firstOrNull;

  /// يحفظ السيارة. يرمي [StateError] عند تواريخ غير منطقية.
  Future<void> saveCar(Car x) async {
    final shipped = x.shippedDate, arrival = x.arrivalDate, sold = x.saleDate;
    if (shipped != null && arrival != null && arrival.isBefore(shipped)) {
      throw StateError('تاريخ الوصول قبل تاريخ الشحن');
    }
    if (x.isSold && sold != null && sold.isBefore(x.purchaseDate)) {
      throw StateError('تاريخ البيع قبل تاريخ الشراء');
    }
    _upsert(_cars, x, (e) => e.id);
    notifyListeners();
    await _saveCars();
  }

  Future<void> deleteCar(String id) async {
    _cars.removeWhere((x) => x.id == id);
    notifyListeners();
    await _saveCars();
  }

  /// يضيف مصروفاً إلى بطاقة السيارة.
  Future<void> addCarCost(String id, CarCost cost) async {
    final x = carById(id);
    if (x == null) return;
    await saveCar(x.copyWith(costs: [...x.costs, cost]));
  }

  /// ينقل السيارة إلى مرحلة أخرى (بدون البيع، فله بياناته الخاصة).
  Future<void> setCarStatus(String id, CarStatus status) async {
    final x = carById(id);
    if (x == null || status == CarStatus.sold) return;
    final updated = Car.fromJson({
      ...x.toJson(),
      'status': status.name,
      // الوصول إلى الميناء يثبّت تاريخ الوصول الفعلي إن لم يكن مسجلاً.
      if (status == CarStatus.atPort && x.arrivalDate == null)
        'arrivalDate': DateTime.now().toIso8601String(),
    });
    _upsert(_cars, updated, (e) => e.id);
    notifyListeners();
    await _saveCars();
  }

  /// السيارات التي لم تصل المعرض بعد.
  List<Car> get carsOnTheWay => _cars.where((x) => x.status.onTheWay).toList();

  int lateCars(DateTime now) => _cars.where((x) => x.isLate(now)).length;

  // ---------- حاويات البضاعة ----------

  Shipment? shipmentById(String id) =>
      _shipments.where((x) => x.id == id).firstOrNull;

  /// يحفظ الحاوية. يرمي [StateError] إذا كان الوصول المتوقع قبل الإبحار.
  Future<void> saveShipment(Shipment x) async {
    if (x.expectedArrival.isBefore(x.departureDate)) {
      throw StateError('تاريخ الوصول المتوقع قبل تاريخ الإبحار');
    }
    _upsert(_shipments, x, (e) => e.id);
    notifyListeners();
    await _saveShipments();
  }

  Future<void> deleteShipment(String id) async {
    _shipments.removeWhere((x) => x.id == id);
    notifyListeners();
    await _saveShipments();
  }

  /// ينقل الحاوية إلى مرحلة أخرى، ويسجّل تاريخ الاستلام عند اكتمالها.
  Future<void> setShipmentStatus(
    String id,
    ShipmentStatus status, {
    DateTime? on,
  }) async {
    final x = shipmentById(id);
    if (x == null) return;
    final received = status == ShipmentStatus.received;
    final updated = Shipment.fromJson({
      ...x.toJson(),
      'status': status.name,
      'receivedDate': received
          ? (on ?? DateTime.now()).toIso8601String()
          : null,
    });
    _upsert(_shipments, updated, (e) => e.id);
    notifyListeners();
    await _saveShipments();
  }

  /// الحاويات التي لم تُستلم بعد.
  List<Shipment> get activeShipments =>
      _shipments.where((x) => !x.isReceived).toList();

  int delayedShipments(DateTime now) =>
      _shipments.where((x) => x.isDelayed(now)).length;

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
        nationalId: '1234567890',
        jobTitle: 'مدير عمليات',
        monthlySalary: 30000,
        hiredAt: DateTime(now.year - 1),
      ),
      Worker(
        id: newId(),
        name: 'يوسف إبراهيم',
        nationalId: '2345678901',
        jobTitle: 'أمين مخزن',
        monthlySalary: 22000,
        hiredAt: DateTime(now.year - 1),
      ),
      Worker(
        id: newId(),
        name: 'عمر فاروق',
        nationalId: '3456789012',
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
    _cars.addAll([
      Car(
        id: newId(),
        make: 'تويوتا',
        model: 'هايلكس',
        year: 2019,
        color: 'أبيض',
        vin: 'MR0FA3CD200123456',
        purchaseDate: DateTime(now.year, now.month, now.day - 30),
        purchasePrice: 520000,
        origin: 'أنتويرب - بلجيكا',
        shippingCompany: 'شركة الأطلسي للشحن البحري',
        container: 'ATLU 552019-3',
        shippedDate: DateTime(now.year, now.month, now.day - 20),
        arrivalDate: DateTime(now.year, now.month, now.day + 5),
        status: CarStatus.atSea,
        costs: [
          CarCost('الشحن', 65000, DateTime(now.year, now.month, now.day - 20)),
        ],
      ),
      Car(
        id: newId(),
        make: 'هيونداي',
        model: 'توسان',
        year: 2018,
        color: 'رمادي',
        vin: 'KMHJ381ABJU765432',
        plate: '2345 AB 00',
        purchaseDate: DateTime(now.year, now.month - 2, 4),
        purchasePrice: 410000,
        origin: 'هامبورغ - ألمانيا',
        shippingCompany: 'شركة المتوسط للملاحة',
        container: 'MEDU 771204-8',
        shippedDate: DateTime(now.year, now.month - 2, 12),
        arrivalDate: DateTime(now.year, now.month - 1, 2),
        status: CarStatus.inStock,
        costs: [
          CarCost('الشحن', 60000, DateTime(now.year, now.month - 2, 12)),
          CarCost('الجمارك', 95000, DateTime(now.year, now.month - 1, 4)),
          CarCost('التخليص', 15000, DateTime(now.year, now.month - 1, 4)),
          CarCost(
            'التسجيل والترقيم',
            12000,
            DateTime(now.year, now.month - 1, 10),
          ),
        ],
      ),
      Car(
        id: newId(),
        make: 'مرسيدس',
        model: 'C200',
        year: 2016,
        color: 'أسود',
        vin: 'WDD2050421F112233',
        plate: '8812 AA 00',
        purchaseDate: DateTime(now.year, now.month - 4, 1),
        purchasePrice: 600000,
        origin: 'أنتويرب - بلجيكا',
        shippingCompany: 'شركة الأطلسي للشحن البحري',
        status: CarStatus.sold,
        costs: [
          CarCost('الشحن', 70000, DateTime(now.year, now.month - 4, 8)),
          CarCost('الجمارك', 140000, DateTime(now.year, now.month - 3, 5)),
          CarCost('تصليح', 25000, DateTime(now.year, now.month - 3, 15)),
        ],
        buyer: 'محمد الأمين',
        buyerPhone: '22 10 20 30',
        salePrice: 980000,
        saleDate: DateTime(now.year, now.month - 1, 22),
      ),
    ]);

    const lineA = 'شركة الأطلسي للشحن البحري';
    const lineB = 'شركة المتوسط للملاحة';
    _shipments.addAll([
      Shipment(
        id: newId(),
        company: lineA,
        billOfLading: 'ATL-2410-551',
        containerNumber: 'ATLU 482193-0',
        contents: 'حديد تسليح 12 مم - 25 طن',
        originPort: 'الدار البيضاء',
        departureDate: DateTime(now.year, now.month, now.day - 6),
        expectedArrival: DateTime(now.year, now.month, now.day + 4),
        goodsValue: 640000,
        freightCost: 85000,
      ),
      Shipment(
        id: newId(),
        company: lineB,
        billOfLading: 'MED-77120',
        containerNumber: 'MEDU 330571-4',
        contents: 'بلاط سيراميك - 1,800 متر',
        originPort: 'فالنسيا',
        departureDate: DateTime(now.year, now.month, now.day - 20),
        expectedArrival: DateTime(now.year, now.month, now.day - 3),
        status: ShipmentStatus.customs,
        goodsValue: 410000,
        freightCost: 120000,
        customsCost: 95000,
        note: 'بانتظار شهادة المطابقة',
      ),
      Shipment(
        id: newId(),
        company: lineA,
        billOfLading: 'ATL-2409-318',
        containerNumber: 'ATLU 401877-2',
        contents: 'أسمنت أبيض - 900 كيس',
        originPort: 'لاس بالماس',
        departureDate: DateTime(now.year, now.month - 1, 2),
        expectedArrival: DateTime(now.year, now.month - 1, 9),
        receivedDate: DateTime(now.year, now.month - 1, 14),
        status: ShipmentStatus.received,
        goodsValue: 270000,
        freightCost: 60000,
        customsCost: 48000,
      ),
      Shipment(
        id: newId(),
        company: lineB,
        billOfLading: 'MED-77302',
        containerNumber: 'MEDU 338840-9',
        contents: 'أدوات صحية وخلاطات',
        originPort: 'إسطنبول',
        departureDate: DateTime(now.year, now.month, now.day - 25),
        expectedArrival: DateTime(now.year, now.month, now.day - 2),
        goodsValue: 380000,
        freightCost: 140000,
        note: 'تأخير بسبب ازدحام ميناء الترانزيت',
      ),
    ]);

    _plots.addAll([
      Plot(
        id: newId(),
        name: 'قطعة 112',
        location: 'تفرغ زينة',
        area: 300,
        purchaseDate: DateTime(now.year, now.month - 7, 3),
        purchasePrice: 4500000,
        status: PlotStatus.building,
        costs: [
          PlotCost(
            'أساسات وحفر',
            650000,
            DateTime(now.year, now.month - 5, 10),
          ),
          PlotCost('أسمنت وحديد', 900000, DateTime(now.year, now.month - 3, 2)),
        ],
      ),
      Plot(
        id: newId(),
        name: 'قطعة 47',
        location: 'توجنين',
        area: 240,
        purchaseDate: DateTime(now.year - 1, 9, 15),
        purchasePrice: 2800000,
        costs: [
          PlotCost('بناء كامل', 3200000, DateTime(now.year - 1, 12, 1)),
          PlotCost('توصيل الكهرباء والماء', 250000, DateTime(now.year, 2, 5)),
        ],
        status: PlotStatus.sold,
        buyer: 'سيدي محمد',
        salePrice: 7600000,
        saleDate: DateTime(now.year, now.month - 1, 20),
      ),
    ]);
    if (_company.phone.isEmpty) {
      _company = const CompanyInfo();
      await _storage.writeList(_kCompany, [_company.toJson()]);
    }

    notifyListeners();
    await _saveAll();
  }

  /// المخازن الأربعة التي طلبها المدير؛ تُضاف مرة واحدة (ما كان موجوداً
  /// باسمه يبقى)، ثم يعدّلها أو يحذفها بحرية من صفحة المخازن.
  static const defaultWarehouses = ['مخزن 1', 'مخزن 2', 'مخزن 3', 'مخزن 4'];

  Future<void> ensureDefaultWarehouses() async {
    if (_company.warehousesSet) return;
    final names = {for (final w in _warehouses) w.name.trim()};
    for (final n in defaultWarehouses) {
      if (!names.contains(n)) _warehouses.add(Warehouse(id: newId(), name: n));
    }
    await _saveWarehouses();
    await saveCompany(_company.copyWith(warehousesSet: true));
  }

  /// أصناف البضاعة كما أرسلها المدير؛ تُضاف مرة واحدة (ما كان موجوداً باسمه
  /// يبقى)، وتظهر في كل المخازن برصيد مستقل لكل مخزن.
  static const defaultProducts = [
    '0.66 غ',
    '0.9 غ',
    '0.98 غ',
    '1.533 غ',
    '1.63 غ',
    '2 غ',
    '2.22 غ',
    '3.20 غ',
    '4 غ',
    '17.875 غ',
    '#5.5',
    '#7.5',
    '#9.5',
    '#13',
    '24# green',
    '25# white',
    '2040# glass',
  ];

  Future<void> ensureDefaultProducts() async {
    if (_company.productsSet) return;
    String key(String n) => n.replaceAll(' ', '').toLowerCase();
    final names = {for (final p in _products) key(p.name)};
    for (final n in defaultProducts) {
      if (!names.contains(key(n))) {
        _products.add(Product(id: newId(), name: n));
      }
    }
    await _saveProducts();
    await saveCompany(_company.copyWith(productsSet: true));
  }

  /// يحذف ما أضافته البيانات التجريبية فقط (الأسمنت والحديد والشركاء
  /// والعمال التجريبيون...) ويُبقي بيانات المؤسسة الحقيقية. يُعرف كل سجل
  /// تجريبي بأكثر من حقل معاً، وما عُدِّل منه أو استُخدم في فاتورة حقيقية يبقى.
  /// يُرجع عدد السجلات المحذوفة.
  Future<int> removeDemoData() async {
    var removed = 0;
    int drop<T>(List<T> list, bool Function(T) test) {
      final before = list.length;
      list.removeWhere(test);
      removed += before - list.length;
      return before - list.length;
    }

    // الأسعار تغيّرت بين نسخ البيانات التجريبية، فيكفي الاسم مع الكود.
    const demoProducts = {
      ('أسمنت', 'C-01'),
      ('حديد تسليح 12مم', 'S-12'),
      ('بلاط سيراميك', 'T-60'),
      ('دهان أبيض', 'P-W'),
      ('أنابيب PVC', 'PVC-4'),
    };
    final productIds = {
      for (final p in _products)
        if (demoProducts.contains((p.name.trim(), p.code.trim()))) p.id,
    };

    // الفواتير التجريبية: أطرافها التجريبية وكل أصنافها تجريبية.
    const demoParties = {
      'مؤسسة الحديد المتحدة',
      'شركة البناء الحديث',
      'عميل نقدي',
    };
    final invoices = [
      for (final inv in _invoices)
        if (demoParties.contains(inv.partyName) &&
            inv.lines.isNotEmpty &&
            inv.lines.every((l) => productIds.contains(l.productId)))
          inv,
    ];
    final invoiceIds = {for (final inv in invoices) inv.id};
    final invoiceTx = {for (final inv in invoices) inv.txId};
    drop(_invoices, (inv) => invoiceIds.contains(inv.id));
    _moves.removeWhere((m) => invoiceIds.contains(m.invoiceId));
    _transactions.removeWhere((x) => invoiceTx.contains(x.id));
    _debts.removeWhere((d) => invoiceIds.contains(d.invoiceId));

    // الأصناف التجريبية غير المستخدمة في فواتير حقيقية، مع حركاتها اليدوية.
    productIds.removeWhere(
      (id) => _moves.any((m) => m.productId == id && m.invoiceId != null),
    );
    final moveTx = {
      for (final m in _moves)
        if (productIds.contains(m.productId) && m.txId != null) m.txId,
    };
    _moves.removeWhere((m) => productIds.contains(m.productId));
    _transactions.removeWhere((x) => moveTx.contains(x.id));
    drop(_products, (p) => productIds.contains(p.id));

    // مخزن الفرع التجريبي إن لم يبقَ عليه شيء.
    drop(
      _warehouses,
      (w) =>
          w.name == 'مخزن الفرع' &&
          !_moves.any((m) => m.warehouseId == w.id || m.toWarehouseId == w.id),
    );

    // هواتف الشركاء والدائنين في نسخ البيانات التجريبية المتتالية.
    const demoPhones = {
      '22 45 67 01',
      '36 45 67 02',
      '46 45 67 03',
      '0500000001',
      '0500000002',
      '0500000003',
      '22 33 44 55',
      '36 10 20 30',
      '45 25 10 10',
      '45 25 00 00',
      '0500000000',
      '0500000010',
    };
    const demoPartners = {'أحمد علي', 'محمد حسن', 'خالد سعيد'};
    const demoWorkers = {
      'سالم يوسف': '1234567890',
      'يوسف إبراهيم': '2345678901',
      'عمر فاروق': '3456789012',
    };
    final people = {
      for (final p in _partners)
        if (demoPartners.contains(p.name) && demoPhones.contains(p.phone)) p.id,
      for (final w in _workers)
        if (demoWorkers.containsKey(w.name) &&
            (w.nationalId.isEmpty || w.nationalId == demoWorkers[w.name]))
          w.id,
    };
    drop(_partners, (p) => people.contains(p.id));
    drop(_workers, (w) => people.contains(w.id));
    drop(
      _transactions,
      (x) =>
          (x.personId != null && people.contains(x.personId)) ||
          (x.category == TxCategory.sales && x.note == 'مبيعات الشهر') ||
          (x.category == TxCategory.rent && x.note == 'إيجار المقر'),
    );

    const demoDebtors = {'سيدي محمد', 'مقاولات الأمل', 'مؤسسة الحديد المتحدة'};
    drop(
      _debts,
      (d) =>
          d.invoiceId == null &&
          demoDebtors.contains(d.personName) &&
          demoPhones.contains(d.phone),
    );

    const demoVins = {
      'MR0FA3CD200123456',
      'KMHJ381ABJU765432',
      'WDD2050421F112233',
    };
    drop(_cars, (c) => demoVins.contains(c.vin));
    drop(
      _shipments,
      (x) => {
        'ATLU 482193-0',
        'MEDU 330571-4',
        'ATLU 401877-2',
        'MEDU 338840-9',
      }.contains(x.containerNumber),
    );
    drop(
      _plots,
      (p) =>
          (p.name == 'قطعة 112' &&
              p.location == 'تفرغ زينة' &&
              p.purchasePrice == 4500000) ||
          (p.name == 'قطعة 47' &&
              p.location == 'توجنين' &&
              p.purchasePrice == 2800000),
    );

    if (removed == 0 && invoices.isEmpty) return 0;
    notifyListeners();
    await _saveAll();
    return removed;
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
    _cars.clear();
    _shipments.clear();
    _orders.clear();
    _plots.clear();
    notifyListeners();
    await _saveAll();
  }
}
