import '../widgets/sacred_text.dart';
import 'package:flutter/material.dart';
import '../core/app_core.dart';
import '../core/search.dart';
import '../widgets/controls.dart';
import '../widgets/rich_editor.dart';
import '../widgets/note_card.dart';
import '../widgets/author_avatar.dart';
import 'readers.dart';
import 'editor.dart';
import '../widgets/delete_confirmation.dart';

String catalogIdentity(String text) => text.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

class AuthorsPage extends StatefulWidget {
  const AuthorsPage({super.key});
  @override
  State<AuthorsPage> createState() => _AuthorsPageState();
}
class _AuthorsPageState extends State<AuthorsPage> {
  final queryController = SacredController();
  @override
  void dispose() { queryController.dispose(); super.dispose(); }
  List<AppRecord> authors = [];
  String query = '';
  bool loading = true;
  String? error;
  @override
  void initState() { super.initState(); load(); }
  Future<void> load() async {
    try {
      final data = await Store.rows('authors');
      if (mounted) setState(() { authors = data; loading = false; error = null; });
    } catch (e) { if (mounted) setState(() { error = e.toString(); loading = false; }); }
  }
  Future<void> open([AppRecord? author]) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => author == null ? const AuthorEditor() : AuthorProfile(author: author)));
    if (mounted) load();
  }
  Future<void> authorAction(String command, AppRecord author) async {
    if (command == 'edit') {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => AuthorEditor(author: author)));
      if (mounted) load();
    } else if (await deleteAuthorProfile(context, author) && mounted) { load(); }
  }
  @override
  Widget build(BuildContext context) {
    final visible = authors.where((a) => matchesSearch(a['name'].toString(), query)).toList();
    return RefreshIndicator(onRefresh: load, child: ListView(padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      physics: const AlwaysScrollableScrollPhysics(), children: [
        Row(children: [Expanded(child: SacredText(tr('authors'), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold))),
          IconButton(key: const ValueKey('new-author'), tooltip: tr('newAuthor'), onPressed: () => open(), icon: const Icon(Icons.person_add_alt_1))]),
        Padding(padding: const EdgeInsets.only(bottom: 12), child: SacredText(tr('authorsDescription'), style: Theme.of(context).textTheme.bodySmall)),
        TextField(controller: queryController,key: const ValueKey('author-search'), textDirection: direction(query, fallback: Directionality.of(context)),
          decoration: InputDecoration(helperText:resultLabel(visible.length),helperStyle:resultStyle,hintText: tr('searchReferences'), prefixIcon: const Icon(Icons.search)),
          onChanged: (value) => setState(() => query = value)),
        const SizedBox(height: 16),
        if (loading) const LinearProgressIndicator(),
        if (error != null) ...[SacredText(error!), TextButton(onPressed: load, child: SacredText(tr('retry')))],
        if (!loading && error == null && visible.isEmpty) SacredText(tr('emptyAuthors')),
        ...visible.map((a) {
          final menuKey = GlobalKey<PopupMenuButtonState<String>>();
          return Card(child: ListTile(key: ValueKey('author-${a['id']}'),
            onLongPress: () => menuKey.currentState?.showButtonMenu(),
            leading: AuthorAvatar(photo: a['photo']?.toString() ?? ''),
            title: SacredText(a['name'].toString(), textDirection: direction(a['name'].toString()), textAlign: textAlignment(a['name'].toString())),
            onTap: () => open(a),
            trailing: PopupMenuButton<String>(key: menuKey, tooltip: tr('itemOptions'),
              onSelected: (value) => authorAction(value, a),
              itemBuilder: (_) => [PopupMenuItem(value: 'edit', child: SacredText(tr('edit'))),
                PopupMenuItem(value: 'delete', child: SacredText(tr('delete')))])));
        }),
      ]));
  }
}
Future<bool> deleteAuthorProfile(BuildContext context, AppRecord author) async {
  if (!await confirmDeletion(context, question: tr('deleteAuthorQuestion'), warning: tr('deleteAuthorWarning'))) return false;
  try {
    await Store.call('deleteAuthor', {'id': author['id']});
    if (context.mounted && catalogIdentity(settings.draftAuthor) == catalogIdentity(author['name'].toString())) {
      await savePreference(context, {'draftAuthor': ''});
    }
    return true;
  } catch (e) { if (context.mounted) errorMessage(context, e); return false; }
}
class AuthorProfile extends StatefulWidget {
  const AuthorProfile({super.key, required this.author});
  final AppRecord author;
  @override
  State<AuthorProfile> createState() => _AuthorProfileState();
}
class _AuthorProfileState extends State<AuthorProfile> {
  late AppRecord author = widget.author;
  Future<void> edit() async {
    final updated = await Navigator.push<AppRecord>(context, MaterialPageRoute(builder: (_) => AuthorEditor(author: author)));
    if (updated != null && mounted) setState(() => author = updated);
  }
  Future<void> remove() async {
    if (await deleteAuthorProfile(context, author) && mounted) Navigator.pop(context);
  }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: settings, builder: (context, _) => Scaffold(
    appBar: AppBar(leading: BackButton(key: const ValueKey('author-back'),
      onPressed: () => Navigator.of(context).maybePop()), title: SacredText(tr('author')), actions: [IconButton(tooltip: tr('delete'), onPressed: remove, icon: const Icon(Icons.delete_outline)), IconButton(tooltip: tr('edit'), onPressed: edit, icon: const Icon(Icons.edit_outlined))]),
    body: ListView(padding: const EdgeInsets.all(24), children: [
      Center(child: AuthorAvatar(photo: author['photo']?.toString() ?? '', radius: 64)),
      const SizedBox(height: 20),
      SacredText(author['name'].toString(), textDirection: direction(author['name'].toString()), textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
      const SizedBox(height: 24), const ReadingSize(),
      StudyText(author['bio']?.toString() ?? '', format: author['bio_format']?.toString() ?? '',
        style: TextStyle(fontSize: settings.textSize, height: 1.9)),
    ])));
}
class AuthorEditor extends StatefulWidget {
  const AuthorEditor({super.key, this.author});
  final AppRecord? author;
  @override
  State<AuthorEditor> createState() => _AuthorEditorState();
}
class _AuthorEditorState extends State<AuthorEditor> {
  final form = GlobalKey<FormState>();
  late final TextEditingController name;
  late final StudyController bio;

