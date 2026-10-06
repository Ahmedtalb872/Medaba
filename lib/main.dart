import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'data/storage.dart';
import 'screens/home_shell.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState(await PrefsStorage.create());
  await state.load();
  runApp(MedabaApp(state: state));
}

class MedabaApp extends StatelessWidget {
  final AppState state;
  const MedabaApp({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: state,
      child: MaterialApp(
        title: 'مدبّر - إدارة الأعمال',
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        home: const HomeShell(),
      ),
    );
  }

  ThemeData _theme(Brightness b) => ThemeData(
    useMaterial3: true,
    colorSchemeSeed: const Color(0xFF1E5AA8),
    brightness: b,
    cardTheme: const CardThemeData(margin: EdgeInsets.zero),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
    ),
  );
}
