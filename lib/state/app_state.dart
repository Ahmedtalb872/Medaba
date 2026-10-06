import 'package:flutter/foundation.dart';

import '../data/storage.dart';
import '../models/models.dart';

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
  final List<ProfitShare> investors;
  final List<ProfitShare> partners;
  const ProfitReport({
    required this.income,
    required this.expenses,
    required this.investors,
    required this.partners,
  });

  double get netProfit => income - expenses;
  double get investorsTotal => investors.fold(0, (s, e) => s + e.amount);
  double get partnersPool => netProfit - investorsTotal;
}

class AppState extends ChangeNotifier {
  static const _kPartners = 'partners';
  static const _kInvestors = 'investors';
  static const _kWorkers = 'workers';
  static const _kTx = 'transactions';

  final Storage _storage;
  AppState(this._storage);

  List<Partner> _partners = [];
  List<Investor> _investors = [];
  List<Worker> _workers = [];
  List<Transaction> _transactions = [];
  bool loaded = false;

  List<Partner> get partners => List.unmodifiable(_partners);
  List<Investor> get investors => List.unmodifiable(_investors);
  List<Worker> get workers => List.unmodifiable(_workers);

  /// المعاملات مرتبة من الأحدث للأقدم.
  List<Transaction> get transactions => List.unmodifiable(
    [..._transactions]..sort((a, b) => b.date.compareTo(a.date)),
  );

  Future<void> load() async {
    _partners = (await _storage.readList(_kPartners))
        .map(Partner.fromJson)
        .toList();
    _investors = (await _storage.readList(_kInvestors))
        .map(Investor.fromJson)
        .toList();
    _workers = (await _storage.readList(_kWorkers))
        .map(Worker.fromJson)
        .toList();
    _transactions = (await _storage.readList(_kTx))
        .map(Transaction.fromJson)
        .toList();
    loaded = true;
    notifyListeners();
  }

  // ---------- عمليات الحفظ ----------

  Future<void> _savePartners() =>
      _storage.writeList(_kPartners, _partners.map((e) => e.toJson()).toList());
  Future<void> _saveInvestors() => _storage.writeList(
    _kInvestors,
    _investors.map((e) => e.toJson()).toList(),
  );
  Future<void> _saveWorkers() =>
      _storage.writeList(_kWorkers, _workers.map((e) => e.toJson()).toList());
  Future<void> _saveTx() =>
      _storage.writeList(_kTx, _transactions.map((e) => e.toJson()).toList());

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

  // ---------- المستثمرون ----------

  double investorsPercentTotal({String? excludeId}) => _investors
      .where((p) => p.id != excludeId)
      .fold(0, (s, p) => s + p.profitPercent);

  Future<void> saveInvestor(Investor i) async {
    _upsert(_investors, i, (e) => e.id);
    notifyListeners();
    await _saveInvestors();
  }

