import 'package:flutter_test/flutter_test.dart';
import 'package:medaba/data/storage.dart';
import 'package:medaba/models/models.dart';
import 'package:medaba/state/app_state.dart';

void main() {
  late AppState s;
  final d = DateTime(2026, 3, 10);

  setUp(() async {
    s = AppState(MemoryStorage());
    await s.load();
  });

  Future<void> tx(TxCategory c, double amount, {String? person}) =>
      s.saveTransaction(
        Transaction(
          id: newId(),
          category: c,
          amount: amount,
          date: d,
          personId: person,
        ),
      );

  test('profit goes to investors first, rest to partners by share', () async {
    await s.savePartner(
      Partner(id: 'a', name: 'A', sharePercent: 60, joinedAt: d),
    );
    await s.savePartner(
      Partner(id: 'b', name: 'B', sharePercent: 40, joinedAt: d),
    );
    await s.saveInvestor(
      Investor(
        id: 'i',
        name: 'I',
        amount: 1000,
        profitPercent: 20,
        investedAt: d,
      ),
    );
    await tx(TxCategory.sales, 10000);
    await tx(TxCategory.rent, 2000);
    // المسحوبات لا تؤثر على الربح.
    await tx(TxCategory.withdrawal, 500, person: 'a');

    final r = s.profitReport(Period.month(d));
    expect(r.netProfit, 8000);
    expect(r.investors.single.amount, 1600);
    expect(r.partnersPool, 6400);
    expect(r.partners.firstWhere((p) => p.id == 'a').amount, 3840);
    expect(r.partners.firstWhere((p) => p.id == 'a').balance, 3340);
    expect(r.partners.firstWhere((p) => p.id == 'b').amount, 2560);
  });

  test('on a loss investors get nothing and partners carry it', () async {
    await s.savePartner(
      Partner(id: 'a', name: 'A', sharePercent: 100, joinedAt: d),
    );
    await s.saveInvestor(
      Investor(
        id: 'i',
        name: 'I',
        amount: 1000,
        profitPercent: 20,
        investedAt: d,
      ),
    );
    await tx(TxCategory.sales, 1000);
    await tx(TxCategory.rent, 3000);

    final r = s.profitReport(Period.month(d));
    expect(r.investors.single.amount, 0);
    expect(r.partners.single.amount, -2000);
  });

  test('period filter excludes other months', () async {
    await tx(TxCategory.sales, 100);
    expect(s.totalIncome(Period.month(DateTime(2026, 4))), 0);
    expect(s.totalIncome(Period.month(d)), 100);
  });

  test('data persists through storage', () async {
    final storage = MemoryStorage();
    final a = AppState(storage);
    await a.load();
    await a.saveWorker(
      Worker(id: 'w', name: 'W', monthlySalary: 3000, hiredAt: d),
    );
    await a.paySalary(a.workers.single, d);

    final b = AppState(storage);
    await b.load();
    expect(b.workers.single.name, 'W');
    expect(b.totalExpenses(), 3000);
    expect(b.personName(b.transactions.single.personId), 'W');
  });

  test('partner share total excludes edited partner', () async {
    await s.savePartner(
      Partner(id: 'a', name: 'A', sharePercent: 70, joinedAt: d),
    );
    expect(s.partnersShareTotal(), 70);
    expect(s.partnersShareTotal(excludeId: 'a'), 0);
  });
}
