import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_core.dart';
import '../core/search.dart';
import '../widgets/controls.dart';
import '../widgets/sacred_text.dart';
import 'core.dart';
import 'tasbih.dart';
import 'counter_store.dart';

class HisnPage extends StatefulWidget {
  const HisnPage({super.key});
  @override
  State<HisnPage> createState() => _HisnPageState();
}

class _HisnPageState extends State<HisnPage> {
  AppRecord? book;
  List<AppRecord> chapters = [];
  String query = '';
  String? error;
  bool loading = true;
  final search = SacredController();
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final raw =
          jsonDecode(await rootBundle.loadString('assets/devotion/hisn.json'))
              as Map;
      if (mounted)
        setState(() {
          book = Map<String, dynamic>.from(raw);
          chapters = (raw['chapters'] as List)
              .map((r) => Map<String, dynamic>.from(r as Map))
              .toList();
          loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          error = e.toString();
          loading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = chapters
        .where(
          (c) =>
              matchesSearch(c['title'].toString(), query) ||
              (c['entries'] as List).any(
                (e) => matchesSearch(e['text'].toString(), query),
              ),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: SacredText(dt('hisn')),
        actions: [
          IconButton(
            tooltip: dt('source'),
            onPressed: book == null
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => HisnSource(book: book!)),
                  ),
            icon: const Icon(Icons.info_outline),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: search,
              textDirection: direction(
                query,
                fallback: Directionality.of(context),
              ),
              onChanged: (v) => setState(() => query = v),
              decoration: InputDecoration(
                helperText: resultLabel(visible.length),
                helperStyle: resultStyle,
                hintText: tr('searchReferences'),
                prefixIcon: const Icon(Icons.search),
              ),
            ),
          ),
          if (loading) const LinearProgressIndicator(),
          if (error != null)
            TextButton(
              onPressed: load,
              child: SacredText('${tr('retry')} · $error'),
            ),
          Expanded(
            child: visible.isEmpty && !loading
                ? Center(child: SacredText(dt('noResults')))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: visible.length,
                    itemBuilder: (_, i) {
                      final c = visible[i];
                      return Card(
                        child: ListTile(
                          title: MatchText(
                            c['title'].toString(),
                            query: query,
                            style: const TextStyle(fontSize: 21, height: 1.6),
                          ),
                          subtitle: SacredText(
                            '${(c['entries'] as List).length} ${dt('azkar')}',
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  HisnChapter(chapter: c, query: query),
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

class HisnChapter extends StatefulWidget {
  const HisnChapter({super.key, required this.chapter, this.query = ''});
  final AppRecord chapter;
  final String query;
  @override
  State<HisnChapter> createState() => _HisnChapterState();
}

class _HisnChapterState extends State<HisnChapter> {
  bool busy = false;
  Future<void> counter([AppRecord? entry]) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final data = await CounterStore.load();
      final items = CounterStore.rows(data, 'items');
      String? id;
      if (entry != null) {
        if (!mounted) return;
        final edited = await Navigator.push<AppRecord>(
          context,
          MaterialPageRoute(
            builder: (_) => ZikrEditor(item: {'text': entry['text'], 'max': 1}),
          ),
        );
        if (edited == null) return;
        final existing = items.indexWhere(
          (i) =>
              i['text'].toString().trim() == edited['text'].toString().trim(),
        );
        if (existing < 0) {
          items.add(edited);
        } else {
          edited['id'] = items[existing]['id'];
          items[existing] = edited;
        }
        id = edited['id'].toString();
      } else {
        final steps = <AppRecord>[];
        for (final raw in widget.chapter['entries'] as List) {
          final text = raw['text'].toString();
          var item = items.where((r) => r['text'] == text).firstOrNull;
          if (item == null) {
            item = {'id': CounterStore.id(), 'text': text, 'max': 1};
            items.add(item);
          }
          steps.add({'itemId': item['id'], 'max': item['max']});
        }
        if (!mounted) return;
        final chain = await Navigator.push<AppRecord>(
          context,
          MaterialPageRoute(
            builder: (_) => ChainEditor(
              items: items,
              chain: {'name': widget.chapter['title'], 'steps': steps},
            ),
          ),
        );
        if (chain == null) return;
        final chains = CounterStore.rows(data, 'chains');
        chains.add(chain);
        data['chains'] = chains;
        id = chain['id'].toString();
      }
      data['items'] = items;
      await DevStore.write('counterLibrary', data);
      if (mounted)
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CounterPage(id: id!, chain: entry == null),
          ),
        );
    } catch (e) {
      if (mounted) errorMessage(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: settings,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: SacredText(
          widget.chapter['title'].toString(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const ReadingSize(),
          FilledButton.icon(
            onPressed: busy || (widget.chapter['entries'] as List).isEmpty
                ? null
                : () => counter(),
            icon: const Icon(Icons.link),
            label: SacredText('${dt('chains')} · ${dt('useCounter')}'),
          ),
          if ((widget.chapter['preface']?.toString() ?? '').isNotEmpty)
            MatchText(
              widget.chapter['preface'].toString(),
              query: widget.query,
              selectable: true,
              style: TextStyle(fontSize: settings.textSize, height: 1.9),
            ),
          ...(widget.chapter['entries'] as List).map((raw) {
            final entry = Map<String, dynamic>.from(raw as Map);
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MatchText(
                      entry['text'].toString(),
                      query: widget.query,
                      selectable: true,
                      style: TextStyle(
                        fontSize: settings.textSize,
                        height: 1.9,
                      ),
                    ),
                    for (final reference in entry['references'] as List? ?? [])
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: MatchText(
                          reference.toString(),
                          query: widget.query,
                          selectable: true,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.6,
                            color: Theme.of(context).disabledColor,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    SacredText(dt('counterReview')),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          tooltip: tr('copy'),
                          onPressed: () => Clipboard.setData(
                            ClipboardData(text: entry['text'].toString()),
                          ),
                          icon: const Icon(Icons.copy),
                        ),
                        TextButton(
                          onPressed: busy ? null : () => counter(entry),
                          child: SacredText(dt('useCounter')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
          SacredText(
            '${dt('source')} : حصن المسلم · hisnul_muslim.sql\n132 ${dt('chapter')} · 267 ${dt('azkar')}',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    ),
  );
}

class HisnSource extends StatelessWidget {
  const HisnSource({super.key, required this.book});
  final AppRecord book;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: settings,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: SacredText('${dt('source')} · حصن المسلم')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: (book['frontMatter'] as List).length,
        itemBuilder: (_, i) {
          final block = (book['frontMatter'] as List)[i];
          return Card(
            child: ExpansionTile(
              title: SacredText(
                block['title'].toString(),
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
              ),
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: ReadingSize(),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: MatchText(
                    block['text'].toString(),
                    selectable: true,
                    style: TextStyle(fontSize: settings.textSize, height: 1.9),
                  ),
                ),
                for (final reference in block['references'] as List? ?? [])
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: MatchText(
                      reference.toString(),
                      selectable: true,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.6,
                        color: Theme.of(context).disabledColor,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    ),
  );
}
