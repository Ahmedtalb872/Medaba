import 'package:flutter/widgets.dart';

/// يسمح للصفحات بالانتقال إلى صفحة أخرى في الهيكل الرئيسي (مثل «عرض الكل»).
class ShellNav extends InheritedWidget {
  final ValueChanged<int> go;
  const ShellNav({super.key, required this.go, required super.child});

  static ShellNav? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellNav>();

  @override
  bool updateShouldNotify(ShellNav old) => false;
}

/// أرقام صفحات الهيكل الرئيسي بنفس ترتيب القائمة الجانبية.
abstract final class ShellPage {
  static const home = 0;
  static const partners = 1;
  static const workers = 2;
  static const inventory = 3;
  static const invoices = 4;
  static const debts = 5;
  static const shipments = 6;
  static const transactions = 7;
  static const profits = 8;
  static const settings = 9;
}
