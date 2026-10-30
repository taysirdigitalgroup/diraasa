import 'dart:convert';

/// Hafs references only: Warsh has a different verse numbering.
List<Map<String, dynamic>> mergeQuranTranslations(List<String> sources) {
  final arabic = jsonDecode(sources.first) as Map;
  final chapters = (arabic['chapters'] as List)
      .map((row) => Map<String, dynamic>.from(row as Map))
      .toList();
  for (final raw in sources.skip(1)) {
    final book = jsonDecode(raw) as Map;
    final language = book['language'];
    if (language != 'fr' && language != 'en') continue;
    final translated = {
      for (final c in book['chapters'] as List) c['number']: c,
    };
    for (final chapter in chapters) {
      final other = translated[chapter['number']];
      if (other == null) continue;
      (chapter['translationTitles'] ??= <String, String>{})[language] =
          other['title'];
      (chapter['translationBasmalas'] ??= <String, String>{})[language] =
          other['basmala'];
      final byNumber = {
        for (final v in other['verses'] as List) v['number']: v['text'],
      };
      for (final verse in chapter['verses'] as List) {
        final text = byNumber[verse['number']];
        if (text is String && text.trim().isNotEmpty) {
          (verse['translations'] ??= <String, String>{})[language] = text;
        }
      }
    }
  }
  return chapters;
}

({String text, String language}) quranVerseText(Map verse, String language) {
  final translated = (verse['translations'] as Map?)?[language];
  if (language != 'ar' &&
      translated is String &&
      translated.trim().isNotEmpty) {
    return (text: translated, language: language);
  }
  return (text: verse['text']?.toString() ?? '', language: 'ar');
}

/// Only the currently played verse follows the audio language. Other cards keep
/// the selected reading language, avoiding unnecessary text layout changes.
String quranPlaybackTextLanguage(
  int number, {
  required String readingLanguage,
  required bool hasPlayback,
  required int playingVerse,
  required String playingLanguage,
}) =>
    hasPlayback &&
        number == playingVerse &&
        ['ar', 'fr', 'en'].contains(playingLanguage)
    ? playingLanguage
    : readingLanguage;
