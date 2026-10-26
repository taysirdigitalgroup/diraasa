import 'sacred_text.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/app_core.dart';
import '../core/search.dart';

// Plain text stays authoritative for search/copy. Formatting is a sidecar.
class StudyController extends TextEditingController {
  StudyController({String text = '', String format = ''}) : super(text: text) {
    marks = List.generate(text.length, (_) => <String, bool>{});
    try {
      for (final run in jsonDecode(format) as List) {
        final start = (run['start'] as num).toInt().clamp(0, text.length).toInt();
        final end = (run['end'] as num).toInt().clamp(start, text.length).toInt();
        final attrs = Map<String, bool>.from(run['attrs'] as Map);
        for (var i = start; i < end; i++) { marks[i].addAll(attrs); }
      }
    } catch (_) { /* Existing plain-text notes have no sidecar. */ }
    previous = text;
    addListener(track);
  }
  late List<Map<String, bool>> marks;
  late String previous;
  void track() {
    if (text == previous) return;
    var start = 0;
    while (start < text.length && start < previous.length && text.codeUnitAt(start) == previous.codeUnitAt(start)) { start++; }
    var oldEnd = previous.length, newEnd = text.length;
    while (oldEnd > start && newEnd > start && previous.codeUnitAt(oldEnd - 1) == text.codeUnitAt(newEnd - 1)) { oldEnd--; newEnd--; }
    final inherited = start > 0 && start <= marks.length ? Map<String, bool>.from(marks[start - 1]) : <String, bool>{};
    marks.replaceRange(start, oldEnd, List.generate(newEnd - start, (_) => Map<String, bool>.from(inherited)));
    previous = text;
  }
  List<Map<String, dynamic>> get runs {
    final result = <Map<String, dynamic>>[];
    var i = 0;
    while (i < marks.length) {
      var end = i + 1;
      while (end < marks.length && same(marks[i], marks[end])) { end++; }
      if (marks[i].isNotEmpty) result.add({'start': i, 'end': end, 'attrs': marks[i]});
      i = end;
    }
    return result;
  }
  bool same(Map<String, bool> a, Map<String, bool> b) => a.length == b.length && a.keys.every((key) => a[key] == b[key]);
  String get format => jsonEncode(runs);
  TextStyle styled(TextStyle base, Map<String, bool> attrs) => base.copyWith(
    fontWeight: attrs['b'] == true || attrs['h'] == true ? FontWeight.bold : base.fontWeight,
    fontStyle: attrs['i'] == true || attrs['q'] == true ? FontStyle.italic : base.fontStyle,
    decoration: attrs['u'] == true ? TextDecoration.underline : base.decoration,
    fontSize: attrs['h'] == true ? (base.fontSize ?? 18) * 1.3 : base.fontSize,
  );
  void apply(String attribute) {
    if (!selection.isValid || text.isEmpty) return;
    var start = selection.start, end = selection.end;
    if (selection.isCollapsed) {
      start = text.lastIndexOf('\n', start - 1) + 1;
      end = text.indexOf('\n', selection.end);
      if (end < 0) end = text.length;
    }
    final enabled = !marks.sublist(start, end).every((m) => m[attribute] == true);
    for (var i = start; i < end; i++) {
      if (enabled) { marks[i][attribute] = true; } else { marks[i].remove(attribute); }
    }
    notifyListeners();
  }
  void list() {
    if (!selection.isValid) return;
    final start = text.lastIndexOf('\n', selection.start - 1) + 1;
    var end = text.indexOf('\n', selection.end);
    if (end < 0) end = text.length;
    final lines = text.substring(start, end).split('\n');
    final remove = lines.every((line) => line.startsWith('• '));
    final replacement = lines.map((line) => remove ? line.substring(2) : '• ' + line).join('\n');
    value = TextEditingValue(text: text.replaceRange(start, end, replacement),
      selection: TextSelection.collapsed(offset: start + replacement.length));
  }
  Future<void> paste(BuildContext context) async {
    try {
      final raw = await Store.call('richClipboard');
      if (raw is! Map || !selection.isValid) return;
      final inserted = raw['text']?.toString() ?? '';
      final start = selection.start, end = selection.end;
      value = TextEditingValue(text: text.replaceRange(start, end, inserted),
        selection: TextSelection.collapsed(offset: start + inserted.length));
      for (var i = start; i < start + inserted.length; i++) { marks[i].clear(); }
      for (final run in (raw['runs'] as List? ?? [])) {
        final from = (run['start'] as num).toInt().clamp(0, inserted.length).toInt();
        final to = (run['end'] as num).toInt().clamp(from, inserted.length).toInt();
        final attrs = Map<String, bool>.from(run['attrs'] as Map);
        for (var i = start + from; i < start + to; i++) { marks[i].addAll(attrs); }
      }
      notifyListeners();
    } catch (e) { if (context.mounted) errorMessage(context, e); }
  }
  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    final base = style ?? const TextStyle();
    if (text.isEmpty || marks.every((m) => m.isEmpty)) return emphasizeNames(super.buildTextSpan(context: context, style: style, withComposing: withComposing));
    final spans = <TextSpan>[];
    var start = 0;
    while (start < text.length) {
      var end = start + 1;
      while (end < text.length && same(marks[start], marks[end])) { end++; }
      spans.add(TextSpan(text: text.substring(start, end), style: styled(base, marks[start])));
      start = end;
    }
    return emphasizeNames(TextSpan(style: base, children: spans));
  }
  @override
  void dispose() { removeListener(track); super.dispose(); }
}

