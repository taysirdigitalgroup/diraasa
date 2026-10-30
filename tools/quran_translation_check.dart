import 'dart:io';
import '../lib/devotion/quran_text.dart';

void main() {
  final chapters = mergeQuranTranslations([
    for (final language in ['hafs', 'fr', 'en'])
      File('assets/devotion/quran_$language.json').readAsStringSync(),
  ]);
  assert(chapters.length == 114);
  var total = 0;
  for (final chapter in chapters) {
    for (final verse in chapter['verses'] as List) {
      total++;
      for (final language in ['ar', 'fr', 'en']) {
        final display = quranVerseText(verse as Map, language);
        assert(display.language == language && display.text.isNotEmpty);
      }
    }
  }
  assert(total == 6236);
  assert(quranVerseText({'text': 'العربية'}, 'en').language == 'ar');
  assert(
    quranVerseText({
          'text': 'العربية',
          'translations': {'fr': ''},
        }, 'fr').text ==
        'العربية',
  );
  final first = (chapters.first['verses'] as List).first as Map;
  assert(quranVerseText(first, 'fr').text.startsWith("Au nom d'Allah"));
  assert(quranVerseText(first, 'en').text.startsWith('In the name of Allah'));
  for (final chapter in chapters) {
    final english = (chapter['translationBasmalas'] as Map?)?['en'];
    if (chapter['number'] != 1 && chapter['number'] != 9) {
      assert(english == 'In the name of Allah, the Gracious, the Merciful');
    }
  }
  for (final current in [0, 1, 2]) {
    for (final lang in ['ar', 'fr', 'en']) {
      for (final card in [0, 1, 2, 3]) {
        final chosen = quranPlaybackTextLanguage(
          card,
          readingLanguage: 'ar',
          hasPlayback: true,
          playingVerse: current,
          playingLanguage: lang,
        );
        assert(chosen == (card == current ? lang : 'ar'));
      }
    }
  }
  assert(
    quranPlaybackTextLanguage(
          2,
          readingLanguage: 'fr',
          hasPlayback: false,
          playingVerse: 2,
          playingLanguage: 'en',
        ) ==
        'fr',
  );
  assert(
    quranPlaybackTextLanguage(
          1,
          readingLanguage: 'en',
          hasPlayback: true,
          playingVerse: 2,
          playingLanguage: 'fr',
        ) ==
        'en',
  );
  print(
    'OK: 114 chapters, 6236 complete FR/EN references, Arabic default/fallback, 112 spaced basmalas, per-verse playback language',
  );
}
