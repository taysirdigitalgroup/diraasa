import '../widgets/sacred_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'app_core.dart';

final _marks = RegExp(r'[\u0610-\u061a\u064b-\u065f\u0670\u06d6-\u06edـ]');
final _harakat = RegExp(r'[\u0610-\u061a\u064b-\u065f\u0670\u06d6-\u06ed]');
// Harakat or explicit uppercase request the original spelling. Hamza alone
// remains tolerant, like other unvocalized Arabic input.
bool preciseSearch(String query) => _harakat.hasMatch(query) || query != query.toLowerCase();
final preciseTokenPattern = RegExp(r'[\p{L}\p{N}\p{M}]+', unicode: true);
final tokenPattern = RegExp(r'[\p{L}\p{N}]+', unicode: true);
String normalize(String value) => value.toLowerCase().replaceAll(_marks, '')
    .replaceAll(RegExp('[أإآٱ]'), 'ا').replaceAll('ى', 'ي');

class MappedText {
  final String original;
  final bool compact, precise;
  late final String value;
  final List<int> starts = [], ends = [];
  MappedText(this.original, {this.compact = false, this.precise = false}) {
    final out = StringBuffer();
    for (final m in RegExp(r'.', dotAll: true, unicode: true).allMatches(original)) {
      final normalized = precise ? m.group(0)! : normalize(m.group(0)!);
      if (normalized.isEmpty) {
        if (ends.isNotEmpty) ends[ends.length - 1] = m.end;
        continue;
      }
      if (compact && normalized.trim().isEmpty) continue;
      out.write(normalized);
      for (var i = 0; i < normalized.length; i++) { starts.add(m.start); ends.add(m.end); }
    }
    value = out.toString();
  }
}

List<TextRange> matchRanges(String text, String query, {String mode = 'contains', bool compact = false, bool? precise}) {
  final strict = precise ?? preciseSearch(query);
  final mapped = MappedText(text, compact: compact, precise: strict);
  var needle = strict ? query.trim() : normalize(query.trim());
  if (compact) needle = needle.replaceAll(' ', '');
  if (needle.isEmpty) return [];
  final matches = <TextRange>[];
  void add(int start, int end) {
    if (start < end && end <= mapped.ends.length) {
      matches.add(TextRange(start: mapped.starts[start], end: mapped.ends[end - 1]));
    }
  }
  if (mode == 'fulltext') {
    final tokens = strict ? preciseTokenPattern : tokenPattern;
    final queries = tokens.allMatches(needle).map((m) => m.group(0)!).toSet();
    for (final token in tokens.allMatches(mapped.value)) {
      for (final part in queries) {
        if (token.group(0)!.startsWith(part)) add(token.start, token.start + part.length);
      }
    }
  } else if (mode == 'prefix') {
    if (mapped.value.startsWith(needle)) add(0, needle.length);
  } else {
    var offset = 0;
    while (offset < mapped.value.length) {
      final index = mapped.value.indexOf(needle, offset);
      if (index < 0) break;
      add(index, index + needle.length);
      offset = index + needle.length;
    }
  }
  matches.sort((a, b) => a.start.compareTo(b.start));
  final merged = <TextRange>[];
  for (final range in matches) {
    if (merged.isNotEmpty && range.start <= merged.last.end) {
      final last = merged.removeLast();
      merged.add(TextRange(start: last.start, end: range.end > last.end ? range.end : last.end));
    } else { merged.add(range); }
  }
  return merged;
}
List<String> noteFieldKeys(String field) {
  switch (field) {
    case 'title':
    case 'Titre': return const ['title'];
    case 'author':
    case 'Auteur': return const ['author'];
    case 'body':
    case 'Contenu': return const ['body'];
    default: return const ['title', 'body', 'author'];
  }
}
String noteFieldQuery(String field, String target, String query) =>
    noteFieldKeys(field).contains(target) ? query : '';

bool matchesSearch(String text, String query) {
  final precise = preciseSearch(query);
  final needle = precise ? query.trim() : normalize(query.trim());
  return needle.isEmpty || (precise ? text : normalize(text)).contains(needle);
}
bool matchesNote(AppRecord n, String query, String field) =>
    noteFieldKeys(field).any((key) => matchesSearch(n[key]?.toString() ?? '', query));
