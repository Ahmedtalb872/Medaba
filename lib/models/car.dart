/// السيارات: تُشترى من الخارج، تُشحن إلى موريتانيا، تُعرض ثم تُباع.
library;

import 'models.dart';

/// مراحل السيارة من الشراء حتى البيع.
enum CarStatus {
  purchased('مشتراة - لم تُشحن'),
  atSea('في البحر'),
  atPort('في الميناء والجمارك'),
  inStock('في المعرض'),
  sold('مباعة');

  final String label;
  const CarStatus(this.label);

  /// ما زالت في الطريق (قبل وصولها إلى المعرض).
  bool get onTheWay => index < CarStatus.inStock.index;
}

/// مصروف على السيارة بعد شرائها (شحن، جمارك، تخليص، نقل، تصليح...).
class CarCost {
  final String label;
  final double amount;
  final DateTime date;
  const CarCost(this.label, this.amount, this.date);

  /// أسماء المصاريف الشائعة، تظهر كأزرار عند الإضافة.
  static const common = [
    'الشحن',
    'الجمارك',
    'التخليص',
    'النقل من الميناء',
    'التسجيل والترقيم',
    'التأمين',
    'تصليح',
    'غسيل وتجهيز',
  ];

  Map<String, dynamic> toJson() => {
    'label': label,
    'amount': amount,
    'date': date.toIso8601String(),
  };

  factory CarCost.fromJson(Map<String, dynamic> j) => CarCost(
    j['label'] as String? ?? '',
    (j['amount'] as num? ?? 0).toDouble(),
    parseDate(j['date']),
  );
}

class Car {
  final String id;
  final String make;
  final String model;
  final int? year;
  final String color;

  /// رقم الشاسيه (VIN).
  final String vin;

  /// رقم اللوحة بعد الترقيم في موريتانيا.
  final String plate;

  /// صورة السيارة JPEG بترميز base64، أو null.
  final String? photo;

  // الشراء والشحن
  final DateTime purchaseDate;
  final double purchasePrice;

  /// البلد أو الميناء الذي شُحنت منه.
  final String origin;
  final String shippingCompany;

  /// رقم الحاوية أو البوليصة.
  final String container;
  final DateTime? shippedDate;

  /// الوصول المتوقع (أو الفعلي بعد الوصول).
  final DateTime? arrivalDate;

  final List<CarCost> costs;
  final CarStatus status;

  // البيع
  final String buyer;
  final String buyerPhone;
  final double salePrice;
  final DateTime? saleDate;
  final String note;

  const Car({
    required this.id,
    required this.make,
    this.model = '',
    this.year,
    this.color = '',
    this.vin = '',
    this.plate = '',
    this.photo,
    required this.purchaseDate,
    this.purchasePrice = 0,
    this.origin = '',
    this.shippingCompany = '',
    this.container = '',
    this.shippedDate,
    this.arrivalDate,
    this.costs = const [],
    this.status = CarStatus.purchased,
    this.buyer = '',
    this.buyerPhone = '',
    this.salePrice = 0,
    this.saleDate,
    this.note = '',
  });

  /// «تويوتا هايلكس 2019».
  String get title => [
    make,
    model,
    if (year != null) '$year',
  ].where((s) => s.isNotEmpty).join(' ');

  bool get isSold => status == CarStatus.sold;

  double get costsTotal => costs.fold(0, (t, c) => t + c.amount);

  /// كل ما دُفع في السيارة: سعر الشراء + المصاريف.
  double get totalCost => purchasePrice + costsTotal;

  /// الربح (أو الخسارة) بعد البيع، و null قبله.
  double? get profit => isSold ? salePrice - totalCost : null;

  /// متأخرة: ما زالت في البحر بعد تاريخ الوصول المتوقع.
  bool isLate(DateTime now) {
    final a = arrivalDate;
    return status == CarStatus.atSea &&
        a != null &&
        DateTime(now.year, now.month, now.day).isAfter(a);
  }

  /// أيام حتى الوصول المتوقع (سالب إذا فات)، أو null بدون تاريخ.
  int? daysToArrival(DateTime now) {
    final a = arrivalDate;
    if (a == null) return null;
    return DateTime(
      a.year,
      a.month,
      a.day,
    ).difference(DateTime(now.year, now.month, now.day)).inDays;
  }

  Car copyWith({
    List<CarCost>? costs,
    String? photo,
    bool clearPhoto = false,
  }) => Car.fromJson({
    ...toJson(),
    if (costs != null) 'costs': [for (final c in costs) c.toJson()],
    'photo': ?photo,
    if (clearPhoto) 'photo': null,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'make': make,
    'model': model,
    'year': year,
    'color': color,
    'vin': vin,
    'plate': plate,
    'photo': photo,
    'purchaseDate': purchaseDate.toIso8601String(),
    'purchasePrice': purchasePrice,
    'origin': origin,
    'shippingCompany': shippingCompany,
    'container': container,
    'shippedDate': shippedDate?.toIso8601String(),
    'arrivalDate': arrivalDate?.toIso8601String(),
    'costs': [for (final c in costs) c.toJson()],
    'status': status.name,
    'buyer': buyer,
    'buyerPhone': buyerPhone,
    'salePrice': salePrice,
    'saleDate': saleDate?.toIso8601String(),
    'note': note,
  };

  factory Car.fromJson(Map<String, dynamic> j) {
    DateTime? date(Object? v) => v == null ? null : parseDate(v);
    return Car(
      id: j['id'] as String,
      make: j['make'] as String? ?? '',
      model: j['model'] as String? ?? '',
      year: (j['year'] as num?)?.toInt(),
      color: j['color'] as String? ?? '',
      vin: j['vin'] as String? ?? '',
      plate: j['plate'] as String? ?? '',
      photo: j['photo'] as String?,
      purchaseDate: parseDate(j['purchaseDate']),
      purchasePrice: (j['purchasePrice'] as num? ?? 0).toDouble(),
      origin: j['origin'] as String? ?? '',
      shippingCompany: j['shippingCompany'] as String? ?? '',
      container: j['container'] as String? ?? '',
      shippedDate: date(j['shippedDate']),
      arrivalDate: date(j['arrivalDate']),
      costs: [
        for (final c in (j['costs'] as List? ?? const []))
          CarCost.fromJson(Map<String, dynamic>.from(c as Map)),
      ],
      status: CarStatus.values.asNameMap()[j['status']] ?? CarStatus.purchased,
      buyer: j['buyer'] as String? ?? '',
      buyerPhone: j['buyerPhone'] as String? ?? '',
      salePrice: (j['salePrice'] as num? ?? 0).toDouble(),
      saleDate: date(j['saleDate']),
      note: j['note'] as String? ?? '',
    );
  }
}
