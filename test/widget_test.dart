import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diraasa/main.dart';

void widgetCase(String description, Future<void> Function(WidgetTester) body) {
  testWidgets(description, body, timeout: const Timeout(Duration(seconds: 45)));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  tearDownAll(() { WidgetController.hitTestWarningShouldBeFatal = false; });
  final note = <String, dynamic>{
    'id': 1, 'title': 'Cours de langue', 'body': 'العِلْمُ نور',
    'author': 'Auteur', 'kind': 'Cours', 'pinned': 1, 'created': 1760000000000, 'updated': 1760000000000,
  };
  final article = <String, dynamic>{
    'id': 12, 'word': 'العِلْمُ', 'root': 'ع ل م', 'definition': 'العِلْمُ نور', 'page': 12,
  };
  final calls = <String>[];
  final writes = <AppRecord>[];
  AppRecord persisted = {};
  setUp(() {
    settings = AppSettings(initialLanguage: 'fr');
    calls.clear(); writes.clear(); persisted = {};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(Store.channel, (call) async {
      calls.add(call.method);
      if (call.method == 'preferences') return persisted;
      if (call.method == 'savePreferences') { persisted = Map<String, dynamic>.from(call.arguments as Map); return true; }
      if (call.method == 'notes') return [note];
      if (call.method == 'search') return [article];
      if (call.method == 'save') { writes.add(Map<String, dynamic>.from(call.arguments as Map)); return 2; }
      return true;
    });
  });
  Future<void> screen(WidgetTester tester, {double width = 400, double height = 900}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, height);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(const Diraasa());
    await tester.pumpAndSettle();
  }
  Future<void> selectMenuOption(WidgetTester tester, String menuKey, String optionKey) async {
    await tester.tap(find.byKey(ValueKey(menuKey)));
    await tester.pumpAndSettle();
    final option = find.byKey(ValueKey(optionKey));
    expect(option, findsOneWidget);
    await tester.ensureVisible(option);
    await tester.pumpAndSettle();
    // CheckedPopupMenuItem intentionally ignores pointer events on its child
    // label. Its parent item is the actual interactive target.
    expect(option.hitTestable(), findsOneWidget);
    await tester.tap(option.hitTestable());
    await tester.pumpAndSettle();
  }
  test('Langue système principale et repli français', () {
    expect(resolveLanguage([const Locale('ar', 'SN')]), 'ar');
    expect(resolveLanguage([const Locale('en', 'US')]), 'en');
    expect(resolveLanguage([const Locale('de'), const Locale('en')]), 'fr');
    expect(resolveLanguage([]), 'fr');
  });
  test('Persistance langue, thème, taille et champs réutilisables', () async {
    expect(settings.themeMode, ThemeMode.system);
    await settings.update({'language': 'ar', 'theme': 'dark', 'textSize': 30,
      'draftTitle': 'عنوان', 'draftAuthor': 'مؤلف', 'draftKind': 'Vers',
      'noteCategory': 'Vers', 'noteField': 'body', 'dictionaryMode': 'contains', 'dictionaryLetter': 'ع'});
    final reopened = AppSettings(initialLanguage: 'en');
    await reopened.load();
    expect(reopened.language, 'ar');
    expect(reopened.themeMode, ThemeMode.dark);
    expect(reopened.textSize, 30);
    expect(reopened.draftTitle, 'عنوان');
    expect(reopened.draftAuthor, 'مؤلف');
    expect(reopened.draftKind, 'Vers');
    expect(reopened.noteCategory, 'Vers');
    expect(reopened.noteField, 'body');
    expect(reopened.dictionaryMode, 'contains');
    expect(reopened.dictionaryLetter, 'ع');
  });
  test('Une écriture de préférence en échec ne bloque pas la suivante', () async {
    var attempts = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(Store.channel, (call) async {
      if (call.method == 'savePreferences') {
        attempts++;
        if (attempts == 1) throw PlatformException(code: 'WRITE_FAILED');
        persisted = Map<String, dynamic>.from(call.arguments as Map);
      }
      return true;
    });
    await expectLater(settings.update({'language': 'ar'}), throwsA(isA<PlatformException>()));
    await settings.update({'theme': 'dark'});
    expect(attempts, 2);
    expect(persisted['language'], 'ar');
    expect(persisted['theme'], 'dark');
  });
  widgetCase('Première écriture immédiate et commits successifs ordonnés', (tester) async {
    // settings was constructed by setUp, outside this widget's FakeAsync zone.
    // An idle queue must not wait on a Future created in that other zone.
    final snapshots = <AppRecord>[];
    final firstAcknowledgement = Completer<void>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(Store.channel, (call) async {
      if (call.method == 'notes') return [note];
      if (call.method == 'savePreferences') {
        snapshots.add(Map<String, dynamic>.from(call.arguments as Map));
        if (snapshots.length == 1) await firstAcknowledgement.future;
        persisted = Map<String, dynamic>.from(call.arguments as Map);
      }
      return true;
    });
    await screen(tester);
    var firstDone = false, secondDone = false;
    Object? failure;
    settings.update({'language': 'ar'}).then<void>((_) { firstDone = true; },
      onError: (Object e, StackTrace _) { failure = e; });
    settings.update({'theme': 'dark', 'noteField': 'body'}).then<void>((_) { secondDone = true; },
      onError: (Object e, StackTrace _) { failure = e; });
    await tester.pump();
    expect(snapshots.length, 1);
    expect(snapshots.first['language'], 'ar');
    expect(firstDone, isFalse);
    expect(secondDone, isFalse);
    firstAcknowledgement.complete();
    await tester.pumpAndSettle();
    expect(failure, isNull);
    expect(firstDone, isTrue);
    expect(secondDone, isTrue);
    expect(snapshots.length, 2);
    expect(snapshots.last['language'], 'ar');
    expect(snapshots.last['theme'], 'dark');
    expect(persisted['noteField'], 'body');
    expect(tester.takeException(), isNull);
  });
  test('Filtres titre/auteur et normalisation arabe', () {
    expect(matchesNote(note, 'Cours', 'title'), isTrue);
    expect(matchesNote(note, 'Auteur', 'title'), isFalse);
    expect(matchesNote(note, 'Auteur', 'author'), isTrue);
    expect(matchesNote(note, 'العلم', 'all'), isTrue);
    expect(matchesNote(note, 'العلم', 'author'), isFalse);
    expect(matchesNote(note, '', 'all'), isTrue);
    expect(direction('123 - العلم'), TextDirection.rtl);
    expect(direction('École العربية'), TextDirection.ltr);
  });
  test('Chaque filtre cible exactement ses champs et son surlignage', () {
    final queries = {'title': 'Cours', 'author': 'Auteur', 'body': 'العلم'};
    for (final field in noteSearchFields) {
      for (final term in queries.entries) {
        final expected = field == 'all' || field == term.key;
        expect(matchesNote(note, term.value, field), expected,
          reason: 'Filtre ' + field + ' / recherche ' + term.key);
      }
      for (final target in ['title', 'author', 'body']) {
        expect(noteFieldQuery(field, target, 'test'),
          field == 'all' || field == target ? 'test' : '');
      }
    }
    expect(matchesNote({...note, 'author': null}, 'Auteur', 'author'), isFalse);
    expect(matchesNote(note, '', 'body'), isTrue);
  });
  test('Surlignage exact avec harakat, racines espacées et préfixes FTS', () {
    const text = 'هذا عِلْمٌ نافع';
    final ranges = matchRanges(text, 'علم');
    expect(ranges.length, 1);
    expect(text.substring(ranges.first.start, ranges.first.end), 'عِلْمٌ');
    expect(matchRanges('ع ل م', 'علم', compact: true).length, 1);
    expect(matchRanges('العلم معلم علمي', 'علم', mode: 'fulltext').length, 1);
    expect(matchRanges('العلم', 'علم', mode: 'prefix'), isEmpty);
    expect(evidenceWords(article, 'علم نور').length, 2);
  });
  widgetCase('Lecture modal puis modification explicite', (tester) async {
    await screen(tester);
    await tester.tap(find.byKey(const ValueKey('note-1')));
    await tester.pumpAndSettle();
    expect(find.byType(NotePreview), findsOneWidget);
    expect(find.byType(Editor), findsNothing);
    expect(calls.where((m) => m == 'save'), isEmpty);
    await tester.tap(find.byTooltip('Fermer'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Options de la note'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Modifier'));
    await tester.pumpAndSettle();
    expect(find.byType(Editor), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  widgetCase('Après sauvegarde, contenu vidé, titre/auteur/type réutilisés', (tester) async {
    await screen(tester, height: 1400);
    await tester.tap(find.text('Nouvelle note'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('note-title')), 'Titre réutilisable');
    await tester.enterText(find.byKey(const ValueKey('note-author')), 'Auteur');
    await tester.enterText(find.byKey(const ValueKey('note-body')), 'Premier contenu');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(writes.length, 1);
    expect(tester.widget<TextFormField>(find.byKey(const ValueKey('note-body'))).controller!.text, '');
    expect(tester.widget<TextFormField>(find.byKey(const ValueKey('note-title'))).controller!.text, 'Titre réutilisable');
    expect(tester.widget<TextFormField>(find.byKey(const ValueKey('note-author'))).controller!.text, 'Auteur');
    await tester.enterText(find.byKey(const ValueKey('note-body')), 'Deuxième contenu');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(writes.length, 2);
    expect(writes.last['id'], isNull); // Creates another note, never overwrites the prior one.
    expect(writes.last['body'], 'Deuxième contenu');
  });
  widgetCase('Changement de langue et thème sans recréer les notes', (tester) async {
    await screen(tester);
    // UI events + pump advance the fake clock and the preference-write queue.
    // Never await a queued platform write here before pumping the widget tree.
    await selectMenuOption(tester, 'language-menu', 'language-option-ar');
    await selectMenuOption(tester, 'theme-menu', 'theme-option-dark');
    expect(find.text('ملاحظات'), findsOneWidget);
    expect(Directionality.of(tester.element(find.byType(Home))), TextDirection.rtl);
    expect(Theme.of(tester.element(find.byType(Home))).brightness, Brightness.dark);
    expect(find.byKey(const ValueKey('note-1')), findsOneWidget);
    expect(persisted['language'], 'ar');
    expect(persisted['theme'], 'dark');
    await selectMenuOption(tester, 'language-menu', 'language-option-en');
    await selectMenuOption(tester, 'theme-menu', 'theme-option-light');
    expect(find.text('Dictionary'), findsOneWidget);
    expect(Directionality.of(tester.element(find.byType(Home))), TextDirection.ltr);
    expect(persisted['language'], 'en');
    expect(persisted['theme'], 'light');
    expect(tester.takeException(), isNull);
  });
  for (final width in [320.0, 360.0]) {
    widgetCase('Recherche sticky, RTL, clavier et focus perdu à $width px', (tester) async {
      await screen(tester, width: width, height: 640);
      final input = find.byKey(const ValueKey('search-field'));
      await tester.tap(input);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.enterText(input, 'العلم');
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(input).textDirection, TextDirection.rtl);
      final pinnedTop = tester.getTopLeft(find.byKey(const ValueKey('sticky-search'))).dy;
      expect(tester.takeException(), isNull);
      FocusManager.instance.primaryFocus?.unfocus();
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(find.text(tr('introNotes')), findsNothing);
      expect(tester.getTopLeft(find.byKey(const ValueKey('sticky-search'))).dy, pinnedTop);
      await tester.enterText(input, 'Cours');
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(input).textDirection, TextDirection.ltr);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dictionnaire'));
      await tester.pumpAndSettle();
      await tester.tap(input);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.enterText(input, 'علم');
      await tester.pumpAndSettle();
      expect(find.byType(SliverPersistentHeader), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  widgetCase('Filtres de Notes : titre, auteur et catégorie combinés', (tester) async {
    await screen(tester, height: 1100);
    final input = find.byKey(const ValueKey('search-field'));
    await tester.enterText(input, 'Auteur');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('note-1')), findsOneWidget);
    final titleFilter = find.byKey(const ValueKey('filter-title'));
    await tester.ensureVisible(titleFilter);
    await tester.pumpAndSettle();
    expect(titleFilter.hitTestable(), findsOneWidget);
    await tester.tap(titleFilter.hitTestable());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('note-1')), findsNothing);
    final authorFilter = find.byKey(const ValueKey('filter-author'));
    await tester.ensureVisible(authorFilter);
    await tester.pumpAndSettle();
    expect(authorFilter.hitTestable(), findsOneWidget);
    await tester.tap(authorFilter.hitTestable());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('note-1')), findsOneWidget);
    final bodyFilter = find.byKey(const ValueKey('filter-body'));
    await tester.ensureVisible(bodyFilter);
    await tester.pumpAndSettle();
    expect(bodyFilter.hitTestable(), findsOneWidget);
    await tester.tap(bodyFilter.hitTestable());
    await tester.pumpAndSettle();
    // The author string must not match when only the content is searched.
    expect(find.byKey(const ValueKey('note-1')), findsNothing);
    await tester.enterText(input, 'العلم');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('note-1')), findsOneWidget);
    expect(persisted['noteField'], 'body');
    await tester.tap(find.byKey(const ValueKey('note-1')));
    await tester.pumpAndSettle();
    final preview = find.byType(NotePreview);
    final matchedTexts = tester.widgetList<MatchText>(
      find.descendant(of: preview, matching: find.byType(MatchText))).toList();
    expect(matchedTexts.singleWhere((w) => w.text == note['body']).query, 'العلم');
    expect(matchedTexts.singleWhere((w) => w.text == note['title']).query, '');
    expect(matchedTexts.singleWhere((w) => w.text == note['author']).query, '');
    await tester.tap(find.byTooltip('Fermer'));
    await tester.pumpAndSettle();
    final verse = find.byKey(const ValueKey('filter-Vers'));
    await tester.ensureVisible(verse);
    await tester.pumpAndSettle();
    expect(verse.hitTestable(), findsOneWidget);
    await tester.tap(verse.hitTestable());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('note-1')), findsNothing);
  });
  widgetCase('Recherche et filtres restent sticky au défilement naturel', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(Store.channel, (call) async {
      if (call.method == 'notes') return List.generate(20, (i) => {...note, 'id': i + 1, 'title': 'Cours ' + i.toString()});
      return true;
    });
    await screen(tester);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await tester.pumpAndSettle();
    final top = tester.getTopLeft(find.byKey(const ValueKey('sticky-search'))).dy;
    final appBarBottom = tester.getBottomLeft(find.byType(AppBar)).dy;
    expect((top - appBarBottom).abs(), lessThanOrEqualTo(1));
    final headerRect = tester.getRect(find.byKey(const ValueKey('sticky-search')));
    expect(headerRect.contains(tester.getCenter(find.byKey(const ValueKey('search-field')))), isTrue);
    // The row is pinned; individual chips can be outside its horizontal viewport.
    final filters = find.byKey(const ValueKey('secondary-filters'));
    expect(headerRect.contains(tester.getCenter(filters)), isTrue);
    final authorFilter = find.byKey(const ValueKey('filter-author'));
    await tester.ensureVisible(authorFilter);
    await tester.pumpAndSettle();
    expect(authorFilter.hitTestable(), findsOneWidget);
    final updatedHeader = tester.getRect(find.byKey(const ValueKey('sticky-search')));
    expect(updatedHeader.contains(tester.getCenter(authorFilter)), isTrue);
    expect(tester.takeException(), isNull);
  });

}
