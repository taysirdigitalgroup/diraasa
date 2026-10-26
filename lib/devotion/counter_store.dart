import '../core/app_core.dart';
import 'core.dart';

class CounterStore {
  static Future<AppRecord> load() async {
    final saved = await DevStore.read('counterLibrary');
    if (saved is Map) return Map<String, dynamic>.from(saved);
    return {
      'items': [
        {'id': 'subhan', 'text': 'سُبْحَانَ اللَّهِ', 'max': 33},
        {'id': 'hamd', 'text': 'الْحَمْدُ لِلَّهِ', 'max': 33},
        {'id': 'takbir', 'text': 'اللَّهُ أَكْبَرُ', 'max': 34},
      ],
      'chains': [],
      'sessions': {},
    };
  }

  static int _sequence = 0;
  static String id() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_sequence++}';
  static List<AppRecord> rows(AppRecord data, String key) =>
      (data[key] as List? ?? [])
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
}
