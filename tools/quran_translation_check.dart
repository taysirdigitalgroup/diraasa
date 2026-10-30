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
  print(
    'OK: 114 chapters, 6236 complete FR/EN references, Arabic default/fallback',
  );
}
