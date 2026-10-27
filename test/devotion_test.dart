import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diraasa/core/app_core.dart';
import 'package:diraasa/devotion/core.dart';
import 'package:diraasa/devotion/prayers.dart';
import 'package:diraasa/devotion/quran.dart';
import 'package:diraasa/core/search.dart';
import 'package:diraasa/devotion/tasbih.dart';
import 'package:diraasa/devotion/reminders.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => settings = AppSettings(initialLanguage: 'fr'));
  test(
    'Références coraniques : sourate, tous versets, verset précis et chiffres arabes',
    () {
      expect(parseReference('3'), (chapter: 3, verse: null, list: false));
      expect(parseReference('3:'), (chapter: 3, verse: null, list: true));
      expect(parseReference('٣:٢٣'), (chapter: 3, verse: 23, list: true));
      expect(parseReference('۳:۲۳'), (chapter: 3, verse: 23, list: true));
      expect(parseReference('الفاتحة'), isNull);
      expect(parseReference('3:23:1'), isNull);
    },
  );
  test(
    'Horaires : fuseau ISO, ajustement et retrait des prières déjà passées',
    () {
      final day = {
        'timings': {
          'Fajr': '2026-10-26T05:00:00+03:00',
          'Dhuhr': '2026-10-26T12:00:00+03:00',
        },
      };
      final events = buildPrayerEvents(
        [day],
        {'Dhuhr': 5},
        now: DateTime.utc(2026, 10, 26, 3),
      );
      expect(events.length, 1);
      expect(
        events.single['at'],
        DateTime.utc(2026, 10, 26, 9, 5).millisecondsSinceEpoch,
      );
    },
  );
  test(
    'Aperçu coranique : indices du surlignage calculés sur le texte affiché',
    () {
      const source =
          'يكاد البرق يخطف أبصارهم كلما أضاء لهم مشوا فيه وإذا أظلم عليهم قاموا';
      final excerpt = quranExcerpt(source, 'ال');
      final ranges = matchRanges(excerpt, 'ال');
      expect(ranges, isNotEmpty);
      for (final range in ranges)
        expect(normalize(excerpt.substring(range.start, range.end)), 'ال');
    },
  );
  test('Sélection de prières : aucune alarme pour une prière désactivée', () {
    final events = buildPrayerEvents(
      [
        {
          'timings': {
            'Fajr': '2026-10-27T05:00:00+00:00',
            'Asr': '2026-10-27T16:00:00+00:00',
          },
        },
      ],
      {},
      now: DateTime.utc(2026, 10, 27),
      enabledPrayers: {'Asr'},
    );
    expect(events.length, 1);
    expect(
      events.single['at'],
      DateTime.utc(2026, 10, 27, 16).millisecondsSinceEpoch,
    );
  });
  test('Actualisation : chaque section suit uniquement ses paramètres', () {
    final base = <String, dynamic>{
      'city': 'Dakar',
      'country': 'Senegal',
      'coordinates': false,
      'latitude': '14.7',
      'longitude': '-17.4',
      'method': 3,
      'hanafi': false,
      'adjustments': {for (final p in prayerNames) p: '0'},
    };
    final changedLocation = {...base, 'city': 'Touba'};
    expect(
      prayerSectionSignature(changedLocation, 'location'),
      isNot(prayerSectionSignature(base, 'location')),
    );
    expect(
      prayerSectionSignature(changedLocation, 'method'),
      prayerSectionSignature(base, 'method'),
    );
    expect(
      prayerSectionSignature({...base, 'hanafi': true}, 'method'),
      isNot(prayerSectionSignature(base, 'method')),
    );
    expect(
      prayerSectionSignature({
        ...base,
        'adjustments': {'Fajr': '5'},
      }, 'adjustments'),
      isNot(prayerSectionSignature(base, 'adjustments')),
    );
    expect(
      prayerSectionSignature({...base, 'audio': 'personal.audio'}, 'method'),
      prayerSectionSignature(base, 'method'),
    );
    expect(
      prayerSectionSignature({...base, 'city': '  DAKAR  '}, 'location'),
      prayerSectionSignature(base, 'location'),
    );
    expect(
      prayerSectionSignature({
        ...base,
        'coordinates': true,
        'latitude': '14,70',
      }, 'location'),
      prayerSectionSignature({...base, 'coordinates': true}, 'location'),
    );
  });
  testWidgets(
    'Sourate : surlignage serré, sans étendre la sélection à la ligne',
    (tester) async {
      const original = 'يَكَادُ الْبَرْقُ يَخْطَفُ أَبْصَارَهُمْ';
      await tester.pumpWidget(
        MaterialApp(
          home: SurahPage(
            reading: 'hafs',
            initialQuery: 'ال',
            chapter: {
              'number': 2,
              'title': 'البقرة',
              'basmala': '',
              'verses': [
                {'number': 1, 'text': original},
              ],
            },
          ),
        ),
      );
      await tester.pump();
      final reader = tester
          .widgetList<EditableText>(find.byType(EditableText))
          .where((e) => e.readOnly)
          .single;
      expect(reader.controller.text, original);
      expect(reader.selectionWidthStyle, ui.BoxWidthStyle.tight);
      expect(reader.selectionHeightStyle, ui.BoxHeightStyle.tight);
      for (final range in matchRanges(original, 'ال'))
        expect(normalize(original.substring(range.start, range.end)), 'ال');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Wird : formulation manuelle sans zikr enregistré', (
    tester,
  ) async {
    AppRecord? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showDialog<AppRecord>(
                  context: context,
                  builder: (_) => const StepDialog(items: []),
                );
              },
              child: const Text('ouvrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'أستغفر الله');
    await tester.enterText(find.byType(TextFormField).last, '7');
    await tester.tap(find.text(tr('save')));
    await tester.pumpAndSettle();
    expect(result?['text'], 'أستغفر الله');
    expect(result?['max'], 7);
    expect(result?.containsKey('itemId'), false);
  });
  testWidgets(
    'Chaîne : maxima par étape, transition et arrêt final persistés',
    (tester) async {
      String saved = jsonEncode({
        'items': [
          {'id': 'a', 'text': 'الله', 'max': 1},
          {'id': 'b', 'text': 'محمد', 'max': 2},
        ],
        'chains': [
          {
            'id': 'chain',
            'name': 'Essai',
            'steps': [
              {'itemId': 'a', 'max': 1},
              {'itemId': 'b', 'max': 2},
            ],
          },
        ],
        'sessions': {},
      });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(Store.channel, (call) async {
            if (call.method == 'devotionRead') return saved;
            if (call.method == 'devotionWrite') {
              saved = (call.arguments as Map)['value'] as String;
              return true;
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(Store.channel, null),
      );
      await tester.pumpWidget(
        const MaterialApp(home: CounterPage(id: 'chain', chain: true)),
      );
      await tester.pumpAndSettle();
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byKey(const ValueKey('counter-tap')));
        await tester.pumpAndSettle();
      }
      final session =
          (jsonDecode(saved)['sessions'] as Map)['chain-chain'] as Map;
      expect(session['index'], 1);
      expect(session['count'], 2);
      expect(session['complete'], true);
      expect(find.text('Terminé'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Rappel : jours choisis, cible et activation persistés', (
    tester,
  ) async {
    String saved = jsonEncode({
      'items': [
        {'id': 'a', 'text': 'الله', 'max': 33},
      ],
      'chains': [],
      'sessions': {},
    });
    var configured = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(Store.channel, (call) async {
          if (call.method == 'devotionRead') return saved;
          if (call.method == 'devotionWrite') {
            saved = (call.arguments as Map)['value'] as String;
            return true;
          }
          if (call.method == 'azanPermissions') return true;
          if (call.method == 'azanStatus')
            return {'exact': true, 'notifications': true, 'background': true};
          if (call.method == 'remindersConfigure') {
            configured = true;
            return true;
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(Store.channel, null),
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: RemindersPage(targetId: 'a', chain: false, label: 'الله'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Programmer un rappel'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Mer'));
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    final reminder = (jsonDecode(saved)['reminders'] as List).single as Map;
    expect(reminder['targetId'], 'a');
    expect(reminder['chain'], false);
    expect(reminder['enabled'], true);
    expect(reminder['weekdays'], [1, 2, 4, 5, 6, 7]);
    expect(configured, true);
    expect(tester.takeException(), isNull);
  });
}
