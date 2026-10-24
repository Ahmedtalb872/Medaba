import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medaba/data/storage.dart';
import 'package:medaba/main.dart';
import 'package:medaba/models/debt.dart';
import 'package:medaba/state/app_state.dart';

void main() {
  final d = DateTime(2026, 3, 10);

  Debt debt(
    String id, {
    DebtDirection dir = DebtDirection.theyOwe,
    double amount = 1000,
    DateTime? due,
    List<DebtPayment> payments = const [],
  }) => Debt(
    id: id,
    direction: dir,
    personName: 'P$id',
    amount: amount,
    date: d,
    dueDate: due,
    payments: payments,
  );

  test('remaining, settled and overdue', () {
    final x = debt(
      'a',
      due: DateTime(2026, 4, 1),
      payments: [DebtPayment(amount: 400, date: d)],
    );
    expect(x.paid, 400);
    expect(x.remaining, 600);
    expect(x.isSettled, isFalse);
    expect(x.isOverdue(DateTime(2026, 4, 1)), isFalse);
    expect(x.isOverdue(DateTime(2026, 4, 2)), isTrue);

    final done = x.copyWith(
      payments: [
        ...x.payments,
        DebtPayment(amount: 600, date: d),
      ],
    );
    expect(done.isSettled, isTrue);
    expect(done.isOverdue(DateTime(2027)), isFalse);
    expect(debt('b').isOverdue(DateTime(2030)), isFalse);
  });

  test('payments, totals, validation and persistence', () async {
    final storage = MemoryStorage();
    final s = AppState(storage);
    await s.load();
    await s.saveDebt(debt('a', amount: 1000));
    await s.saveDebt(debt('b', dir: DebtDirection.weOwe, amount: 300));

    await s.addDebtPayment('a', DebtPayment(amount: 250, date: d));
    expect(s.debtsRemaining(DebtDirection.theyOwe), 750);
    expect(s.debtsRemaining(DebtDirection.weOwe), 300);

    expect(
      () => s.addDebtPayment('a', DebtPayment(amount: 800, date: d)),
      throwsStateError,
    );
    // لا يمكن تخفيض مبلغ الدين تحت ما سُدِّد منه.
    expect(
      () => s.saveDebt(
        debt('a', amount: 100, payments: s.debtById('a')!.payments),
      ),
      throwsStateError,
    );

    final reloaded = AppState(storage);
    await reloaded.load();
    expect(reloaded.debtById('a')!.payments.single.amount, 250);
    expect(reloaded.debtById('b')!.direction, DebtDirection.weOwe);

    await reloaded.deleteDebt('b');
    expect(reloaded.debts.length, 1);
  });

  testWidgets('record a payment from the debts screen', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final state = AppState(MemoryStorage());
    await state.load();
    await state.saveDebt(debt('a', amount: 1000));
    await tester.pumpWidget(MedabaApp(state: state));
    await tester.pumpAndSettle();

    await tester.tap(find.text('الديون').first);
    await tester.pumpAndSettle();
    // الجدول قابل للتمرير أفقياً؛ نمرّره حتى يظهر زر التسديد.
    await tester.ensureVisible(find.byTooltip('تسجيل تسديد'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('تسجيل تسديد'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'المبلغ المسدَّد'),
      '400',
    );
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(state.debtById('a')!.remaining, 600);
    expect(find.text('مسدَّد جزئياً'), findsOneWidget);
  });
}
