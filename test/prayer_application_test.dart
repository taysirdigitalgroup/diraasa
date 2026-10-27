import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diraasa/core/app_core.dart';
import 'package:diraasa/devotion/prayers.dart';
import 'package:diraasa/devotion/prayer_settings.dart';
import 'package:diraasa/widgets/sacred_text.dart';

Map<String, dynamic> prayerDay(DateTime date) => {
  'date': {
    'gregorian': {
      'date':
          '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}',
    },
  },
  'meta': {'timezone': 'UTC'},
  'timings': {
    for (final entry in {
      'Fajr': 5,
      'Dhuhr': 12,
      'Asr': 16,
      'Maghrib': 18,
      'Isha': 20,
    }.entries)
      entry.key: DateTime.utc(
        date.year,
        date.month,
        date.day,
        entry.value,
      ).toIso8601String(),
  },
};
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, dynamic> saved;
  bool nativeEnabled = false;
  final scheduled = <Map>[];
  final today = DateTime.now();
  final oldSync = DateTime.now()
      .subtract(const Duration(days: 1))
      .millisecondsSinceEpoch;
  setUp(() {
    settings = AppSettings(initialLanguage: 'fr');
    nativeEnabled = false;
    scheduled.clear();
    saved = {
      'options': {
        'city': 'Dakar',
        'country': 'Senegal',
        'coordinates': false,
        'latitude': '14.7',
        'longitude': '-17.4',
        'method': 3,
        'hanafi': false,
        'address': 'Adresse mémorisée',
        'adjustments': {
          for (final p in prayerNames) p: p == 'Dhuhr' ? '5' : '0',
        },
      },
      'days': [prayerDay(today), prayerDay(today.add(const Duration(days: 1)))],
      'syncedAt': oldSync,
      'adhanWanted': true,
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(Store.channel, (call) async {
          final args = call.arguments is Map ? call.arguments as Map : {};
          if (call.method == 'localTimezone') return 'UTC';
          if (call.method == 'audioCatalog') return '[]';
          if (call.method == 'devotionRead')
            return args['key'] == 'prayerBundle' ? jsonEncode(saved) : null;
          if (call.method == 'devotionWrite') {
            if (args['key'] == 'prayerBundle')
              saved = Map<String, dynamic>.from(
                jsonDecode(args['value'] as String) as Map,
              );
            return true;
          }
          if (call.method == 'azanStatus')
            return {
              'enabled': nativeEnabled,
              'requested': nativeEnabled,
              'exact': true,
              'notifications': true,
              'background': true,
            };
          if (call.method == 'azanDisable') {
            nativeEnabled = false;
            return true;
          }
          if (call.method == 'azanSchedule') {
            scheduled.add(Map.from(args));
            nativeEnabled = true;
            return {
              'enabled': true,
              'until': (args['events'] as List).last['at'],
            };
          }
          return true;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(Store.channel, null),
  );
  Future<void> page(
    WidgetTester tester, {
    Future<dynamic> Function(Uri)? fetch,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 1400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: PrayersPage(fetch: fetch)));
    await tester.pumpAndSettle();
  }

  String displayed(WidgetTester tester) => tester
      .widget<SacredText>(find.byKey(const ValueKey('prayer-time-Dhuhr')))
      .data!;
  test('Ajustements séparés : horaires, avances azan et chiffres arabes', () {
    final options = {
      'adjustments': {'Fajr': '١٠', 'Dhuhr': '-5'},
    };
    final combined = combinedPrayerOffsets(options, defaultAzanLeads);
    expect(combined['Fajr'], -35);
    expect(combined['Dhuhr'], -20);
    expect(combined['Maghrib'], 0);
    expect(prayerMinuteValue('', 17), 17);
    expect(wallTime('2026-10-27T00:10:00+00:00', -45), '23:25');
  });
  testWidgets(
    'Brouillon sans effet, fermeture restaure, Appliquer local puis champ vide',
    (tester) async {
      await page(tester);
      expect(displayed(tester), '12:05');
      final beforeSchedules = scheduled.length;
      await tester.tap(find.byKey(const ValueKey('prayer-panel-adjustments')));
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('prayer-offset-Dhuhr'));
      await tester.enterText(field, '20');
      await tester.pump();
      expect(
        tester
            .widget<SacredText>(
              find.byKey(const ValueKey('prayer-preview-Dhuhr')),
            )
            .data,
        '12:20',
      );
      expect(displayed(tester), '12:05');
      expect(scheduled.length, beforeSchedules);
      await tester.tap(find.byTooltip(tr('close')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('prayer-panel-adjustments')));
      await tester.pumpAndSettle();
      expect(tester.widget<TextFormField>(field).controller!.text, '5');
      await tester.enterText(field, '20');
      // Editing marks the modal dirty. Rebuild before tapping the button,
      // which was disabled while the draft still matched the applied values.
      await tester.pump();
      final apply = find.byKey(const ValueKey('refresh-adjustments'));
      expect(tester.widget<FilledButton>(apply).onPressed, isNotNull);
      await tester.tap(apply);
      await tester.pumpAndSettle();
      expect((saved['options'] as Map)['adjustments']['Dhuhr'], '20');
      expect(displayed(tester), '12:20');
      expect(saved['syncedAt'], oldSync);
      expect(nativeEnabled, true);
      await tester.enterText(field, '');
      await tester.tap(find.byTooltip(tr('close')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('prayer-panel-adjustments')));
      await tester.pumpAndSettle();
      expect(field, findsOneWidget, reason: 'Le modal doit pouvoir être rouvert');
      expect(tester.widget<TextFormField>(field).controller!.text, '20');
      expect(displayed(tester), '12:20');
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Avances azan : défauts, aperçu, application sans changer les prières',
    (tester) async {
      await page(tester);
      final open = find.byKey(const ValueKey('adjust-azan-times'));
      await tester.ensureVisible(open);
      await tester.tap(open);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('azan-offset-Fajr')),
            )
            .controller!
            .text,
        '45',
      );
      expect(
        tester
            .widget<SacredText>(
              find.byKey(const ValueKey('azan-preview-Dhuhr')),
            )
            .data,
        '11:50',
      );
      await tester.enterText(
        find.byKey(const ValueKey('azan-offset-Dhuhr')),
        '30',
      );
      await tester.pump();
      expect(
        tester
            .widget<SacredText>(
              find.byKey(const ValueKey('azan-preview-Dhuhr')),
            )
            .data,
        '11:35',
      );
      await tester.tap(find.byKey(const ValueKey('refresh-azanAdjustments')));
      await tester.pumpAndSettle();
      expect(displayed(tester), '12:05');
      expect((saved['azanLeads'] as Map)['Dhuhr'], 30);
      expect(saved['syncedAt'], oldSync);
      await tester.pumpWidget(const SizedBox());
    },
  );
  Future<dynamic> calendar(Uri uri) async {
    final year = int.parse(uri.pathSegments[2]),
        month = int.parse(uri.pathSegments[3]);
    return {
      'code': 200,
      'data': [
        for (int d = 1; d <= DateTime(year, month + 1, 0).day; d++)
          prayerDay(DateTime(year, month, d)),
      ],
    };
  }

  testWidgets('Cache indisponible puis synchronisé : reprend le choix activé', (
    tester,
  ) async {
    saved['days'] = [];
    await page(tester, fetch: calendar);
    expect(nativeEnabled, false);
    expect(saved['adhanWanted'], true);
    await tester.tap(find.byKey(const ValueKey('prayer-global-refresh')));
    await tester.pumpAndSettle();
    expect(nativeEnabled, true);
    expect(saved['adhanWanted'], true);
    expect(saved['syncedAt'], greaterThan(oldSync));
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Choix désactivé conservé après synchronisation', (tester) async {
    saved['days'] = [];
    saved['adhanWanted'] = false;
    await page(tester, fetch: calendar);
    await tester.tap(find.byKey(const ValueKey('prayer-global-refresh')));
    await tester.pumpAndSettle();
    expect(nativeEnabled, false);
    expect(saved['adhanWanted'], false);
    expect(scheduled, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'Échec réseau : dernières heures, localisation et sync conservées',
    (tester) async {
      await page(tester, fetch: (_) => Future.error(StateError('offline')));
      await tester.tap(find.byKey(const ValueKey('prayer-global-refresh')));
      await tester.pumpAndSettle();
      expect(displayed(tester), '12:05');
      expect(saved['syncedAt'], oldSync);
      expect((saved['options'] as Map)['address'], 'Adresse mémorisée');
      expect(nativeEnabled, true);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
