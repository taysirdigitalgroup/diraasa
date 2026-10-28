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
  assert(quranAudioUri(3, 0, 'ar').toString().endsWith('/hafs/ar/003000.mp3'));
  print(
    'OK: Hafs filenames, raw AR/FR URLs, basmala and continuous/single queues',
  );
}
