import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diraasa/core/app_core.dart';
import 'package:diraasa/screens/backup.dart';
import 'package:diraasa/screens/privacy.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<String> calls;
  Completer<dynamic>? exportGate;
  setUp(() {
    calls = [];
    exportGate = null;
    settings = AppSettings(initialLanguage: 'fr');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(Store.channel, (call) async {
          calls.add(call.method);
          switch (call.method) {
            case 'driveStatus':
              return {'configured': false, 'connected': false, 'email': ''};
            case 'backupRecoveryList':
              return [];
            case 'backupExportLocal':
              final gate = exportGate;
              if (gate != null) return await gate.future;
              return true;
            case 'backupPrepareLocal':
              return {
                'createdAt': 1793145600000,
                'notes': 3,
                'authors': 2,
                'themes': 1,
                'azkar': 4,
                'wird': 1,
                'attachments': 2,
              };
            case 'preferences':
              return {'language': 'fr', 'theme': 'dark', 'textSize': 28};
            default:
              return true;
          }
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(Store.channel, null),
  );
  Future<void> open(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 1000);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: BackupPage()));
    await tester.pumpAndSettle();
  }

  testWidgets('Sauvegarde locale disponible sans configuration Google', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('export')));
    await tester.pumpAndSettle();
    expect(calls, contains('backupExportLocal'));
    expect(calls, isNot(contains('driveConnect')));
    expect(find.text('Sauvegarde créée.'), findsOneWidget);
  });
  testWidgets('Annuler ne restaure jamais les données', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('import')));
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(
      tester.widget<ListTile>(find.byKey(const ValueKey('import'))).onTap,
      isNull,
    );
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(calls, contains('backupCancel'));
    expect(calls, isNot(contains('backupApply')));
  });
  testWidgets(
    'Double confirmation, restauration puis rechargement des préférences',
    (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('import')));
      await tester.pumpAndSettle();
      expect(find.byType(LinearProgressIndicator), findsNothing);
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();
      expect(find.text('Notes : 3'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(calls, isNot(contains('backupApply')));
      await tester.tap(find.byKey(const ValueKey('confirm-restore')));
      await tester.pumpAndSettle();
      expect(calls.where((c) => c == 'backupApply').length, 1);
      expect(settings.theme, 'dark');
      expect(settings.textSize, 28);
      expect(calls, contains('backupCancel'));
    },
  );
  testWidgets('Progression pendant le transfert, actions verrouillées', (
    tester,
  ) async {
    final transfer = Completer<dynamic>();
    exportGate = transfer;
    await open(tester);
    try {
      await tester.tap(find.byKey(const ValueKey('export')));
      // Wait for the method channel to enter the blocked transfer. A single
      // frame does not guarantee that async preference flushing has finished.
      final progress = find.byKey(const ValueKey('backup-progress'));
      for (var frame = 0; frame < 20; frame++) {
        if (calls.contains('backupExportLocal') &&
            progress.evaluate().isNotEmpty)
          break;
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(calls.where((c) => c == 'backupExportLocal').length, 1);
      expect(progress, findsOneWidget);
      expect(
        tester.widget<ListTile>(find.byKey(const ValueKey('import'))).onTap,
        isNull,
      );
      transfer.complete(true);
      await tester.pumpAndSettle();
      expect(progress, findsNothing);
      expect(
        tester.widget<ListTile>(find.byKey(const ValueKey('import'))).onTap,
        isNotNull,
      );
    } finally {
      if (!transfer.isCompleted) transfer.complete(true);
      await tester.pumpAndSettle();
    }
  });
  testWidgets('Annuler le résumé libère le verrou et permet un nouvel import', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('import')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(calls, isNot(contains('backupApply')));
    expect(calls, contains('backupCancel'));
    await tester.tap(find.byKey(const ValueKey('import')));
    await tester.pumpAndSettle();
    expect(calls.where((c) => c == 'backupPrepareLocal').length, 2);
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(calls, isNot(contains('backupApply')));
  });
  testWidgets('Lien de confidentialité ouvre la politique intégrée', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PrivacyLink())),
    );
    await tester.tap(find.byKey(const ValueKey('privacy-link')));
    await tester.pumpAndSettle();
    expect(find.byType(PrivacyPage), findsOneWidget);
    expect(find.text('Responsable et contact'), findsOneWidget);
  });
}
