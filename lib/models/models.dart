/// نماذج البيانات الأساسية للتطبيق: الشركاء، العمال، والمعاملات المالية.
library;

String newId() => '${DateTime.now().microsecondsSinceEpoch}${_counter++}';
int _counter = 0;

DateTime parseDate(Object? v) =>
    v is String ? DateTime.parse(v) : DateTime.now();

/// أين يستثمر الشريك: في الشركة كلها، أو في صفقة واحدة محددة.
enum PartnerScope {
  company('الشركة كلها'),
  car('سيارة'),
  plot('قطعة أرضية'),
  warehouse('مخزن'),
  container('حاوية'),
  other('صفقة أخرى');

  final String label;
  const PartnerScope(this.label);

  /// الصفقة مختارة من السيارات أو القطع المسجلة (وليست نصاً يكتبه المدير).
  bool get linked => this == car || this == plot || this == warehouse;
}

/// شريك في المشروع يملك نسبة من الأرباح ويساهم برأس مال.
///
/// شريك الشركة يأخذ نسبته من صافي ربح الشركة كلها. أما المستثمر في صفقة
/// محددة (سيارة، قطعة أرضية، حاوية...) فيأخذ نسبته من ربح تلك الصفقة فقط.
class Partner {
  final String id;
  final String name;
  final String phone;

  /// نسبة الشريك من الأرباح (0 - 100): من أرباح الشركة أو من ربح صفقته.
  final double sharePercent;

  /// رأس المال، أو المبلغ المستثمر في الصفقة.
  final double capital;
  final DateTime joinedAt;
  final String notes;

  final PartnerScope scope;

  /// السيارة أو القطعة المرتبطة (عند [PartnerScope.linked]).
  final String? dealId;

  /// وصف الصفقة للحاوية والصفقات الأخرى (رقم الحاوية، البضاعة...).
  final String dealTitle;

  /// ربح الحاوية أو الصفقة الأخرى بعد انتهائها، يكتبه المدير.
  /// (ربح السيارة والقطعة يُحسب تلقائياً عند بيعها.)
  final double? dealProfit;

  const Partner({
    required this.id,
    required this.name,
    this.phone = '',
    required this.sharePercent,
    this.capital = 0,
    required this.joinedAt,
    this.notes = '',
    this.scope = PartnerScope.company,
    this.dealId,
    this.dealTitle = '',
    this.dealProfit,
  });

  bool get isCompanyPartner => scope == PartnerScope.company;

  /// مفتاح الصفقة: المستثمرون بنفس المفتاح يتقاسمون نفس الربح.
  String get dealKey =>
      '${scope.name}:${scope.linked || dealId != null ? dealId : dealTitle.trim()}';

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'sharePercent': sharePercent,
    'capital': capital,
    'joinedAt': joinedAt.toIso8601String(),
    'notes': notes,
    'scope': scope.name,
    'dealId': dealId,
    'dealTitle': dealTitle,
    'dealProfit': dealProfit,
  };

  factory Partner.fromJson(Map<String, dynamic> j) => Partner(
    id: j['id'] as String,
    name: j['name'] as String,
    phone: j['phone'] as String? ?? '',
    sharePercent: (j['sharePercent'] as num).toDouble(),
    capital: (j['capital'] as num?)?.toDouble() ?? 0,
    joinedAt: parseDate(j['joinedAt']),
    notes: j['notes'] as String? ?? '',
    scope: PartnerScope.values.asNameMap()[j['scope']] ?? PartnerScope.company,
    dealId: j['dealId'] as String?,
    dealTitle: j['dealTitle'] as String? ?? '',
    dealProfit: (j['dealProfit'] as num?)?.toDouble(),
  );
}

/// عامل/موظف براتب شهري.
/// عمل متفق عليه مع عامل بالمقاولة، مثل بناء منزل: مبلغ كلي يُدفع
/// على مراحل كلما انتهت مرحلة، حتى يكتمل.
class WorkJob {
  final String id;
  final String title;

  /// المبلغ الكلي المتفق عليه.
  final double agreed;
  final DateTime start;

  /// مكان العمل: plot أو car أو other، ومعرّف القطعة أو السيارة.
  /// ما يُدفع للمراحل يُضاف لتكاليف القطعة أو السيارة.
  final String place;
  final String? refId;
  final String notes;

  const WorkJob({
    required this.id,
    required this.title,
    required this.agreed,
    required this.start,
    this.place = 'other',
    this.refId,
    this.notes = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'agreed': agreed,
    'start': start.toIso8601String(),
    'place': place,
    'refId': refId,
    'notes': notes,
  };

  factory WorkJob.fromJson(Map<String, dynamic> j) => WorkJob(
    id: j['id'] as String,
    title: j['title'] as String? ?? '',
    agreed: (j['agreed'] as num?)?.toDouble() ?? 0,
    start: parseDate(j['start']),
    place: j['place'] as String? ?? 'other',
    refId: j['refId'] as String?,
    notes: j['notes'] as String? ?? '',
  );
}

class Worker {
  final String id;
  final String name;
  final String phone;

  /// دور العامل في العمل (الوظيفة).
  final String jobTitle;

  /// الرقم الوطني (NNI) كما في بطاقة التعريف.
  final String nationalId;

  /// صورة العامل JPEG بترميز base64، أو null.
  final String? photo;

