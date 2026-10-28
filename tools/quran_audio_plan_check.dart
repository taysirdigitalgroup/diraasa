import '../lib/devotion/quran_audio_plan.dart';

void main() {
  assert(quranAudioFilename(1, 1) == '001001.mp3');
  assert(quranAudioFilename(114, 6) == '114006.mp3');
  assert(
    quranAudioPlaylist(2, [1, 2, 3], 1, continuous: true).join(',') ==
        '0,1,2,3',
  );
  assert(quranAudioPlaylist(1, [1, 2], 1, continuous: true).join(',') == '1,2');
  assert(quranAudioPlaylist(9, [1, 2], 1, continuous: true).join(',') == '1,2');
  assert(
    quranAudioPlaylist(2, [1, 2, 3], 2, continuous: true).join(',') == '2,3',
  );
  assert(
    quranAudioUri(3, 0, 'ar').toString().endsWith('/quran-hafs-ar/003000.mp3'),
  );
  assert(
    quranAudioUri(
      114,
      6,
      'en',
    ).toString().endsWith('/quran-hafs-en/114006.mp3'),
  );
  assert(hafsVerseCounts.length == 114);
  assert(hafsVerseCounts.reduce((a, b) => a + b) == 6236);
  for (var chapter = 1; chapter <= 114; chapter++) {
    for (var verse = 1; verse <= hafsVerseCounts[chapter - 1]; verse++) {
      for (final language in ['ar', 'fr', 'en']) {
        assert(
          quranAudioUri(
            chapter,
            verse,
            language,
          ).path.endsWith(quranAudioFilename(chapter, verse)),
        );
      }
    }
  }
  print(
    'OK: Hafs filenames, raw AR/FR/EN URLs, basmala and continuous/single queues',
  );
}
