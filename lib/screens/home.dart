import 'dart:async';
import 'package:flutter/material.dart';
import '../core/app_core.dart';
import '../core/search.dart';
import '../widgets/controls.dart';
import 'editor.dart';
import 'readers.dart';

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}
class _HomeState extends State<Home> {
  int tab = 0, revision = 0;
  List<AppRecord> notes = [], entries = [];
  String query = '', category = 'all', field = 'all', mode = 'prefix', letter = '';
  bool loading = false, more = false, introHidden = false;
  String? error;
  Timer? debounce;
  final search = TextEditingController();
  final scroll = ScrollController();
  final focus = FocusNode();
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
  void focusChanged() {
    if (!focus.hasFocus) return; // No automatic re-expansion on focus loss.
    if (!introHidden) setState(() => introHidden = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && scroll.hasClients) scroll.animateTo(0,
        duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
    });
  }
  Future<void> load({bool append = false}) async {
    debounce?.cancel();
    final token = ++revision;
    final currentTab = tab;
    setState(() { loading = true; error = null; });
    try {
      final data = currentTab == 0 ? await Store.rows('notes') : await Store.rows('search', {
        'q': query, 'letter': letter, 'mode': mode, 'offset': append ? entries.length : 0,
      });
      if (!mounted || revision != token || tab != currentTab) return;
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
      final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
        title: Text(tr('deleteQuestion')), content: Text(tr('deleteWarning')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(tr('delete'))),
        ],
      ));
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
    final searchHeight = (scaler.scale(16) + 40).clamp(56, 110).toDouble();
    final filterHeight = (scaler.scale(14) + 28).clamp(44, 100).toDouble();
    final headerHeight = searchHeight + 2 * filterHeight + 20;
    return Scaffold(
      appBar: AppBar(titleSpacing: 10,
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          Image.asset('assets/images/diraasa_internal.png', width: 28, height: 28, semanticLabel: 'Diraasa'),
          const SizedBox(width: 6),
          const Flexible(child: Text('Diraasa', key: ValueKey('app-title'), maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24))),
        ]),
        actions: [
          const LanguageMenu(), const ThemeMenu(),
          IconButton(tooltip: tr('about'), icon: const Icon(Icons.info_outline, size: 22),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const About()))),
        ],
      ),
      bottomNavigationBar: keyboard ? null : NavigationBar(
        selectedIndex: tab, onDestinationSelected: (value) {
          if (tab == value) return;
          focus.unfocus(); debounce?.cancel();
          setState(() { tab = value; query = ''; search.clear(); });
          load();
        },
        destinations: [
          NavigationDestination(icon: const Icon(Icons.edit_note_outlined), label: tr('notes')),
          NavigationDestination(icon: const Icon(Icons.menu_book_outlined), label: tr('dictionary')),
        ],
      ),
      floatingActionButton: tab == 0 && !keyboard ? FloatingActionButton.extended(
        onPressed: () => edit(), icon: const Icon(Icons.add), label: Text(tr('new'))) : null,
      body: SafeArea(child: CustomScrollView(
        key: ValueKey('results-$tab'), controller: scroll,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          if (!introHidden) SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(22, 16, 22, 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(tr(tab == 0 ? 'introNotes' : 'introDictionary'),
                style: const TextStyle(fontSize: 30, height: 1.2, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Text(tab == 0 ? 'دراسة · ' + tr('notebook') : 'مختار الصحاح · ' + tr('offline'),
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
                    onTap: focusChanged, onChanged: changed, onSubmitted: (_) => focus.unfocus(),
                    textDirection: query.isEmpty ? (tab == 1 ? TextDirection.rtl : Directionality.of(context)) : direction(query),
                    textAlign: TextAlign.start, textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
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
              Text(tr('error') + ' : ' + error!), TextButton(onPressed: () => load(), child: Text(tr('retry'))),
            ]),
          )),
          if (!loading && error == null && (tab == 0 ? visible.isEmpty : entries.isEmpty))
            SliverFillRemaining(hasScrollBody: false, child: Padding(padding: const EdgeInsets.all(24),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.auto_stories_outlined, size: 48, color: Color(0xffb18b4b)),
                const SizedBox(height: 12), Text(tr(tab == 0 ? 'emptyNotes' : 'emptyDictionary'),
                  textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8), Text(tr('adjustFilters'), textAlign: TextAlign.center),
              ]),
            )),
          SliverPadding(padding: EdgeInsets.fromLTRB(16, 10, 16, keyboard ? 20 : 100),
            sliver: SliverList(delegate: SliverChildBuilderDelegate((context, index) {
              if (tab == 0) return noteCard(visible[index]);
              if (index == entries.length) return OutlinedButton(
                onPressed: loading ? null : () => load(append: true), child: Text(tr('more')));
              return articleCard(entries[index]);
            }, childCount: tab == 0 ? visible.length : entries.length + (more ? 1 : 0))),
          ),
        ],
      )),
    );
  }
  Widget chips(List<String> options, String selected, ValueChanged<String> onSelected, String Function(String) label) =>
    SingleChildScrollView(scrollDirection: Axis.horizontal,
      child: Row(children: options.map((value) => Padding(padding: const EdgeInsetsDirectional.only(end: 7),
        child: ChoiceChip(
          key: ValueKey('filter-$value'), label: Text(label(value)), selected: selected == value,
          onSelected: (_) => onSelected(value), visualDensity: VisualDensity.compact,
        ),
      )).toList()),
    );

  Widget noteCard(AppRecord note) {
    final title = note['title'].toString(), body = note['body'].toString(), author = note['author']?.toString() ?? '';
    return Card(
      key: ValueKey('note-${note['id']}'), margin: const EdgeInsets.only(bottom: 12), elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .45))),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: () => preview(note), child: Stack(children: [
        Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(padding: const EdgeInsets.only(right: 92), child: SizedBox(height: 42,
            child: Row(textDirection: TextDirection.ltr, children: [
              CircleAvatar(radius: 20, backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Icon(note['kind'] == 'Vers' ? Icons.format_quote : Icons.edit_note)),
              const SizedBox(width: 10),
              Expanded(child: Text(tr(note['kind'].toString()), maxLines: 2, overflow: TextOverflow.ellipsis,
                textDirection: direction(tr(note['kind'].toString())),
                style: const TextStyle(color: Color(0xffb18b4b), fontWeight: FontWeight.w600))),
            ]),
          )),
          const SizedBox(height: 14),
          MatchText(title, query: noteFieldQuery(field, 'title', query),
            style: TextStyle(fontSize: settings.textSize - 1, height: 1.6, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          MatchText(matchExcerpt(body, noteFieldQuery(field, 'body', query)), query: noteFieldQuery(field, 'body', query),
            maxLines: 4, style: TextStyle(fontSize: settings.textSize - 5, height: 1.8)),
          if (author.isNotEmpty) ...[
            const SizedBox(height: 14), MatchText(author, query: noteFieldQuery(field, 'author', query),
              style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
          const SizedBox(height: 12), Text(tr('created') + ' ' + date(note['created']),
            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ])),
        Positioned(top: 3, right: 3, child: Directionality(textDirection: TextDirection.ltr,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (note['pinned'] == 1) Tooltip(message: tr('pinned'),
              child: Icon(Icons.push_pin, size: 18, color: Theme.of(context).colorScheme.primary)),
            PopupMenuButton<String>(
              tooltip: tr('options'), onSelected: (command) => action(command, note),
              itemBuilder: (_) => [
                PopupMenuItem(value: 'pin', child: Text(tr(note['pinned'] == 1 ? 'unpin' : 'pin'))),
                PopupMenuItem(value: 'edit', child: Text(tr('edit'))),
                PopupMenuItem(value: 'delete', child: Text(tr('delete'))),
              ],
            ),
          ]),
        )),
      ])),
    );
  }
  Widget articleCard(AppRecord entry) {
    final effectiveQuery = query.isEmpty ? letter : query;
    final fullQuery = mode == 'fulltext' ? query : '';
    return Card(
      key: ValueKey('entry-${entry['id']}'), margin: const EdgeInsets.only(bottom: 12), elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .45))),
      child: InkWell(borderRadius: BorderRadius.circular(22),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) =>
          Article(entry: entry, query: effectiveQuery, mode: mode))),
        child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            CircleAvatar(backgroundColor: Theme.of(context).colorScheme.primaryContainer, child: const Icon(Icons.menu_book)),
            const SizedBox(width: 12),
            Expanded(child: MatchText(entry['word'], query: effectiveQuery, mode: mode,
              style: TextStyle(fontSize: settings.textSize + 2, height: 1.7, fontWeight: FontWeight.bold))),
          ]),
          if (entry['root'].toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            MatchText(entry['root'], query: effectiveQuery, mode: mode, compact: true,
              style: const TextStyle(color: Color(0xffb18b4b))),
          ],
          const SizedBox(height: 10),
          MatchText(matchExcerpt(entry['definition'], fullQuery, mode: 'fulltext'),
            query: fullQuery, mode: 'fulltext', maxLines: 4, style: TextStyle(fontSize: settings.textSize - 5, height: 1.85)),
          if (fullQuery.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 6, children: evidenceWords(entry, fullQuery).map((word) =>
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark ? const Color(0xff665024) : const Color(0xffffedac),
                  borderRadius: BorderRadius.circular(8)),
                child: Text(word, textDirection: direction(word)),
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