  /// الأجر: راتب الشهر، أو أجرة اليوم للعامل اليومي ([daily]).
  final double monthlySalary;
  final DateTime hiredAt;
  final bool active;

  /// عامل باليومية (مثل عمال تفريغ الحاويات) بدل الراتب الشهري.
  final bool daily;

  /// عامل بالمقاولة: يُدفع له على مراحل [jobs] بدل الراتب أو اليومية.
  final bool contract;

  /// أعمال عامل المقاولة.
  final List<WorkJob> jobs;

  const Worker({
    required this.id,
    required this.name,
    this.phone = '',
    this.jobTitle = '',
    this.nationalId = '',
    this.photo,
    required this.monthlySalary,
    required this.hiredAt,
    this.active = true,
    this.daily = false,
    this.contract = false,
    this.jobs = const [],
  });

  /// «الراتب الشهري» أو «الأجرة اليومية».
  String get wageLabel => contract
      ? 'مقاولة (حسب الإنجاز)'
      : daily
      ? 'الأجرة اليومية'
      : 'الراتب الشهري';

  /// نوع الأجر كما يظهر للمستخدم.
  String get payKind => contract
      ? 'مقاولة'
      : daily
      ? 'يومية'
      : 'راتب شهري';

  WorkJob? jobById(String id) => jobs.where((j) => j.id == id).firstOrNull;

  Worker withJobs(List<WorkJob> jobs) => Worker.fromJson({
    ...toJson(),
    'jobs': [for (final j in jobs) j.toJson()],
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'jobTitle': jobTitle,
    'nationalId': nationalId,
    'photo': photo,
    'monthlySalary': monthlySalary,
    'hiredAt': hiredAt.toIso8601String(),
    'active': active,
    'daily': daily,
    if (contract) 'contract': true,
    if (jobs.isNotEmpty) 'jobs': [for (final j in jobs) j.toJson()],
  };

  /// نسخة بصورة جديدة (أو بدون صورة).
  Worker withPhoto(String? photo) => Worker(
    id: id,
    name: name,
    phone: phone,
    jobTitle: jobTitle,
    nationalId: nationalId,
    photo: photo,
    monthlySalary: monthlySalary,
    hiredAt: hiredAt,
    active: active,
    daily: daily,
    contract: contract,
    jobs: jobs,
  );

  factory Worker.fromJson(Map<String, dynamic> j) => Worker(
    id: j['id'] as String,
    name: j['name'] as String,
    phone: j['phone'] as String? ?? '',
    jobTitle: j['jobTitle'] as String? ?? '',
    nationalId: j['nationalId'] as String? ?? '',
    photo: j['photo'] as String?,
    monthlySalary: (j['monthlySalary'] as num).toDouble(),
    hiredAt: parseDate(j['hiredAt']),
    active: j['active'] as bool? ?? true,
    daily: j['daily'] as bool? ?? false,
    contract: j['contract'] as bool? ?? false,
    jobs: [
      for (final x in j['jobs'] as List? ?? const [])
        WorkJob.fromJson(Map<String, dynamic>.from(x as Map)),
    ],
  );
}

enum TxType {
  income('إيراد'),
  expense('مصروف');

  final String label;
  const TxType(this.label);
}

/// تصنيفات المعاملات. المسحوبات لا تدخل في حساب الربح لأنها توزيع وليست مصروفاً تشغيلياً.
enum TxCategory {
  sales('مبيعات', TxType.income),
  otherIncome('إيراد آخر', TxType.income),
  salary('رواتب', TxType.expense),
  rent('إيجار', TxType.expense),
  supplies('مشتريات ومواد', TxType.expense),
  utilities('فواتير وخدمات', TxType.expense),
  otherExpense('مصروف آخر', TxType.expense),
  withdrawal('مسحوبات شريك', TxType.expense);

  final String label;
  final TxType type;
  const TxCategory(this.label, this.type);

  bool get affectsProfit => this != TxCategory.withdrawal;

  static List<TxCategory> forType(TxType t) =>
      values.where((c) => c.type == t).toList();
}

/// معاملة مالية (إيراد أو مصروف)، يمكن ربطها بعامل أو شريك.
class Transaction {
  final String id;
  final TxCategory category;
  final double amount;
  final DateTime date;
  final String note;

  /// معرّف الشخص المرتبط (عامل/شريك) إن وجد.
  final String? personId;

  /// ما تخصه المعاملة: مخزن أو حاوية (مثل أجور عمال التفريغ).
  final String? refId;

  const Transaction({
    required this.id,
    required this.category,
    required this.amount,
    required this.date,
    this.note = '',
    this.personId,
    this.refId,
  });

  TxType get type => category.type;

  Map<String, dynamic> toJson() => {
    'id': id,
    'category': category.name,
    'amount': amount,
    'date': date.toIso8601String(),
    'note': note,
    'personId': personId,
    if (refId != null) 'refId': refId,
  };

  factory Transaction.fromJson(Map<String, dynamic> j) => Transaction(
    id: j['id'] as String,
    category: TxCategory.values.byName(j['category'] as String),
    amount: (j['amount'] as num).toDouble(),
    date: parseDate(j['date']),
    note: j['note'] as String? ?? '',
    personId: j['personId'] as String?,
    refId: j['refId'] as String?,
  );
}
