import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diraasa/core/app_core.dart';
import 'package:diraasa/devotion/quran.dart';
import 'package:diraasa/devotion/quran_audio.dart';
import 'package:diraasa/devotion/quran_audio_plan.dart';
import 'package:diraasa/devotion/quran_text.dart';

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
  test(
    'Quitter la page garde la lecture ; retour rattache le verset et le mode',
    () async {
      final calls = <String>[];
      final status = <String, dynamic>{
        'session': 'service-session',
        'revision': 20,
        'state': 'playing',
        'chapter': 1,
        'verse': 4,
        'language': 'fr',
        'mode': 'ar-fr-en',
        'continuous': true,
        'position': 1200,
        'duration': 5000,
      };
      Future<dynamic> api(String method, AppRecord? args) async {
        calls.add(method);
        return status;
      }

      final first = QuranAudioController(api: api);
      await first.attach(1);
      expect(first.verse, 4);
      expect(first.language, 'ar-fr-en');
      expect(first.playingLanguage, 'fr');
      expect(first.continuous, isTrue);
      first.dispose();
      await Future<void>.delayed(Duration.zero);
      expect(calls, isNot(contains('quranAudioStop')));
      final second = QuranAudioController(api: api);
      addTearDown(second.dispose);
      await second.attach(2);
      expect(second.active, isFalse);
      await second.attach(1);
      expect(second.hasPlayback, isTrue);
      expect(second.verse, 4);
      await second.stop();
      expect(calls.where((c) => c == 'quranAudioStop'), hasLength(1));
    },
  );
  test('Traduction et repli arabe ne changent jamais la référence', () {
    final verse = <String, dynamic>{
      'number': 2,
      'text': 'الحمد لله',
      'translations': {'fr': 'Louange à Allah.', 'en': 'Praise be to Allah.'},
    };
    expect(quranVerseText(verse, 'fr').text, 'Louange à Allah.');
    expect(quranVerseText(verse, 'en').language, 'en');
    expect(quranVerseText({'text': 'الحمد لله'}, 'fr').language, 'ar');
    expect(verse['number'], 2);
  });
  testWidgets(
    'Le texte suit la langue effective du son, cache sans texte technique',
    (tester) async {
      var session = '';
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(Store.channel, (call) async {
            if (call.method == 'devotionRead') return null;
            if (call.method == 'quranAudioStatus') return {'state': 'stopped'};
            if (call.method == 'quranAudioStart') {
              session = (call.arguments as Map)['session'] as String;
              return {
                'session': session,
                'revision': 1,
                'state': 'playing',
                'chapter': 1,
                'verse': 1,
                'language': 'fr',
                'duration': 5000,
              };
            }
            return true;
          });
      await tester.pumpWidget(
        MaterialApp(
          home: SurahPage(
            reading: 'hafs',
            chapter: {
              'number': 1,
              'title': 'الفاتحة',
              'basmala': '',
              'verses': [
                {
                  'number': 1,
                  'text': 'بسم الله',
                  'translations': {
                    'fr': 'Au nom du Très Miséricordieux.',
                    'en': 'In the name of the Most Merciful.',
                  },
                },
              ],
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('play-ayah-1')));
      await tester.pump();
      expect(
        find.textContaining(
          'Au nom du Très Miséricordieux.',
          findRichText: true,
        ),
        findsWidgets,
      );
      deliverQuranAudioEvent({
        'session': session,
        'revision': 2,
        'state': 'playing',
        'chapter': 1,
        'verse': 1,
        'language': 'en',
        'duration': 5000,
      });
      await tester.pump();
      await tester.pump();
      expect(
        find.textContaining(
          'In the name of the Most Merciful.',
          findRichText: true,
        ),
        findsWidgets,
      );
      expect(find.textContaining('Cache temporaire'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
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
