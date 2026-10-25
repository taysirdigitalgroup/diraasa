import 'package:flutter/material.dart';
import 'app_core.dart';

final _marks = RegExp(r'[\u0610-\u061a\u064b-\u065f\u0670\u06d6-\u06edـ]');
final tokenPattern = RegExp(r'[\p{L}\p{N}]+', unicode: true);
String normalize(String value) => value.toLowerCase().replaceAll(_marks, '')
    .replaceAll(RegExp('[أإآٱ]'), 'ا').replaceAll('ى', 'ي');

class MappedText {
  final String original;
  final bool compact;
  late final String value;
  final List<int> starts = [], ends = [];
  MappedText(this.original, {this.compact = false}) {
    final out = StringBuffer();
    for (final m in RegExp(r'.', dotAll: true, unicode: true).allMatches(original)) {
      final normalized = normalize(m.group(0)!);
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

List<TextRange> matchRanges(String text, String query, {String mode = 'contains', bool compact = false}) {
  final mapped = MappedText(text, compact: compact);
  var needle = normalize(query.trim());
  if (compact) needle = needle.replaceAll(' ', '');
  if (needle.isEmpty) return [];
  final matches = <TextRange>[];
  void add(int start, int end) {
    if (start < end && end <= mapped.ends.length) {
      matches.add(TextRange(start: mapped.starts[start], end: mapped.ends[end - 1]));
    }
  }
  if (mode == 'fulltext') {
    final queries = tokenPattern.allMatches(needle).map((m) => m.group(0)!).toSet();
    for (final token in tokenPattern.allMatches(mapped.value)) {
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

bool matchesNote(AppRecord n, String query, String field) {
  final needle = normalize(query.trim());
  return needle.isEmpty || noteFieldKeys(field).any((key) =>
      normalize(n[key]?.toString() ?? '').contains(needle));
}
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
    final spans = <InlineSpan>[];
    var last = 0;
    for (final range in ranges) {
      if (range.start > last) spans.add(TextSpan(text: text.substring(last, range.start)));
      spans.add(TextSpan(text: text.substring(range.start, range.end),
        style: TextStyle(backgroundColor: color, fontWeight: FontWeight.w700)));
      last = range.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    final span = TextSpan(style: DefaultTextStyle.of(context).style.merge(style), children: spans);
    if (selectable) return SelectableText.rich(span,
      textDirection: direction(text), textAlign: textAlignment(text));
    return Text.rich(span, textDirection: direction(text), textAlign: textAlignment(text),
      maxLines: maxLines, overflow: maxLines == null ? TextOverflow.clip : TextOverflow.ellipsis);
  }
}

/// Each queried FTS token has a visible source witness even if its occurrence
/// lies beyond the truncated preview. Compact roots are part of the FTS index.
List<String> evidenceWords(AppRecord entry, String query) {
  final words = <String>[];
  for (final token in tokenPattern.allMatches(normalize(query)).map((m) => m.group(0)!).toSet()) {
    for (final key in ['word', 'root', 'definition']) {
      final source = entry[key]?.toString() ?? '';
      final ranges = matchRanges(source, token, mode: 'fulltext', compact: key == 'root');
      if (ranges.isNotEmpty) {
        words.add(source.substring(ranges.first.start, ranges.first.end));
        break;
      }
    }
  }
  return words.toSet().toList();
}
