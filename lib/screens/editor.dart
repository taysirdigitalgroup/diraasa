import 'package:flutter/material.dart';
import '../core/app_core.dart';
import '../widgets/controls.dart';

class Editor extends StatefulWidget {
  final AppRecord? note;
  const Editor({super.key, this.note});
  @override
  State<Editor> createState() => _EditorState();
}
class _EditorState extends State<Editor> {
  late final TextEditingController title, body, author;
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
    title = TextEditingController(text: widget.note?['title'] ?? settings.draftTitle);
    author = TextEditingController(text: widget.note?['author'] ?? settings.draftAuthor);
    body = TextEditingController(text: widget.note?['body'] ?? '');
    kind = widget.note?['kind'] ?? settings.draftKind;
  }
  void settingsChanged() { if (mounted) setState(() {}); }
  @override
  void dispose() { settings.removeListener(settingsChanged); title.dispose(); author.dispose(); body.dispose(); bodyFocus.dispose(); super.dispose(); }
  Future<void> save() async {
    if (saving || !form.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      await Store.call('save', {'id': noteId, 'title': title.text.trim(), 'body': body.text.trim(),
        'author': author.text.trim(), 'kind': kind});
    } catch (e) {
      if (mounted) { setState(() => saving = false); errorMessage(context, e); }
      return;
    }
    if (!mounted) return;
    // A successful save becomes a fresh entry: never overwrite the saved note
    // when the retained title/author/category are reused.
    setState(() { noteId = null; created = null; body.clear(); saving = false; });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('saved'))));
    await savePreference(context, {'draftTitle': title.text, 'draftAuthor': author.text, 'draftKind': kind});
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tr(noteId == null ? 'new' : 'editNote'),
      maxLines: 1, overflow: TextOverflow.ellipsis),
      actions: [TextButton(onPressed: saving ? null : save, child: Text(tr(saving ? 'saving' : 'save')))]),
    body: Form(key: form, child: ListView(padding: const EdgeInsets.all(20), children: [
      Text(created == null ? tr('autoDate') : tr('created') + ' ' + date(created)),
      const SizedBox(height: 16),
      DropdownButtonFormField<String>(
        key: ValueKey('kind-' + kind),
        initialValue: kind, decoration: InputDecoration(labelText: tr('type')),
        items: kinds.map((value) => DropdownMenuItem(value: value, child: Text(tr(value)))).toList(),
        onChanged: (value) => setState(() => kind = value!)),
      const SizedBox(height: 16),
      TextFormField(key: const ValueKey('note-title'), controller: title,
        textDirection: direction(title.text, fallback: Directionality.of(context)), textAlign: TextAlign.start,
        onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: tr('title')),
        validator: (value) => value!.trim().isEmpty ? tr('requiredTitle') : null),
      const SizedBox(height: 16),
      TextFormField(key: const ValueKey('note-author'), controller: author,
        textDirection: direction(author.text, fallback: Directionality.of(context)), textAlign: TextAlign.start,
        onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: tr('optionalAuthor'))),
      const SizedBox(height: 12),
      const ReadingSize(),
      const SizedBox(height: 12),
      TextFormField(key: const ValueKey('note-body'), controller: body, focusNode: bodyFocus,
        textDirection: direction(body.text, fallback: Directionality.of(context)), textAlign: TextAlign.start,
        onChanged: (_) => setState(() {}), minLines: 10, maxLines: null,
        style: TextStyle(fontSize: settings.textSize, height: 1.85),
        decoration: InputDecoration(labelText: tr('body'), alignLabelWithHint: true),
        validator: (value) => value!.trim().isEmpty ? tr('requiredBody') : null),
    ])),
  );
}
