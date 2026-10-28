#!/usr/bin/env python3
"""Run the actual Dart controller outside Flutter, with minimal platform adapters.
Usage: python3 tools/quran_background_check.py /path/to/dart
Does not exercise Android notifications or audio output.
"""
import pathlib
import subprocess
import sys
import tempfile

project = pathlib.Path(__file__).resolve().parents[1]
source = (project / 'lib/devotion/quran_audio.dart').read_text()
controller = source[source.index('final _quranAudioEvents'):source.index('class QuranAudioControls')]
program = "import 'dart:async';\nimport '" + (project / 'lib/devotion/quran_audio_plan.dart').as_uri() + "';\n" + r'''
typedef AppRecord = Map<String, dynamic>;
class ChangeNotifier { void notifyListeners() {} void dispose() {} }
class DevStore {
  static final data = <String, dynamic>{};
  static Future<dynamic> read(String key) async => data[key];
  static Future<void> write(String key, dynamic value) async { data[key] = value; }
}
class Store { static Future<dynamic> call(String method, AppRecord? args) async => null; }
''' + controller + r'''
Future<void> main() async {
  final calls = <String>[];
  final current = <String, dynamic>{
    'session':'background-1', 'revision':10, 'state':'playing',
    'chapter':1, 'verse':3, 'mode':'ar-fr-en', 'language':'fr',
    'continuous':true, 'duration':8000, 'position':1000,
  };
  Future<dynamic> api(String method, AppRecord? args) async {
    calls.add(method);
    if (method == 'quranAudioStop') current['state'] = 'stopped';
    return Map<String, dynamic>.from(current);
  }
  final first = QuranAudioController(api:api);
  await first.attach(2);
  assert(!first.active);
  await first.attach(1);
  assert(first.hasPlayback && first.verse == 3);
  assert(first.language == 'ar-fr-en' && first.playingLanguage == 'fr');
  first.dispose();
  await Future<void>.delayed(Duration.zero);
  assert(!calls.contains('quranAudioStop'));
  final second = QuranAudioController(api:api);
  await second.attach(1);
  assert(second.continuous && second.position == 1000);
  deliverQuranAudioEvent({...current, 'revision':11, 'verse':4, 'language':'ar'});
  await Future<void>.delayed(Duration.zero);
  assert(second.verse == 4 && second.playingLanguage == 'ar');
  await second.attach(1); // an older poll must not overwrite a newer event
  assert(second.verse == 4);
  await second.stop();
  assert(calls.where((v) => v == 'quranAudioStop').length == 1);
  second.dispose();
  print('OK: disposal preserves service playback, chapter/mode reattachment, events, stale status rejection, explicit stop');
}
'''
with tempfile.TemporaryDirectory(prefix='diraasa-controller-') as folder:
    file = pathlib.Path(folder) / 'check.dart'
    file.write_text(program)
    subprocess.run([sys.argv[1] if len(sys.argv)>1 else 'dart', '--enable-asserts', str(file)], check=True)
