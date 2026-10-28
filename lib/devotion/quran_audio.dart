import 'dart:async';
import 'package:flutter/material.dart';
import '../core/app_core.dart';
import '../widgets/sacred_text.dart';
import 'core.dart';
import 'quran_audio_plan.dart';

String qa(String key) {
  final labels = quranAudioLabels[key];
  return labels == null
      ? tr(key)
      : labels[settings.language == 'ar'
            ? 1
            : settings.language == 'en'
            ? 2
            : 0];
}

const quranAudioLabels = <String, List<String>>{
  'continuous': [
    'Lecture continue de la sourate',
    'تشغيل السورة متتابعة',
    'Continuous surah playback',
  ],
  'audioLanguage': ['Audio', 'الصوت', 'Audio'],
  'ar': ['Arabe', 'العربية', 'Arabic'],
  'fr': ['Français', 'الفرنسية', 'French'],
  'pause': ['Pause', 'إيقاف مؤقت', 'Pause'],
  'resume': ['Reprendre', 'استئناف', 'Resume'],
  'play': ['Écouter', 'استماع', 'Play'],
  'stop': ['Arrêter', 'إيقاف', 'Stop'],
  'basmala': ['Basmala', 'البسملة', 'Basmala'],
  'hafsOnly': [
    'Les audios sont disponibles pour Hafs uniquement.',
    'الصوت متاح لرواية حفص فقط.',
    'Audio is available for Hafs only.',
  ],
  'focus': [
    'Une autre lecture ou alarme utilise l’audio. Réessayez après sa fin.',
    'هناك تشغيل أو منبه يستخدم الصوت. حاول بعد انتهائه.',
    'Another playback or alarm is using audio. Try again when it ends.',
  ],
  'unavailable': [
    'Audio indisponible. Vérifiez la connexion et la présence du fichier dans le dépôt.',
    'الصوت غير متاح. تحقق من الاتصال ووجود الملف في المستودع.',
    'Audio unavailable. Check the connection and that the file exists in the repository.',
  ],
  'streaming': [
    'Écoute en ligne · synchronisation par verset',
    'استماع عبر الإنترنت · متابعة الآية الحالية',
    'Online audio · verse-level synchronization',
  ],
};

typedef QuranAudioApi =
    Future<dynamic> Function(String method, AppRecord? args);

class QuranAudioController extends ChangeNotifier {
  QuranAudioController({QuranAudioApi? api})
    : _api = api ?? ((method, args) => Store.call(method, args));
  final QuranAudioApi _api;
  Timer? _timer;
  bool _disposed = false, _polling = false;
  int _generation = 0;
  String language = 'ar', state = 'stopped', error = '';
  int verse = -1, chapter = 0, position = 0, duration = 0;
  bool continuous = false;
  bool get active => ['playing', 'paused', 'loading'].contains(state);
  Future<void> loadLanguage() async {
    try {
      final value = await DevStore.read('quranAudioLanguage');
      if (!_disposed && _generation == 0 && ['ar', 'fr'].contains(value)) {
        language = value as String;
        notifyListeners();
      }
    } catch (_) {}
  }

  void _apply(dynamic raw) {
    if (_disposed || raw is! Map) return;
    state = raw['state']?.toString() ?? 'stopped';
    verse = (raw['verse'] as num?)?.toInt() ?? -1;
    chapter = (raw['chapter'] as num?)?.toInt() ?? 0;
    position = (raw['position'] as num?)?.toInt() ?? 0;
    duration = (raw['duration'] as num?)?.toInt() ?? 0;
    error = raw['error']?.toString() ?? '';
    if (!active) {
      _timer?.cancel();
      _timer = null;
    }
    notifyListeners();
  }

  Future<void> poll() async {
    if (_disposed || _polling) return;
    _polling = true;
    final token = _generation;
    try {
      final status = await _api('quranAudioStatus', null);
      if (token == _generation) _apply(status);
    } catch (_) {
      if (!_disposed && token == _generation) {
        state = 'error';
        error = 'connection';
        _timer?.cancel();
        notifyListeners();
      }
    } finally {
      _polling = false;
    }
  }

  Future<void> play(
    int surah,
    List<int> verses,
    int start, {
    bool all = false,
  }) async {
    final queue = quranAudioPlaylist(surah, verses, start, continuous: all);
    _timer?.cancel();
    _timer = null;
    final token = ++_generation;
    continuous = all;
    chapter = surah;
    verse = queue.first;
    state = 'loading';
    error = '';
    position = 0;
    duration = 0;
    notifyListeners();
    try {
      final value = await _api('quranAudioStart', {
        'chapter': surah,
        'language': language,
        'verses': queue,
      });
      if (_disposed || token != _generation) return;
      _apply(value);
      _timer?.cancel();
      if (active)
        _timer = Timer.periodic(
          const Duration(milliseconds: 500),
          (_) => poll(),
        );
    } catch (e) {
      if (!_disposed && token == _generation) {
        state = 'error';
        error = e.toString();
        notifyListeners();
      }
    }
  }

