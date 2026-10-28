import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import '../core/app_core.dart';
import '../widgets/sacred_text.dart';
import 'core.dart';

Future<bool> ensureAlarmReady(BuildContext context) async {
  final initial = await Store.call('azanStatus') as Map;
  if (initial['notifications'] == true &&
      initial['exact'] == true &&
      initial['background'] == true)
    return true;
  if (!context.mounted) return false;
  return await showDialog<bool>(
        context: context,
        builder: (_) => const AlarmReadiness(),
      ) ??
      false;
}

class AlarmReadiness extends StatefulWidget {
  const AlarmReadiness({super.key});
  @override
  State<AlarmReadiness> createState() => _AlarmReadinessState();
}

class _AlarmReadinessState extends State<AlarmReadiness>
    with WidgetsBindingObserver {
  Map status = {};
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) check();
  }

  Future<void> check() async {
    final s = await Store.call('azanStatus') as Map;
    if (mounted) setState(() => status = s);
  }

  Future<void> request(String method) async {
    try {
      await Store.call(method);
      await check();
    } catch (e) {
      if (mounted) errorMessage(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: SacredText(dt('alarmAccess')),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SacredText(dt('alarmAccessNotice')),
          for (final item in [
            ('notifications', 'azanPermissions', 'notificationAccess'),
            ('exact', 'azanExactSettings', 'exactSettings'),
            ('background', 'backgroundSettings', 'backgroundAccess'),
          ])
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                status[item.$1] == true
                    ? Icons.check_circle
                    : Icons.warning_amber,
              ),
              title: SacredText(dt(item.$3)),
              onTap: () => request(item.$2),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => request('applicationSettings'),
        child: SacredText(dt('androidSettings')),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: SacredText(tr('cancel')),
      ),
      FilledButton(
        onPressed: () async {
          await check();
          if (mounted &&
              status['notifications'] == true &&
              status['exact'] == true &&
              status['background'] == true)
            Navigator.pop(context, true);
        },
        child: SacredText(dt('checkAccess')),
      ),
    ],
  );
}

Future<String?> chooseAlarmAudio(
  BuildContext context, {
  bool reminder = false,
  bool fajr = false,
}) async {
  final raw = await Store.call(reminder ? 'reminderCatalog' : 'audioCatalog');
  final rows = jsonDecode(raw as String) as List;
  final soundCount = rows.length;
  if (reminder) {
    final azans = await Store.call('audioCatalog');
    rows.addAll(jsonDecode(azans as String) as List);
  }
  if (!reminder) {
    rows.removeWhere((r) => (r['id'] == 'asset:audio/adhan_5.m4a') != fajr);
  }
  if (!context.mounted) return null;
  try {
  return await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheet) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(sheet).height * .7,
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: SacredText(
                dt(reminder ? 'chooseAlarmSound' : fajr ? 'chooseFajrAzan' : 'chooseAzan'),
                style: Theme.of(sheet).textTheme.titleLarge,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: SacredText(dt('phoneAudio')),
              onTap: () async {
                final value = await Store.call('pickAzan');
                if (sheet.mounted && value is String)
                  Navigator.pop(sheet, value);
              },
            ),
            for (final entry in rows.asMap().entries) ...[
              if (reminder && (entry.key == 0 || entry.key == soundCount))
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: SacredText(
                    dt(entry.key == 0 ? 'alarmSounds' : 'adhans'),
                    style: Theme.of(sheet).textTheme.titleSmall,
                  ),
                ),
              ListTile(
                title: SacredText(
                  entry.value['labelKey'] == null
                      ? entry.value['label'].toString()
                      : dt(entry.value['labelKey'].toString()),
                ),
                leading: AudioPreviewButton(audio: entry.value['id'].toString()),
                onTap: () async {
                  await Store.call('azanPreviewStop');
                  if (sheet.mounted)
                    Navigator.pop(sheet, entry.value['id'].toString());
                },
              ),
            ],
          ],
        ),
      ),
    ),
  );
  } finally {
    await Store.call('azanPreviewStop');
  }
}

class AudioPreviewButton extends StatefulWidget {
  const AudioPreviewButton({super.key, required this.audio});
  final String audio;
  @override
  State<AudioPreviewButton> createState() => _AudioPreviewButtonState();
}
class _AudioPreviewButtonState extends State<AudioPreviewButton> {
  Timer? timer;
  bool playing = false, busy = false;
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(milliseconds: 500), (_) => refresh());
    refresh();
  }
  Future<void> refresh() async {
    try {
      final status = await Store.call('azanPreviewStatus');
      final next = status is Map && status['audio'] == widget.audio &&
          status['playing'] == true;
      if (mounted && next != playing) setState(() => playing = next);
    } catch (_) {
      if (mounted && playing) setState(() => playing = false);
    }
  }
  Future<void> toggle() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await Store.call('azanPreviewToggle', {'audio': widget.audio});
      await refresh();
    } catch (e) {
      if (mounted) errorMessage(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
  @override
  void dispose() { timer?.cancel(); super.dispose(); }
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: playing ? 'Pause' : dt('testAudio'),
    onPressed: busy ? null : toggle,
    icon: Icon(playing ? Icons.pause_circle_outline : Icons.play_circle_outline),
  );
}

Future<void> testAlarm(BuildContext context, String audio) async {
  try {
    if (!await ensureAlarmReady(context)) return;
    await Store.call('alarmTest', {'audio': audio});
    if (context.mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: SacredText(dt('alarmTestNotice'))));
  } catch (e) {
    if (context.mounted) errorMessage(context, e);
  }
}

String reminderAudioLabel(String audio) {
  if (normalizeBundledAudio(audio) == serigneAdhanAsset)
    return serigneAdhanName;
  const keys = {
    'reminder.ogg': 'gentleBell',
    'reminder_birds.m4a': 'soundBirds',
    'reminder_water.m4a': 'soundWater',
    'reminder_waves.m4a': 'soundWaves',
    'reminder_chime.m4a': 'soundChime',
    'reminder_alarm.m4a': 'soundAlarm',
  };
  final key = audio.startsWith('asset:audio/')
      ? keys[audio.split('/').last]
      : null;
  if (audio.startsWith('asset:audio/adhan_'))
    return '${dt('integratedAdhan')} · ${audio.split('_').last.split('.').first}';
  return dt(key ?? 'phoneAudio');
}