String matchExcerpt(String text, String query, {String mode = 'contains'}) {
  final ranges = matchRanges(text, query, mode: mode);
  if (ranges.isEmpty || ranges.first.start < 90) return text;
  final start = (ranges.first.start - 45).clamp(0, text.length).toInt();
  return '…' + text.substring(start);
}
class MatchText extends StatelessWidget {
  final String text, query, mode;
  final TextStyle? style;
  final int? maxLines;
  final bool selectable, compact;
  const MatchText(this.text, {super.key, this.query = '', this.mode = 'contains',
    this.style, this.maxLines, this.selectable = false, this.compact = false});
  @override
  Widget build(BuildContext context) {
    final ranges = matchRanges(text, query, mode: mode, compact: compact);
    final color = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xff665024) : const Color(0xffffedac);
    // Keep a single shaping run: never change weight, split spans or insert
    // characters inside a joined Arabic word just to color a match.
    final effectiveStyle = DefaultTextStyle.of(context).style.merge(style);
    final Widget content = selectable
      ? SacredSelectableText(text, style: effectiveStyle,
          textDirection: direction(text), textAlign: textAlignment(text))
      : SacredText(text, style: effectiveStyle,
          textDirection: direction(text), textAlign: textAlignment(text),
          maxLines: maxLines, overflow: maxLines == null ? TextOverflow.clip : TextOverflow.ellipsis);
    return _MatchBackground(ranges: ranges, color: color, child: content);
  }
}

/// Paint behind the actual laid-out paragraph/editable, without re-shaping it.
class _MatchBackground extends SingleChildRenderObjectWidget {
  final List<TextRange> ranges;
  final Color color;
  const _MatchBackground({required this.ranges, required this.color, required super.child});
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMatchBackground(ranges, color);
  @override
  void updateRenderObject(BuildContext context, covariant _RenderMatchBackground renderObject) {
    renderObject.update(ranges, color);
  }
}
class _RenderMatchBackground extends RenderProxyBox {
  List<TextRange> _ranges;
  Color _color;
  _RenderMatchBackground(this._ranges, this._color);
  void update(List<TextRange> ranges, Color color) {
    _ranges = ranges; _color = color; markNeedsPaint();
  }
  RenderBox? findText(RenderObject? node) {
    if (node is RenderParagraph) return node;
    if (node is RenderEditable) return node;
    RenderBox? found;
    node?.visitChildren((child) { found ??= findText(child); });
    return found;
  }
  @override
  void paint(PaintingContext context, Offset offset) {
    final target = _ranges.isEmpty ? null : findText(child);
    if (target != null) {
      final canvas = context.canvas;
      final paint = Paint()..color = _color;
      final transform = target.getTransformTo(this);
      canvas.save();
      canvas.clipRect(offset & size);
      for (final range in _ranges) {
        final selection = TextSelection(baseOffset: range.start, extentOffset: range.end);
        final boxes = target is RenderParagraph
            ? target.getBoxesForSelection(selection)
            : (target as RenderEditable).getBoxesForSelection(selection);
        for (final box in boxes) {
          final rect = MatrixUtils.transformRect(transform, box.toRect()).shift(offset);
          canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(2)), paint);
        }
      }
      canvas.restore();
    }
    super.paint(context, offset);
  }
}

/// Each queried FTS token has a visible source witness even if its occurrence
/// lies beyond the truncated preview. Compact roots are part of the FTS index.
List<String> evidenceWords(AppRecord entry, String query) {
  final words = <String>[];
  final precise = preciseSearch(query);
  final tokens = precise ? preciseTokenPattern : tokenPattern;
  for (final token in tokens.allMatches(precise ? query : normalize(query)).map((m) => m.group(0)!).toSet()) {
    for (final key in ['word', 'root', 'definition']) {
      final source = entry[key]?.toString() ?? '';
      final ranges = matchRanges(source, token, mode: 'fulltext', compact: key == 'root', precise: precise);
      if (ranges.isNotEmpty) {
        words.add(source.substring(ranges.first.start, ranges.first.end));
        break;
      }
    }
  }
  return words.toSet().toList();
}

Widget highlightStudyText(BuildContext context, String text, String query, Widget child) =>
  _MatchBackground(ranges: matchRanges(text, query),
    color: Theme.of(context).brightness == Brightness.dark ? const Color(0xff665024) : const Color(0xffffedac), child: child);
