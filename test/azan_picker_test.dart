import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diraasa/core/app_core.dart';
import 'package:diraasa/devotion/alarm_controls.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final fajr in [false, true]) {
    testWidgets('Liste azan séparée Fajr=$fajr et lecture/pause', (tester) async {
      settings = AppSettings(initialLanguage: 'fr');
      String? playing;
      bool active = false;
      final catalog = [
        {'id': 'asset:audio/adhan_1.m4a', 'label': 'Azan général'},
        {'id': 'asset:audio/adhan_5.m4a', 'label': 'Ali Ibn Ahmed Mala'},
      ];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(Store.channel, (call) async {
        if (call.method == 'audioCatalog') return jsonEncode(catalog);
        if (call.method == 'azanPreviewStatus') {
          return {'audio': playing, 'playing': active};
        }
        if (call.method == 'azanPreviewToggle') {
          final id = (call.arguments as Map)['audio'] as String;
          active = playing == id ? !active : true;
          playing = id;
        }
        if (call.method == 'azanPreviewStop') active = false;
        return true;
      });
      addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(Store.channel, null));
      await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) =>
          Scaffold(body: TextButton(onPressed: () { chooseAlarmAudio(context, fajr: fajr); }, child: const Text('Ouvrir'))))));
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();
      expect(find.text('Ali Ibn Ahmed Mala'), fajr ? findsOneWidget : findsNothing);
      expect(find.text('Azan général'), fajr ? findsNothing : findsOneWidget);
      expect(find.byIcon(Icons.play_circle_outline), findsOneWidget);
      await tester.tap(find.byIcon(Icons.play_circle_outline));
      await tester.pump();
      expect(active, true);
      expect(find.byIcon(Icons.pause_circle_outline), findsOneWidget);
      await tester.tap(find.byIcon(Icons.pause_circle_outline));
      await tester.pump();
      expect(active, false);
      expect(find.byIcon(Icons.play_circle_outline), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
