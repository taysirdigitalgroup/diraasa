// Hafs verse-level audio only. Warsh numbering must never use this playlist.
const quranAudioRepository =
    'https://raw.githubusercontent.com/taysirdigitalgroup/diraasa-quran-sounds/main';
// Verse counts from the bundled Hafs text; excludes separate basmalas.
const hafsVerseCounts = <int>[
  7,
  286,
  200,
  176,
  120,
  165,
  206,
  75,
  129,
  109,
  123,
  111,
  43,
  52,
  99,
  128,
  111,
  110,
  98,
  135,
  112,
  78,
  118,
  64,
  77,
  227,
  93,
  88,
  69,
  60,
  34,
  30,
  73,
  54,
  45,
  83,
  182,
  88,
  75,
  85,
  54,
  53,
  89,
  59,
  37,
  35,
  38,
  29,
  18,
  45,
  60,
  49,
  62,
  55,
  78,
  96,
  29,
  22,
  24,
  13,
  14,
  11,
  11,
  18,
  12,
  12,
  30,
  52,
  52,
  44,
  28,
  28,
  20,
  56,
  40,
  31,
  50,
  40,
  46,
  42,
  29,
  19,
  36,
  25,
  22,
  17,
  19,
  26,
  30,
  20,
  15,
  21,
  11,
  8,
  8,
  19,
  5,
  8,
  8,
  11,
  11,
  8,
  3,
  9,
  5,
  4,
  7,
  3,
  6,
  3,
  5,
  4,
  5,
  6,
];
String quranAudioFilename(int chapter, int verse) {
  if (chapter < 1 ||
      chapter > 114 ||
      verse < 0 ||
      verse >
          (chapter >= 1 && chapter <= 114 ? hafsVerseCounts[chapter - 1] : 0) ||
      (verse == 0 && (chapter == 1 || chapter == 9))) {
    throw ArgumentError('Invalid Hafs audio reference');
  }
  return '${chapter.toString().padLeft(3, '0')}${verse.toString().padLeft(3, '0')}.mp3';
}

Uri quranAudioUri(int chapter, int verse, String language) {
  if (!['ar', 'fr', 'en'].contains(language))
    throw ArgumentError('Audio language');
  return Uri.parse(
    '$quranAudioRepository/quran-hafs-$language/${quranAudioFilename(chapter, verse)}',
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
  for (final verse in verses) {
    if (verse <= 0) throw ArgumentError('Invalid numbered verse');
    quranAudioFilename(chapter, verse);
  }
  final ordered = verses.toSet().toList()..sort();
  if (!ordered.contains(start))
    throw ArgumentError('Verse absent from chapter');
  if (!continuous) return [start];
  return [
    if (start == 1 && chapter != 1 && chapter != 9) 0,
    ...ordered.where((n) => n >= start),
  ];
}
