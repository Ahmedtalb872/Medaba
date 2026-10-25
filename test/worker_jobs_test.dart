import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medaba/data/storage.dart';
import 'package:medaba/main.dart';
import 'package:medaba/models/models.dart';
import 'package:medaba/models/plot.dart';
import 'package:medaba/pdf/job_invoice_pdf.dart';
import 'package:medaba/state/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppState s;
  final d = DateTime(2026, 10, 1);

  setUp(() async {
    s = AppState(MemoryStorage());
    await s.load();
    for (final w in [...s.workers]) {
      await s.deleteWorker(w.id);
    }
    await s.savePlot(
      Plot(
        id: 'p',
        name: 'منزل تفرغ زينة',
        location: 'تفرغ زينة',
        area: 300,
        purchaseDate: d,
        purchasePrice: 1000000,
        costs: const [],
        status: PlotStatus.building,
      ),
    );
    await s.saveWorker(
      Worker(
        id: 'w',
        name: 'الشيخ',
        monthlySalary: 0,
        hiredAt: d,
        contract: true,
      ),
    );
  });

  Worker worker() => s.workers.firstWhere((w) => w.id == 'w');

  test('a contract job is paid stage by stage until the amount ends', () async {
    final job = WorkJob(
      id: 'j',
      title: 'بناء منزل',
      agreed: 500000,
      start: d,
      place: 'plot',
      refId: 'p',
    );
    await s.saveJob('w', job);
    expect(Worker.fromJson(worker().toJson()).jobs.single.agreed, 500000);
    expect(s.monthlyPayroll, 0);

    await s.payJobStage(
      worker(),
      job,
      stage: 'الأساس',
      amount: 200000,
      date: d,
    );
    await s.payJobStage(
      worker(),
      job,
      stage: 'الجدران',
      amount: 150000,
      date: d.add(const Duration(days: 20)),
    );
    expect(s.jobPaid('j'), 350000);
    expect(s.jobLeft(job), 150000);
    expect(s.workerJobsLeft(worker()), 150000);
    // يُضاف لتكاليف القطعة، ويظهر في مصاريف العامل.
    expect(s.plotById('p')!.costsTotal, 350000);
    expect(s.paidToWorker('w'), 350000);

    // لا يُدفع أكثر من الباقي، ولا يقل المتفق عليه عن المدفوع.
    expect(
      () => s.payJobStage(worker(), job, stage: 'x', amount: 200000, date: d),
      throwsStateError,
    );
    expect(
      () => s.saveJob(
        'w',
        WorkJob(id: 'j', title: 'بناء منزل', agreed: 100, start: d),
      ),
      throwsStateError,
    );
    expect(() => s.deleteJob('w', 'j'), throwsStateError);

    // حذف مرحلة يزيلها من تكاليف القطعة أيضاً.
    await s.deleteJobStage(job, s.jobPayments('j').last.id);
    expect(s.jobPaid('j'), 200000);
    expect(s.plotById('p')!.costsTotal, 200000);

    final pdf = await buildJobInvoicePdf(
      worker: worker(),
      job: job,
      company: s.company,
      stages: [(date: d, stage: 'الأساس', amount: 200000)],
    );
    expect(pdf.length, greaterThan(1000));
  });

  testWidgets('a contract worker is added and a stage is paid on a phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(380, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await s.deleteWorker('w');

    await tester.pumpWidget(MedabaApp(state: s));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('العمال').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('إضافة عامل').first);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'الاسم'),
      'الشيخ',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'الدور في العمل'),
      'بنّاء',
    );
    await tester.tap(find.text('مقاولة'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'العمل (مثلاً: بناء منزل)'),
      'بناء منزل',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'المبلغ الكلي المتفق عليه'),
      '500000',
    );
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();
    final w = s.workers.single;
    expect(w.contract, isTrue);
    expect(w.jobs.single.agreed, 500000);

    final jobs = find.byTooltip('الأعمال والمراحل');
    await tester.scrollUntilVisible(
      jobs,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(jobs);
    await tester.pumpAndSettle();
    await tester.tap(find.text('دفع مرحلة منتهية'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(
        TextFormField,
        'المرحلة المنتهية (مثلاً: الأساس، الجدران، السقف)',
      ),
      'الأساس',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'المبلغ المدفوع'),
      '200000',
    );
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();
    expect(s.jobPaid(w.jobs.single.id), 200000);
    expect(find.textContaining('الأساس'), findsOneWidget);
    expect(find.textContaining('الباقي 300,000'), findsOneWidget);
    expect(find.text('فاتورة العمل PDF'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('contract jobs and their invoice show on the workers page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(380, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final job = WorkJob(id: 'j', title: 'بناء منزل', agreed: 500000, start: d);
    await s.saveJob('w', job);
    await s.payJobStage(
      worker(),
      job,
      stage: 'الأساس',
      amount: 200000,
      date: d,
    );

    await tester.pumpWidget(MedabaApp(state: s));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('العمال').last);
    await tester.pumpAndSettle();

    final row = find.text('بناء منزل • الشيخ');
    await tester.scrollUntilVisible(
      row,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('المقاولون وأعمالهم'), findsOneWidget);
    expect(find.textContaining('الباقي 300,000'), findsOneWidget);
    await tester.ensureVisible(find.text('الفاتورة'));
    await tester.pumpAndSettle();
    expect(find.text('دفع مرحلة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