  late String photo;
  bool saving = false;
  @override
  void initState() {
    super.initState();
    final a = widget.author ?? {};
    name = SacredController(text: a['name']?.toString() ?? '');
    bio = StudyController(text: a['bio']?.toString() ?? '', format: a['bio_format']?.toString() ?? '');
    photo = a['photo']?.toString() ?? '';
  }
  @override
  void dispose() { name.dispose(); bio.dispose(); super.dispose(); }
  Future<void> pickPhoto() async {
    try {
      final path = await Store.call('pickPhoto');
      if (path is String && mounted) setState(() => photo = path);
    } catch (e) { if (mounted) errorMessage(context, e); }
  }
  Future<void> save() async {
    if (saving || !form.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      final values = <String, dynamic>{'id': widget.author?['id'], 'name': name.text.trim(),
        'birth': widget.author?['birth'] ?? '', 'death': widget.author?['death'] ?? '', 'alive': widget.author?['alive'] ?? 1,
        'bio': bio.text, 'bio_format': bio.format, 'photo': photo};
      values['id'] = await Store.call('saveAuthor', values);
      // Reload canonical spelling after case/spacing deduplication.
      final rows = await Store.rows('authors');
      final saved = rows.firstWhere((a) => a['id'] == values['id'], orElse: () => values);
      if (mounted) Navigator.pop(context, saved);
    } catch (e) { if (mounted) { setState(() => saving = false); errorMessage(context, e); } }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: SacredText(tr(widget.author == null ? 'newAuthor' : 'editAuthor')),
      actions: [TextButton(onPressed: saving ? null : save, child: SacredText(tr(saving ? 'saving' : 'save')))]),
    body: Form(key: form, child: ListView(padding: const EdgeInsets.all(20), children: [
      Center(child: AuthorAvatar(photo: photo, radius: 48)),
      Wrap(alignment: WrapAlignment.center, children: [
        TextButton.icon(onPressed: pickPhoto, icon: const Icon(Icons.add_photo_alternate_outlined), label: SacredText(tr('photo'))),
        if (photo.isNotEmpty) TextButton(onPressed: () async {
          if (await confirmDeletion(context, question: tr('removePhoto')) && mounted) setState(() => photo = '');
        }, child: SacredText(tr('removePhoto'))),
      ]),
      TextFormField(key: const ValueKey('author-name'), controller: name, textDirection: direction(name.text),
        onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: tr('fullName')),
        validator: (value) => value!.trim().isEmpty ? tr('requiredName') : null),
      const SizedBox(height: 16),
      const SizedBox(height: 16), FormatToolbar(controller: bio),
      TextFormField(key: const ValueKey('author-bio'), controller: bio, minLines: 8, maxLines: null,
        contextMenuBuilder: (context, state) => richContextMenu(context, state, bio),
        textDirection: direction(bio.text, fallback: Directionality.of(context)), onChanged: (_) => setState(() {}),
        style: const TextStyle(fontSize: 20, height: 1.8), decoration: InputDecoration(labelText: tr('biography'), alignLabelWithHint: true)),
    ])));
}

