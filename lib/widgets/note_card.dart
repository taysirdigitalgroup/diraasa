import 'sacred_text.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/app_core.dart';
import '../core/search.dart';
import 'author_avatar.dart';
import 'rich_editor.dart';

class StudyNoteCard extends StatelessWidget {
  const StudyNoteCard({super.key, required this.note, required this.onTap,
    required this.onAction, this.query = '', this.field = 'all'});
  final AppRecord note;
  final VoidCallback onTap;
  final ValueChanged<String> onAction;
  final String query, field;
  @override
  Widget build(BuildContext context) {
    final menuKey = GlobalKey<PopupMenuButtonState<String>>();
    final title = note['title'].toString(), body = note['body'].toString(), author = note['author']?.toString() ?? '';
    return Card(
      key: ValueKey('note-${note['id']}'), margin: const EdgeInsets.only(bottom: 12), elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .45))),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, onLongPress: () => menuKey.currentState?.showButtonMenu(), child: Stack(children: [
        Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(padding: const EdgeInsets.only(left: 38, right: 76),
            child: MatchText(title, query: noteFieldQuery(field, 'title', query), maxLines: 1,
              style: TextStyle(fontSize: 14, height: 1.6, fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant))),
          const SizedBox(height: 14),
          StudyText(body, format: note['body_format']?.toString() ?? '',
            query: noteFieldQuery(field, 'body', query), selectable: false, maxLines: 6,
            style: const TextStyle(fontSize: 19, height: 1.8)),
          if (author.isNotEmpty) ...[
            const SizedBox(height: 16), authorBadge(context, author, note['author_photo']?.toString() ?? ''),
          ],
          const SizedBox(height: 12), SacredText(tr('created') + ' ' + date(note['created']),
            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ])),
        Positioned(top: 0, left: 0, child: IgnorePointer(child: SizedBox(width: 76, height: 76,
          child: ClipRect(child: Stack(children: [
            Positioned(top: 17, left: -27, child: Transform.rotate(angle: -math.pi / 4,
              child: Container(width: 112, height: 18, alignment: Alignment.center,
                color: typeColor(note['kind'].toString()),
                child: Padding(padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: SacredText(tr(note['kind'].toString()), maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w600)))))),
          ]))))),
        Positioned(top: 3, right: 3, child: Directionality(textDirection: TextDirection.ltr,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (note['pinned'] == 1) Tooltip(message: tr('pinned'),
              child: Icon(Icons.push_pin, size: 18, color: Theme.of(context).colorScheme.primary)),
            PopupMenuButton<String>(key: menuKey,
              tooltip: tr('options'), onSelected: onAction,
              itemBuilder: (_) => [
                PopupMenuItem(value: 'pin', child: SacredText(tr(note['pinned'] == 1 ? 'unpin' : 'pin'))),
                PopupMenuItem(value: 'edit', child: SacredText(tr('edit'))),
                PopupMenuItem(value: 'delete', child: SacredText(tr('delete'))),
              ],
            ),
          ]),
        )),
      ])),
    );
  }
  Widget authorBadge(BuildContext context, String author, String photo) {
    final identity = author.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
    // Stable across launches, locale and card order; never use String.hashCode.
    final hash = identity.runes.fold<int>(0, (value, rune) => (value * 31 + rune) & 0x7fffffff);
    const hues = [155.0, 205.0, 265.0, 325.0, 30.0, 90.0];
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = HSLColor.fromAHSL(1, hues[hash % hues.length], .55, dark ? .76 : .30).toColor();
    return Align(alignment: direction(author) == TextDirection.rtl ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(color: color.withValues(alpha: dark ? .14 : .08),
          borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisSize: MainAxisSize.min, textDirection: direction(author), children: [
          if (photo.isNotEmpty) AuthorAvatar(photo: photo, radius: 14)
          else Icon(Icons.person_outline_rounded, size: 18, color: color),
          const SizedBox(width: 7),
          Flexible(child: MatchText(author, query: noteFieldQuery(field, 'author', query),
            style: TextStyle(fontSize: 13, height: 1.5, color: color, fontWeight: FontWeight.w600))),
        ])));
  }
}

Color typeColor(String kind) {
  const palette = <String, Color>{
    'Livre': Color(0xff176357), 'Cours': Color(0xff285c91),
    'Vocabulaire': Color(0xff72509b), 'Notion': Color(0xff9b456b),
    'Définition': Color(0xff8c651c), 'Grammaire': Color(0xff356b38),
    'Conjugaison': Color(0xff9b4933), 'Règle': Color(0xff4b578f),
    'Exemple': Color(0xff267278), 'Exercice': Color(0xff7d6932),
    'Résumé': Color(0xff685d56), 'Vers': Color(0xff91365a),
    'Citation': Color(0xff5c4490), 'Autre': Color(0xff50646b),
  };
  return palette[kind] ?? const Color(0xff50646b);
}
