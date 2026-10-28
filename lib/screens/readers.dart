import '../widgets/sacred_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_core.dart';
import '../core/search.dart';
import '../widgets/controls.dart';
import 'editor.dart';
import 'sources.dart';
import 'privacy.dart';
import '../widgets/rich_editor.dart';

Future<void> copyText(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted)
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: SacredText(tr('copied'))));
}

class NotePreview extends StatelessWidget {
  final AppRecord note;
  final String query, field;
  const NotePreview({
    super.key,
    required this.note,
    this.query = '',
    this.field = 'all',
  });
  @override
  Widget build(BuildContext context) {
    final title = note['title'].toString(),
        body = note['body'].toString(),
        author = note['author']?.toString() ?? '';
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) => SafeArea(
        key: const ValueKey('note-preview'),
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: SacredText(
                      tr('readNote'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: tr('copy'),
                    icon: const Icon(Icons.copy_outlined),
                    onPressed: () => copyText(
                      context,
                      [title, body, if (author.isNotEmpty) author].join('\n\n'),
                    ),
                  ),
                  IconButton(
                    tooltip: tr('close'),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SacredText(
                      tr(note['kind'].toString()),
                      style: const TextStyle(color: Color(0xffb18b4b)),
                    ),
                    const SizedBox(height: 12),
                    MatchText(
                      title,
                      selectable: true,
                      query: noteFieldQuery(field, 'title', query),
                      style: TextStyle(
                        fontSize: settings.textSize + 3,
                        fontWeight: FontWeight.bold,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (author.isNotEmpty) ...[
                      MatchText(
                        author,
                        selectable: true,
                        query: noteFieldQuery(field, 'author', query),
                        style: const TextStyle(fontSize: 17),
                      ),
                      const SizedBox(height: 8),
                    ],
                    SacredText(
                      tr('created') + ' ' + date(note['created']),
                      style: const TextStyle(fontSize: 12),
                    ),
                    const ReadingSize(),
                    const SizedBox(height: 16),
                    StudyText(
                      body,
                      format: note['body_format']?.toString() ?? '',
                      query: noteFieldQuery(field, 'body', query),
                      style: TextStyle(
                        fontSize: settings.textSize,
                        height: 1.9,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Article extends StatelessWidget {
  final AppRecord entry;
  final String query, mode;
  const Article({
    super.key,
    required this.entry,
    this.query = '',
    this.mode = 'prefix',
  });
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: settings,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        leading: BackButton(
          key: const ValueKey('article-back'),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const SacredText('مختار الصحاح'),
        actions: [
          IconButton(
            tooltip: tr('copy'),
            icon: const Icon(Icons.copy),
            onPressed: () => copyText(
              context,
              entry['word'].toString() +
                  '\n' +
                  entry['definition'].toString() +
                  '\nمختار الصحاح — الرازي',
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          SacredText(
            tr('entry') + ' ' + entry['page'].toString() + ' · الرازي',
            style: const TextStyle(color: Color(0xffb18b4b)),
          ),
          const SizedBox(height: 12),
          MatchText(
            entry['word'],
            query: query,
            mode: mode,
            selectable: true,
            style: TextStyle(
              fontSize: settings.textSize + 12,
              height: 1.7,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (entry['root'].toString().isNotEmpty) ...[
            const SizedBox(height: 10),
            SacredText(tr('root')),
            MatchText(
              entry['root'],
              query: query,
              mode: mode,
              compact: true,
              selectable: true,
            ),
          ],
          const ReadingSize(),
          MatchText(
            entry['definition'],
            query: mode == 'fulltext' ? query : '',
            mode: 'fulltext',
            selectable: true,
            style: TextStyle(fontSize: settings.textSize, height: 1.9),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.edit_note),
            label: SacredText(tr('study')),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => Editor(
                  note: {
                    'title': entry['word'],
                    'body': entry['definition'],
                    'author': 'الرازي — مختار الصحاح',
                    'kind': 'Vocabulaire',
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class About extends StatelessWidget {
  const About({super.key});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: settings,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: SacredText(tr('about'))),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Image.asset(
              'assets/images/diraasa_internal.png',
              width: 112,
              height: 112,
              semanticLabel: 'Diraasa',
            ),
          ),
          const SizedBox(height: 18),
          const SacredText(
            'Diraasa · دراسة',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          SacredText(tr('aboutText')),
          const SizedBox(height: 16),
          SettingsMenuRow(label: tr('language'), menu: const LanguageMenu()),
          SettingsMenuRow(label: tr('theme'), menu: const ThemeMenu()),
          const ReadingSize(),
          const SourcesSection(),
          const SizedBox(height: 16),
          ListTile(
            title: SacredText(tr('developer')),
            subtitle: const SacredText(
              'Aliou Mbengue\nTaysir Digital Group (TDG)',
            ),
          ),
          ...[
            '+221 76 455 03 58',
            'taysirdigitalgroup@gmail.com',
            'https://taysirdigitalgroup.github.io/',
          ].map(
            (value) => ListTile(
              onTap: () => openReferenceLink(
                context,
                value.startsWith('+')
                    ? 'tel:${value.replaceAll(' ', '')}'
                    : value.contains('@')
                    ? 'mailto:$value'
                    : value,
              ),
              leading: Icon(
                value.startsWith('+')
                    ? Icons.phone_outlined
                    : value.contains('@')
                    ? Icons.mail_outline
                    : Icons.language,
              ),
              title: SacredText(value, textDirection: TextDirection.ltr),
              trailing: IconButton(
                tooltip: tr('copy'),
                icon: const Icon(Icons.copy),
                onPressed: () => copyText(context, value),
              ),
            ),
          ),
          const DonationsSection(),
          const PrivacyLink(),
          const SizedBox(height: 24),
          const SacredText(
            '2.3.1 · © 2026 Taysir Digital Group',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
