import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:diraasa/widgets/controls.dart';
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
      if (call.method == 'richClipboard') return {'text': 'نص منسق', 'runs': [{'start': 0, 'end': 2, 'attrs': {'b': true}}]};
      if (call.method == 'authors') return [{'id': 1, 'name': 'Auteur', 'alive': 1, 'bio': '', 'photo': ''}];
      if (call.method == 'renameTheme') { writes.add(Map<String, dynamic>.from(call.arguments as Map)); return (call.arguments as Map)['label']; }
      if (call.method == 'saveAuthor') { writes.add(Map<String, dynamic>.from(call.arguments as Map)); return 2; }
      if (call.method == 'references') return [{'label': 'Cours de langue'}, {'label': 'العربية'}];
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
      final appBarBottom = tester.getBottomLeft(find.byType(AppBar)).dy;
      // Off-screen sliver children may retain stale paint transforms.
      // Measure the visible pinned header, not the hidden intro paragraph.
      final visibleHeaderTop = tester.getTopLeft(find.byKey(const ValueKey('sticky-search'))).dy;
      expect((pinnedTop - appBarBottom).abs(), lessThanOrEqualTo(1));
      expect((visibleHeaderTop - appBarBottom).abs(), lessThanOrEqualTo(1));
      expect((visibleHeaderTop - pinnedTop).abs(), lessThanOrEqualTo(1));
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

  widgetCase('Taille de lecture persistée, cartes fixes et contenu de saisie ajusté', (tester) async {
    await screen(tester, height: 1300);
    final noteCard = find.byKey(const ValueKey('note-1'));
    double cardSize(String text) => tester.widgetList<MatchText>(
      find.descendant(of: noteCard, matching: find.byType(MatchText)))
      .singleWhere((widget) => widget.text == text).style!.fontSize!;
    final titleSize = cardSize(note['title'] as String);
    final bodySize = cardSize(note['body'] as String);
    settings.update({'textSize': 36});
    await tester.pumpAndSettle();
    expect(persisted['textSize'], 36);
    expect(cardSize(note['title'] as String), titleSize);
    expect(cardSize(note['body'] as String), bodySize);
    await tester.tap(noteCard);
    await tester.pumpAndSettle();
    final modalBody = tester.widgetList<MatchText>(
      find.descendant(of: find.byType(NotePreview), matching: find.byType(MatchText)))
      .singleWhere((widget) => widget.text == note['body']);
    expect(modalBody.style!.fontSize, 36);
    await tester.tap(find.byTooltip('Fermer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dictionnaire'));
    await tester.pumpAndSettle();
    final entry = find.byKey(const ValueKey('entry-12'));
    final wordStyle = tester.widgetList<MatchText>(find.descendant(of: entry, matching: find.byType(MatchText)))
      .singleWhere((widget) => widget.text == article['word']).style!;
    expect(wordStyle.fontSize, 24);
    await tester.tap(entry);
    await tester.pumpAndSettle();
    final definition = tester.widgetList<MatchText>(
      find.descendant(of: find.byType(Article), matching: find.byType(MatchText)))
      .singleWhere((widget) => widget.text == article['definition']);
    expect(definition.style!.fontSize, 36);
    final back = find.byKey(const ValueKey('article-back'));
    expect(back.hitTestable(), findsOneWidget);
    await tester.tap(back.hitTestable());
    await tester.pumpAndSettle();
    expect(find.byType(Article), findsNothing);
    expect(find.byType(Home), findsOneWidget);
    await tester.tap(find.text('Notes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nouvelle note'));
    await tester.pumpAndSettle();
    final bodyInput = tester.widget<TextField>(find.descendant(
      of: find.byKey(const ValueKey('note-body')), matching: find.byType(TextField)));
    expect(bodyInput.style!.fontSize, 36);
    expect(tester.takeException(), isNull);
  });
  widgetCase('Retour en haut : intro réapparaît, recherche descend, puis se fixe', (tester) async {
    // Also exercise the short-list case: it must have enough scroll range.
    await screen(tester, height: 900);
    final input = find.byKey(const ValueKey('search-field'));
    final intro = find.byKey(const ValueKey('intro-content'));
    final header = find.byKey(const ValueKey('sticky-search'));
    final appBarBottom = tester.getBottomLeft(find.byType(AppBar)).dy;
    await tester.tap(input);
    await tester.pumpAndSettle();
    expect((tester.getTopLeft(header).dy - appBarBottom).abs(), lessThanOrEqualTo(1));
    // Do not unfocus manually: dragging must release the editor's caret lock.
    expect(tester.widget<TextField>(input).focusNode!.hasFocus, isTrue);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 600));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(input).focusNode!.hasFocus, isFalse);
    expect(tester.getTopLeft(intro).dy, greaterThanOrEqualTo(appBarBottom));
    expect(tester.getTopLeft(header).dy, greaterThan(appBarBottom + 40));
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect((tester.getTopLeft(header).dy - appBarBottom).abs(), lessThanOrEqualTo(1));
    expect(tester.takeException(), isNull);
  });

  widgetCase('Surlignage sans découpage ni changement de géométrie arabe', (tester) async {
    const original = 'عليه والعِلْمُ لا إله';
    Widget sample(String query, {bool selectable = false}) => MaterialApp(home: Scaffold(
      body: Center(child: SizedBox(width: 280, child: MatchText(original,
        query: query, selectable: selectable, style: const TextStyle(fontSize: 26, height: 1.8))))));
    await tester.pumpWidget(sample(''));
    await tester.pumpAndSettle();
    final rich = find.descendant(of: find.byType(MatchText), matching: find.byType(RichText));
    final baseline = tester.renderObject<RenderParagraph>(rich);
    final beforeSize = baseline.size;
    final beforeBoxes = baseline.getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: original.length))
      .map((box) => box.toRect()).toList();
    await tester.pumpWidget(sample('ل'));
    await tester.pumpAndSettle();
    final paragraph = tester.renderObject<RenderParagraph>(rich);
    final span = paragraph.text as TextSpan;
    expect(span.toPlainText(), original);
    expect(span.children ?? <InlineSpan>[], isEmpty);
    expect(paragraph.size, beforeSize);
    final afterBoxes = paragraph.getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: original.length))
      .map((box) => box.toRect()).toList();
    expect(afterBoxes, beforeBoxes);
    await tester.pumpWidget(sample('ل', selectable: true));
    await tester.pumpAndSettle();
    expect(tester.widget<SelectableText>(find.byType(SelectableText)).data, original);
    expect(tester.takeException(), isNull);
  });
  widgetCase('Picker constant : le curseur et la valeur suivent chaque déplacement', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Center(child: ReadingSize()))));
    await tester.pumpAndSettle();
    final picker = find.byKey(const ValueKey('reading-size'));
    final before = tester.widget<Slider>(picker).value;
    await tester.drag(picker, const Offset(120, 0));
    await tester.pumpAndSettle();
    final larger = tester.widget<Slider>(picker).value;
    expect(larger, greaterThan(before));
    expect(larger, settings.textSize);
    expect(persisted['textSize'], larger);
    await tester.drag(picker, const Offset(-160, 0));
    await tester.pumpAndSettle();
    final smaller = tester.widget<Slider>(picker).value;
    expect(smaller, lessThan(larger));
    expect(persisted['textSize'], smaller);
    expect(tester.takeException(), isNull);
  });
  test('Types enrichis, traductions complètes et anciens types conservés', () async {
    for (final type in ['Cours', 'Vocabulaire', 'Vers', 'Citation', 'Notion', 'Définition',
      'Grammaire', 'Conjugaison', 'Règle', 'Exemple', 'Exercice', 'Résumé', 'Autre']) {
      expect(kinds, contains(type));
      expect(labels[type]?.length, 3);
    }
    await settings.update({'draftKind': 'Notion', 'noteCategory': 'Notion'});
    final reopened = AppSettings(initialLanguage: 'fr');
    await reopened.load();
    expect(reopened.draftKind, 'Notion');
    expect(reopened.noteCategory, 'Notion');
  });
  widgetCase('Étirement Notes : recharge sans perdre recherche et filtre Contenu', (tester) async {
    await screen(tester, height: 1100);
    final input = find.byKey(const ValueKey('search-field'));
    await tester.enterText(input, 'العلم');
    await tester.pumpAndSettle();
    final bodyFilter = find.byKey(const ValueKey('filter-body'));
    await tester.ensureVisible(bodyFilter);
    await tester.pumpAndSettle();
    await tester.tap(bodyFilter.hitTestable());
    await tester.pumpAndSettle();
    // Return to the real top first, then start a new pull from the edge.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 600));
    await tester.pumpAndSettle();
    final before = calls.where((method) => method == 'notes').length;
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 600));
    await tester.pumpAndSettle();
    expect(calls.where((method) => method == 'notes').length, greaterThan(before));
    expect(tester.widget<TextField>(input).controller!.text, 'العلم');
    expect(tester.widget<ChoiceChip>(bodyFilter).selected, isTrue);
    expect(find.byKey(const ValueKey('note-1')), findsOneWidget);
    await tester.tap(find.text('Dictionnaire'));
    await tester.pumpAndSettle();
    final dictionaryCalls = calls.where((method) => method == 'search').length;
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 600));
    await tester.pumpAndSettle();
    expect(calls.where((method) => method == 'search').length, dictionaryCalls);
    expect(tester.takeException(), isNull);
  });

  widgetCase('Sélecteurs réutilisables : recherche et sélection sans changer le contenu', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Editor()));
    await tester.pumpAndSettle();
    final editorScroll = find.descendant(of: find.byType(Editor), matching: find.byType(Scrollable)).first;
    final bodyField = find.byKey(const ValueKey('note-body'));
    await tester.scrollUntilVisible(bodyField, 200, scrollable: editorScroll);
    await tester.pumpAndSettle();
    final bodyController = tester.widget<TextFormField>(bodyField).controller!;
    await tester.enterText(bodyField, 'Texte conservé');
    for (final field in ['title', 'author']) {
      final button = find.byKey(ValueKey('choose-' + field));
      // ListView builds off-screen fields lazily. Scroll to build the target
      // before asking for its geometry; ensureVisible alone cannot do this.
      await tester.scrollUntilVisible(button, -200, scrollable: editorScroll);
      await tester.pumpAndSettle();
      expect(button.hitTestable(), findsOneWidget);
      await tester.tap(button.hitTestable());
      await tester.pumpAndSettle();
      final searchField = find.byKey(const ValueKey('reference-search'));
      await tester.enterText(searchField, 'العَرَبِيَّة');
      await tester.pumpAndSettle();
      // Vocalized query is precise: the unvocalized fixture must be absent.
      expect(find.widgetWithText(ListTile, 'العربية'), findsNothing);
      await tester.enterText(searchField, 'العربية');
      await tester.pumpAndSettle();
      expect(find.text('Cours de langue'), findsNothing);
      final option = find.widgetWithText(ListTile, 'العربية');
      expect(option, findsOneWidget);
      await tester.tap(option);
      await tester.pumpAndSettle();
      final input = tester.widget<TextFormField>(find.byKey(ValueKey('note-' + field)));
      expect(input.controller!.text, 'العربية');
      expect(bodyController.text, 'Texte conservé');
    }
    expect(calls.where((method) => method == 'references').length, 2);
    expect(tester.takeException(), isNull);
  });

  test('Formatage préserve le texte arabe et se sérialise séparément', () {
    final controller = StudyController(text: 'العلم نور');
    controller.selection = const TextSelection(baseOffset: 0, extentOffset: 5);
    controller.apply('b');
    final restored = StudyController(text: controller.text, format: controller.format);
    expect(restored.text, 'العلم نور');
    expect(restored.marks.first['b'], true);
    expect(restored.marks.last['b'], isNull);
    restored.selection = TextSelection.collapsed(offset: restored.text.length);
    restored.list();
    expect(restored.text, '• العلم نور');
    controller.dispose(); restored.dispose();
  });
  widgetCase('Quatre onglets, profil auteur et thème vers notes', (tester) async {
    await screen(tester, height: 1100);
    expect(tester.widgetList<NavigationDestination>(find.byType(NavigationDestination)).map((d) => d.label),
      ['Notes', 'Thèmes', 'Auteurs', 'Dictionnaire']);
    await tester.tap(find.widgetWithText(NavigationDestination, 'Auteurs'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('author-1')));
    await tester.pumpAndSettle();
    expect(find.byType(AuthorProfile), findsOneWidget);
    expect(find.text('Auteur'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('author-back')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(NavigationDestination, 'Thèmes'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Cours de langue'));
    await tester.pumpAndSettle();
    expect(find.byType(ThemeNotesPage), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byKey(const ValueKey('note-1')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('note-1')));
    await tester.pumpAndSettle();
    expect(find.byType(NotePreview), findsOneWidget);
    await tester.tap(find.byTooltip('Fermer'));
    await tester.pumpAndSettle();
    expect(find.byType(ThemeNotesPage), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('theme-notes-back')));
    await tester.pumpAndSettle();
    expect(find.byType(ThemesPage), findsOneWidget);
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 1);
    expect(tester.takeException(), isNull);
  });
  widgetCase('Nouveau profil : nom obligatoire et biographie conservée', (tester) async {
    await screen(tester, height: 1100);
    await tester.tap(find.widgetWithText(NavigationDestination, 'Auteurs'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('new-author')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(find.text('Ajoutez le nom complet'), findsOneWidget);
    expect(writes, isEmpty);
    await tester.enterText(find.byKey(const ValueKey('author-name')), 'Nouvel Auteur');
    final bio = find.byKey(const ValueKey('author-bio'));
    await tester.scrollUntilVisible(bio, 200, scrollable: find.byType(Scrollable).first);
    await tester.enterText(bio, 'سيرة المؤلف');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(writes.single['name'], 'Nouvel Auteur');
    expect(writes.single['bio'], 'سيرة المؤلف');
    expect(find.byType(AuthorEditor), findsNothing);
    expect(tester.takeException(), isNull);
  });

  widgetCase('Collage Android formaté dans le contenu', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Editor()));
    await tester.pumpAndSettle();
    final field = find.byKey(const ValueKey('note-body'));
    await tester.scrollUntilVisible(field, 200, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(field);
    final input = tester.widget<TextFormField>(field);
    final controller = input.controller! as StudyController;
    await controller.paste(tester.element(field));
    await tester.pumpAndSettle();
    expect(controller.text, 'نص منسق');
    expect(controller.marks.first['b'], true);
    expect(controller.marks.last['b'], isNull);
    expect(tester.takeException(), isNull);
  });

  test('Citation : format conservé sans ajouter de caractères au texte', () {
    final controller = StudyController(text: 'العلم نور');
    controller.selection = const TextSelection(baseOffset: 0, extentOffset: 8);
    controller.apply('q');
    final restored = StudyController(text: controller.text, format: controller.format);
    expect(restored.text, 'العلم نور');
    expect(restored.marks.first['q'], true);
    controller.dispose(); restored.dispose();
  });

  widgetCase('Cartes : contenu mis en forme et bandeau du type', (tester) async {
    final body = note['body'] as String;
    final controller = StudyController(text: body);
    controller.selection = const TextSelection(baseOffset: 0, extentOffset: 5);
    controller.apply('b');
    final formatted = {...note, 'body_format': controller.format};
    controller.dispose();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: StudyNoteCard(
      note: formatted, onTap: () {}, onAction: (_) {}))));
    await tester.pumpAndSettle();
    final text = tester.widgetList<Text>(find.byType(Text)).singleWhere(
      (widget) => widget.textSpan?.toPlainText() == body);
    expect(((text.textSpan! as TextSpan).children!.first as TextSpan).style!.fontWeight, FontWeight.bold);
    expect(find.byType(Transform), findsWidgets);
    expect(kinds.map(typeColor).toSet().length, kinds.length);
    expect(tester.takeException(), isNull);
  });

  test('Recherche adaptative : saisie simple tolérante, harakat et casse explicites', () {
    final data = {'title': 'Cours', 'author': 'أحمد', 'body': 'عِلْم وعَلَم علم'};
    expect(matchesNote(data, 'cours', 'title'), isTrue);
    expect(matchesNote(data, 'Cours', 'title'), isTrue);
    expect(matchesNote(data, 'COURS', 'title'), isFalse);
    expect(matchesNote(data, 'احمد', 'author'), isTrue);
    expect(matchesNote(data, 'إحمد', 'author'), isTrue);
    expect(matchRanges(data['body']!, 'علم').length, 3);
    final exact = matchRanges(data['body']!, 'عِلْم');
    expect(exact.length, 1);
    expect(data['body']!.substring(exact.single.start, exact.single.end), 'عِلْم');
    expect(matchesNote({'body': 'عَلَم'}, 'عِلْم', 'body'), isFalse);
    expect(matchRanges('أَكَلَ إِكَلَ', 'أَكَلَ').length, 1);
    expect(matchRanges('COURS Cours cours', 'Cours').length, 1);
    expect(matchRanges('عِلْم عَلَم', 'عِل', mode: 'fulltext').length, 1);
  });

  test('Noms mis en valeur : texte et harakat intacts, y compris spans séparés', () {
    const original = 'اللَّهُ ومُحَمَّد ﷲ';
    final span = emphasizeNames(const TextSpan(text: original));
    expect(span.toPlainText(), original);
    final colored = <TextStyle>[];
    void walk(InlineSpan part) {
      if (part is TextSpan) {
        if (part.style?.color != null) colored.add(part.style!);
        for (final child in part.children ?? <InlineSpan>[]) { walk(child); }
      }
    }
    walk(span);
    expect(colored.where((style) => style.color == const Color(0xffe53935)).length, 2);
    expect(colored.where((style) => style.color == const Color(0xff2196f3)).length, 1);
    expect(colored.every((style) => style.fontWeight == FontWeight.bold), isTrue);
    final split = emphasizeNames(const TextSpan(children: [TextSpan(text: 'ال'), TextSpan(text: 'له')]));
    expect(split.toPlainText(), 'الله');
  });
  widgetCase('Suppression : alerte puis confirmation, annulation sans écriture', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => Scaffold(
      body: FilledButton(onPressed: () async {
        if (await confirmDeletion(context, question: 'Confirmer ?')) await Store.call('delete', {'id': 1});
      }, child: const Text('Déclencher'))))));
    await tester.tap(find.text('Déclencher'));
    await tester.pumpAndSettle();
    expect(calls.where((method) => method == 'delete'), isEmpty);
    await tester.tap(find.byKey(const ValueKey('delete-continue')));
    await tester.pumpAndSettle();
    expect(calls.where((method) => method == 'delete'), isEmpty);
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(calls.where((method) => method == 'delete'), isEmpty);
    await tester.tap(find.text('Déclencher'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('delete-continue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('delete-confirm')));
    await tester.pumpAndSettle();
    expect(calls.where((method) => method == 'delete').length, 1);
  });

  widgetCase('Thèmes : ajout manuel et suppression réservée aux thèmes vides', (tester) async {
    await screen(tester, height: 1100);
    await tester.tap(find.widgetWithText(NavigationDestination, 'Thèmes'));
    await tester.pumpAndSettle();
    final occupied = find.widgetWithText(ListTile, 'Cours de langue');
    expect(find.descendant(of: occupied, matching: find.byTooltip('Supprimer')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('new-theme')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('new-theme-name')), 'Thème ajouté');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(calls.where((method) => method == 'saveTheme').length, 1);
    expect(find.byType(NewThemeDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  widgetCase('Appui long : options notes et renommage thème sans suppression occupée', (tester) async {
    await screen(tester, height: 1100);
    await tester.longPress(find.byKey(const ValueKey('note-1')));
    await tester.pumpAndSettle();
    expect(find.text('Modifier'), findsOneWidget);
    expect(find.text('Supprimer'), findsOneWidget);
    await tester.tapAt(const Offset(2, 2));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(NavigationDestination, 'Thèmes'));
    await tester.pumpAndSettle();
    await tester.longPress(find.widgetWithText(ListTile, 'Cours de langue'));
    await tester.pumpAndSettle();
    expect(find.text('Supprimer'), findsNothing);
    await tester.tap(find.text('Modifier'));
    await tester.pumpAndSettle();
    final field = find.byKey(const ValueKey('new-theme-name'));
    expect(tester.widget<TextFormField>(field).controller!.text, 'Cours de langue');
    await tester.enterText(field, 'Études de langue');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(writes.single['oldLabel'], 'Cours de langue');
    expect(writes.single['label'], 'Études de langue');
    expect(tester.takeException(), isNull);
  });

}
