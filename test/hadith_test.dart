import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diraasa/core/app_core.dart';
import 'package:diraasa/devotion/hadith.dart';
import 'package:diraasa/devotion/prayers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => settings = AppSettings(initialLanguage: 'fr'));
  test('Hadith : normalisation, vocalisation précise, référence et numéro', () {
    final row = decodeHadith(
      jsonEncode({
        'entries': [
          {
            'id': 1,
            'number': 23,
            'title': 'أحمد',
            'text': 'أَحْمَدُ يَتَعَلَّمُ العِلْمَ Islam',
            'references': ['الراوي: أحمد'],
          },
        ],
      }),
    ).single;
    expect(hadithMatches(row, 'احمد'), true);
    expect(hadithMatches(row, 'أَحْمَدُ'), true);
    expect(hadithMatches(row, 'أَحْمَدَ'), false);
    expect(hadithMatches(row, '٢٣'), true);
    expect(hadithMatches(row, '2'), false);
    expect(hadithMatches(row, 'الراوي'), true);
    expect(hadithMatches(row, 'islam'), true);
    expect(hadithMatches(row, 'ISLAM'), false);
  });
  testWidgets(
    'Prières : quatre icônes, modal de méthode réactif, aucun dépliant',
    (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(Store.channel, (call) async {
            if (call.method == 'localTimezone') return 'Africa/Dakar';
            if (call.method == 'audioCatalog') return '[]';
            if (call.method == 'devotionRead') return null;
            if (call.method == 'azanStatus')
              return {
                'enabled': false,
                'exact': true,
                'background': true,
                'notifications': true,
              };
            return true;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(Store.channel, null),
      );
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 800);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: PrayersPage()));
      await tester.pumpAndSettle();
      for (final section in ['location', 'method', 'adjustments', 'audio'])
        expect(find.byKey(ValueKey('prayer-panel-$section')), findsOneWidget);
      expect(find.byType(ExpansionTile), findsNothing);
      await tester.tap(find.byKey(const ValueKey('prayer-panel-method')));
      await tester.pumpAndSettle();
      final button = find.byKey(const ValueKey('refresh-method'));
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      await tester.tap(find.byType(SwitchListTile).last);
      await tester.pump();
      expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
