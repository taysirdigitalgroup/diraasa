import '../widgets/sacred_text.dart';
import 'package:flutter/material.dart';
import '../core/app_core.dart';
import '../widgets/controls.dart';
import '../core/search.dart';
import '../widgets/rich_editor.dart';

class Editor extends StatefulWidget {
  final AppRecord? note;
  const Editor({super.key, this.note});
  @override
  State<Editor> createState() => _EditorState();
}
class _EditorState extends State<Editor> {
  late final TextEditingController title, author;
  late final StudyController body;
  late String kind;
  dynamic noteId, created;
  final form = GlobalKey<FormState>();
  final bodyFocus = FocusNode();
  bool saving = false;
  @override
  void initState() {
    super.initState();
    settings.addListener(settingsChanged);
    noteId = widget.note?['id'];
    created = widget.note?['created'];
    title = SacredController(text: widget.note?['title'] ?? settings.draftTitle);
    author = SacredController(text: widget.note?['author'] ?? settings.draftAuthor);
    body = StudyController(text: widget.note?['body'] ?? '', format: widget.note?['body_format'] ?? '');
    kind = widget.note?['kind'] ?? settings.draftKind;
  }
  void settingsChanged() { if (mounted) setState(() {}); }
  @override
  void dispose() { settings.removeListener(settingsChanged); title.dispose(); author.dispose(); body.dispose(); bodyFocus.dispose(); super.dispose(); }
  Future<void> chooseReference(String field, TextEditingController controller) async {
    FocusScope.of(context).unfocus();
    try {
      final rows = await Store.rows('references', {'field': field});
      if (!mounted) return;
      final value = await showModalBottomSheet<String>(
        context: context, isScrollControlled: true, useSafeArea: true,
        builder: (_) => ReferencePicker(field: field,
          values: rows.map((row) => row['label'].toString()).toList()),
      );
      if (value != null && mounted) setState(() {
        controller.value = TextEditingValue(text: value, selection: TextSelection.collapsed(offset: value.length));
      });
    } catch (e) { if (mounted) errorMessage(context, e); }
  }
  Future<void> save() async {
    if (saving || !form.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      await Store.call('save', {'id': noteId, 'title': title.text.trim(), 'body': body.text,
        'author': author.text.trim(), 'kind': kind, 'body_format': body.format});
    } catch (e) {
      if (mounted) { setState(() => saving = false); errorMessage(context, e); }
      return;
    }
    if (!mounted) return;
    // A successful save becomes a fresh entry: never overwrite the saved note
    // when the retained title/author/category are reused.
    setState(() { noteId = null; created = null; body.clear(); saving = false; });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: SacredText(tr('saved'))));
    await savePreference(context, {'draftTitle': title.text, 'draftAuthor': author.text, 'draftKind': kind});
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: SacredText(tr(noteId == null ? 'new' : 'editNote'),
      maxLines: 1, overflow: TextOverflow.ellipsis),
      actions: [TextButton(onPressed: saving ? null : save, child: SacredText(tr(saving ? 'saving' : 'save')))]),
    body: Form(key: form, child: ListView(padding: const EdgeInsets.all(20), children: [
      SacredText(created == null ? tr('autoDate') : tr('created') + ' ' + date(created)),
      const SizedBox(height: 16),
      DropdownButtonFormField<String>(
        key: ValueKey('kind-' + kind),
        initialValue: kind, isExpanded: true, menuMaxHeight: 360, decoration: InputDecoration(labelText: tr('type')),
        items: kinds.map((value) => DropdownMenuItem(value: value, child: SacredText(tr(value)))).toList(),
        onChanged: (value) => setState(() => kind = value!)),
      const SizedBox(height: 16),
      TextFormField(key: const ValueKey('note-title'), controller: title,
        textDirection: direction(title.text, fallback: Directionality.of(context)), textAlign: TextAlign.start,
        onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: tr('title'), suffixIcon: IconButton(
          key: const ValueKey('choose-title'), tooltip: tr('chooseTitle'),
          onPressed: () => chooseReference('title', title), icon: const Icon(Icons.list_alt_rounded))),
        validator: (value) => value!.trim().isEmpty ? tr('requiredTitle') : null),
      const SizedBox(height: 16),
      TextFormField(key: const ValueKey('note-author'), controller: author,
        textDirection: direction(author.text, fallback: Directionality.of(context)), textAlign: TextAlign.start,
        onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: tr('optionalAuthor'), suffixIcon: IconButton(
          key: const ValueKey('choose-author'), tooltip: tr('chooseAuthor'),
          onPressed: () => chooseReference('author', author), icon: const Icon(Icons.person_search_outlined)))),
      const SizedBox(height: 12),
      const ReadingSize(),
      const SizedBox(height: 12),
      FormatToolbar(controller: body),
      TextFormField(contextMenuBuilder: (context, state) => richContextMenu(context, state, body), key: const ValueKey('note-body'), controller: body, focusNode: bodyFocus,
        textDirection: direction(body.text, fallback: Directionality.of(context)), textAlign: TextAlign.start,
        onChanged: (_) => setState(() {}), minLines: 10, maxLines: null,
        style: TextStyle(fontSize: settings.textSize, height: 1.85),
        decoration: InputDecoration(labelText: tr('body'), alignLabelWithHint: true),
        validator: (value) => value!.trim().isEmpty ? tr('requiredBody') : null),
    ])),
  );
}

class ReferencePicker extends StatefulWidget {
  const ReferencePicker({super.key, required this.field, required this.values});
  final String field;
  final List<String> values;
  @override
  State<ReferencePicker> createState() => _ReferencePickerState();
}
class _ReferencePickerState extends State<ReferencePicker> {
  final queryController = SacredController();
  @override
  void dispose() { queryController.dispose(); super.dispose(); }
  String query = '';
  @override
  Widget build(BuildContext context) {
    final visible = widget.values.where((value) => matchesSearch(value, query)).toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(height: MediaQuery.sizeOf(context).height * .72,
        child: Column(children: [
          ListTile(title: SacredText(tr(widget.field == 'title' ? 'chooseTitle' : 'chooseAuthor')),
            trailing: IconButton(tooltip: tr('close'), icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context))),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: TextField(controller: queryController,
            key: const ValueKey('reference-search'),
            textDirection: direction(query, fallback: Directionality.of(context)),
            onChanged: (value) => setState(() => query = value),
            decoration: InputDecoration(hintText: tr('searchReferences'), prefixIcon: const Icon(Icons.search)))),
          const SizedBox(height: 12),
          Expanded(child: visible.isEmpty
            ? Center(child: Padding(padding: const EdgeInsets.all(24), child: SacredText(tr('noReferences'))))
            : ListView.builder(itemCount: visible.length, itemBuilder: (context, index) => ListTile(
                title: SacredText(visible[index], textDirection: direction(visible[index]),
                  textAlign: textAlignment(visible[index])),
                onTap: () => Navigator.pop(context, visible[index])))),
        ])),
    );
  }
}
