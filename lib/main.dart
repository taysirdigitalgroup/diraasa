import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/app_core.dart';
import 'screens/home.dart';
export 'core/app_core.dart';
export 'core/search.dart';
export 'screens/home.dart';
export 'screens/editor.dart';
export 'screens/readers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try { await settings.load(); } catch (e) { debugPrint('Diraasa preferences: $e'); }
  runApp(const Diraasa());
}
class Diraasa extends StatelessWidget {
  const Diraasa({super.key});
  ThemeData theme(Brightness brightness) => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff174e40), brightness: brightness),
    scaffoldBackgroundColor: brightness == Brightness.dark ? const Color(0xff10231e) : const Color(0xfff7f5ef),
    inputDecorationTheme: InputDecorationTheme(filled: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none)),
  );
  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: settings, builder: (context, _) => MaterialApp(
    debugShowCheckedModeBanner: false, title: 'Diraasa',
    locale: Locale(settings.language),
    supportedLocales: const [Locale('fr'), Locale('ar'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: theme(Brightness.light), darkTheme: theme(Brightness.dark), themeMode: settings.themeMode,
    home: const Home(),
  ));
}
