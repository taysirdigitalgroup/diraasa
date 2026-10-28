import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diraasa/core/app_core.dart';
import 'package:diraasa/screens/backup.dart';
import 'package:diraasa/screens/privacy.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<String> calls;
  setUp(() {
    calls = [];
    settings = AppSettings(initialLanguage: 'fr');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(Store.channel, (call) async {
          calls.add(call.method);
          switch (call.method) {
            case 'driveStatus':
              return {'configured': false, 'connected': false, 'email': ''};
            case 'backupRecoveryList':
              return [];
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
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();
      expect(find.text('Notes : 3'), findsOneWidget);
      expect(calls, isNot(contains('backupApply')));
      await tester.tap(find.byKey(const ValueKey('confirm-restore')));
      await tester.pumpAndSettle();
      expect(calls.where((c) => c == 'backupApply').length, 1);
      expect(settings.theme, 'dark');
      expect(settings.textSize, 28);
      expect(calls, contains('backupCancel'));
    },
  );
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
