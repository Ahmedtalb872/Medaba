import 'package:flutter_test/flutter_test.dart';
import 'package:medaba/data/storage.dart';
import 'package:medaba/models/inventory.dart';
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

  test('net profit is split between partners by share', () async {
    await s.savePartner(
      Partner(id: 'a', name: 'A', sharePercent: 60, joinedAt: d),
    );
    await s.savePartner(
      Partner(id: 'b', name: 'B', sharePercent: 40, joinedAt: d),
    );
    await tx(TxCategory.sales, 10000);
    await tx(TxCategory.rent, 2000);
    // المسحوبات لا تؤثر على الربح.
    await tx(TxCategory.withdrawal, 500, person: 'a');

    final r = s.profitReport(Period.month(d));
    expect(r.netProfit, 8000);
    expect(r.partners.firstWhere((p) => p.id == 'a').amount, 4800);
    expect(r.partners.firstWhere((p) => p.id == 'a').balance, 4300);
    expect(r.partners.firstWhere((p) => p.id == 'b').amount, 3200);
  });

  test('partners carry a loss by share', () async {
    await s.savePartner(
      Partner(id: 'a', name: 'A', sharePercent: 100, joinedAt: d),
    );
    await tx(TxCategory.sales, 1000);
    await tx(TxCategory.rent, 3000);

    expect(s.profitReport(Period.month(d)).partners.single.amount, -2000);
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

  group('inventory', () {
    const w1 = Warehouse(id: 'w1', name: 'Main');
    const w2 = Warehouse(id: 'w2', name: 'Branch');
    const p = Product(
      id: 'p',
      name: 'Cement',
      costPrice: 10,
      salePrice: 15,
      minQty: 20,
    );

    StockMove move(
      MoveType type,
      double qty, {
      String id = '',
      String wh = 'w1',
      String? to,
      double price = 0,
    }) => StockMove(
      id: id.isEmpty ? newId() : id,
      type: type,
      productId: 'p',
      warehouseId: wh,
      toWarehouseId: to,
      qty: qty,
      unitPrice: price,
      date: d,
    );

    setUp(() async {
      await s.saveWarehouse(w1);
      await s.saveWarehouse(w2);
      await s.saveProduct(p);
    });

    test('stock per warehouse follows in, out and transfer', () async {
      await s.saveMove(move(MoveType.stockIn, 100));
      await s.saveMove(move(MoveType.transfer, 30, to: 'w2'));
      await s.saveMove(move(MoveType.stockOut, 5, wh: 'w2'));

      expect(s.stockOf('p', warehouseId: 'w1'), 70);
      expect(s.stockOf('p', warehouseId: 'w2'), 25);
      expect(s.stockOf('p'), 95);
      expect(s.stockValue(), 950);
    });

    test('purchase and sale create linked transactions', () async {
      await s.saveMove(move(MoveType.purchase, 10, id: 'm1', price: 10));
      await s.saveMove(move(MoveType.sale, 4, id: 'm2', price: 15));

      expect(s.totalExpenses(), 100);
      expect(s.totalIncome(), 60);
      final saleTx = s.transactions.firstWhere(
        (t) => t.category == TxCategory.sales,
      );
      expect(s.isLinkedTransaction(saleTx.id), isTrue);

      // تعديل الكمية يحدّث المبلغ، والحذف يحذف المعاملة.
      await s.saveMove(
        move(MoveType.sale, 2, id: 'm2', price: 15).copyWith(txId: saleTx.id),
      );
      expect(s.totalIncome(), 30);
      expect(s.transactions.length, 2);
      await s.deleteMove('m2');
      expect(s.totalIncome(), 0);
      expect(s.transactions.length, 1);
    });

    test('cannot issue more than available', () async {
      await s.saveMove(move(MoveType.stockIn, 10, id: 'in'));
      expect(
        () => s.saveMove(move(MoveType.sale, 11, price: 15)),
        throwsStateError,
      );
      expect(
        () => s.saveMove(move(MoveType.transfer, 1, wh: 'w2', to: 'w1')),
        throwsStateError,
      );
      // تعديل حركة صادرة لا يحسبها مرتين.
      await s.saveMove(move(MoveType.stockOut, 10, id: 'out'));
      await s.saveMove(move(MoveType.stockOut, 10, id: 'out'));
      expect(s.stockOf('p'), 0);
    });

    test('low stock and delete guards', () async {
      await s.saveMove(move(MoveType.stockIn, 20));
      expect(s.lowStockProducts.single.id, 'p');
      expect(await s.deleteProduct('p'), isFalse);
      expect(await s.deleteWarehouse('w1'), isFalse);
      expect(await s.deleteWarehouse('w2'), isTrue);
    });
  });

  test('demo data seeds without errors', () async {
    await s.seedDemoData();
    expect(s.warehouses, isNotEmpty);
    expect(s.lowStockProducts, isNotEmpty);
    for (final p in s.products) {
      for (final w in s.warehouses) {
        expect(s.stockOf(p.id, warehouseId: w.id), greaterThanOrEqualTo(0));
      }
    }
  });
}
