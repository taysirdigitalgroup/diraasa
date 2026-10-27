import 'package:flutter/material.dart';

import '../core/app_core.dart';
import '../widgets/sacred_text.dart';
import '../widgets/delete_confirmation.dart';
import 'core.dart';
import 'alarm_controls.dart';
import 'counter_store.dart';

Future<void> syncCounterReminders(AppRecord data) async {
  await Store.call('remindersConfigure', {
    'reminders': data['reminders'] as List? ?? [],
  });
}

class RemindersPage extends StatefulWidget {
  const RemindersPage({
    super.key,
    required this.targetId,
    required this.chain,
    required this.label,
  });
  final String targetId, label;
  final bool chain;
  @override
  State<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends State<RemindersPage> {
  AppRecord? data;
  String? error;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final value = await CounterStore.load();
      if (mounted) setState(() => data = value);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Future<bool> permissions() => ensureAlarmReady(context);

  Future<void> edit([AppRecord? reminder]) async {
    final value = await Navigator.push<AppRecord>(
      context,
      MaterialPageRoute(builder: (_) => ReminderEditor(reminder: reminder)),
    );
    if (value == null || data == null) return;
    if (value['enabled'] == true && !await permissions()) return;
    value.addAll({
      'targetId': widget.targetId,
      'chain': widget.chain,
      'label': widget.label,
    });
    final rows = CounterStore.rows(data!, 'reminders');
    final index = rows.indexWhere((r) => r['id'] == value['id']);
    if (index < 0) {
      rows.add(value);
    } else {
      rows[index] = value;
    }
    data!['reminders'] = rows;
    await save();
  }

  Future<void> save() async {
    setState(() => busy = true);
    try {
      await DevStore.write('counterLibrary', data);
      await syncCounterReminders(data!);
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) errorMessage(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> remove(AppRecord row) async {
    if (!await confirmDeletion(context, question: dt('deleteReminder'))) return;
    data!['reminders'] = CounterStore.rows(
      data!,
      'reminders',
    ).where((r) => r['id'] != row['id']).toList();
    await save();
  }

  @override
  Widget build(BuildContext context) {
    final rows = data == null
        ? <AppRecord>[]
        : CounterStore.rows(data!, 'reminders')
              .where(
                (r) =>
                    r['targetId'] == widget.targetId &&
                    r['chain'] == widget.chain,
              )
              .toList();
    return Scaffold(
      appBar: AppBar(
        title: SacredText(dt('reminders')),
        actions: [
          IconButton(
            tooltip: dt('newReminder'),
            onPressed: data == null || busy ? null : () => edit(),
            icon: const Icon(Icons.add_alarm),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          SacredText(
            widget.label,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          SacredText(dt('reminderNotice')),
          TextButton(
            onPressed: () => Store.call('azanExactSettings'),
            child: SacredText(dt('exactSettings')),
          ),
          if (data == null && error == null) const LinearProgressIndicator(),
          if (error != null) SacredText(error!),
          ...rows.map((row) {
            final menu = GlobalKey<PopupMenuButtonState<String>>();
            return Card(
              child: ListTile(
                onLongPress: () => menu.currentState?.showButtonMenu(),
                leading: Switch(
                  value: row['enabled'] == true,
                  onChanged: busy
                      ? null
                      : (enabled) async {
                          if (enabled && !await permissions()) return;
                          final all = CounterStore.rows(data!, 'reminders');
                          final i = all.indexWhere((r) => r['id'] == row['id']);
                          all[i]['enabled'] = enabled;
                          data!['reminders'] = all;
                          await save();
                        },
                ),
                title: SacredText(
                  '${row['hour'].toString().padLeft(2, '0')}:${row['minute'].toString().padLeft(2, '0')}',
                ),
                subtitle: SacredText(
                  (row['weekdays'] as List).map((d) => dt('day$d')).join(' · '),
                ),
                onTap: () => edit(row),
                trailing: PopupMenuButton<String>(
                  key: menu,
                  tooltip: tr('itemOptions'),
                  onSelected: (v) => v == 'edit' ? edit(row) : remove(row),
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'edit', child: SacredText(tr('edit'))),
                    PopupMenuItem(
                      value: 'delete',
                      child: SacredText(tr('delete')),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class ReminderEditor extends StatefulWidget {
  const ReminderEditor({super.key, this.reminder});
  final AppRecord? reminder;
  @override
  State<ReminderEditor> createState() => _ReminderEditorState();
}

class _ReminderEditorState extends State<ReminderEditor> {
  late TimeOfDay time = TimeOfDay(
    hour: (widget.reminder?['hour'] as num?)?.toInt() ?? 8,
    minute: (widget.reminder?['minute'] as num?)?.toInt() ?? 0,
  );
  late Set<int> days =
      (widget.reminder?['weekdays'] as List? ?? [1, 2, 3, 4, 5, 6, 7])
          .map((v) => (v as num).toInt())
          .toSet();
  late String audio =
      widget.reminder?['audio']?.toString() ?? 'asset:audio/reminder.ogg';
  late bool enabled = widget.reminder?['enabled'] != false;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: SacredText(dt('newReminder')),
      actions: [
        TextButton(
          onPressed: () {
            if (days.isEmpty) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: SacredText(dt('chooseDays'))));
              return;
            }
            Navigator.pop(context, {
              'id': widget.reminder?['id'] ?? CounterStore.id(),
              'hour': time.hour,
              'minute': time.minute,
              'weekdays': days.toList()..sort(),
              'enabled': enabled,
              'audio': audio,
            });
          },
          child: SacredText(tr('save')),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        ListTile(
          leading: const Icon(Icons.schedule),
          title: SacredText(
            time.format(context),
            style: const TextStyle(fontSize: 32),
          ),
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: time,
            );
            if (picked != null && mounted) setState(() => time = picked);
          },
        ),
        Wrap(
          spacing: 8,
          children: [
            for (var day = 1; day <= 7; day++)
              FilterChip(
                label: SacredText(dt('day$day')),
                selected: days.contains(day),
                onSelected: (v) => setState(() {
                  if (v) {
                    days.add(day);
                  } else {
                    days.remove(day);
                  }
                }),
              ),
          ],
        ),
        ListTile(
          leading: const Icon(Icons.music_note),
          title: SacredText(dt('audio')),
          subtitle: SacredText(
            audio.startsWith('asset:') ? dt('gentleBell') : dt('phoneAudio'),
          ),
          onTap: () async {
            final v = await chooseAlarmAudio(context, reminder: true);
            if (v != null && mounted) setState(() => audio = v);
          },
        ),
        TextButton(
          onPressed: () => Store.call('azanPreview', {'audio': audio}),
          child: SacredText(dt('testAudio')),
        ),
        TextButton(
          onPressed: () => Store.call('azanStop'),
          child: SacredText(dt('stopAudio')),
        ),
        TextButton(onPressed:()=>testAlarm(context,audio),child:SacredText(dt('alarmTest'))),
        SwitchListTile(
          title: SacredText(dt('activateReminder')),
          value: enabled,
          onChanged: (v) => setState(() => enabled = v),
        ),
      ],
    ),
  );
}