  Future<void> deleteInvestor(String id) async {
    _investors.removeWhere((e) => e.id == id);
    notifyListeners();
    await _saveInvestors();
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

  String? personName(String? id) {
    if (id == null) return null;
    for (final p in _partners) {
      if (p.id == id) return p.name;
    }
    for (final i in _investors) {
      if (i.id == id) return i.name;
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

  double get totalCapital =>
      _partners.fold<double>(0, (s, p) => s + p.capital) +
      _investors.fold<double>(0, (s, i) => s + i.amount);

  /// الرصيد النقدي = كل الإيرادات - كل المصروفات (بما فيها المسحوبات) + رأس المال.
  double get cashBalance =>
      totalCapital +
      totalIncome() -
      _transactions
          .where((t) => t.type == TxType.expense)
          .fold<double>(0, (s, t) => s + t.amount);

  /// توزيع الأرباح: يأخذ كل مستثمر نسبته من صافي الربح أولاً،
  /// ثم يوزَّع الباقي على الشركاء حسب نسبهم.
  /// في حالة الخسارة لا يحصل المستثمرون على شيء ويتحمل الشركاء الخسارة.
  ProfitReport profitReport([Period? p]) {
    final income = totalIncome(p);
    final expenses = totalExpenses(p);
    final net = income - expenses;
    final distributable = net > 0 ? net : 0.0;

    final inv = _investors
        .map(
          (i) => ProfitShare(
            i.id,
            i.name,
            i.profitPercent,
            distributable * i.profitPercent / 100,
            withdrawnBy(i.id, p),
          ),
        )
        .toList();
    final pool = net - inv.fold<double>(0, (s, e) => s + e.amount);

    final partnersTotal = partnersShareTotal();
    final par = _partners
        .map(
          (x) => ProfitShare(
            x.id,
            x.name,
            x.sharePercent,
            partnersTotal == 0 ? 0 : pool * x.sharePercent / partnersTotal,
            withdrawnBy(x.id, p),
          ),
        )
        .toList();

    return ProfitReport(
      income: income,
      expenses: expenses,
      investors: inv,
      partners: par,
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

  /// يملأ التطبيق ببيانات تجريبية للعرض على الزبون.
  Future<void> seedDemoData() async {
    final now = DateTime.now();
    final p1 = Partner(
      id: newId(),
      name: 'أحمد علي',
      phone: '0500000001',
      sharePercent: 50,
      capital: 100000,
      joinedAt: DateTime(now.year - 1),
    );
    final p2 = Partner(
      id: newId(),
      name: 'محمد حسن',
      phone: '0500000002',
      sharePercent: 30,
      capital: 60000,
      joinedAt: DateTime(now.year - 1),
    );
    final p3 = Partner(
      id: newId(),
      name: 'خالد سعيد',
      phone: '0500000003',
      sharePercent: 20,
      capital: 40000,
      joinedAt: DateTime(now.year - 1),
    );
    final inv = Investor(
      id: newId(),
      name: 'شركة الاستثمار الأولى',
      phone: '0500000010',
      amount: 150000,
      profitPercent: 25,
      investedAt: DateTime(now.year - 1, 6),
    );
    final workers = [
      Worker(
        id: newId(),
        name: 'سالم يوسف',
        jobTitle: 'مدير عمليات',
        monthlySalary: 8000,
        hiredAt: DateTime(now.year - 1),
      ),
      Worker(
        id: newId(),
        name: 'يوسف إبراهيم',
        jobTitle: 'محاسب',
        monthlySalary: 6000,
        hiredAt: DateTime(now.year - 1),
      ),
      Worker(
        id: newId(),
        name: 'عمر فاروق',
        jobTitle: 'فني',
        monthlySalary: 4500,
        hiredAt: DateTime(now.year - 1, 3),
      ),
    ];
    _partners.addAll([p1, p2, p3]);
    _investors.add(inv);
    _workers.addAll(workers);

    for (var i = 5; i >= 0; i--) {
      final d = DateTime(now.year, now.month - i, 5);
      _transactions.addAll([
        Transaction(
          id: newId(),
          category: TxCategory.sales,
          amount: 60000 + i * 4000.0,
          date: d,
          note: 'مبيعات الشهر',
        ),
        Transaction(
          id: newId(),
          category: TxCategory.rent,
          amount: 7000,
          date: d,
          note: 'إيجار المقر',
        ),
        Transaction(
          id: newId(),
          category: TxCategory.supplies,
          amount: 12000 + i * 500.0,
          date: d,
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
        amount: 10000,
        date: DateTime(now.year, now.month, 1),
        note: 'سحب أرباح',
        personId: p1.id,
      ),
    );

    notifyListeners();
    await Future.wait([
      _savePartners(),
      _saveInvestors(),
      _saveWorkers(),
      _saveTx(),
    ]);
  }

  Future<void> clearAll() async {
    _partners.clear();
    _investors.clear();
    _workers.clear();
    _transactions.clear();
    notifyListeners();
    await Future.wait([
      _savePartners(),
      _saveInvestors(),
      _saveWorkers(),
      _saveTx(),
    ]);
  }
}
