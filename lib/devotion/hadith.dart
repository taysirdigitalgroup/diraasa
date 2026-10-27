import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_core.dart';
import '../core/search.dart';
import '../widgets/controls.dart';
import '../widgets/sacred_text.dart';
import 'core.dart';

List<AppRecord> decodeHadith(String raw) {
  final rows = ((jsonDecode(raw) as Map)['entries'] as List)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
  for (final row in rows) {
    row['_searchText'] =
        '${row['title']}\n${row['text']}\n${(row['references'] as List).join('\n')}';
    row['_normalized'] = normalize(row['_searchText'].toString());
  }
  return rows;
}

bool hadithMatches(AppRecord row, String query) {
  final q = westernDigits(query.trim());
  if (q.isEmpty) return true;
  if (RegExp(r'^\d+$').hasMatch(q)) return row['number'] == int.tryParse(q);
  if (preciseSearch(query))
    return (row['_searchText']?.toString() ??
            '${row['title']}\n${row['text']}\n${(row['references'] as List).join('\n')}')
        .contains(query.trim());
  return (row['_normalized']?.toString() ??
          normalize(
            '${row['title']}\n${row['text']}\n${(row['references'] as List).join('\n')}',
          ))
      .contains(normalize(query.trim()));
}

class HadithPage extends StatefulWidget {
  const HadithPage({super.key});
  @override
  State<HadithPage> createState() => _HadithPageState();
}

class _HadithPageState extends State<HadithPage> {
  final search = SacredController();
  String book = 'bukhari', query = '';
  List<AppRecord> entries = [];
  int limit = 40, revision = 0;
  bool loading = true;
  String? error;
  @override
  void initState() {
    super.initState();
    restore();
  }

  @override
  void dispose() {
    revision++;
    search.dispose();
    super.dispose();
  }

  Future<void> restore() async {
    try {
      final saved = await DevStore.read('hadithBook');
      if (saved == 'muslim' || saved == 'bukhari') book = saved.toString();
    } catch (_) {}
    if (mounted) load();
  }

  Future<void> chooseBook(String value) async {
    book = value;
    load();
    try {
      await DevStore.write('hadithBook', book);
    } catch (e) {
      if (mounted) errorMessage(context, e);
    }
  }

  Future<void> load() async {
    final token = ++revision;
    setState(() {
      loading = true;
      error = null;
      entries = [];
      limit = 40;
    });
    try {
      final result = await compute(
        decodeHadith,
        await rootBundle.loadString('assets/devotion/hadith_$book.json'),
      );
      if (mounted && token == revision) setState(() => entries = result);
    } catch (e) {
      if (mounted && token == revision) setState(() => error = e.toString());
    } finally {
      if (mounted && token == revision) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hits = entries.where((e) => hadithMatches(e, query)).toList();
    return Scaffold(
      appBar: AppBar(title: SacredText(dt('hadith'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  key: ValueKey('hadith-book-$book'),
                  initialValue: book,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(
                      value: 'bukhari',
                      child: SacredText('صحيح البخاري'),
                    ),
                    DropdownMenuItem(
                      value: 'muslim',
                      child: SacredText('صحيح مسلم'),
                    ),
                  ],
                  onChanged: loading
                      ? null
                      : (v) {
                          if (v != null && v != book) chooseBook(v);
                        },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: search,
                  textDirection: direction(query, fallback: TextDirection.rtl),
                  onChanged: (v) => setState(() {
                    query = v;
                    limit = 40;
                  }),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: dt('hadithSearch'),
                    helperText: loading ? '…' : resultLabel(hits.length),
                    helperStyle: resultStyle,
                  ),
                ),
              ],
            ),
          ),
          if (loading) const LinearProgressIndicator(),
          if (error != null)
            TextButton(onPressed: load, child: SacredText(tr('retry'))),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              itemCount: hits.isEmpty
                  ? 1
                  : (hits.length > limit ? limit + 1 : hits.length),
              itemBuilder: (context, index) {
                if (hits.isEmpty)
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: SacredText(loading ? '' : dt('noResults')),
                  );
                if (index == limit)
                  return OutlinedButton(
                    onPressed: () => setState(() => limit += 40),
                    child: SacredText(tr('more')),
                  );
                final entry = hits[index];
                return Card(
                  child: InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => HadithReader(
                          entry: entry,
                          query:
                              RegExp(
                                r'^\d+$',
                              ).hasMatch(westernDigits(query.trim()))
                              ? ''
                              : query,
                        ),
                      ),
                    ),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SacredText(
                            '${book == 'bukhari' ? 'صحيح البخاري' : 'صحيح مسلم'} · ${entry['number'] ?? '—'}',
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          const SizedBox(height: 8),
                          MatchText(
                            quranLikeExcerpt(entry['text'].toString(), query),
                            query: query,
                            style: const TextStyle(fontSize: 19, height: 1.8),
                          ),
                          const SizedBox(height: 10),
                          HadithReferences(entry: entry, query: query),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

String quranLikeExcerpt(String text, String query) {
  final ranges = matchRanges(text, query);
  final start = ranges.isEmpty
      ? 0
      : (ranges.first.start - 45).clamp(0, text.length).toInt();
  final end = (start + 300).clamp(0, text.length).toInt();
  return '${start > 0 ? '… ' : ''}${text.substring(start, end)}${end < text.length ? ' …' : ''}';
}

class HadithReferences extends StatelessWidget {
  const HadithReferences({super.key, required this.entry, this.query = ''});
  final AppRecord entry;
  final String query;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final ref in entry['references'] as List)
        MatchText(
          ref.toString(),
          query: query,
          style: TextStyle(
            fontSize: 12,
            height: 1.6,
            color: Theme.of(context).disabledColor,
          ),
        ),
    ],
  );
}

class HadithReader extends StatelessWidget {
  const HadithReader({super.key, required this.entry, this.query = ''});
  final AppRecord entry;
  final String query;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: settings,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: SacredText('${dt('hadithNumber')} ${entry['number'] ?? '—'}'),
        actions: [
          IconButton(
            tooltip: tr('copy'),
            icon: const Icon(Icons.copy),
            onPressed: () => Clipboard.setData(
              ClipboardData(
                text:
                    '${entry['text']}\n\n${(entry['references'] as List).join('\n')}',
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const ReadingSize(),
          MatchText(
            entry['text'].toString(),
            query: query,
            selectable: true,
            style: TextStyle(fontSize: settings.textSize, height: 1.9),
          ),
          const SizedBox(height: 20),
          HadithReferences(entry: entry, query: query),
        ],
      ),
    ),
  );
}
