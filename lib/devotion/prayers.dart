import 'package:flutter/material.dart';

import '../core/app_core.dart';
import '../widgets/sacred_text.dart';
import 'core.dart';

const prayerNames = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];

class PrayersPage extends StatefulWidget {
  const PrayersPage({super.key});
  @override
  State<PrayersPage> createState() => _PrayersPageState();
}

class _PrayersPageState extends State<PrayersPage> {
  final city = SacredController(text: 'Dakar'),
      country = SacredController(text: 'Senegal');
  bool coordinates = false;
  final latitude = SacredController(text: '14.7167'),
      longitude = SacredController(text: '-17.4677');
  final adjustments = {
    for (final p in prayerNames) p: SacredController(text: '0'),
  };
  final form = GlobalKey<FormState>();
  int method = 3;
  bool hanafi = false, busy = true, enabled = false, stale = false;
  String audio = '', timezone = '', error = '';
  List<AppRecord> days = [];
  DateTime date = DateTime.now();
  int until = 0;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    city.dispose();
    country.dispose();
    latitude.dispose();
    longitude.dispose();
    for (final c in adjustments.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> load() async {
    try {
      final bundle = await DevStore.read('prayerBundle');
      final saved = bundle is Map ? bundle['options'] : null;
      if (saved is Map) {
        city.text = saved['city']?.toString() ?? 'Dakar';
        country.text = saved['country']?.toString() ?? 'Senegal';
        coordinates = saved['coordinates'] == true;
        latitude.text = saved['latitude']?.toString() ?? latitude.text;
        longitude.text = saved['longitude']?.toString() ?? longitude.text;
        method = (saved['method'] as num?)?.toInt() ?? 3;
        if(![1,2,3,4,5,12,21].contains(method)) method=3;
        hanafi = saved['hanafi'] == true;
        audio = saved['audio']?.toString() ?? '';
        for (final p in prayerNames) {
          adjustments[p]!.text =
              (saved['adjustments'] as Map?)?[p]?.toString() ?? '0';
        }
      }
      final chosenAudio = await DevStore.read('prayerAudio');
      if (chosenAudio is String) audio = chosenAudio;
      final cache = bundle is Map ? bundle['days'] : null;
      if (cache is List)
        days = cache.map((r) => Map<String, dynamic>.from(r as Map)).toList();
      final status = await Store.call('azanStatus');
      if (status is Map) {
        enabled = status['enabled'] == true;
        until = (status['until'] as num?)?.toInt() ?? 0;
      }
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  AppRecord get options => {
    'city': city.text,
    'country': country.text,
    'coordinates': coordinates,
    'latitude': latitude.text,
    'longitude': longitude.text,
    'method': method,
    'hanafi': hanafi,
    'audio': audio,
    'adjustments': {for (final p in prayerNames) p: adjustments[p]!.text},
  };
  void edited() {
    if (enabled) {
      enabled = false;
      Store.call('azanDisable').catchError((Object e) {
        if (mounted) errorMessage(context, e);
        return null;
      });
    }
    setState(() => stale = true);
  }

  Future<void> refresh() async {
    if (!form.currentState!.validate() || busy) return;
    setState(() {
      busy = true;
      error = '';
    });
    try {
      final now = DateTime.now();
      final next = DateTime(now.year, now.month + 1);
      final rows = <AppRecord>[];
      for (final month in [DateTime(now.year, now.month), next]) {
        final uri = Uri.https(
          'api.aladhan.com',
          '/v1/${coordinates ? 'calendar' : 'calendarByCity'}/${month.year}/${month.month}',
          {
            if (coordinates) 'latitude': latitude.text.trim().replaceAll(',', '.'),
            if (coordinates) 'longitude': longitude.text.trim().replaceAll(',', '.'),
            if (!coordinates) 'city': city.text.trim(),
            if (!coordinates) 'country': country.text.trim(),
            'method': '$method',
            'school': hanafi ? '1' : '0',
            'iso8601': 'true',
          },
        );
        final raw = await fetchJson(uri) as Map;
        if (raw['code'] != 200) throw StateError(raw['status'].toString());
        rows.addAll(
          (raw['data'] as List).map((r) => Map<String, dynamic>.from(r as Map)),
        );
      }
      if (rows.isEmpty) throw StateError('No timings');
      await DevStore.write('prayerBundle', {'options': options, 'days': rows});
      days = rows;
      stale = false;
      if (enabled) await schedule();
    } catch (e) {
      error = '${dt('networkError')}\n$e';
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  List<AppRecord> get events => buildPrayerEvents(days, {
    for (final p in prayerNames)
      p: int.tryParse(westernDigits(adjustments[p]!.text)) ?? 0,
  });
  Future<void> schedule() async {
    final allowed = await Store.call('azanPermissions');
    if (allowed != true) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: SacredText(dt('permissions'))));
      return;
    }
    final status = await Store.call('azanStatus') as Map;
    if (status['exact'] != true) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: SacredText(dt('permissions'))));
      return;
    }
    final rows = events;
    if (audio.isEmpty || rows.isEmpty || stale)
      throw StateError(dt('chooseAudioFirst'));
    final configured = await Store.call('azanSchedule', {
      'audio': audio,
      'events': rows,
    }) as Map;
    enabled = configured['enabled'] == true;
    until = (configured['until'] as num?)?.toInt() ?? 0;
  }

  Future<void> toggle() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      if (enabled) {
        await Store.call('azanDisable');
        enabled = false;
      } else {
        await schedule();
      }
    } catch (e) {
      if (mounted) errorMessage(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> chooseAudio() async {
    try {
      final result = await Store.call('pickAzan');
      if (result is! String) return;
      audio = result;
      await DevStore.write('prayerAudio', audio);
      if (enabled) await schedule();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) errorMessage(context, e);
    }
  }

  Future<void> preview() async {
    try {
      if (await Store.call('azanPermissions') != true) {
        if (mounted)
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: SacredText(dt('permissions'))));
        return;
      }
      await Store.call('azanPreview', {'audio': audio});
    } catch (e) {
      if (mounted) errorMessage(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stamp =
        '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
    final current = days
        .where((r) => (r['date'] as Map)['gregorian']['date'] == stamp)
        .firstOrNull;
    timezone = current?['meta']?['timezone']?.toString() ?? '';
    return Scaffold(
      appBar: AppBar(title: SacredText(dt('prayers'))),
      body: Form(
        key: form,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            SacredText(
              dt('prayerNotice'),
              style: const TextStyle(fontSize: 13, height: 1.6),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: SacredText(dt('coordinatesMode')),
              value: coordinates,
              onChanged: (v) {
                coordinates = v;
                edited();
              },
            ),
            if (!coordinates) ...[
              TextFormField(
                controller: city,
              textDirection: direction(city.text, fallback: Directionality.of(context)),
                decoration: InputDecoration(labelText: dt('city')),
                onChanged: (_) => edited(),
                validator: (v) => v!.trim().isEmpty ? dt('required') : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: country,
              textDirection: direction(country.text, fallback: Directionality.of(context)),
                decoration: InputDecoration(labelText: dt('country')),
                onChanged: (_) => edited(),
                validator: (v) => v!.trim().isEmpty ? dt('required') : null,
              ),
            ],
            if (coordinates)
              TextFormField(
                controller: latitude,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(labelText: dt('latitude')),
                onChanged: (_) => edited(),
                validator: (v) {
                  final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                  return n == null || n < -90 || n > 90 ? dt('required') : null;
                },
              ),
            const SizedBox(height: 12),
            if (coordinates)
              TextFormField(
                controller: longitude,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(labelText: dt('longitude')),
                onChanged: (_) => edited(),
                validator: (v) {
                  final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                  return n == null || n < -180 || n > 180
                      ? dt('required')
                      : null;
                },
              ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              key: ValueKey('prayer-method-$method'),
              initialValue: method,
              isExpanded: true,
              decoration: InputDecoration(labelText: dt('method')),
              items:
                  const <int, String>{
                        1: 'Karachi',
                        2: 'ISNA',
                        3: 'Muslim World League',
                        4: 'Umm al-Qura',
                        5: 'Egypt',
                        12: 'UOIF',
                        21: 'Morocco',
                      }.entries
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: SacredText(e.value),
                        ),
                      )
                      .toList(),
              onChanged: (v) {
                if (v != null) {
                  method = v;
                  edited();
                }
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: SacredText(dt('school')),
              value: hanafi,
              onChanged: (v) {
                hanafi = v;
                edited();
              },
            ),
            ...prayerNames.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextFormField(
                  controller: adjustments[p],
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: true,
                  ),
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: '${dt(p)} · ${dt('offset')}',
                  ),
                  onChanged: (_) => edited(),
                  validator: (v) {
                    final n = int.tryParse(westernDigits(v ?? ''));
                    return n == null || n < -120 || n > 120
                        ? dt('invalidNumber')
                        : null;
                  },
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: busy ? null : refresh,
              icon: const Icon(Icons.refresh),
              label: SacredText(dt('refreshTimes')),
            ),
            if (busy) const LinearProgressIndicator(),
            if (error.isNotEmpty) SacredText(error),
            const Divider(),
            TextButton.icon(
              onPressed: () async {
                final selected = await showDatePicker(
                  context: context,
                  initialDate: date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (selected != null && mounted)
                  setState(() => date = selected);
              },
              icon: const Icon(Icons.calendar_month),
              label: SacredText('$stamp · $timezone'),
            ),
            if (stale) SacredText(dt('refreshTimes')),
            if (current != null && !stale)
              ...prayerNames.map((p) {
                final raw = DateTime.tryParse(
                  (current['timings'] as Map)[p].toString(),
                );
                final offset =
                    int.tryParse(westernDigits(adjustments[p]!.text)) ?? 0;
                // DateTime.parse converts offset timestamps to UTC; use the source's wall-clock text for display.
                final source = (current['timings'] as Map)[p].toString();
                final time = RegExp(r'T(\d\d):(\d\d)').firstMatch(source);
                final minutes = time == null
                    ? null
                    : (int.parse(time[1]!) * 60 +
                              int.parse(time[2]!) +
                              offset +
                              1440) %
                          1440;
                return Card(
                  child: ListTile(
                    title: SacredText(dt(p)),
                    trailing: SacredText(
                      raw == null || minutes == null
                          ? '—'
                          : '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }),
            const Divider(),
            OutlinedButton.icon(
              onPressed: busy ? null : chooseAudio,
              icon: const Icon(Icons.audio_file),
              label: SacredText(dt('audio')),
            ),
            if (audio.isNotEmpty)
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: preview,
                      child: SacredText(dt('testAudio')),
                    ),
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: () => Store.call('azanStop'),
                      child: SacredText(dt('stopAudio')),
                    ),
                  ),
                ],
              ),
            TextButton(
              onPressed: () => Store.call('azanExactSettings'),
              child: SacredText(dt('exactSettings')),
            ),
            FilledButton(
              onPressed: busy ? null : toggle,
              child: SacredText(dt(enabled ? 'deactivate' : 'activate')),
            ),
            if (enabled && until > 0)
              SacredText(
                '${dt('scheduleUntil')} ${DateTime.fromMillisecondsSinceEpoch(until).toLocal()}',
              ),
            const SizedBox(height: 12),
            const SacredText(
              'AlAdhan · https://aladhan.com/prayer-times-api',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

List<AppRecord> buildPrayerEvents(
  List<AppRecord> days,
  Map<String, int> offsets, {
  DateTime? now,
}) {
  final events = <AppRecord>[];
  final instant = (now ?? DateTime.now()).millisecondsSinceEpoch;
  for (final day in days) {
    final timings = day['timings'] as Map;
    for (final prayer in prayerNames) {
      final value = DateTime.tryParse(timings[prayer]?.toString() ?? '');
      if (value == null) continue;
      final at = value
          .add(Duration(minutes: offsets[prayer] ?? 0))
          .millisecondsSinceEpoch;
      if (at > instant) events.add({'at': at, 'name': '${dt(prayer)} · أذان'});
    }
  }
  events.sort((a, b) => (a['at'] as int).compareTo(b['at'] as int));
  return events;
}
