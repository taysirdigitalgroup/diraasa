import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diraasa/core/app_core.dart';
import 'package:diraasa/devotion/quran.dart';
import 'package:diraasa/devotion/quran_audio.dart';
import 'package:diraasa/devotion/quran_audio_plan.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('15 modes audio : toutes les permutations sans répétition', () {
    final expected = <String>{'ar', 'fr', 'en'};
    for (final a in ['ar', 'fr', 'en']) {
      for (final b in ['ar', 'fr', 'en']) {
        if (a == b) continue;
        expected.add('$a-$b');
        for (final c in ['ar', 'fr', 'en']) {
          if (c != a && c != b) expected.add('$a-$b-$c');
        }
      }
    }
    expect(quranAudioModes.toSet(), expected);
    expect(quranAudioModes.length, 15);
  });
  setUp(() {
    settings = AppSettings(initialLanguage: 'fr');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(Store.channel, (call) async {
          if (call.method == 'devotionRead') return null;
          return true;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(Store.channel, null),
  );
  test('Noms Hafs et basmalas sans doublon ni basmala pour At-Tawba', () {
    expect(quranAudioFilename(1, 1), '001001.mp3');
    expect(quranAudioFilename(114, 6), '114006.mp3');
    expect(
      quranAudioUri(2, 0, 'fr').toString(),
      endsWith('/quran-hafs-fr/002000.mp3'),
    );
    expect(quranAudioPlaylist(1, [1, 2, 3], 1, continuous: true), [1, 2, 3]);
    expect(quranAudioPlaylist(2, [1, 2, 3], 1, continuous: true), [0, 1, 2, 3]);
    expect(quranAudioPlaylist(9, [1, 2, 3], 1, continuous: true), [1, 2, 3]);
    expect(quranAudioPlaylist(2, [1, 2, 3], 2, continuous: true), [2, 3]);
    expect(quranAudioPlaylist(2, [1, 2, 3], 1, continuous: false), [1]);
    expect(
      quranAudioUri(114, 6, 'en').toString(),
      endsWith('/quran-hafs-en/114006.mp3'),
    );
    expect(() => quranAudioFilename(114, 7), throwsArgumentError);
    expect(() => quranAudioFilename(9, 0), throwsArgumentError);
    expect(() => quranAudioUri(2, 1, 'es'), throwsArgumentError);
  });
  test(
    'Synchronisation du verset natif, pause, reprise, recherche audio et arrêt',
    () async {
      var current = <String, dynamic>{
        'state': 'playing',
        'chapter': 2,
        'verse': 1,
        'position': 0,
        'duration': 5000,
        'error': '',
      };
      final calls = <String>[];
      final audio = QuranAudioController(
        api: (method, args) async {
          calls.add(method);
          if (method == 'quranAudioStart') {
            expect(args!['verses'], [0, 1, 2, 3]);
            current = {...current, 'verse': 0};
          }
          if (method == 'quranAudioPause')
            current = {...current, 'state': 'paused'};
          if (method == 'quranAudioResume')
            current = {...current, 'state': 'playing'};
          if (method == 'quranAudioSeek')
            current = {...current, 'position': args!['position']};
          return current;
        },
      );
      addTearDown(audio.dispose);
      await audio.play(2, [1, 2, 3], 1, all: true);
      expect(audio.verse, 0);
      current = {...current, 'verse': 2};
      await audio.poll();
      expect(audio.verse, 2);
      await audio.toggle();
      expect(audio.state, 'paused');
      await audio.toggle();
      expect(audio.state, 'playing');
      await audio.seek(1500);
      expect(audio.position, 1500);
      await audio.stop();
      expect(audio.active, false);
      expect(
        calls,
        containsAll([
          'quranAudioStart',
          'quranAudioStatus',
          'quranAudioPause',
          'quranAudioResume',
          'quranAudioSeek',
          'quranAudioStop',
        ]),
      );
    },
  );
  test('Événements natifs immédiats, sans retour à un état périmé', () async {
    String session = '';
    final audio = QuranAudioController(
      api: (method, args) async {
        if (method == 'quranAudioStart') session = args!['session'] as String;
        return {
          'state': 'loading',
          'session': session,
          'revision': 1,
          'chapter': 1,
          'verse': 1,
        };
      },
    );
    addTearDown(audio.dispose);
    await audio.play(1, [1, 2], 1, all: true);
    expect(audio.hasPlayback, false);
    deliverQuranAudioEvent({
      'session': session,
      'revision': 3,
      'state': 'playing',
      'chapter': 1,
      'verse': 2,
    });
    await Future<void>.delayed(Duration.zero);
    expect(audio.verse, 2);
    expect(audio.hasPlayback, true);
    deliverQuranAudioEvent({
      'session': session,
      'revision': 2,
      'state': 'loading',
      'chapter': 1,
      'verse': 1,
    });
    deliverQuranAudioEvent({
      'session': 'other',
      'revision': 4,
      'state': 'playing',
      'chapter': 1,
      'verse': 1,
    });
    await Future<void>.delayed(Duration.zero);
    expect(audio.verse, 2);
    expect(audio.state, 'playing');
  });
  testWidgets(
    'Warsh sans lecture Hafs ; contrôles Hafs sans débordement à 320 px',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 800);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final chapter = <String, dynamic>{
        'number': 2,
        'title': 'البقرة',
        'basmala': 'بسم الله الرحمن الرحيم',
        'verses': [
          {'number': 1, 'text': 'الم'},
          {'number': 2, 'text': 'ذلك الكتاب'},
        ],
      };
      await tester.pumpWidget(
        MaterialApp(
          home: SurahPage(reading: 'warsh', chapter: chapter),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('quran-continuous')), findsNothing);
      expect(find.byKey(const ValueKey('play-ayah-1')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MaterialApp(
          home: SurahPage(reading: 'hafs', chapter: chapter),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('quran-continuous')), findsOneWidget);
      expect(find.byKey(const ValueKey('play-ayah-1')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