class ThemesPage extends StatefulWidget {
  const ThemesPage({super.key, required this.onOpen});
  final Future<void> Function(String) onOpen;
  @override
  State<ThemesPage> createState() => _ThemesPageState();
}
class _ThemesPageState extends State<ThemesPage> {
  final queryController = SacredController();
  @override
  void dispose() { queryController.dispose(); super.dispose(); }
  List<AppRecord> themes = [];
  Map<String, int> counts = {};
  String query = '';
  bool loading = true;
  String? error;
  @override
  void initState() { super.initState(); load(); }
  Future<void> load() async {
    try {
      final data = await Store.rows('references', {'field': 'title'});
      final entries = await Store.rows('notes');
      final totals = <String, int>{};
      for (final note in entries) {
        final key = catalogIdentity(note['title'].toString());
        totals[key] = (totals[key] ?? 0) + 1;
      }
      if (mounted) setState(() { themes = data; counts = totals; loading = false; error = null; });
    } catch (e) { if (mounted) setState(() { error = e.toString(); loading = false; }); }
  }
  Future<void> add() async {
    final value = await showDialog<String>(context: context, builder: (_) => const NewThemeDialog());
    if (value == null) return;
    try { await Store.call('saveTheme', {'label': value}); if (mounted) load(); }
    catch (e) { if (mounted) errorMessage(context, e); }
  }
  Future<void> remove(String label) async {
    if (!await confirmDeletion(context, question: tr('deleteThemeQuestion'))) return;
    try {
      await Store.call('deleteTheme', {'label': label});
      if (mounted && catalogIdentity(settings.draftTitle) == catalogIdentity(label)) await savePreference(context, {'draftTitle': ''});
      if (mounted) load();
    }
    catch (e) { if (mounted) errorMessage(context, e); }
  }
  Future<void> rename(String label) async {
    final value = await showDialog<String>(context: context, builder: (_) => NewThemeDialog(initialLabel: label));
    if (value == null || value == label) return;
    try {
      final canonical = await Store.call('renameTheme', {'oldLabel': label, 'label': value});
      if (mounted && catalogIdentity(settings.draftTitle) == catalogIdentity(label)) {
        await savePreference(context, {'draftTitle': canonical is String ? canonical : value});
      }
      if (mounted) load();
    } catch (e) { if (mounted) errorMessage(context, e); }
  }
  @override
  Widget build(BuildContext context) {
    final visible = themes.where((row) => matchesSearch(row['label'].toString(), query)).toList();
    return RefreshIndicator(onRefresh: load, child: ListView(padding: const EdgeInsets.all(20),
      physics: const AlwaysScrollableScrollPhysics(), children: [
        Row(children: [Expanded(child: SacredText(tr('themes'), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold))),
          IconButton(key: const ValueKey('new-theme'), tooltip: tr('newTheme'), onPressed: add, icon: const Icon(Icons.add))]),
        Padding(padding: const EdgeInsets.only(bottom: 12), child: SacredText(tr('themesDescription'), style: Theme.of(context).textTheme.bodySmall)),
        const SizedBox(height: 16),
        TextField(controller: queryController,decoration: InputDecoration(helperText:resultLabel(visible.length),helperStyle:resultStyle,hintText: tr('searchReferences'), prefixIcon: const Icon(Icons.search)),
          textDirection: direction(query, fallback: Directionality.of(context)), onChanged: (value) => setState(() => query = value)),
        const SizedBox(height: 16),
        if (loading) const LinearProgressIndicator(),
        if (error != null) ...[SacredText(error!), TextButton(onPressed: load, child: SacredText(tr('retry')))],
        if (!loading && error == null && visible.isEmpty) SacredText(tr('emptyThemes')),
        ...visible.map((row) {
          final label = row['label'].toString();
          final count = counts[catalogIdentity(label)] ?? 0;
          final menuKey = GlobalKey<PopupMenuButtonState<String>>();
          return Card(child: ListTile(onLongPress: () => menuKey.currentState?.showButtonMenu(),leading: const Icon(Icons.topic_outlined),
            title: SacredText(label, maxLines: 2, overflow: TextOverflow.ellipsis, textDirection: direction(label), textAlign: textAlignment(label)),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [SacredText('$count'),
              PopupMenuButton<String>(key: menuKey, tooltip: tr('itemOptions'),
                onSelected: (value) { if (value == 'edit') { rename(label); } else { remove(label); } },
                itemBuilder: (_) => [PopupMenuItem(value: 'edit', child: SacredText(tr('edit'))),
                  if (count == 0) PopupMenuItem(value: 'delete', child: SacredText(tr('delete')))])]), onTap: () async { await widget.onOpen(label); if (mounted) load(); }));
        }),
      ]));
  }
}

