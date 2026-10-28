// Hafs verse-level audio only. Warsh numbering must never use this playlist.
const quranAudioRepository =
    'https://raw.githubusercontent.com/taysirdigitalgroup/diraasa-quran-sounds/main';
String quranAudioFilename(int chapter, int verse) {
  if (chapter < 1 ||
      chapter > 114 ||
      verse < 0 ||
      verse > 286 ||
      (verse == 0 && (chapter == 1 || chapter == 9))) {
    throw ArgumentError('Invalid Hafs audio reference');
  }
  return '${chapter.toString().padLeft(3, '0')}${verse.toString().padLeft(3, '0')}.mp3';
}

Uri quranAudioUri(int chapter, int verse, String language) {
  if (!['ar', 'fr'].contains(language)) throw ArgumentError('Audio language');
  return Uri.parse(
    '$quranAudioRepository/hafs/$language/${quranAudioFilename(chapter, verse)}',
  );
}

List<int> quranAudioPlaylist(
  int chapter,
  List<int> verses,
  int start, {
  required bool continuous,
}) {
  quranAudioFilename(chapter, start);
  if (start == 0) return [0];
  final ordered = verses.toSet().toList()..sort();
  if (!ordered.contains(start))
    throw ArgumentError('Verse absent from chapter');
  if (!continuous) return [start];
  return [
    if (start == 1 && chapter != 1 && chapter != 9) 0,
    ...ordered.where((n) => n >= start),
  ];
}
