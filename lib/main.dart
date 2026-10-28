import 'devotion/quran.dart';
import 'devotion/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/app_core.dart';
import 'screens/home.dart';
import 'devotion/tasbih.dart';
import 'devotion/quran_audio.dart';
export 'core/app_core.dart';
export 'core/search.dart';
export 'screens/home.dart';
export 'screens/editor.dart';
export 'screens/readers.dart';
export 'screens/catalogs.dart';
export 'widgets/rich_editor.dart';
export 'widgets/note_card.dart';
export 'widgets/sacred_text.dart';
export 'widgets/delete_confirmation.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await settings.load();
  } catch (e) {
    debugPrint('Diraasa preferences: $e');
  }
  runApp(const Diraasa());
}

final appNavigatorKey = GlobalKey<NavigatorState>();

class Diraasa extends StatefulWidget {
  const Diraasa({super.key});
  @override
  State<Diraasa> createState() => _DiraasaState();
}

class _DiraasaState extends State<Diraasa> with WidgetsBindingObserver {
  bool checkingLaunch = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Store.channel.setMethodCallHandler((call) async {
      if (call.method == 'quranAudioChanged')
        deliverQuranAudioEvent(call.arguments);
      if (call.method == 'quranAudioOpen') await openQuranAudio();
      if (call.method == 'devotionPending') await openPending();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => openPending());
  }

  bool openingQuranAudio = false;
  Future<void> openQuranAudio() async {
    if (!mounted || openingQuranAudio) return;
    openingQuranAudio = true;
    try {
      final raw = await Store.call('quranAudioLaunch');
      if (raw is! Map ||
          !['playing', 'paused', 'loading'].contains(raw['state']))
        return;
      final chapters = await QuranData.book('hafs');
      final matches = chapters.where((c) => c['number'] == raw['chapter']);
      if (!mounted || matches.isEmpty) return;
      final verse = (raw['verse'] as num?)?.toInt() ?? 1;
      appNavigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => SurahPage(
            reading: 'hafs',
            chapter: matches.first,
            initialVerse: verse > 0 ? verse : 1,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Diraasa Quran audio: $e');
    } finally {
      openingQuranAudio = false;
    }
  }

  Future<void> openPending() async {
    await openQuranAudio();
    if (!mounted || checkingLaunch) return;
    checkingLaunch = true;
    try {
      final value = await Store.call('devotionLaunch');
      if (mounted && value is Map && value['id'] is String) {
        appNavigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => CounterPage(
              id: value['id'] as String,
              chain: value['chain'] == true,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Diraasa reminder: $e');
    } finally {
      checkingLaunch = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) openPending();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    Store.channel.setMethodCallHandler(null);
    super.dispose();
  }

  ThemeData theme(Brightness brightness) => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xff174e40),
      brightness: brightness,
    ),
    scaffoldBackgroundColor: brightness == Brightness.dark
        ? const Color(0xff10231e)
        : const Color(0xfff7f5ef),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: settings,
    builder: (context, _) => MaterialApp(
      navigatorKey: appNavigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Diraasa',
      locale: Locale(settings.language),
      supportedLocales: const [Locale('fr'), Locale('ar'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      themeMode: settings.themeMode,
      home: const Home(),
    ),
  );
}
