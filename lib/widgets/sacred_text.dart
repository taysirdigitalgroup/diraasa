import 'package:flutter/material.dart';

/// Apply display-only styles. Original letters, combining marks and clipboard
/// content are never replaced; attached Arabic prefixes stay in one run.
TextSpan emphasizeNames(TextSpan source) {
  final text = source.toPlainText();
  final ranges = <({int start, int end, Color color})>[];
  for (final token in RegExp(r'[\p{L}\p{M}ـ\uFDF2]+', unicode: true).allMatches(text)) {
    final normalized = token.group(0)!.replaceAll('\uFDF2', 'الله')
      .replaceAll(RegExp(r'[\u0610-\u061a\u064b-\u065f\u0670\u06d6-\u06edـ]'), '')
      .replaceAll(RegExp('[أإآٱ]'), 'ا');
    final match = RegExp(r'^[وفبلك]{0,2}(الله(?:م)?|لله|محمد(?:ا)?)$').firstMatch(normalized);
    if (match != null) ranges.add((start: token.start, end: token.end,
      color: !match.group(1)!.startsWith('محمد') ? const Color(0xffe53935) : const Color(0xff2196f3)));
  }
  if (ranges.isEmpty) return source;
  var offset = 0;
  InlineSpan visit(InlineSpan span) {
    if (span is! TextSpan) { offset++; return span; }
    final pieces = <InlineSpan>[];
    final raw = span.text ?? '';
    var local = 0;
    for (final range in ranges) {
      final start = (range.start - offset).clamp(0, raw.length).toInt();
      final end = (range.end - offset).clamp(0, raw.length).toInt();
      if (start >= end) continue;
      if (start > local) pieces.add(TextSpan(text: raw.substring(local, start)));
      pieces.add(TextSpan(text: raw.substring(start, end),
        style: TextStyle(fontWeight: FontWeight.bold, color: range.color)));
      local = end;
    }
    if (local < raw.length) pieces.add(TextSpan(text: raw.substring(local)));
    offset += raw.length;
    for (final child in span.children ?? <InlineSpan>[]) { pieces.add(visit(child)); }
    return TextSpan(style: span.style, children: pieces, recognizer: span.recognizer,
      semanticsLabel: span.semanticsLabel);
  }
  return visit(source) as TextSpan;
}

class SacredText extends StatelessWidget {
  const SacredText(String this.data, {super.key, this.style, this.textAlign, this.textDirection,
    this.maxLines, this.overflow, this.semanticsLabel}) : textSpan = null;
  const SacredText.rich(InlineSpan this.textSpan, {super.key, this.style, this.textAlign, this.textDirection,
    this.maxLines, this.overflow}) : data = null, semanticsLabel = null;
  final String? data, semanticsLabel;
  final InlineSpan? textSpan;
  final TextStyle? style;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final int? maxLines;
  final TextOverflow? overflow;
  @override
  Widget build(BuildContext context) {
    final source = textSpan is TextSpan ? textSpan! as TextSpan : TextSpan(text: data,
      children: textSpan == null ? null : [textSpan!]);
    final emphasized = emphasizeNames(source);
    // Keep Flutter's original plain-text path when there is nothing to style.
    // Text.rich would add a parent span even for an unchanged plain string.
    if (data != null && identical(emphasized, source)) {
      return Text(data!, style: style, textAlign: textAlign, textDirection: textDirection,
        maxLines: maxLines, overflow: overflow, semanticsLabel: semanticsLabel);
    }
    return Text.rich(emphasized, style: style, textAlign: textAlign,
      textDirection: textDirection, maxLines: maxLines, overflow: overflow,
      semanticsLabel: semanticsLabel);
  }
}

class SacredSelectableText extends StatelessWidget {
  const SacredSelectableText(String this.data, {super.key, this.style, this.textDirection, this.textAlign}) : textSpan = null;
  const SacredSelectableText.rich(TextSpan this.textSpan, {super.key, this.style,
    this.textDirection, this.textAlign}) : data = null;
  final String? data;
  final TextSpan? textSpan;
  final TextStyle? style;
  final TextDirection? textDirection;
  final TextAlign? textAlign;
  @override
  Widget build(BuildContext context) {
    final source = textSpan ?? TextSpan(text: data);
    final emphasized = emphasizeNames(source);
    if (data != null && identical(emphasized, source)) {
      return SelectableText(data!, style: style, textDirection: textDirection, textAlign: textAlign);
    }
    return SelectableText.rich(emphasized, style: style,
      textDirection: textDirection, textAlign: textAlign);
  }
}

class SacredController extends TextEditingController {
  SacredController({super.text});
  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) =>
    emphasizeNames(super.buildTextSpan(context: context, style: style, withComposing: withComposing));
}
