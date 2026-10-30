import 'dart:async';
import 'package:flutter/material.dart';

import '../core/app_core.dart';
import '../core/search.dart';
import '../widgets/sacred_text.dart';
import '../widgets/controls.dart';
import 'core.dart';
import 'quran_audio.dart';
import 'quran_text.dart';

class QuranPage extends StatefulWidget {
  const QuranPage({super.key});
  @override
  State<QuranPage> createState() => _QuranPageState();
}

class _QuranPageState extends State<QuranPage> {
  final search = SacredController();
  List<AppRecord> chapters = [];
  String reading = 'hafs', query = '';
  String? error;
  bool loading = true;
  int limit = 60, revision = 0;
  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    try {
      final saved = await DevStore.read('quranReading');
      if (saved == 'hafs' || saved == 'warsh') reading = saved as String;
    } catch (_) {
      /* Local assets still work without preferences. */
    }
    if (mounted) load();
  }

  Future<void> load() async {
    final token = ++revision;
    setState(() {
      loading = true;
      error = null;
      chapters = [];
    });
    try {
      final data = await QuranData.book(reading);
      if (mounted && token == revision)
        setState(() {
          chapters = data;
          loading = false;
        });
    } catch (e) {
      if (mounted && token == revision)
        setState(() {
          error = e.toString();
          loading = false;
        });
    }
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hits = <({AppRecord chapter, AppRecord? verse})>[];
    final reference = parseReference(query);
    final precise = preciseSearch(query);
    final needle = precise ? query.trim() : normalize(query.trim());
    bool match(AppRecord row, String key) =>
        (precise ? row[key].toString() : row['_normalized'].toString())
            .contains(needle);
    for (final chapter in chapters) {
      if (reference != null) {
        if (chapter['number'] != reference.chapter) continue;
        if (!reference.list) {
          hits.add((chapter: chapter, verse: null));
          continue;
        }
        for (final raw in chapter['verses'] as List) {
          final verse = Map<String, dynamic>.from(raw as Map);
          if (reference.verse == null || verse['number'] == reference.verse)
            hits.add((chapter: chapter, verse: verse));
        }
      } else if (query.trim().isEmpty) {
        hits.add((chapter: chapter, verse: null));
      } else {
        if (match(chapter, 'title') ||
            (chapter['translationTitles'] as Map? ?? {}).values.any(
              (t) => matchesSearch(t.toString(), query),
            ))
          hits.add((chapter: chapter, verse: null));
        for (final raw in chapter['verses'] as List) {
          final verse = Map<String, dynamic>.from(raw as Map);
          if (match(verse, 'text')) {
            hits.add((chapter: chapter, verse: verse));
          } else {
            for (final lang in ['fr', 'en']) {
              final display = quranVerseText(verse, lang);
              if (display.language == lang &&
                  matchesSearch(display.text, query)) {
                hits.add((
                  chapter: chapter,
                  verse: {
                    ...verse,
                    'text': display.text,
                    '_displayLanguage': lang,
                  },
                ));
                break;
              }
            }
          }
        }
      }
    }
    return Scaffold(
      appBar: AppBar(title: SacredText(dt('quran'))),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      key: ValueKey('reading-$reading'),
                      initialValue: reading,
                      decoration: InputDecoration(labelText: dt('reading')),
                      items: ['hafs', 'warsh']
                          .map(
                            (r) => DropdownMenuItem(
                              value: r,
                              child: SacredText(dt(r)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) async {
                        if (value == null) return;
                        setState(() {
                          reading = value;
                          limit = 60;
                        });
                        load();
                        try {
                          await DevStore.write('quranReading', value);
                        } catch (e) {
                          if (context.mounted) errorMessage(context, e);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                key: const ValueKey('quran-search'),
                controller: search,
                textDirection: direction(
                  query,
                  fallback: Directionality.of(context),
                ),
                decoration: InputDecoration(
                  helperText: resultLabel(hits.length),
                  helperStyle: resultStyle,
                  hintText: dt('quranHint'),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: tr('clear'),
                    onPressed: () {
                      search.clear();
                      setState(() {
                        query = '';
                        limit = 60;
                      });
                    },
                  ),
                ),
                onChanged: (value) => setState(() {
                  query = value;
                  limit = 60;
                }),
              ),
            ),
            const SizedBox(height: 10),
            if (loading) const LinearProgressIndicator(),
            if (error != null)
              TextButton(
                onPressed: load,
                child: SacredText('${tr('retry')} · $error'),
              ),
            Expanded(
              child: hits.isEmpty && !loading
                  ? Center(child: SacredText(dt('noResults')))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: hits.length > limit ? limit + 1 : hits.length,
                      itemBuilder: (context, index) {
                        if (index == limit)
                          return OutlinedButton(
                            onPressed: () => setState(() => limit += 60),
                            child: SacredText(tr('more')),
                          );
                        final hit = hits[index],
                            chapter = hit.chapter,
                            verse = hit.verse;
                        return Card(
                          child: ListTile(
                            key: ValueKey(
                              'quran-${chapter['number']}-${verse?['number'] ?? 0}',
                            ),
                            title: MatchText(
                              '${chapter['number']} · ${chapter['title']}',
                              query: reference == null ? query : '',
                              style: TextStyle(
                                fontFamily: reading == 'warsh'
                                    ? 'UthmaniWarsh'
                                    : 'UthmaniHafs',
                                fontSize: 24,
                              ),
                            ),
                            subtitle: verse == null
                                ? SacredText(
                                    '${(chapter['verses'] as List).length} ${dt('verse')}',
                                  )
                                : MatchText(
                                    quranExcerpt(
                                      verse['text'].toString(),
                                      query,
                                    ),
                                    query: reference == null ? query : '',

                                    style: TextStyle(
                                      fontFamily:
                                          verse['_displayLanguage'] != null
                                          ? null
                                          : reading == 'warsh'
                                          ? 'UthmaniWarsh'
                                          : 'UthmaniHafs',
                                      fontSize: 24,
                                      height: 1.8,
                                    ),
                                  ),
                            trailing: verse == null
                                ? null
                                : SacredText('${verse['number']}'),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SurahPage(
                                  reading: reading,
                                  chapter: chapter,
                                  initialVerse: verse?['number'] as int? ?? 1,
                                  initialQuery: reference == null ? query : '',
                                  initialTextLanguage:
                                      verse?['_displayLanguage'] as String? ??
                                      'ar',
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class SurahPage extends StatefulWidget {
  const SurahPage({
    super.key,
    required this.reading,
    required this.chapter,
    this.initialVerse = 1,
    this.initialQuery = '',
    this.initialTextLanguage = 'ar',
  });
  final String reading, initialQuery, initialTextLanguage;
  final AppRecord chapter;
  final int initialVerse;
  @override
  State<SurahPage> createState() => _SurahPageState();
}

class _SurahPageState extends State<SurahPage> with WidgetsBindingObserver {
  final search = SacredController();
  String query = '';
  late final QuranAudioController audio;
  int anchorVerse = 1;
  String audioMark = '';
  String textLanguage = 'ar';
  String get displayLanguage => textLanguage;
  String languageFor(int number) => quranPlaybackTextLanguage(
    number,
    readingLanguage: textLanguage,
    hasPlayback: audio.hasPlayback,
    playingVerse: audio.verse,
    playingLanguage: audio.playingLanguage,
  );
  ({String text, String language}) get basmalaDisplay => quranVerseText({
    'text': widget.chapter['basmala'],
    'translations': widget.chapter['translationBasmalas'],
  }, languageFor(0));
  ({String text, String language}) verseDisplay(AppRecord verse) {
    final current = quranVerseText(verse, languageFor(verse['number'] as int));
    final needle = query.isNotEmpty ? query : widget.initialQuery;
    if (!(audio.hasPlayback && verse['number'] == audio.verse) &&
        needle.isNotEmpty &&
        parseReference(needle) == null &&
        !matchesSearch(current.text, needle)) {
      for (final lang in ['ar', 'fr', 'en']) {
        final other = quranVerseText(verse, lang);
        if (matchesSearch(other.text, needle)) return other;
      }
    }
    return current;
  }

  List<int> get verseNumbers => (widget.chapter['verses'] as List)
      .map((v) => (v['number'] as num).toInt())
      .toList();
  @override
  void initState() {
    super.initState();
    anchorVerse = widget.initialVerse;
    textLanguage = widget.reading == 'hafs' ? widget.initialTextLanguage : 'ar';
    audio = QuranAudioController()..addListener(audioChanged);
    if (widget.reading == 'hafs') {
      unawaited(
        audio.loadLanguage().then(
          (_) => audio.attach(widget.chapter['number'] as int),
        ),
      );
    }
    WidgetsBinding.instance.addObserver(this);
  }

  void audioChanged() {
    final mark =
        '${audio.state}:${audio.verse}:${audio.playingLanguage}:${audio.error}';
    if (!mounted || mark == audioMark) return;
    setState(() {
      audioMark = mark;
      if (audio.hasPlayback && audio.verse >= 0 && query.trim().isEmpty) {
        anchorVerse = audio.verse == 0 ? 1 : audio.verse;
      }
    });
  }

  Future<void> playVerse(int number) async {
    if (audio.active && audio.verse == number) {
      await audio.toggle();
    } else {
      await audio.play(widget.chapter['number'] as int, verseNumbers, number);
    }
  }

  Future<void> playContinuous() async {
    if (audio.continuous && audio.active) {
      await audio.toggle();
    } else {
      await audio.play(
        widget.chapter['number'] as int,
        verseNumbers,
        audio.state == 'completed'
            ? widget.initialVerse
            : audio.verse > 0
            ? audio.verse
            : anchorVerse,
        all: true,
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.reading == 'hafs') {
      unawaited(audio.attach(widget.chapter['number'] as int));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    audio.removeListener(audioChanged);
    audio.dispose();
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: settings,
    builder: (context, _) {
      final verses = (widget.chapter['verses'] as List)
          .map((v) => Map<String, dynamic>.from(v as Map))
          .toList();
      final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
      final reference = parseReference(query);
      final visible = query.trim().isEmpty
          ? verses
          : verses
                .where(
                  (v) => reference == null
                      ? (matchesSearch(v['text'].toString(), query) ||
                            ['fr', 'en'].any(
                              (lang) => matchesSearch(
                                quranVerseText(v, lang).text,
                                query,
                              ),
                            ))
                      : reference.chapter == widget.chapter['number'] &&
                            (reference.verse == null ||
                                v['number'] == reference.verse),
                )
                .toList();
      final anchorIndex = verses.indexWhere((v) => v['number'] == anchorVerse);
      final start = anchorIndex < 0 ? 0 : anchorIndex;
      const anchor = ValueKey('surah-anchor');
      Widget verseCard(AppRecord verse) {
        final display = verseDisplay(verse);
        return Card(
          key: ValueKey('ayah-${verse['number']}'),
          color: audio.hasPlayback && verse['number'] == audio.verse
              ? Theme.of(context).colorScheme.secondaryContainer
              : verse['number'] == widget.initialVerse &&
                    widget.initialVerse != 1
              ? Theme.of(context).colorScheme.primaryContainer
              : null,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: SacredText(
                        '${widget.chapter['number']}:${verse['number']}',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (widget.reading == 'hafs')
                      IconButton(
                        key: ValueKey('play-ayah-${verse['number']}'),
                        tooltip:
                            audio.active &&
                                audio.verse == verse['number'] &&
                                audio.state == 'playing'
                            ? qa('pause')
                            : qa('play'),
                        icon: Icon(
                          audio.active &&
                                  audio.verse == verse['number'] &&
                                  audio.state == 'playing'
                              ? Icons.pause_circle_outline
                              : Icons.play_circle_outline,
                        ),
                        onPressed: () => playVerse(verse['number'] as int),
                      ),
                  ],
                ),
                MatchText(
                  display.text,
                  selectable: true,
                  query: query.isNotEmpty && reference == null
                      ? query
                      : widget.initialQuery,
                  style: TextStyle(
                    fontFamily: display.language != 'ar'
                        ? null
                        : widget.reading == 'warsh'
                        ? 'UthmaniWarsh'
                        : 'UthmaniHafs',
                    fontSize:
                        settings.textSize + (display.language == 'ar' ? 4 : 0),
                    height: display.language == 'ar' ? 2 : 1.6,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      return Scaffold(
        appBar: AppBar(
          title: SacredText(
            '${widget.chapter['title']} · ${dt(widget.reading)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: search,
                  textDirection: direction(
                    query,
                    fallback: Directionality.of(context),
                  ),
                  decoration: InputDecoration(
                    helperText: resultLabel(visible.length),
                    helperStyle: resultStyle,
                    hintText: dt('inSurah'),
                    prefixIcon: const Icon(Icons.search),
                  ),
                  onChanged: (value) => setState(() {
                    query = value;
                    if (query.trim().isEmpty &&
                        audio.hasPlayback &&
                        audio.verse >= 0) {
                      anchorVerse = audio.verse == 0 ? 1 : audio.verse;
                    }
                  }),
                ),
              ),
              if (!keyboard)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: ReadingSize(),
                ),
              if (!keyboard && widget.reading == 'hafs')
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      SacredText(
                        settings.language == 'ar'
                            ? 'النص'
                            : settings.language == 'en'
                            ? 'Text'
                            : 'Texte',
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: displayLanguage,
                          items: ['ar', 'fr', 'en']
                              .map(
                                (lang) => DropdownMenuItem(
                                  value: lang,
                                  child: SacredText(qa(lang)),
                                ),
                              )
                              .toList(),
                          onChanged: audio.hasPlayback
                              ? null
                              : (lang) {
                                  if (lang != null)
                                    setState(() => textLanguage = lang);
                                },
                        ),
                      ),
                    ],
                  ),
                ),
              if (!keyboard && widget.reading == 'hafs')
                QuranAudioControls(
                  audio: audio,
                  onContinuous: () => playContinuous(),
                ),
              if (!keyboard && widget.reading != 'hafs')
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: SacredText(
                    qa('hafsOnly'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              if (!keyboard &&
                  (widget.chapter['basmala']?.toString() ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(
                    children: [
                      Expanded(
                        child: SacredText(
                          basmalaDisplay.text,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: basmalaDisplay.language != 'ar'
                                ? null
                                : widget.reading == 'warsh'
                                ? 'UthmaniWarsh'
                                : 'UthmaniHafs',
                            backgroundColor:
                                audio.hasPlayback && audio.verse == 0
                                ? Theme.of(
                                    context,
                                  ).colorScheme.secondaryContainer
                                : null,
                            fontSize: 22,
                          ),
                        ),
                      ),
                      if (widget.reading == 'hafs')
                        IconButton(
                          tooltip: qa('basmala'),
                          icon: Icon(
                            audio.active &&
                                    audio.verse == 0 &&
                                    audio.state == 'playing'
                                ? Icons.pause_circle_outline
                                : Icons.play_circle_outline,
                          ),
                          onPressed: () => playVerse(0),
                        ),
                    ],
                  ),
                ),

              Expanded(
                child: query.trim().isNotEmpty
                    ? visible.isEmpty
                          ? Center(child: SacredText(dt('noResults')))
                          : ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: visible.length,
                              itemBuilder: (_, i) => verseCard(visible[i]),
                            )
                    : CustomScrollView(
                        key: ValueKey(
                          'surah-${widget.reading}-${widget.chapter['number']}-$start',
                        ),
                        center: anchor,
                        slivers: [
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (_, i) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: verseCard(verses[start - i - 1]),
                              ),
                              childCount: start,
                            ),
                          ),
                          SliverList(
                            key: anchor,
                            delegate: SliverChildBuilderDelegate(
                              (_, i) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: verseCard(verses[start + i]),
                              ),
                              childCount: verses.length - start,
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

// Render an actual excerpt, without ellipsis layout boxes spanning hidden glyphs.
String quranExcerpt(String text, String query) {
  final ranges = matchRanges(text, query);
  final start = ranges.isEmpty
      ? 0
      : (ranges.first.start - 55).clamp(0, text.length).toInt();
  final end = (start + 240).clamp(0, text.length).toInt();
  return '${start > 0 ? '… ' : ''}${text.substring(start, end)}${end < text.length ? ' …' : ''}';
}
