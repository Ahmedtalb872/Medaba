import 'package:flutter/material.dart';

/// لوحة ألوان التطبيق. كل مؤشر له تدرّج لوني خاص به.
abstract final class AppColors {
  static const seed = Color(0xFF4F46E5);
  static const lightBackground = Color(0xFFF4F6FB);
  static const darkBackground = Color(0xFF0F1222);

  static const income = [Color(0xFF34D399), Color(0xFF059669)];
  static const expense = [Color(0xFFFB7185), Color(0xFFE11D48)];
  static const profit = [Color(0xFF818CF8), Color(0xFF6D28D9)];
  static const loss = [Color(0xFFF87171), Color(0xFFB91C1C)];
  static const cash = [Color(0xFF22D3EE), Color(0xFF0E7490)];
  static const capital = [Color(0xFF60A5FA), Color(0xFF1D4ED8)];
  static const people = [Color(0xFFE879F9), Color(0xFF9333EA)];
  static const workers = [Color(0xFFFBBF24), Color(0xFFEA580C)];
  static const payroll = [Color(0xFFF472B6), Color(0xFFBE185D)];

  /// خلفية القائمة الجانبية.
  static const sidebar = [
    Color(0xFF1E1B4B),
    Color(0xFF312E81),
    Color(0xFF4338CA),
  ];

  /// ألوان متتالية لتمييز الأشخاص في أشرطة التوزيع.
  static const series = [
    Color(0xFF8B5CF6),
    Color(0xFF06B6D4),
    Color(0xFFF59E0B),
    Color(0xFFEC4899),
    Color(0xFF10B981),
    Color(0xFF3B82F6),
    Color(0xFFEF4444),
  ];

  static Color seriesAt(int i) => series[i % series.length];

  static LinearGradient gradient(List<Color> c) => LinearGradient(
    colors: c,
    begin: AlignmentDirectional.topStart,
    end: AlignmentDirectional.bottomEnd,
  );
}
