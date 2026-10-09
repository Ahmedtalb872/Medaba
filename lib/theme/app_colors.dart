import 'package:flutter/material.dart';

/// لوحة ألوان التطبيق، مستوحاة من علم موريتانيا: أخضر عميق وذهبي وأحمر
/// على خلفية بلون الرمل. كل مؤشر له لونان (فاتح، داكن).
abstract final class AppColors {
  static const seed = Color(0xFF0B6E4F);
  static const gold = Color(0xFFE0A526);
  static const lightBackground = Color(0xFFF6F2E9);
  static const darkBackground = Color(0xFF0C1713);

  static const income = [Color(0xFF2FB37E), Color(0xFF0B6E4F)];
  static const expense = [Color(0xFFE5484D), Color(0xFFB4232A)];
  static const profit = [Color(0xFFF2C14E), Color(0xFFB7791F)];
  static const loss = [Color(0xFFE5484D), Color(0xFF8E1B1F)];
  static const cash = [Color(0xFF2BA3A0), Color(0xFF136F6C)];
  static const capital = [Color(0xFF4F7FC4), Color(0xFF274C86)];
  static const people = [Color(0xFF9A7BD1), Color(0xFF5B3E96)];
  static const workers = [Color(0xFFF08A3C), Color(0xFFB45309)];
  static const payroll = [Color(0xFFC08457), Color(0xFF7C4A24)];
  static const stock = [Color(0xFF7FA650), Color(0xFF4A6B26)];
  static const ok = [Color(0xFF2FB37E), Color(0xFF0B6E4F)];

  /// الأخضر الداكن للهوية: أزرار رئيسية ورؤوس الجداول.
  static const brand = Color(0xFF0B4D38);
  static const brandLight = Color(0xFFD5EBDF);

  /// القائمة الجانبية: خضراء داكنة بنص أبيض، والخيار المحدد بلون ذهبي.
  static const navBackground = Color(0xFF0A3B2C);
  static const navBackgroundEnd = Color(0xFF0E4B39);
  static const navBorder = Color(0xFF0A3B2C);
  static const navText = Color(0xFFFFFFFF);
  static const navMuted = Color(0xFFC3D5CD);
  static const navSelected = Color(0x26FFFFFF);
  static const navAccent = Color(0xFFF2C14E);

  /// الشريط العلوي على الجوال وعناصر داكنة أخرى.
  static const sidebar = [Color(0xFF07291F), Color(0xFF0B4D38)];

  /// ألوان متتالية لتمييز الأشخاص في أشرطة التوزيع.
  static const series = [
    Color(0xFF0B6E4F),
    Color(0xFFE0A526),
    Color(0xFFB4232A),
    Color(0xFF136F6C),
    Color(0xFF5B3E96),
    Color(0xFFB45309),
    Color(0xFF274C86),
  ];

  static Color seriesAt(int i) => series[i % series.length];

  static LinearGradient gradient(List<Color> c) => LinearGradient(
    colors: c,
    begin: AlignmentDirectional.topStart,
    end: AlignmentDirectional.bottomEnd,
  );
}
