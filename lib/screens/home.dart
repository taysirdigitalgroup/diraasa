import '../widgets/sacred_text.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../core/app_core.dart';
import '../core/search.dart';
import '../widgets/controls.dart';
import 'editor.dart';
import 'readers.dart';
import 'catalogs.dart';
import '../widgets/note_card.dart';
import '../widgets/delete_confirmation.dart';
import '../devotion/hub.dart';
import '../devotion/core.dart';

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}
class _HomeState extends State<Home> {
  int tab = 0, revision = 0;
  List<AppRecord> notes = [], entries = [];
  String query = '', category = 'all', field = 'all', mode = 'prefix', letter = '';
  bool loading = false, more = false;
  String? error;
  Timer? debounce;
  int dictionaryCount=0;
  final search = SacredController();
  final scroll = ScrollController();
  final focus = FocusNode();
  final introKey = GlobalKey();
  int focusRequest = 0;
  bool userDragging = false;
  bool keepSearchPinned = false;
  double? lastViewportExtent;
  @override
  void initState() {
    super.initState();
    category = settings.noteCategory; field = settings.noteField;
    mode = settings.dictionaryMode; letter = settings.dictionaryLetter;
    focus.addListener(focusChanged); settings.addListener(settingsChanged); load();
  }
  void settingsChanged() { if (mounted) setState(() {}); }
  @override
  void dispose() {
    settings.removeListener(settingsChanged);
    debounce?.cancel(); focus.removeListener(focusChanged); focus.dispose(); scroll.dispose(); search.dispose(); super.dispose();
  }
  double get introExtent {
    final box = introKey.currentContext?.findRenderObject();
    return box is RenderBox && box.hasSize ? box.size.height : 0;
  }
  void focusChanged() {
    final request = ++focusRequest;
    if (!focus.hasFocus || userDragging) return;
    keepSearchPinned = true;
    // Keep the intro in the scrollable. Focus merely scrolls past it, so a
    // reverse drag can reveal it naturally without an automatic blur toggle.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !scroll.hasClients || !focus.hasFocus || userDragging || request != focusRequest) return;
      final target = introExtent.clamp(scroll.position.minScrollExtent, scroll.position.maxScrollExtent).toDouble();
      scroll.animateTo(target, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
    });
  }
  bool handleMetrics(ScrollMetricsNotification notification) {
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) return false;
    final viewport = notification.metrics.viewportDimension;
    final oldViewport = lastViewportExtent;
    lastViewportExtent = viewport;
    if (oldViewport == null || (oldViewport - viewport).abs() < 0.5 ||
        !keepSearchPinned || userDragging) return false;
    final request = focusRequest;
    // Keyboard opening/closing can clamp the offset on short result sets.
    // Restore the anchor after layout, unless a real user drag took over.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !scroll.hasClients || userDragging || !keepSearchPinned || request != focusRequest) return;
      final target = introExtent.clamp(scroll.position.minScrollExtent, scroll.position.maxScrollExtent).toDouble();
      if ((scroll.offset - target).abs() > 0.5) scroll.jumpTo(target);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
    return false;
  }
  bool handleScroll(ScrollNotification notification) {
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) return false;
    if (notification is ScrollStartNotification && notification.dragDetails != null) {
      // A user drag takes priority over pending focus/caret positioning.
      userDragging = true;
      keepSearchPinned = false;
      focusRequest++;
      focus.unfocus();
    } else if (notification is ScrollEndNotification) {
      userDragging = false;
    }
    return false;
  }
  Future<void> load({bool append = false}) async {
    debounce?.cancel();
    final token = ++revision;
    final currentTab = tab;
    setState(() { loading = true; error = null; });
    try {
      if (currentTab > 1) { if (mounted) setState(() => loading = false); return; }
      final data = currentTab == 0 ? await Store.rows('notes') : await Store.rows('search', {
        'q': query, 'letter': letter, 'mode': mode, 'offset': append ? entries.length : 0,
      });
      final total=currentTab==1?await Store.call('searchCount',{'q':query,'letter':letter,'mode':mode}):0;
      if (!mounted || revision != token || tab != currentTab) return;
      dictionaryCount=(total as num?)?.toInt()??0;
      setState(() {
        if (currentTab == 0) { notes = data; } else { entries = append ? [...entries, ...data] : data; more = data.length == 60; }
        loading = false;
      });
    } catch (e) {
      if (mounted && revision == token) setState(() { error = e.toString(); loading = false; });
    }
  }
  void changed(String value) {
    debounce?.cancel();
    setState(() {
      query = value;
      if (tab == 1) { entries = []; more = false; loading = true; }
    });
    if (tab == 1) {
      revision++;
      debounce = Timer(const Duration(milliseconds: 260), () => load());
    }
  }
  Future<void> edit([AppRecord? note]) async {
    focus.unfocus();
    await Navigator.push(context, MaterialPageRoute(builder: (_) => Editor(note: note)));
    if (mounted) load(); // Editor stays open after save; refresh also when navigating back.
  }
  Future<void> preview(AppRecord note) async {
    focus.unfocus();
    await showModalBottomSheet<void>(
      context: context, isScrollControlled: true, showDragHandle: true,
      builder: (_) => FractionallySizedBox(heightFactor: .85, child: NotePreview(note: note, query: query, field: field)),
    );
  }
  Future<void> action(String command, AppRecord note) async {
    if (command == 'edit') { await edit(note); return; }
    if (command == 'delete') {
      final confirmed = await confirmDeletion(context, question: tr('deleteQuestion'));
      if (confirmed != true) return;
    }
    try { await Store.call(command, {'id': note['id']}); if (mounted) load(); }
    catch (e) { if (mounted) errorMessage(context, e); }
  }
  void dictionaryFilter(VoidCallback change) {
    debounce?.cancel();
    setState(() { change(); entries = []; more = false; });
    savePreference(context, {'dictionaryMode': mode, 'dictionaryLetter': letter});
    load();
  }
  @override
  Widget build(BuildContext context) {
    final visible = notes.where((n) => (category == 'all' || n['kind'] == category) &&
      matchesNote(n, query, field)).toList();
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    final scaler = MediaQuery.textScalerOf(context);
    final searchHeight = (scaler.scale(16) + 58).clamp(74, 128).toDouble();
    final filterHeight = (scaler.scale(14) + 28).clamp(44, 100).toDouble();
    final headerHeight = searchHeight + 2 * filterHeight + 20;
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Directionality(textDirection: TextDirection.ltr,
          child: AppBar(titleSpacing: 10,
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          Image.asset('assets/images/diraasa_internal.png', width: 28, height: 28, semanticLabel: 'Diraasa'),
          const SizedBox(width: 6),
          const Flexible(child: SacredText('Diraasa', key: ValueKey('app-title'), maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24))),
        ]),
        actions: [
          IconButton(key: const ValueKey('devotion-hub'), tooltip: dt('hub'), icon: const Icon(Icons.mosque_outlined, size: 22),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DevotionHub()))),
          const LanguageMenu(), const ThemeMenu(),
          IconButton(tooltip: tr('about'), icon: const Icon(Icons.info_outline, size: 22),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const About()))),
        ],
      ))),
      bottomNavigationBar: keyboard ? null : Directionality(textDirection: TextDirection.ltr,
        child: NavigationBarTheme(data: const NavigationBarThemeData(
          labelTextStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12))), child: NavigationBar(
        selectedIndex: [0, 3, 2, 1].indexOf(tab), onDestinationSelected: (index) {
          final value = [0, 3, 2, 1][index];
          if (tab == value) return;
          focus.unfocus(); debounce?.cancel();
          setState(() { tab = value; query = ''; search.clear(); userDragging = false; keepSearchPinned = false; lastViewportExtent = null; focusRequest++; });
          load();
        },
        destinations: [
          NavigationDestination(icon: const Icon(Icons.edit_note_outlined), label: tr('notes')),
          NavigationDestination(icon: const Icon(Icons.topic_outlined), label: tr('themes')),
          NavigationDestination(icon: const Icon(Icons.people_outline), label: tr('authors')),
          NavigationDestination(icon: const Icon(Icons.menu_book_outlined), label: tr('dictionary')),
        ],
      ))),
      floatingActionButton: tab == 0 && !keyboard ? FloatingActionButton.extended(
        onPressed: () => edit(), icon: const Icon(Icons.add), label: SacredText(tr('new'))) : null,
      body: tab == 2 ? const SafeArea(child: AuthorsPage())
        : tab == 3 ? SafeArea(child: ThemesPage(onOpen: (theme) async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => ThemeNotesPage(theme: theme)));
          }))
        : SafeArea(child: NotificationListener<ScrollMetricsNotification>(
        onNotification: handleMetrics,
        child: NotificationListener<ScrollNotification>(
        onNotification: handleScroll,
        child: RefreshIndicator(
          key: const ValueKey('notes-refresh'),
          onRefresh: () => load(),
          notificationPredicate: (notification) => tab == 0 && notification.depth == 0,
          triggerMode: RefreshIndicatorTriggerMode.onEdge,
          child: CustomScrollView(
        key: ValueKey('results-$tab'), controller: scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
        slivers: [
          SliverToBoxAdapter(child: Padding(key: introKey, padding: const EdgeInsets.fromLTRB(22, 16, 22, 20),
            child: Column(key: const ValueKey('intro-content'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SacredText(tr(tab == 0 ? 'introNotes' : 'introDictionary'),
                style: const TextStyle(fontSize: 30, height: 1.2, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              SacredText(tab == 0 ? 'دراسة · ' + tr('notebook') : 'مختار الصحاح · ' + tr('offline'),
                style: const TextStyle(color: Color(0xffb18b4b))),
            ]),
          )),
          SliverPersistentHeader(key: const ValueKey('search-header'), pinned: true, delegate: StickySearch(
            height: headerHeight,
            child: Material(
              key: const ValueKey('sticky-search'),
              color: Theme.of(context).scaffoldBackgroundColor, elevation: 1,
              child: Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(children: [
                  SizedBox(height: searchHeight, child: TextField(
                    key: const ValueKey('search-field'), controller: search, focusNode: focus,
                    onTap: () { userDragging = false; focusChanged(); }, onChanged: changed, onSubmitted: (_) => focus.unfocus(),
                    textDirection: query.isEmpty ? (tab == 1 ? TextDirection.rtl : Directionality.of(context)) : direction(query),
                    textAlign: TextAlign.start, textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      helperText: loading ? '…' : resultLabel(tab==0?visible.length:dictionaryCount),helperStyle:resultStyle,
                      hintText: tr(tab == 0 ? 'searchNotes' : 'searchDictionary'),
                      hintTextDirection: Directionality.of(context),
                      prefixIcon: const Icon(Icons.search), suffixIcon: IconButton(
                        tooltip: tr('clear'), icon: const Icon(Icons.close),
                        onPressed: () { search.clear(); changed(''); }),
                    ),
                  )),
                  SizedBox(key: const ValueKey('primary-filters'), height: filterHeight, child: tab == 0
                    ? chips(['all', ...kinds], category,
                        (value) {
                          setState(() => category = value);
                          savePreference(context, {'noteCategory': value});
                        }, (value) => tr(value))
                    : chips(['prefix', 'contains', 'fulltext'], mode,
                        (value) => dictionaryFilter(() => mode = value), tr)),
                  SizedBox(key: const ValueKey('secondary-filters'), height: filterHeight, child: tab == 0
                    ? chips(noteSearchFields, field,
                        (value) {
                          setState(() => field = value);
                          savePreference(context, {'noteField': value});
                        }, (value) => tr(value == 'all' ? 'allFields' : value == 'body' ? 'content' : value))
                    : chips(['', ...'ابتثجحخدذرزسشصضطظعغفقكلمنهوي'.split('')], letter,
                        (value) => dictionaryFilter(() => letter = value), (value) => value.isEmpty ? tr('letters') : value)),
                ]),
              ),
            ),
          )),
          if (loading) const SliverToBoxAdapter(child: LinearProgressIndicator(minHeight: 2)),
          if (error != null) SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(16),
            child: Column(children: [
              SacredText(tr('error') + ' : ' + error!), TextButton(onPressed: () => load(), child: SacredText(tr('retry'))),
            ]),
          )),
          if (!loading && error == null && (tab == 0 ? visible.isEmpty : entries.isEmpty))
            SliverFillRemaining(hasScrollBody: false, child: Padding(padding: const EdgeInsets.all(24),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.auto_stories_outlined, size: 48, color: Color(0xffb18b4b)),
                const SizedBox(height: 12), SacredText(tr(tab == 0 ? 'emptyNotes' : 'emptyDictionary'),
                  textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8), SacredText(tr('adjustFilters'), textAlign: TextAlign.center),
              ]),
            )),
          SliverPadding(padding: EdgeInsets.fromLTRB(16, 10, 16, keyboard ? 20 : 100),
            sliver: SliverList(delegate: SliverChildBuilderDelegate((context, index) {
              if (tab == 0) return noteCard(visible[index]);
              if (index == entries.length) return OutlinedButton(
                onPressed: loading ? null : () => load(append: true), child: SacredText(tr('more')));
              return articleCard(entries[index]);
            }, childCount: tab == 0 ? visible.length : entries.length + (more ? 1 : 0))),
          ),
          // Give short/empty result sets enough scroll range to pin the search
          // without deleting the intro or adding a second nested scroll view.
          SliverLayoutBuilder(builder: (context, constraints) {
            final missing = constraints.viewportMainAxisExtent + introExtent - constraints.precedingScrollExtent;
            return SliverToBoxAdapter(child: SizedBox(height: missing > 0 ? missing : 0));
          }),
        ],
      ))))),
    );
  }
  Widget chips(List<String> options, String selected, ValueChanged<String> onSelected, String Function(String) label) =>
    SingleChildScrollView(scrollDirection: Axis.horizontal,
      child: Row(children: options.map((value) => Padding(padding: const EdgeInsetsDirectional.only(end: 7),
        child: ChoiceChip(
          key: ValueKey('filter-$value'), label: SacredText(label(value)), selected: selected == value,
          onSelected: (_) => onSelected(value), visualDensity: VisualDensity.compact,
        ),
      )).toList()),
    );

  Widget noteCard(AppRecord note) => StudyNoteCard(note: note, query: query, field: field,
    onTap: () => preview(note), onAction: (command) => action(command, note));
  Future<void> articleOptions(AppRecord entry) async {
    final value = await showQuickOptions(context, [
      (value: 'open', label: tr('open'), icon: Icons.menu_book_outlined),
      (value: 'study', label: tr('study'), icon: Icons.edit_note_outlined),
    ]);
    if (!mounted) return;
    if (value == 'open') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => Article(entry: entry,
        query: query.isEmpty ? letter : query, mode: mode)));
    } else if (value == 'study') {
      edit({'title': entry['word'], 'body': entry['definition'],
        'author': 'الرازي — مختار الصحاح', 'kind': 'Vocabulaire'});
    }
  }
  Widget articleCard(AppRecord entry) {
    final effectiveQuery = query.isEmpty ? letter : query;
    final fullQuery = mode == 'fulltext' ? query : '';
    return Card(
      key: ValueKey('entry-${entry['id']}'), margin: const EdgeInsets.only(bottom: 12), elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .45))),
      child: InkWell(borderRadius: BorderRadius.circular(22), onLongPress: () => articleOptions(entry),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) =>
          Article(entry: entry, query: effectiveQuery, mode: mode))),
        child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            CircleAvatar(backgroundColor: Theme.of(context).colorScheme.primaryContainer, child: const Icon(Icons.menu_book)),
            const SizedBox(width: 12),
            Expanded(child: MatchText(entry['word'], query: effectiveQuery, mode: mode,
              style: const TextStyle(fontSize: 24, height: 1.7, fontWeight: FontWeight.bold))),
          ]),
          if (entry['root'].toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            MatchText(entry['root'], query: effectiveQuery, mode: mode, compact: true,
              style: const TextStyle(color: Color(0xffb18b4b))),
          ],
          const SizedBox(height: 10),
          MatchText(matchExcerpt(entry['definition'], fullQuery, mode: 'fulltext'),
            query: fullQuery, mode: 'fulltext', maxLines: 4, style: const TextStyle(fontSize: 18, height: 1.85)),
          if (fullQuery.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 6, children: evidenceWords(entry, fullQuery).map((word) =>
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark ? const Color(0xff665024) : const Color(0xffffedac),
                  borderRadius: BorderRadius.circular(8)),
                child: SacredText(word, textDirection: direction(word)),
              )).toList()),
          ],
        ])),
      ),
    );
  }
}
class StickySearch extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;
  StickySearch({required this.height, required this.child});
  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => SizedBox.expand(child: child);
  @override
  bool shouldRebuild(covariant StickySearch oldDelegate) => true;
}
