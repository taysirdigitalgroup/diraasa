import 'dart:convert';
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
      TextButton(onPressed:()=>request('applicationSettings'),child:SacredText(dt('androidSettings'))),
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
}) async {
  final raw = await Store.call('audioCatalog');
  final rows = reminder
      ? <dynamic>[
          {'id': 'asset:audio/reminder.ogg', 'label': dt('gentleBell')},
        ]
      : jsonDecode(raw as String) as List;
  if (!context.mounted) return null;
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheet) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(sheet).height * .7,
        child: ListView(
          children: [
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: SacredText(dt('phoneAudio')),
              onTap: () async {
                final value = await Store.call('pickAzan');
                if (sheet.mounted && value is String)
                  Navigator.pop(sheet, value);
              },
            ),
            for (final row in rows)
              ListTile(
                title: SacredText(row['label'].toString()),
                leading: IconButton(
                  icon: const Icon(Icons.play_circle_outline),
                  onPressed: () =>
                      Store.call('azanPreview', {'audio': row['id']}),
                ),
                onTap: () async {
                  await Store.call('azanStop');
                  if (sheet.mounted) Navigator.pop(sheet, row['id'].toString());
                },
              ),
            TextButton(
              onPressed: () => Store.call('azanStop'),
              child: SacredText(dt('stopAudio')),
            ),
          ],
        ),
      ),
    ),
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