class FormatToolbar extends StatelessWidget {
  const FormatToolbar({super.key, required this.controller});
  final StudyController controller;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(scrollDirection: Axis.horizontal,
    child: Row(children: [
      for (final item in <(String, IconData)>[('bold', Icons.format_bold), ('italic', Icons.format_italic),
        ('underline', Icons.format_underlined), ('heading', Icons.title), ('list', Icons.format_list_bulleted), ('quote', Icons.format_quote), ('paste', Icons.content_paste)])
        IconButton(tooltip: tr(item.$1), icon: Icon(item.$2), onPressed: () {
          if (item.$1 == 'paste') { controller.paste(context); }
          else if (item.$1 == 'list') { controller.list(); }
          else { controller.apply({'bold': 'b', 'italic': 'i', 'underline': 'u', 'heading': 'h', 'quote': 'q'}[item.$1]!); }
        }),
    ]));
}

Widget richContextMenu(BuildContext context, EditableTextState state, StudyController controller) =>
  AdaptiveTextSelectionToolbar.buttonItems(anchors: state.contextMenuAnchors,
    buttonItems: state.contextMenuButtonItems.map((item) => item.type == ContextMenuButtonType.paste
      ? ContextMenuButtonItem(type: ContextMenuButtonType.paste, onPressed: () {
          state.hideToolbar(); controller.paste(context);
        }) : item).toList());

class StudyText extends StatelessWidget {
  const StudyText(this.text, {super.key, this.format = '', this.query = '', this.selectable = true, this.maxLines, required this.style});
  final String text, format, query;
  final TextStyle style;
  final bool selectable;
  final int? maxLines;
  @override
  Widget build(BuildContext context) {
    final display = maxLines == null ? text : matchExcerpt(text, query);
    if (format.isEmpty || format == '[]') return MatchText(display, selectable: selectable,
      maxLines: maxLines, query: query, style: style);
    final controller = StudyController(text: text, format: format);
    if (display != text) {
      final start = text.length - display.length + 1;
      final kept = controller.marks.sublist(start);
      controller.text = display;
      controller.marks = [<String, bool>{}, ...kept];
    }
    final span = controller.buildTextSpan(context: context, style: style, withComposing: false);
    final quoted = controller.marks.any((mark) => mark['q'] == true);
    controller.dispose();
    final content = selectable
      ? SacredSelectableText.rich(span, textDirection: direction(display), textAlign: textAlignment(display))
      : SacredText.rich(span, textDirection: direction(display), textAlign: textAlignment(display),
          maxLines: maxLines, overflow: maxLines == null ? TextOverflow.clip : TextOverflow.ellipsis);
    final highlighted = highlightStudyText(context, display, query, content);
    if (!quoted) return highlighted;
    return Container(padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: .05),
        border: BorderDirectional(start: BorderSide(color: Theme.of(context).colorScheme.primary, width: 3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Align(alignment: AlignmentDirectional.centerStart,
          child: Icon(Icons.format_quote, size: 20, color: Theme.of(context).colorScheme.primary)),
        highlighted,
      ]));
  }
}
