import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diraasa/core/app_core.dart';
import 'package:diraasa/devotion/hisn.dart';
import 'package:diraasa/screens/sources.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];
  setUp(() {
    settings = AppSettings(initialLanguage: 'fr');
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(Store.channel, (call) async {
          calls.add(call);
          return true;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(Store.channel, null),
  );
  testWidgets('Infos Hisn : deux parties, aucun chapitre de zikr', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HisnSource(
          book: {
            'frontMatter': [
              {
                'title': 'المقدمة',
                'text': 'مقدمة الكتاب',
                'references': ['مرجع المقدمة'],
              },
              {
                'title': 'فضل الذكر',
                'text': 'فوائد الذكر',
                'references': ['مرجع الفضائل'],
              },
            ],
            'chapters': [
              {'title': 'أذكار الاستيقاظ'},
            ],
          },
        ),
      ),
    );
    expect(find.byType(ExpansionTile), findsNWidgets(2));
    expect(find.text('المقدمة'), findsOneWidget);
    expect(find.text('فضل الذكر'), findsOneWidget);
    expect(find.text('أذكار الاستيقاظ'), findsNothing);
    await tester.tap(find.text('فضل الذكر'));
    await tester.pumpAndSettle();
    expect(find.text('فوائد الذكر'), findsOneWidget);
    expect(find.text('مرجع الفضائل'), findsOneWidget);
  });
  testWidgets('Sources : cinq accès de référence', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: SourcesSection())),
      ),
    );
    for (final key in [
      'dictionaryReferences',
      'hisnReferences',
      'quranReferences',
      'prayerReferences',
      'audioReferences',
    ])
      expect(find.byKey(ValueKey('source-$key')), findsOneWidget);
  });
  testWidgets('Don PayPal : lien exact fourni par le DEV ENV', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: DonationsSection())),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('donate-paypal')));
    await tester.pump();
    expect(calls.single.method, 'openExternal');
    expect(
      (calls.single.arguments as Map)['url'],
      'https://paypal.me/MBENGUE28',
    );
    expect(find.text('Wave'), findsOneWidget);
    expect(find.text('Orange Money'), findsOneWidget);
  });
}