  Future<void> _command(String method, [AppRecord? args]) async {
    final token = _generation;
    try {
      final value = await _api(method, args);
      if (token == _generation) _apply(value);
    } catch (e) {
      if (!_disposed && token == _generation) {
        state = 'error';
        error = e.toString();
        _timer?.cancel();
        notifyListeners();
      }
    }
  }

  Future<void> toggle() async {
    if (state == 'playing' || state == 'loading') {
      await _command('quranAudioPause');
    } else if (state == 'paused') {
      await _command('quranAudioResume');
    }
  }

  Future<void> seek(int milliseconds) =>
      _command('quranAudioSeek', {'position': milliseconds});
  Future<void> stop() async {
    ++_generation;
    _timer?.cancel();
    _timer = null;
    if (!_disposed) {
      state = 'stopped';
      verse = -1;
      position = 0;
      duration = 0;
      error = '';
      notifyListeners();
    }
    try {
      await _api('quranAudioStop', null);
    } catch (_) {}
  }

  Future<void> selectLanguage(String value) async {
    if (!['ar', 'fr'].contains(value)) return;
    await stop();
    if (_disposed) return;
    language = value;
    notifyListeners();
    await DevStore.write('quranAudioLanguage', value);
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    _timer?.cancel();
    unawaited(_api('quranAudioStop', null).catchError((Object _) => null));
    super.dispose();
  }
}

class QuranAudioControls extends StatefulWidget {
  const QuranAudioControls({
    super.key,
    required this.audio,
    required this.onContinuous,
  });
  final QuranAudioController audio;
  final VoidCallback onContinuous;
  @override
  State<QuranAudioControls> createState() => _QuranAudioControlsState();
}

class _QuranAudioControlsState extends State<QuranAudioControls> {
  QuranAudioController get audio => widget.audio;
  double? seekValue;
  String time(int ms) =>
      '${(ms ~/ 60000).toString().padLeft(2, '0')}:${((ms ~/ 1000) % 60).toString().padLeft(2, '0')}';
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: audio,
    builder: (context, _) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey('quran-audio-language-${audio.language}'),
                  initialValue: audio.language,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: qa('audioLanguage'),
                    isDense: true,
                  ),
                  items: ['ar', 'fr']
                      .map(
                        (v) => DropdownMenuItem(
                          value: v,
                          child: SacredText(qa(v)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) async {
                    if (v != null) {
                      try {
                        await audio.selectLanguage(v);
                      } catch (e) {
                        if (context.mounted) errorMessage(context, e);
                      }
                    }
                  },
                ),
              ),
              IconButton(
                key: const ValueKey('quran-continuous'),
                tooltip: qa('continuous'),
                icon: Icon(
                  audio.continuous && audio.state == 'playing'
                      ? Icons.pause_circle_outline
                      : Icons.play_circle_outline,
                ),
                onPressed: widget.onContinuous,
              ),
              IconButton(
                tooltip: qa('stop'),
                icon: const Icon(Icons.stop_circle_outlined),
                onPressed: audio.active ? () => audio.stop() : null,
              ),
              if (audio.active)
                SacredText(
                  audio.verse == 0
                      ? qa('basmala')
                      : '${audio.chapter}:${audio.verse}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
            ],
          ),
          if (audio.state == 'loading') const LinearProgressIndicator(),
          if (audio.duration > 0 && audio.active)
            Row(
              children: [
                SacredText(
                  time(audio.position),
                  textDirection: TextDirection.ltr,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                Expanded(
                  child: Slider(
                    value: (seekValue ?? audio.position.toDouble())
                        .clamp(0, audio.duration)
                        .toDouble(),
                    max: audio.duration.toDouble(),
                    onChanged: (v) => setState(() => seekValue = v),
                    onChangeEnd: (v) async {
                      await audio.seek(v.round());
                      if (mounted) setState(() => seekValue = null);
                    },
                  ),
                ),
                SacredText(
                  time(audio.duration),
                  textDirection: TextDirection.ltr,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          if (audio.state == 'error')
            SacredText(
              '${qa(audio.error == 'focus' ? 'focus' : 'unavailable')} ${RegExp(r'^\d{6}\.mp3$').hasMatch(audio.error) ? audio.error : ''}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          if (!audio.active && audio.state != 'error')
            SacredText(
              qa('streaming'),
              style: Theme.of(context).textTheme.labelSmall,
            ),
        ],
      ),
    ),
  );
}
