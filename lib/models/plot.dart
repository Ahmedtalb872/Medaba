/// القطع الأرضية: شراؤها، بناؤها، ثم بيعها.
library;

import 'models.dart';

/// مراحل القطعة من الشراء حتى البيع.
enum PlotStatus {
  land('أرض فارغة'),
  building('قيد البناء'),
  ready('جاهزة للبيع'),
  sold('مباعة');

  final String label;
  const PlotStatus(this.label);
}

/// تكلفة على القطعة بعد شرائها (مواد بناء، عمال، رسوم، توصيل كهرباء...).
class PlotCost {
  final String label;
  final double amount;
  final DateTime date;
  const PlotCost(this.label, this.amount, this.date);

  Map<String, dynamic> toJson() => {
    'label': label,
    'amount': amount,
    'date': date.toIso8601String(),
  };

  factory PlotCost.fromJson(Map<String, dynamic> j) => PlotCost(
    j['label'] as String? ?? '',
    (j['amount'] as num? ?? 0).toDouble(),
    parseDate(j['date']),
  );
}

class Plot {
  final String id;

  /// اسم أو رقم القطعة كما في الوثائق.
  final String name;

  /// المقاطعة / الحي.
  final String location;

  /// المساحة بالمتر المربع (0 إذا لم تُحدد).
  final double area;
  final DateTime purchaseDate;
  final double purchasePrice;
  final List<PlotCost> costs;
  final PlotStatus status;
  final String buyer;
  final double salePrice;
  final DateTime? saleDate;
  final String note;

  const Plot({
    required this.id,
    required this.name,
    this.location = '',
    this.area = 0,
    required this.purchaseDate,
    this.purchasePrice = 0,
    this.costs = const [],
    this.status = PlotStatus.land,
    this.buyer = '',
    this.salePrice = 0,
    this.saleDate,
    this.note = '',
  });

  bool get isSold => status == PlotStatus.sold;

  /// مجموع تكاليف البناء والرسوم بعد الشراء.
  double get costsTotal => costs.fold(0, (t, c) => t + c.amount);

  /// كل ما دُفع في القطعة: سعر الشراء + التكاليف.
  double get totalCost => purchasePrice + costsTotal;

  /// الربح (أو الخسارة) بعد البيع، و null قبله.
  double? get profit => isSold ? salePrice - totalCost : null;

  Plot copyWith({List<PlotCost>? costs}) => Plot(
    id: id,
    name: name,
    location: location,
    area: area,
    purchaseDate: purchaseDate,
    purchasePrice: purchasePrice,
    costs: costs ?? this.costs,
    status: status,
    buyer: buyer,
    salePrice: salePrice,
    saleDate: saleDate,
    note: note,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'location': location,
    'area': area,
    'purchaseDate': purchaseDate.toIso8601String(),
    'purchasePrice': purchasePrice,
    'costs': [for (final c in costs) c.toJson()],
    'status': status.name,
    'buyer': buyer,
    'salePrice': salePrice,
    'saleDate': saleDate?.toIso8601String(),
    'note': note,
  };

  factory Plot.fromJson(Map<String, dynamic> j) => Plot(
    id: j['id'] as String,
    name: j['name'] as String? ?? '',
    location: j['location'] as String? ?? '',
    area: (j['area'] as num? ?? 0).toDouble(),
    purchaseDate: parseDate(j['purchaseDate']),
    purchasePrice: (j['purchasePrice'] as num? ?? 0).toDouble(),
    costs: [
      for (final c in (j['costs'] as List? ?? const []))
        PlotCost.fromJson(Map<String, dynamic>.from(c as Map)),
    ],
    status: PlotStatus.values.asNameMap()[j['status']] ?? PlotStatus.land,
    buyer: j['buyer'] as String? ?? '',
    salePrice: (j['salePrice'] as num? ?? 0).toDouble(),
    saleDate: j['saleDate'] == null ? null : parseDate(j['saleDate']),
    note: j['note'] as String? ?? '',
  );
}
