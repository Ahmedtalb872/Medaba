/// نماذج الديون: ديون لنا عند الزبائن، وديون علينا للموردين وغيرهم.
library;

import 'models.dart';

enum DebtDirection {
  /// شخص يدين لنا (زبون اشترى بالآجل مثلاً).
  theyOwe('لنا', 'المدين'),

  /// نحن ندين لشخص (مورد مثلاً).
  weOwe('علينا', 'الدائن');

  final String label;

  /// اسم الطرف الآخر في النموذج.
  final String partyLabel;
  const DebtDirection(this.label, this.partyLabel);
}

/// دفعة واحدة من تسديد الدين.
class DebtPayment {
  final double amount;
  final DateTime date;
  final String note;

  const DebtPayment({required this.amount, required this.date, this.note = ''});

  Map<String, dynamic> toJson() => {
    'amount': amount,
    'date': date.toIso8601String(),
    'note': note,
  };

  factory DebtPayment.fromJson(Map<String, dynamic> j) => DebtPayment(
    amount: (j['amount'] as num).toDouble(),
    date: parseDate(j['date']),
    note: j['note'] as String? ?? '',
  );
}

/// دين بمبلغ أصلي وتسديدات متتالية.
class Debt {
  final String id;
  final DebtDirection direction;
  final String personName;
  final String phone;
  final double amount;
  final DateTime date;

  /// تاريخ الاستحقاق (اختياري)؛ بعده يُعتبر الدين متأخراً إن لم يُسدَّد.
  final DateTime? dueDate;
  final String note;
  final List<DebtPayment> payments;

  const Debt({
    required this.id,
    required this.direction,
    required this.personName,
    this.phone = '',
    required this.amount,
    required this.date,
    this.dueDate,
    this.note = '',
    this.payments = const [],
  });

  double get paid => payments.fold(0, (s, p) => s + p.amount);
  double get remaining => amount - paid;
  bool get isSettled => remaining <= 0.0001;

  bool isOverdue(DateTime now) {
    final due = dueDate;
    if (due == null || isSettled) return false;
    return DateTime(now.year, now.month, now.day).isAfter(due);
  }

  Debt copyWith({List<DebtPayment>? payments}) => Debt(
    id: id,
    direction: direction,
    personName: personName,
    phone: phone,
    amount: amount,
    date: date,
    dueDate: dueDate,
    note: note,
    payments: payments ?? this.payments,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'direction': direction.name,
    'personName': personName,
    'phone': phone,
    'amount': amount,
    'date': date.toIso8601String(),
    'dueDate': dueDate?.toIso8601String(),
    'note': note,
    'payments': [for (final p in payments) p.toJson()],
  };

  factory Debt.fromJson(Map<String, dynamic> j) => Debt(
    id: j['id'] as String,
    direction: DebtDirection.values.byName(j['direction'] as String),
    personName: j['personName'] as String,
    phone: j['phone'] as String? ?? '',
    amount: (j['amount'] as num).toDouble(),
    date: parseDate(j['date']),
    dueDate: j['dueDate'] == null ? null : parseDate(j['dueDate']),
    note: j['note'] as String? ?? '',
    payments: [
      for (final p in j['payments'] as List? ?? const [])
        DebtPayment.fromJson(p as Map<String, dynamic>),
    ],
  );
}
