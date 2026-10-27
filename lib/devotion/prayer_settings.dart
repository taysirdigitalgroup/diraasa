// Pure helpers shared by display, draft previews and scheduling.
const defaultAzanLeads = <String, int>{
  'Fajr': 45,
  'Dhuhr': 15,
  'Asr': 15,
  'Maghrib': 0,
  'Isha': 15,
};
int prayerMinuteValue(String value, int fallback) {
  final digits = value
      .replaceAllMapped(
        RegExp('[٠-٩]'),
        (m) => (m[0]!.codeUnitAt(0) - 0x660).toString(),
      )
      .replaceAllMapped(
        RegExp('[۰-۹]'),
        (m) => (m[0]!.codeUnitAt(0) - 0x6f0).toString(),
      );
  return int.tryParse(digits.trim()) ?? fallback;
}

Map<String, int> prayerAppliedOffsets(Map options) => {
  for (final p in defaultAzanLeads.keys)
    p: prayerMinuteValue(
      (options['adjustments'] as Map?)?[p]?.toString() ?? '0',
      0,
    ).clamp(-120, 120).toInt(),
};
Map<String, int> prayerAzanLeads(Map? values) => {
  for (final p in defaultAzanLeads.keys)
    p: prayerMinuteValue(
      values?[p]?.toString() ?? '',
      defaultAzanLeads[p]!,
    ).clamp(0, 180).toInt(),
};
Map<String, int> combinedPrayerOffsets(Map options, Map<String, int> leads) {
  final offsets = prayerAppliedOffsets(options);
  return {
    for (final p in defaultAzanLeads.keys)
      p: offsets[p]! - (leads[p] ?? defaultAzanLeads[p]!),
  };
}