/// A route inside Themes: no Home instance and no tab switch.
class ThemeNotesPage extends StatefulWidget {
  const ThemeNotesPage({super.key, required this.theme});
  final String theme;
  @override
  State<ThemeNotesPage> createState() => _ThemeNotesPageState();
}
class _ThemeNotesPageState extends State<ThemeNotesPage> {
  final queryController = SacredController();
  @override
  void dispose() { queryController.dispose(); super.dispose(); }
  List<AppRecord> notes = [];
  String query = '';
  bool loading = true;
  String? error;
  @override
  void initState() { super.initState(); load(); }
  Future<void> load() async {
    try {
      final rows = await Store.rows('notes');
      if (mounted) setState(() {
        notes = rows.where((note) => catalogIdentity(note['title'].toString()) == catalogIdentity(widget.theme)).toList();
        loading = false; error = null;
      });
    } catch (e) { if (mounted) setState(() { loading = false; error = e.toString(); }); }
  }
  Future<void> preview(AppRecord note) async {
    FocusScope.of(context).unfocus();
    await showModalBottomSheet<void>(context: context, isScrollControlled: true, showDragHandle: true,
      builder: (_) => FractionallySizedBox(heightFactor: .85, child: NotePreview(note: note, query: query)));
  }
  Future<void> action(String command, AppRecord note) async {
    if (command == 'edit') {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => Editor(note: note)));
      if (mounted) load();
      return;
    }
    if (command == 'delete') {
      final confirmed = await confirmDeletion(context, question: tr('deleteQuestion'));
      if (confirmed != true) return;
    }
    try { await Store.call(command, {'id': note['id']}); if (mounted) load(); }
    catch (e) { if (mounted) errorMessage(context, e); }
  }
  @override
  Widget build(BuildContext context) {
    final visible = notes.where((note) => matchesNote(note, query, 'all')).toList();
    return Scaffold(
      appBar: AppBar(leading: BackButton(key: const ValueKey('theme-notes-back'),
        onPressed: () => Navigator.of(context).maybePop()),
        title: SacredText(widget.theme, maxLines: 1, overflow: TextOverflow.ellipsis,
          textDirection: direction(widget.theme))),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(16), child: TextField(controller: queryController,
          key: const ValueKey('theme-notes-search'),
          textDirection: direction(query, fallback: Directionality.of(context)),
          decoration: InputDecoration(helperText:resultLabel(visible.length),helperStyle:resultStyle,hintText: tr('searchNotes'), prefixIcon: const Icon(Icons.search)),
          onChanged: (value) => setState(() => query = value))),
        if (loading) const LinearProgressIndicator(),
        if (error != null) ...[SacredText(error!), TextButton(onPressed: load, child: SacredText(tr('retry')))],
        Expanded(child: RefreshIndicator(onRefresh: load, child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          itemCount: visible.isEmpty ? 1 : visible.length,
          itemBuilder: (context, index) {
            if (visible.isEmpty) return Padding(padding: const EdgeInsets.all(24),
              child: SacredText(loading ? '' : tr('emptyNotes'), textAlign: TextAlign.center));
            final note = visible[index];
            return StudyNoteCard(note: note, query: query,
              onTap: () => preview(note), onAction: (command) => action(command, note));
          }))),
      ]),
    );
  }
}

class NewThemeDialog extends StatefulWidget {
  const NewThemeDialog({super.key, this.initialLabel});
  final String? initialLabel;
  @override
  State<NewThemeDialog> createState() => _NewThemeDialogState();
}
class _NewThemeDialogState extends State<NewThemeDialog> {
  late final controller = SacredController(text: widget.initialLabel ?? '');
  final form = GlobalKey<FormState>();
  @override
  void dispose() { controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AlertDialog(title: SacredText(tr(widget.initialLabel == null ? 'newTheme' : 'editTheme')),
    content: Form(key: form, child: TextFormField(key: const ValueKey('new-theme-name'), controller: controller,
      autofocus: true, textDirection: direction(controller.text, fallback: Directionality.of(context)),
      onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: tr('title')),
      validator: (value) => value!.trim().isEmpty ? tr('requiredTitle') : null)),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: SacredText(tr('cancel'))),
      FilledButton(onPressed: () { if (form.currentState!.validate()) Navigator.pop(context, controller.text.trim()); }, child: SacredText(tr('save')))]);
}
