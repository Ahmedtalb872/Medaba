/// الشحنات البحرية الواردة عبر شركات الشحن.
library;

import 'models.dart';

/// مراحل الشحنة من الإبحار حتى الاستلام في المخزن.
enum ShipmentStatus {
  atSea('في البحر'),
  atPort('وصلت الميناء'),
  customs('في الجمارك'),
  received('تم الاستلام');

  final String label;
  const ShipmentStatus(this.label);

  /// المرحلة التالية، أو null إذا كانت الشحنة مستلمة.
  ShipmentStatus? get next =>
      index + 1 < values.length ? values[index + 1] : null;
}

/// شحنة بحرية واحدة (حاوية أو أكثر ببوليصة شحن واحدة).
class Shipment {
  final String id;

  /// شركة الشحن البحري.
  final String company;

  /// رقم بوليصة الشحن (Bill of Lading).
  final String billOfLading;
  final String containerNumber;

  /// وصف البضاعة.
  final String contents;
  final String originPort;
  final String destinationPort;
  final DateTime departureDate;

  /// تاريخ الوصول المتوقع إلى الميناء.
  final DateTime expectedArrival;

  /// تاريخ الاستلام الفعلي (عند اكتمال الشحنة).
  final DateTime? receivedDate;
  final ShipmentStatus status;
  final double goodsValue;
  final double freightCost;

  /// رسوم الجمارك والتخليص والنقل من الميناء.
  final double customsCost;
  final String note;

  const Shipment({
    required this.id,
    required this.company,
    this.billOfLading = '',
    this.containerNumber = '',
    required this.contents,
    this.originPort = '',
    this.destinationPort = 'نواكشوط',
    required this.departureDate,
    required this.expectedArrival,
    this.receivedDate,
    this.status = ShipmentStatus.atSea,
    this.goodsValue = 0,
    this.freightCost = 0,
    this.customsCost = 0,
    this.note = '',
  });

  /// التكلفة الكاملة: قيمة البضاعة + الشحن + الجمارك.
  double get totalCost => goodsValue + freightCost + customsCost;

  bool get isReceived => status == ShipmentStatus.received;

  /// متأخرة: ما زالت في البحر بعد تاريخ الوصول المتوقع.
  bool isDelayed(DateTime now) =>
      status == ShipmentStatus.atSea &&
      DateTime(now.year, now.month, now.day).isAfter(expectedArrival);

  /// عدد الأيام حتى الوصول المتوقع (سالب إذا فات).
  int daysToArrival(DateTime now) => DateTime(
    expectedArrival.year,
    expectedArrival.month,
    expectedArrival.day,
  ).difference(DateTime(now.year, now.month, now.day)).inDays;

  Map<String, dynamic> toJson() => {
    'id': id,
    'company': company,
    'billOfLading': billOfLading,
    'containerNumber': containerNumber,
    'contents': contents,
    'originPort': originPort,
    'destinationPort': destinationPort,
    'departureDate': departureDate.toIso8601String(),
    'expectedArrival': expectedArrival.toIso8601String(),
    'receivedDate': receivedDate?.toIso8601String(),
    'status': status.name,
    'goodsValue': goodsValue,
    'freightCost': freightCost,
    'customsCost': customsCost,
    'note': note,
  };

  factory Shipment.fromJson(Map<String, dynamic> j) => Shipment(
    id: j['id'] as String,
    company: j['company'] as String,
    billOfLading: j['billOfLading'] as String? ?? '',
    containerNumber: j['containerNumber'] as String? ?? '',
    contents: j['contents'] as String? ?? '',
    originPort: j['originPort'] as String? ?? '',
    destinationPort: j['destinationPort'] as String? ?? '',
    departureDate: parseDate(j['departureDate']),
    expectedArrival: parseDate(j['expectedArrival']),
    receivedDate: j['receivedDate'] == null
        ? null
        : parseDate(j['receivedDate']),
    status: ShipmentStatus.values.byName(j['status'] as String),
    goodsValue: (j['goodsValue'] as num? ?? 0).toDouble(),
    freightCost: (j['freightCost'] as num? ?? 0).toDouble(),
    customsCost: (j['customsCost'] as num? ?? 0).toDouble(),
    note: j['note'] as String? ?? '',
  );
}
