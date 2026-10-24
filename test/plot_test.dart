import 'package:flutter_test/flutter_test.dart';
import 'package:medaba/data/storage.dart';
import 'package:medaba/models/plot.dart';
import 'package:medaba/state/app_state.dart';

void main() {
  final bought = DateTime(2026, 1, 10);

  Plot plot({PlotStatus status = PlotStatus.building, double sale = 0}) => Plot(
    id: 'p',
    name: 'قطعة 5',
    location: 'تفرغ زينة',
    area: 300,
    purchaseDate: bought,
    purchasePrice: 1000,
    costs: [PlotCost('أسمنت', 300, bought), PlotCost('عمال', 200, bought)],
    status: status,
    salePrice: sale,
    saleDate: status == PlotStatus.sold ? DateTime(2026, 6, 1) : null,
  );

  test('total cost and profit', () {
    expect(plot().costsTotal, 500);
    expect(plot().totalCost, 1500);
    expect(plot().profit, isNull);
    expect(plot(status: PlotStatus.sold, sale: 2000).profit, 500);
    expect(plot(status: PlotStatus.sold, sale: 1200).profit, -300);
  });

  test('plots survive saving and loading', () async {
    final storage = MemoryStorage();
    final a = AppState(storage);
    await a.load();
    await a.savePlot(plot());
    await a.addPlotCost('p', PlotCost('كهرباء', 100, bought));

    final b = AppState(storage);
    await b.load();
    final x = b.plotById('p')!;
    expect(x.costs.map((c) => c.label), ['أسمنت', 'عمال', 'كهرباء']);
    expect(x.totalCost, 1600);
    expect(x.area, 300);
    expect(AppState.storageKeys, contains('plots'));
  });

  test('a plot cannot be sold before it was bought', () async {
    final a = AppState(MemoryStorage());
    await a.load();
    final bad = Plot.fromJson({
      ...plot(status: PlotStatus.sold, sale: 2000).toJson(),
      'saleDate': DateTime(2025, 1, 1).toIso8601String(),
    });
    expect(() => a.savePlot(bad), throwsStateError);
  });
}
