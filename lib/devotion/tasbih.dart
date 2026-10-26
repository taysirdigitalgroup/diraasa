import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_core.dart';
import '../core/search.dart';
import '../widgets/sacred_text.dart';
import '../widgets/delete_confirmation.dart';
import 'core.dart';
import 'reminders.dart';
import 'counter_store.dart';

class TasbihPage extends StatefulWidget {
  const TasbihPage({super.key});
  @override
  State<TasbihPage> createState() => _TasbihPageState();
}

class _TasbihPageState extends State<TasbihPage> {
  AppRecord? data;
  String? error;
  String query = '';
  final search = SacredController();
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final value = await CounterStore.load();
      if (mounted)
        setState(() {
          data = value;
          error = null;
        });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Future<void> edit(String key, [AppRecord? row]) async {
    if (data == null) return;
    final value = await Navigator.push<AppRecord>(
      context,
      MaterialPageRoute(
        builder: (_) => key == 'items'
            ? ZikrEditor(item: row)
            : ChainEditor(chain: row, items: CounterStore.rows(data!, 'items')),
      ),
    );
    if (value == null) return;
    final list = CounterStore.rows(data!, key);
    final index = list.indexWhere((r) => r['id'] == value['id']);
    if (index < 0) {
      list.add(value);
    } else {
      list[index] = value;
    }
    data![key] = list;
    if (key == 'chains' && index >= 0)
      (data!['sessions'] as Map?)?.remove('chain-${value['id']}');
    final reminders = CounterStore.rows(data!, 'reminders');
    for (final reminder in reminders) {
      if (reminder['targetId'] == value['id'] &&
          reminder['chain'] == (key == 'chains'))
        reminder['label'] = (key == 'chains' ? value['name'] : value['text'])
            .toString();
    }
    data!['reminders'] = reminders;
    try {
      await DevStore.write('counterLibrary', data);
      await syncCounterReminders(data!);
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        errorMessage(context, e);
        load();
      }
    }
  }

  Future<void> remove(String key, AppRecord row) async {
    if (!await confirmDeletion(
      context,
      question: dt(key == 'items' ? 'deleteZikr' : 'deleteChain'),
    ))
      return;
    data![key] = CounterStore.rows(
      data!,
      key,
    ).where((r) => r['id'] != row['id']).toList();
    if (key == 'items') {
      final chains = CounterStore.rows(data!, 'chains');
      (data!['sessions'] as Map?)?.remove('single-${row['id']}');
      for (final chain in chains) {
        final old = chain['steps'] as List;
        chain['steps'] = old
            .where((step) => step['itemId'] != row['id'])
            .toList();
        if ((chain['steps'] as List).length != old.length)
          (data!['sessions'] as Map?)?.remove('chain-${chain['id']}');
      }
      data!['chains'] = chains;
    } else {
      (data!['sessions'] as Map?)?.remove('chain-${row['id']}');
    }
    final activeChains = CounterStore.rows(
      data!,
      'chains',
    ).where((c) => (c['steps'] as List).isNotEmpty).map((c) => c['id']).toSet();
    data!['reminders'] = CounterStore.rows(data!, 'reminders')
        .where(
          (r) =>
              !(r['targetId'] == row['id'] &&
                  r['chain'] == (key == 'chains')) &&
              (r['chain'] != true || activeChains.contains(r['targetId'])),
        )
        .toList();
    try {
      await DevStore.write('counterLibrary', data);
      await syncCounterReminders(data!);
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        errorMessage(context, e);
        load();
      }
    }
  }

  Future<void> reminders(AppRecord row, bool chain) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RemindersPage(
          targetId: row['id'].toString(),
          chain: chain,
          label: (chain ? row['name'] : row['text']).toString(),
        ),
      ),
    );
    if (mounted) load();
  }

  Future<void> start(AppRecord row, bool chain) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CounterPage(id: row['id'].toString(), chain: chain),
      ),
    );
    if (mounted) load();
  }

  @override
  Widget build(BuildContext context) {
    final items = data == null
        ? <AppRecord>[]
        : CounterStore.rows(data!, 'items');
    final chains = data == null
        ? <AppRecord>[]
        : CounterStore.rows(data!, 'chains');
    Widget tile(AppRecord row, bool chain) {
      final menu = GlobalKey<PopupMenuButtonState<String>>();
      final key = chain ? 'chains' : 'items';
      return Card(
        child: ListTile(
          onLongPress: () => menu.currentState?.showButtonMenu(),
          title: SacredText(
            (chain ? row['name'] : row['text']).toString(),
            textDirection: direction(
              (chain ? row['name'] : row['text']).toString(),
            ),
          ),
          subtitle: SacredText(
            chain
                ? '${(row['steps'] as List).length} ${dt('step')}'
                : '${row['max']}',
          ),
          onTap: chain && (row['steps'] as List).isEmpty
              ? null
              : () => start(row, chain),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: dt('reminders'),
                onPressed: chain && (row['steps'] as List).isEmpty ? null : () => reminders(row, chain),
                icon: const Icon(Icons.alarm),
              ),
              PopupMenuButton<String>(
                key: menu,
                tooltip: tr('itemOptions'),
                onSelected: (value) =>
                    value == 'edit' ? edit(key, row) : remove(key, row),
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'edit', child: SacredText(tr('edit'))),
                  PopupMenuItem(
                    value: 'delete',
                    child: SacredText(tr('delete')),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: SacredText(dt('tasbih'))),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          TextField(
            controller: search,
            textDirection: direction(
              query,
              fallback: Directionality.of(context),
            ),
            onChanged: (v) => setState(() => query = v),
            decoration: InputDecoration(
              hintText: tr('searchReferences'),
              prefixIcon: const Icon(Icons.search),
            ),
          ),
          if (data == null && error == null) const LinearProgressIndicator(),
          if (error != null)
            TextButton(
              onPressed: load,
              child: SacredText('${tr('retry')} · $error'),
            ),
          Row(
            children: [
              Expanded(
                child: SacredText(
                  dt('azkar'),
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                tooltip: dt('newZikr'),
                onPressed: () => edit('items'),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          ...items
              .where((i) => matchesSearch(i['text'].toString(), query))
              .map((r) => tile(r, false)),
          Row(
            children: [
              Expanded(
                child: SacredText(
                  dt('chains'),
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                tooltip: dt('newChain'),
                onPressed: items.isEmpty ? null : () => edit('chains'),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          ...chains
              .where((i) => matchesSearch(i['name'].toString(), query))
              .map((r) => tile(r, true)),
        ],
      ),
    );
  }
}

class ZikrEditor extends StatefulWidget {
  const ZikrEditor({super.key, this.item});
  final AppRecord? item;
  @override
  State<ZikrEditor> createState() => _ZikrEditorState();
}

class _ZikrEditorState extends State<ZikrEditor> {
  late final text = SacredController(
    text: widget.item?['text']?.toString() ?? '',
  );
  late final maximum = SacredController(
    text: widget.item?['max']?.toString() ?? '33',
  );
  final form = GlobalKey<FormState>();
  @override
  void dispose() {
    text.dispose();
    maximum.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: SacredText(dt('zikr')),
      actions: [
        TextButton(
          onPressed: () {
            if (form.currentState!.validate())
              Navigator.pop(context, {
                'id': widget.item?['id'] ?? CounterStore.id(),
                'text': text.text.trim(),
                'max': int.parse(westernDigits(maximum.text)),
              });
          },
          child: SacredText(tr('save')),
        ),
      ],
    ),
    body: Form(
      key: form,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextFormField(
            controller: text,
            minLines: 3,
            maxLines: null,
            textDirection: direction(
              text.text,
              fallback: Directionality.of(context),
            ),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: dt('formulation')),
            validator: (v) => v!.trim().isEmpty ? dt('required') : null,
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: maximum,
            keyboardType: TextInputType.number,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(labelText: dt('maximum')),
            validator: validMaximum,
          ),
        ],
      ),
    ),
  );
}

String? validMaximum(String? value) {
  final number = int.tryParse(westernDigits(value ?? ''));
  return number == null || number < 1 || number > 100000
      ? dt('invalidNumber')
      : null;
}

class ChainEditor extends StatefulWidget {
  const ChainEditor({super.key, this.chain, required this.items});
  final AppRecord? chain;
  final List<AppRecord> items;
  @override
  State<ChainEditor> createState() => _ChainEditorState();
}

class _ChainEditorState extends State<ChainEditor> {
  late final name = SacredController(
    text: widget.chain?['name']?.toString() ?? '',
  );
  late final List<AppRecord> steps = (widget.chain?['steps'] as List? ?? [])
      .map((s) => Map<String, dynamic>.from(s as Map))
      .toList();
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> step([int? index]) async {
    final result = await showDialog<AppRecord>(
      context: context,
      builder: (_) => StepDialog(
        items: widget.items,
        step: index == null ? null : steps[index],
      ),
    );
    if (result != null && mounted)
      setState(() {
        if (index == null) {
          steps.add(result);
        } else {
          steps[index] = result;
        }
      });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: SacredText(dt('chains')),
      actions: [
        TextButton(
          onPressed: () {
            if (name.text.trim().isEmpty || steps.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: SacredText(
                    dt(steps.isEmpty ? 'notEmptyChain' : 'required'),
                  ),
                ),
              );
              return;
            }
            Navigator.pop(context, {
              'id': widget.chain?['id'] ?? CounterStore.id(),
              'name': name.text.trim(),
              'steps': steps,
            });
          },
          child: SacredText(tr('save')),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        TextField(
          controller: name,
          textDirection: direction(name.text, fallback: Directionality.of(context)),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(labelText: dt('name')),
        ),
        ...steps.asMap().entries.map((entry) {
          final i = entry.key,
              s = entry.value,
              item = widget.items
                  .where((r) => r['id'] == s['itemId'])
                  .firstOrNull;
          return Card(
            child: Column(
              children: [
                ListTile(
                  title: SacredText(item?['text']?.toString() ?? ''),
                  subtitle: SacredText('${s['max']}'),
                  onTap: () => step(i),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      tooltip: dt('moveUp'),
                      onPressed: i == 0
                          ? null
                          : () => setState(() {
                              final a = steps.removeAt(i);
                              steps.insert(i - 1, a);
                            }),
                      icon: const Icon(Icons.arrow_upward),
                    ),
                    IconButton(
                      tooltip: dt('moveDown'),
                      onPressed: i == steps.length - 1
                          ? null
                          : () => setState(() {
                              final a = steps.removeAt(i);
                              steps.insert(i + 1, a);
                            }),
                      icon: const Icon(Icons.arrow_downward),
                    ),
                    IconButton(
                      tooltip: tr('delete'),
                      onPressed: () async {
                        if (await confirmDeletion(
                              context,
                              question: tr('deleteWarning'),
                            ) &&
                            mounted)
                          setState(() => steps.removeAt(i));
                      },
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
        OutlinedButton.icon(
          onPressed: () => step(),
          icon: const Icon(Icons.add),
          label: SacredText(dt('addStep')),
        ),
      ],
    ),
  );
}

class StepDialog extends StatefulWidget {
  const StepDialog({super.key, required this.items, this.step});
  final List<AppRecord> items;
  final AppRecord? step;
  @override
  State<StepDialog> createState() => _StepDialogState();
}

class _StepDialogState extends State<StepDialog> {
  late String id =
      widget.step?['itemId']?.toString() ?? widget.items.first['id'].toString();
  late final maximum = SacredController(
    text:
        widget.step?['max']?.toString() ?? widget.items.first['max'].toString(),
  );
  final form = GlobalKey<FormState>();
  @override
  void dispose() {
    maximum.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: SacredText(dt('step')),
    content: Form(
      key: form,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: id,
              isExpanded: true,
              items: widget.items
                  .map(
                    (i) => DropdownMenuItem(
                      value: i['id'].toString(),
                      child: SacredText(
                        i['text'].toString(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) id = v;
              },
            ),
            TextFormField(
              controller: maximum,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: dt('maximum')),
              validator: validMaximum,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: SacredText(tr('cancel')),
      ),
      FilledButton(
        onPressed: () {
          if (form.currentState!.validate())
            Navigator.pop(context, {
              'itemId': id,
              'max': int.parse(westernDigits(maximum.text)),
            });
        },
        child: SacredText(tr('save')),
      ),
    ],
  );
}

class CounterPage extends StatefulWidget {
  const CounterPage({super.key, required this.id, this.chain = false});
  final String id;
  final bool chain;
  @override
  State<CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<CounterPage> {
  AppRecord? data;
  List<AppRecord> steps = [];
  int index = 0, count = 0;
  bool complete = false;
  String? error;
  String get sessionKey => '${widget.chain ? 'chain' : 'single'}-${widget.id}';
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      steps = [];
      final value = await CounterStore.load(),
          items = CounterStore.rows(value, 'items');
      if (widget.chain) {
        final chain = CounterStore.rows(
          value,
          'chains',
        ).where((r) => r['id'] == widget.id).firstOrNull;
        for (final raw in chain?['steps'] as List? ?? []) {
          final item = items.where((i) => i['id'] == raw['itemId']).firstOrNull;
          if (item != null) steps.add({...item, 'max': raw['max']});
        }
      } else {
        steps = items.where((i) => i['id'] == widget.id).toList();
      }
      final saved = (value['sessions'] as Map?)?[sessionKey] as Map?;
      index = ((saved?['index'] as num?)?.toInt() ?? 0)
          .clamp(0, steps.isEmpty ? 0 : steps.length - 1)
          .toInt();
      count = ((saved?['count'] as num?)?.toInt() ?? 0)
          .clamp(0, steps.isEmpty ? 0 : (steps[index]['max'] as num).toInt())
          .toInt();
      complete =
          saved?['complete'] == true &&
          steps.isNotEmpty &&
          index == steps.length - 1 &&
          count == (steps[index]['max'] as num).toInt();
      if (mounted) setState(() => data = value);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Future<void> persist() async {
    data!['sessions'] ??= <String, dynamic>{};
    (data!['sessions'] as Map)[sessionKey] = {
      'index': index,
      'count': count,
      'complete': complete,
    };
    try {
      await DevStore.write('counterLibrary', data);
    } catch (e) {
      if (mounted) errorMessage(context, e);
    }
  }

  void increment() {
    if (steps.isEmpty || complete) return;
    HapticFeedback.selectionClick();
    setState(() {
      count++;
      if (count >= (steps[index]['max'] as num).toInt()) {
        if (index < steps.length - 1) {
          index++;
          count = 0;
          HapticFeedback.mediumImpact();
        } else {
          complete = true;
        }
      }
    });
    unawaited(persist());
  }

  @override
  Widget build(BuildContext context) {
    if (data == null)
      return Scaffold(
        appBar: AppBar(title: SacredText(dt('counter'))),
        body: Center(
          child: error == null
              ? const CircularProgressIndicator()
              : SacredText(error!),
        ),
      );
    if (steps.isEmpty)
      return Scaffold(
        appBar: AppBar(title: SacredText(dt('counter'))),
        body: Center(child: SacredText(dt('emptyCounter'))),
      );
    final current = steps[index], maximum = (current['max'] as num).toInt();
    return Scaffold(
      appBar: AppBar(
        title: SacredText(dt('counter')),
        actions: [
          IconButton(
            tooltip: dt('reminders'),
            icon: const Icon(Icons.alarm),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RemindersPage(
                    targetId: widget.id,
                    chain: widget.chain,
                    label: current['text'].toString(),
                  ),
                ),
              );
              if (mounted) load();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            SacredText(
              '${dt('step')} ${index + 1}/${steps.length}',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SacredText(
              current['text'].toString(),
              textAlign: TextAlign.center,
              textDirection: direction(current['text'].toString()),
              style: const TextStyle(
                fontSize: 28,
                height: 1.9,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 28),
            Center(
              child: Semantics(
                button: true,
                label: dt('counter'),
                child: GestureDetector(
                  key: const ValueKey('counter-tap'),
                  onTap: increment,
                  child: SizedBox(
                    width: 240,
                    height: 240,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox.expand(
                          child: CircularProgressIndicator(
                            value: count / maximum,
                            strokeWidth: 12,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SacredText(
                              '$count',
                              key: const ValueKey('counter-value'),
                              style: const TextStyle(
                                fontSize: 66,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SacredText('/ $maximum'),
                            if (complete) SacredText(dt('complete')),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: tr('clear'),
                  onPressed: count == 0
                      ? null
                      : () {
                          setState(() {
                            count--;
                            complete = false;
                          });
                          persist();
                        },
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                TextButton.icon(
                  onPressed: () async {
                    if (await confirmDeletion(
                          context,
                          question: dt('resetQuestion'),
                        ) &&
                        mounted) {
                      setState(() {
                        index = 0;
                        count = 0;
                        complete = false;
                      });
                      persist();
                    }
                  },
                  icon: const Icon(Icons.restart_alt),
                  label: SacredText(dt('reset')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
