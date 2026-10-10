import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/cloud.dart';
import 'data/storage.dart';
import 'screens/cloud_gate.dart';
import 'screens/home_shell.dart';
import 'state/app_state.dart';
import 'theme/app_colors.dart';

/// نسخة العرض (`--dart-define=DEMO=true`) تبدأ ببيانات تجريبية عند أول تشغيل.
const _demo = bool.fromEnvironment('DEMO');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (cloudConfigured) {
    // البيانات في قاعدة البيانات: تسجيل الدخول أولاً ثم تحميلها.
    await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey);
    runApp(const CloudGate());
    return;
  }
  final storage = await openLocalStorage();
  final state = AppState(storage);
  await state.load();
  if (_demo && state.partners.isEmpty && state.products.isEmpty) {
    await state.seedDemoData();
  }
  runApp(MedabaApp(state: state));
}

/// تخزين المتصفح أو الجهاز.
Future<Storage> openLocalStorage() async {
  try {
    return await PrefsStorage.create();
  } catch (_) {
    // بعض المتصفحات تمنع التخزين المحلي (نافذة خاصة مثلاً)؛ نعمل في الذاكرة.
    return MemoryStorage();
  }
}

/// إعدادات MaterialApp المشتركة بين التطبيق وشاشة الدخول.
MaterialApp buildMaterialApp({required Widget home}) => MaterialApp(
  title: 'طيبة - إدارة الأعمال',
  debugShowCheckedModeBanner: false,
  locale: const Locale('ar'),
  supportedLocales: const [Locale('ar'), Locale('en')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  theme: _theme(Brightness.light),
  darkTheme: _theme(Brightness.dark),
  // الواجهة فاتحة دائماً (خلفية بلون الرمل) حتى لو كان الجهاز في الوضع الليلي.
  themeMode: ThemeMode.light,
  home: home,
);

class MedabaApp extends StatelessWidget {
  final AppState state;
  const MedabaApp({super.key, required this.state});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider.value(
    value: state,
    child: buildMaterialApp(home: const HomeShell()),
  );
}

ThemeData _theme(Brightness b) {
  final dark = b == Brightness.dark;
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.seed, brightness: b);
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'ReadexPro',
    colorScheme: scheme,
    scaffoldBackgroundColor: dark
        ? AppColors.darkBackground
        : AppColors.lightBackground,
    cardTheme: CardThemeData(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: dark ? scheme.surfaceContainer : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: dark ? null : AppColors.brand,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        side: WidgetStatePropertyAll(BorderSide(color: scheme.outlineVariant)),
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.brand
              : (dark ? scheme.surfaceContainer : Colors.white),
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? Colors.white
              : scheme.onSurface,
        ),
        iconColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? Colors.white
              : scheme.onSurfaceVariant,
        ),
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: dark ? scheme.primary : AppColors.brand,
      indicatorColor: dark ? scheme.primary : AppColors.brand,
      labelStyle: const TextStyle(
        fontFamily: 'ReadexPro',
        fontWeight: FontWeight.bold,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    dataTableTheme: DataTableThemeData(
      headingRowColor: WidgetStatePropertyAll(
        scheme.primaryContainer.withValues(alpha: dark ? 0.35 : 0.55),
      ),
      headingTextStyle: TextStyle(
        fontWeight: FontWeight.bold,
        color: scheme.onPrimaryContainer,
      ),
    ),
  );
}
