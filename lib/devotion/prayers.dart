import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_core.dart';
import '../widgets/sacred_text.dart';
import 'core.dart';
import 'prayer_clock.dart';
import 'alarm_controls.dart';
import 'prayer_settings.dart';

const prayerNames = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];

class PrayersPage extends StatefulWidget {
  const PrayersPage({super.key, this.fetch});
  final Future<dynamic> Function(Uri)? fetch;
  @override
  State<PrayersPage> createState() => _PrayersPageState();
}

class _PrayersPageState extends State<PrayersPage> with WidgetsBindingObserver {
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
  String audio = 'asset:audio/adhan_1.m4a',
      timezone = '',
      error = '',
      address = '';
  Set<String> activePrayers = prayerNames.toSet();
  List<AppRecord> days = [];
  DateTime date = DateTime.now();
  int until = 0, syncedAt = 0;
  bool adhanWanted = false;
  AppRecord appliedOptions = {};
  Map<String, int> azanLeads = Map.of(defaultAzanLeads);
  final azanDraft = {
    for (final p in prayerNames)
      p: SacredController(text: defaultAzanLeads[p].toString()),
  };
  bool cacheCheckBusy = false;
  int lastAutoAttempt = 0;

  List<AppRecord> audioChoices = [];
  Timer? ticker;
  bool followToday = true;
  String deviceTimezone = '';
  Map<String, String> appliedSections = {};
  String sectionValue(String section) => section == 'azanAdjustments'
      ? jsonEncode({
          for (final p in prayerNames)
            p: prayerMinuteValue(azanDraft[p]!.text, azanLeads[p]!),
        })
      : prayerSectionSignature(options, section);
  bool sectionDirty(String section) => section == 'azanAdjustments'
      ? prayerNames.any(
          (p) =>
              azanDraft[p]!.text.trim().isEmpty ||
              prayerMinuteValue(azanDraft[p]!.text, -999) != azanLeads[p],
        )
      : appliedSections[section] != sectionValue(section);
  Map<String, String> get sectionSignatures => {
    for (final section in ['location', 'method', 'adjustments'])
      section: sectionValue(section),
  };
  Future<void> updateTimezone() async {
    try {
      final zone = await Store.call('localTimezone');
      if (mounted && zone is String) updateState(() => deviceTimezone = zone);
    } catch (_) {
      /* DateTime supplies a local fallback. */
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      updateTimezone();
      checkNewCache();
    }
  }

  StateSetter? _refreshPanel;
  BuildContext? _panelContext;
  void updateState(VoidCallback change) {
    if (!mounted) return;
    setState(change);
    if (_panelContext?.mounted == true) _refreshPanel?.call(() {});
  }

  void _reportError(Object value) {
    if (!mounted) return;
    updateState(() => error = value.toString());
    if (_panelContext?.mounted != true) errorMessage(context, value);
  }

  Future<void> openPanel(String section) async {
    if (busy || _refreshPanel != null) return;
    if (section != 'location') restoreDraft(appliedOptions);
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (sheet) => StatefulBuilder(
          builder: (panel, setPanelState) {
            _refreshPanel = setPanelState;
            _panelContext = panel;
            return FractionallySizedBox(
              heightFactor: .9,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(panel).bottom,
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 8, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: SacredText(
                              dt(
                                section == 'azanAdjustments'
                                    ? 'adjustAzanTimes'
                                    : section == 'audio'
                                    ? 'chooseAzan'
                                    : section == 'adjustments'
                                    ? 'offset'
                                    : section,
                              ),
                              style: Theme.of(panel).textTheme.titleLarge,
                            ),
                          ),
                          IconButton(
                            tooltip: tr('close'),
                            onPressed: () => Navigator.pop(panel),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    if (busy) const LinearProgressIndicator(),
                    if (error.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        child: SacredText(
                          error,
                          style: TextStyle(
                            color: Theme.of(panel).colorScheme.error,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Form(
                          key: form,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: panelFields(section, panel),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    } finally {
      _refreshPanel = null;
      _panelContext = null;
      if (mounted)
        updateState(() {
          restoreDraft(appliedOptions);
          restoreAzanDraft();
        });
      checkNewCache();
    }
  }

  List<Widget> panelFields(String section, BuildContext panel) {
    switch (section) {
      case 'location':
        return [
          FilledButton.tonalIcon(
            onPressed: busy ? null : detect,
            icon: const Icon(Icons.gps_fixed),
            label: SacredText(dt('detectLocation')),
          ),
          if (address.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: SacredText(address),
            ),
          SwitchListTile(
            title: SacredText(dt('coordinatesMode')),
            value: coordinates,
            onChanged: busy
                ? null
                : (v) {
                    coordinates = v;
                    edited();
                  },
          ),
          if (coordinates) ...[
            field(latitude, dt('latitude'), number: true),
            field(longitude, dt('longitude'), number: true),
          ] else ...[
            field(city, dt('city')),
            field(country, dt('country')),
          ],
          sectionRefresh('location'),
        ];
      case 'method':
        return [
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
            onChanged: busy
                ? null
                : (v) {
                    if (v != null) {
                      method = v;
                      edited();
                    }
                  },
          ),
          SwitchListTile(
            title: SacredText(dt('school')),
            value: hanafi,
            onChanged: busy
                ? null
                : (v) {
                    hanafi = v;
                    edited();
                  },
          ),
          sectionRefresh('method'),
        ];
      case 'adjustments':
        return [
          for (final p in prayerNames) adjustmentField(p, false),
          sectionRefresh('adjustments'),
        ];
      case 'azanAdjustments':
        return [
          for (final p in prayerNames) adjustmentField(p, true),
          sectionRefresh('azanAdjustments'),
        ];
      case 'audio':
        return [
          FilledButton.tonalIcon(
            onPressed: busy ? null : chooseAudio,
            icon: const Icon(Icons.library_music),
            label: SacredText(dt('chooseAzan')),
          ),
          const SizedBox(height: 12),
          SacredText(
            audioChoices
                    .where((r) => r['id'] == audio)
                    .firstOrNull?['label']
                    ?.toString() ??
                dt('phoneAudio'),
          ),
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
        ];
      default:
        return [];
    }
  }

  Widget panelIcon(String section, IconData icon, String title) =>
      IconButton.filledTonal(
        key: ValueKey('prayer-panel-$section'),
        tooltip: dt(title),
        onPressed: busy ? null : () => openPanel(section),
        icon: Icon(icon),
      );
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    updateTimezone();
    load();
    ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (DateTime.now().second == 0) {
        updateTimezone();
        checkNewCache();
      }
      if (mounted)
        updateState(() {
          if (followToday) date = DateTime.now();
        });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ticker?.cancel();
    city.dispose();
    country.dispose();
    latitude.dispose();
    longitude.dispose();
    for (final c in [...adjustments.values, ...azanDraft.values]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> load() async {
    if (mounted) updateState(() => busy = true);
    try {
      final catalog = await Store.call('audioCatalog');
      if (!mounted) return;
      if (catalog is String)
        audioChoices = (jsonDecode(catalog) as List)
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList();
      final bundle = await DevStore.read('prayerBundle');
      if (!mounted) return;
      final saved = bundle is Map ? bundle['options'] : null;
      stale = bundle is Map && bundle['stale'] == true;
      if (saved is Map) {
        city.text = saved['city']?.toString() ?? 'Dakar';
        country.text = saved['country']?.toString() ?? 'Senegal';
        coordinates = saved['coordinates'] == true;
        latitude.text = saved['latitude']?.toString() ?? latitude.text;
        longitude.text = saved['longitude']?.toString() ?? longitude.text;
        method = (saved['method'] as num?)?.toInt() ?? 3;
        if (![1, 2, 3, 4, 5, 12, 21].contains(method)) method = 3;
        hanafi = saved['hanafi'] == true;
        address = saved['address']?.toString() ?? '';
        if (saved['activePrayers'] is List)
          activePrayers = (saved['activePrayers'] as List)
              .map((p) => p.toString())
              .toSet();
        audio = saved['audio']?.toString() ?? 'asset:audio/adhan_1.m4a';
        for (final p in prayerNames) {
          adjustments[p]!.text =
              (saved['adjustments'] as Map?)?[p]?.toString() ?? '0';
        }
      }
      appliedOptions = {
        ...options,
        'adjustments': {
          for (final p in prayerNames)
            p: prayerMinuteValue(adjustments[p]!.text, 0).toString(),
        },
      };
      if (bundle is Map) {
        syncedAt = (bundle['syncedAt'] as num?)?.toInt() ?? 0;
        azanLeads = prayerAzanLeads(bundle['azanLeads'] as Map?);
      }
      restoreDraft(appliedOptions);
      restoreAzanDraft();
      final chosenAudio = await DevStore.read('prayerAudio');
      if (!mounted) return;
      if (chosenAudio is String && chosenAudio.isNotEmpty) audio = chosenAudio;
      if (audio.isEmpty) audio = "asset:audio/adhan_1.m4a";
      audio = normalizeBundledAudio(audio);
      final cache = bundle is Map ? bundle['days'] : null;
      if (cache is List)
        days = cache.map((r) => Map<String, dynamic>.from(r as Map)).toList();
      appliedSections = {
        for (final section in ['location', 'method', 'adjustments'])
          section: prayerSectionSignature(appliedOptions, section),
      };
      stale = days.isEmpty;
      final status = await Store.call('azanStatus');
      if (!mounted) return;
      if (status is Map) {
        enabled = status['enabled'] == true;
        until = (status['until'] as num?)?.toInt() ?? 0;
      }
      adhanWanted = bundle is Map && bundle['adhanWanted'] is bool
          ? bundle['adhanWanted'] as bool
          : (status is Map ? status['requested'] == true || enabled : enabled);
      await reconcile();
      await persistBundle();
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) updateState(() => busy = false);
    }
  }

  AppRecord get options => {
    'address': address,
    'activePrayers': activePrayers.toList(),
    'city': city.text,
    'country': country.text,
    'coordinates': coordinates,
    'latitude': latitude.text,
    'longitude': longitude.text,
    'method': method,
    'hanafi': hanafi,
    'audio': audio,
    'adjustments': {
      for (final p in prayerNames)
        p:
            int.tryParse(westernDigits(adjustments[p]!.text))?.toString() ??
            adjustments[p]!.text,
    },
  };
  void restoreDraft(Map source) {
    if (source.isEmpty) return;
    city.text = source['city']?.toString() ?? 'Dakar';
    country.text = source['country']?.toString() ?? 'Senegal';
    coordinates = source['coordinates'] == true;
    latitude.text = source['latitude']?.toString() ?? '14.7167';
    longitude.text = source['longitude']?.toString() ?? '-17.4677';
    address = source['address']?.toString() ?? '';
    method = (source['method'] as num?)?.toInt() ?? 3;
    hanafi = source['hanafi'] == true;
    final offsets = prayerAppliedOffsets(source);
    for (final p in prayerNames) adjustments[p]!.text = offsets[p].toString();
  }

  void restoreAzanDraft() {
    for (final p in prayerNames) azanDraft[p]!.text = azanLeads[p].toString();
  }

  void restoreEmptyMinutes() {
    final offsets = prayerAppliedOffsets(appliedOptions);
    for (final p in prayerNames) {
      if (adjustments[p]!.text.trim().isEmpty)
        adjustments[p]!.text = offsets[p].toString();
      if (azanDraft[p]!.text.trim().isEmpty)
        azanDraft[p]!.text = azanLeads[p].toString();
    }
  }

  void edited() {
    updateState(() => error = '');
  }

  Future<void> persistBundle() async {
    await DevStore.write('prayerBundle', {
      'options': {
        ...appliedOptions,
        'audio': audio,
        'activePrayers': activePrayers.toList(),
      },
      'days': days,
      'syncedAt': syncedAt,
      'adhanWanted': adhanWanted,
      'azanLeads': azanLeads,
      'appliedSections': appliedSections,
    });
    final cached = await DevStore.read('prayerBundle');
    if (cached is Map &&
        ((cached['syncedAt'] as num?)?.toInt() ?? 0) > syncedAt) {
      days = (cached['days'] as List)
          .map((d) => Map<String, dynamic>.from(d as Map))
          .toList();
      syncedAt = (cached['syncedAt'] as num).toInt();
    }
  }

  Future<void> checkNewCache() async {
    if (!mounted || busy || cacheCheckBusy || _panelContext != null) return;
    cacheCheckBusy = true;
    try {
      final raw = await DevStore.read('prayerBundle');
      if (mounted &&
          _panelContext == null &&
          raw is Map &&
          ((raw['syncedAt'] as num?)?.toInt() ?? 0) > syncedAt)
        await load();
      if (mounted &&
          !busy &&
          _panelContext == null &&
          adhanWanted &&
          !enabled) {
        await reconcile();
        if (mounted) updateState(() {});
      }
      if (mounted && !busy && _panelContext == null && days.isNotEmpty) {
        final end = days
            .map(
              (d) =>
                  DateTime.tryParse(
                    (d['timings'] as Map?)?['Isha']?.toString() ?? '',
                  )?.millisecondsSinceEpoch ??
                  0,
            )
            .fold<int>(0, (a, b) => a > b ? a : b);
        if (end > 0 &&
            end <= DateTime.now().millisecondsSinceEpoch &&
            DateTime.now().millisecondsSinceEpoch - lastAutoAttempt >=
                15 * 60 * 1000) {
          lastAutoAttempt = DateTime.now().millisecondsSinceEpoch;
          await refresh();
        }
      }
    } catch (_) {
    } finally {
      cacheCheckBusy = false;
    }
  }

  Future<void> applyPanel(String section) async {
    if (busy) return;
    restoreEmptyMinutes();
    if (form.currentState?.validate() == false) return;
    if (section == 'location' || section == 'method') {
      await refresh();
      return;
    }
    if (section != 'adjustments' && section != 'azanAdjustments') return;
    updateState(() {
      busy = true;
      error = '';
    });
    final old = appliedOptions, oldLeads = Map<String, int>.from(azanLeads);
    bool committed = false;
    try {
      if (section == 'adjustments') {
        for (final p in prayerNames) {
          final v = int.tryParse(westernDigits(adjustments[p]!.text));
          if (v == null || v.abs() > 120) throw StateError(dt('invalidOffset'));
        }
        appliedOptions = {
          ...appliedOptions,
          'adjustments': {
            for (final p in prayerNames)
              p:
                  int.tryParse(
                    westernDigits(adjustments[p]!.text),
                  )?.toString() ??
                  adjustments[p]!.text,
          },
        };
      } else {
        for (final p in prayerNames) {
          final v = int.tryParse(westernDigits(azanDraft[p]!.text));
          if (v == null || v < 0 || v > 180)
            throw StateError(dt('invalidLead'));
        }
        azanLeads = {
          for (final p in prayerNames)
            p: int.parse(westernDigits(azanDraft[p]!.text)),
        };
      }
      await persistBundle();
      committed = true;
      appliedSections = {
        for (final section in ['location', 'method', 'adjustments'])
          section: prayerSectionSignature(appliedOptions, section),
      };
      await reconcile();
    } catch (e) {
      if (!committed) {
        appliedOptions = old;
        azanLeads = oldLeads;
      }
      _reportError(e);
    } finally {
      if (mounted) updateState(() => busy = false);
    }
  }

  AppRecord? get displayedDay {
    final stamp =
        '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
    return days
            .where((d) => (d['date'] as Map?)?['gregorian']?['date'] == stamp)
            .firstOrNull ??
        days.lastOrNull;
  }

  String adjustedTime(String prayer, {bool lead = false, bool draft = false}) {
    final day = displayedDay;
    if (day == null) return '—';
    var minutes = prayerAppliedOffsets(appliedOptions)[prayer] ?? 0;
    if (draft && !lead) {
      final value = prayerMinuteValue(adjustments[prayer]!.text, minutes);
      if (value.abs() <= 120) minutes = value;
    }
    if (lead) {
      var value = draft
          ? prayerMinuteValue(azanDraft[prayer]!.text, azanLeads[prayer]!)
          : azanLeads[prayer]!;
      if (value < 0 || value > 180) value = azanLeads[prayer]!;
      minutes -= value;
    }
    return wallTime((day['timings'] as Map)[prayer]?.toString() ?? '', minutes);
  }

  Widget adjustmentField(String prayer, bool lead) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      children: [
        Expanded(
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: TextFormField(
              key: ValueKey('${lead ? 'azan' : 'prayer'}-offset-$prayer'),
              controller: lead ? azanDraft[prayer] : adjustments[prayer],
              enabled: !busy,
              keyboardType: TextInputType.numberWithOptions(signed: !lead),
              textDirection: TextDirection.ltr,
              inputFormatters: lead
                  ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩۰-۹]'))]
                  : null,
              decoration: InputDecoration(
                labelText: dt(prayer),
                prefixIcon: lead
                    ? const Center(
                        widthFactor: 1,
                        child: Text('-', style: TextStyle(fontSize: 22)),
                      )
                    : null,
                prefixIconConstraints: lead
                    ? const BoxConstraints(minWidth: 32, maxWidth: 32)
                    : null,
              ),
              onChanged: (_) => edited(),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return null;
                final v = int.tryParse(westernDigits(value));
                return v == null || (lead ? (v < 0 || v > 180) : v.abs() > 120)
                    ? dt(lead ? 'invalidLead' : 'invalidOffset')
                    : null;
              },
            ),
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 76,
          child: SacredText(
            adjustedTime(prayer, lead: lead, draft: true),
            key: ValueKey('${lead ? 'azan' : 'prayer'}-preview-$prayer'),
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
  Future<void> refresh() async {
    if (busy) return;
    restoreEmptyMinutes();
    if (form.currentState?.validate() == false) return;
    if (!coordinates &&
        (city.text.trim().isEmpty || country.text.trim().isEmpty)) {
      _reportError(dt('required'));
      return;
    }
    if (coordinates) {
      final lat = double.tryParse(latitude.text.replaceAll(',', '.')),
          lon = double.tryParse(longitude.text.replaceAll(',', '.'));
      if (lat == null || lon == null || lat.abs() > 90 || lon.abs() > 180) {
        _reportError(dt('required'));
        return;
      }
    }
    for (final c in adjustments.values) {
      final n = int.tryParse(westernDigits(c.text));
      if (n == null || n.abs() > 120) {
        _reportError(dt('invalidNumber'));
        return;
      }
    }
    final requestOptions = jsonEncode(options);
    final requested = Map<String, dynamic>.from(
      jsonDecode(requestOptions) as Map,
    );
    final requestSections = sectionSignatures;
    updateState(() {
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
          '/v1/${requested['coordinates'] == true ? 'calendar' : 'calendarByCity'}/${month.year}/${month.month}',
          {
            if (requested['coordinates'] == true)
              'latitude': requested['latitude'].toString().trim().replaceAll(
                ',',
                '.',
              ),
            if (requested['coordinates'] == true)
              'longitude': requested['longitude'].toString().trim().replaceAll(
                ',',
                '.',
              ),
            if (requested['coordinates'] != true)
              'city': requested['city'].toString().trim(),
            if (requested['coordinates'] != true)
              'country': requested['country'].toString().trim(),
            'method': requested['method'].toString(),
            'school': requested['hanafi'] == true ? '1' : '0',
            'iso8601': 'true',
          },
        );
        final raw = await (widget.fetch ?? fetchJson)(uri) as Map;
        if (raw['code'] != 200) throw StateError(raw['status'].toString());
        rows.addAll(
          (raw['data'] as List).map((r) => Map<String, dynamic>.from(r as Map)),
        );
      }
      if (rows.isEmpty) throw StateError('No timings');
      if (!mounted) return;
      if (requestOptions != jsonEncode(options))
        throw StateError(dt('refreshTimes'));
      if (!mounted) return;
      final previousOptions = appliedOptions,
          previousDays = days,
          previousSynced = syncedAt;
      appliedOptions = Map<String, dynamic>.from(options);
      days = rows;
      syncedAt = DateTime.now().millisecondsSinceEpoch;
      try {
        await persistBundle();
      } catch (e) {
        appliedOptions = previousOptions;
        days = previousDays;
        syncedAt = previousSynced;
        rethrow;
      }
      appliedSections = requestSections;
      stale = false;
      await reconcile();
    } catch (e) {
      error = '${dt('networkError')}\n$e';
    } finally {
      if (mounted) updateState(() => busy = false);
    }
  }

  List<AppRecord> get events => buildPrayerEvents(
    days,
    combinedPrayerOffsets(appliedOptions, azanLeads),
    enabledPrayers: activePrayers,
  );
  Future<void> reconcile() async {
    final rows = events;
    if (!adhanWanted || rows.isEmpty) {
      await Store.call('azanDisable');
      enabled = false;
      until = 0;
      return;
    }
    final status = await Store.call('azanStatus') as Map;
    if (status['notifications'] != true ||
        status['exact'] != true ||
        status['background'] != true) {
      await Store.call('azanDisable');
      enabled = false;
      return;
    }
    final configured =
        await Store.call('azanSchedule', {
              'audio': audio,
              'events': rows,
              'fromPrayerCache': true,
            })
            as Map;
    enabled = configured['enabled'] == true;
    until = (configured['until'] as num?)?.toInt() ?? 0;
  }

  Future<void> toggle([bool? value]) async {
    if (busy) return;
    updateState(() => busy = true);
    final oldWanted = adhanWanted;
    bool committed = false;
    try {
      final want = value ?? !adhanWanted;
      if (want && !await ensureAlarmReady(context)) return;
      adhanWanted = want;
      await persistBundle();
      committed = true;
      await reconcile();
    } catch (e) {
      if (!committed) adhanWanted = oldWanted;
      _reportError(e);
    } finally {
      if (mounted) updateState(() => busy = false);
    }
  }

  Future<void> chooseAudio() async {
    try {
      final result = await chooseAlarmAudio(context);
      if (result is! String) return;
      audio = result;
      await DevStore.write('prayerAudio', audio);
      await persistBundle();
      await reconcile();
      if (mounted) updateState(() {});
    } catch (e) {
      if (mounted) _reportError(e);
    }
  }

  Future<void> preview() async {
    try {
      if (await Store.call('azanPermissions') != true) {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: SacredText(dt('permissions'))));
        return;
      }
      await Store.call('azanPreview', {'audio': audio});
    } catch (e) {
      if (mounted) _reportError(e);
    }
  }

  Future<void> detect() async {
    if (busy) return;
    updateState(() => busy = true);
    try {
      final pos = await Store.call('detectLocation') as Map;
      if (!mounted) return;
      latitude.text = pos['latitude'].toString();
      longitude.text = pos['longitude'].toString();
      address = pos['address']?.toString() ?? '';
      try {
        final place =
            await fetchJson(
                  Uri.https('nominatim.openstreetmap.org', '/reverse', {
                    'lat': latitude.text,
                    'lon': longitude.text,
                    'format': 'jsonv2',
                    'zoom': '18',
                    'addressdetails': '1',
                    'accept-language': settings.language,
                  }),
                )
                as Map;
        address = place['display_name']?.toString() ?? address;
        final details = place['address'] as Map?;
        final locality =
            details?['city'] ??
            details?['town'] ??
            details?['village'] ??
            details?['suburb'];
        if (locality != null) city.text = locality.toString();
        if (details?['country'] != null)
          country.text = details!['country'].toString();
      } catch (_) {
        /* Coordinates remain usable when reverse lookup is unavailable. */
      }
      if (!mounted) return;

      if (address.isEmpty) address = dt('locationUnknown');
      if (pos['city'].toString().isNotEmpty) city.text = pos['city'].toString();
      if (pos['country'].toString().isNotEmpty)
        country.text = pos['country'].toString();
      coordinates = true;
      edited();
    } catch (e) {
      if (mounted) _reportError(e);
    } finally {
      if (mounted) updateState(() => busy = false);
    }
  }

  Widget field(SacredController c, String label, {bool number = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: c,
          enabled: !busy,
          textDirection: number ? TextDirection.ltr : direction(c.text),
          keyboardType: number
              ? const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                )
              : TextInputType.text,
          decoration: InputDecoration(labelText: label),
          onChanged: (_) {
            if (c == latitude || c == longitude || c == city || c == country)
              address = '';
            edited();
          },
          validator: (v) =>
              v == null || v.trim().isEmpty ? dt('required') : null,
        ),
      );
  Widget sectionRefresh(String section) => Align(
    alignment: AlignmentDirectional.centerEnd,
    child: FilledButton.tonalIcon(
      key: ValueKey('refresh-$section'),
      onPressed: busy || !sectionDirty(section)
          ? null
          : () => applyPanel(section),
      icon: const Icon(Icons.refresh, size: 18),
      label: SacredText(dt('apply')),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final stamp =
        '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
    final current = displayedDay;
    timezone =
        current?['meta']?['timezone']?.toString() ??
        DateTime.now().timeZoneName;
    final colors = Theme.of(context).colorScheme;
    final localZone = deviceTimezone.isEmpty
        ? DateTime.now().timeZoneName
        : deviceTimezone;
    return Scaffold(
      appBar: AppBar(title: SacredText(dt('prayers'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: colors.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 350),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Stack(
                        children: [
                          const Positioned.fill(
                            child: Padding(
                              padding: EdgeInsets.all(30),
                              child: PrayerClock(),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            left: 0,
                            child: panelIcon(
                              'location',
                              Icons.location_on_outlined,
                              'location',
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            child: panelIcon(
                              'method',
                              Icons.calculate_outlined,
                              'method',
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: panelIcon(
                              'adjustments',
                              Icons.tune,
                              'offset',
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: panelIcon(
                              'audio',
                              Icons.volume_up_outlined,
                              'chooseAzan',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SacredText(
                    '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')} · ${dt('localTime')}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.calendar_month),
                    label: SacredText('$stamp · $localZone'),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null && mounted)
                        updateState(() {
                          date = picked;
                          followToday = false;
                        });
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: TextButton.icon(
                          onPressed: busy ? null : detect,
                          icon: const Icon(Icons.my_location, size: 18),
                          label: SacredText(
                            dt('location'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      Flexible(
                        child: TextButton.icon(
                          key: const ValueKey('prayer-global-refresh'),
                          onPressed: busy ? null : refresh,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: SacredText(
                            dt('refresh'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if ((appliedOptions['address']?.toString() ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: SacredText(
                appliedOptions['address'].toString(),
                style: const TextStyle(fontSize: 13, height: 1.5),
              ),
            ),
          if (appliedOptions['coordinates'] == true)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: SacredText(
                '© OpenStreetMap contributors',
                style: TextStyle(fontSize: 10),
              ),
            ),
          if (busy) const LinearProgressIndicator(),
          if (error.isNotEmpty) SacredText(error),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: SacredText(
              dt('prayerTimes'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          SacredText(
            '${dt('lastSync')}: ${syncedAt == 0 ? '—' : syncLabel(syncedAt)}',
            key: const ValueKey('prayer-last-sync'),
            style: const TextStyle(fontSize: 11),
          ),
          if (current != null &&
              (current['date'] as Map)['gregorian']['date'] != stamp)
            SacredText(
              '${dt('cachedTimesDate')} ${(current['date'] as Map)['gregorian']['date']}',
              style: const TextStyle(fontSize: 11),
            ),
          if (timezone != localZone && days.isNotEmpty)
            SacredText(
              '${dt('prayerTimes')} · $timezone',
              style: const TextStyle(fontSize: 11),
            ),
          if (stale) SacredText(dt('refreshTimes')),
          for (final p in prayerNames)
            Card(
              child: ListTile(
                leading: IconButton(
                  tooltip: dt(
                    activePrayers.contains(p) ? 'deactivate' : 'activate',
                  ),
                  icon: Icon(
                    activePrayers.contains(p)
                        ? Icons.notifications_active
                        : Icons.notifications_off_outlined,
                    color: activePrayers.contains(p)
                        ? colors.primary
                        : colors.outline,
                  ),
                  onPressed: busy
                      ? null
                      : () async {
                          updateState(() {
                            if (!activePrayers.remove(p)) activePrayers.add(p);
                          });
                          try {
                            await persistBundle();
                            await reconcile();
                          } catch (e) {
                            _reportError(e);
                          }
                          if (mounted) updateState(() {});
                        },
                ),
                title: SacredText(dt(p)),
                trailing: SacredText(
                  adjustedTime(p),
                  key: ValueKey('prayer-time-$p'),
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextButton.icon(
                    onPressed: busy ? null : () => testAlarm(context, audio),
                    icon: const Icon(Icons.alarm),
                    label: SacredText(dt('alarmTest')),
                  ),
                  SwitchListTile(
                    title: SacredText(dt('activateAzan')),
                    value: enabled,
                    onChanged: busy ? null : (v) => toggle(v),
                    secondary: Icon(
                      enabled
                          ? Icons.notifications_active
                          : Icons.notifications_off_outlined,
                    ),
                  ),
                  TextButton(
                    key: const ValueKey('adjust-azan-times'),
                    onPressed: busy ? null : () => openPanel('azanAdjustments'),
                    child: SacredText(dt('adjustAzanTimes')),
                  ),
                  if (adhanWanted && !enabled) ...[
                    SacredText(
                      dt('azanWaiting'),
                      style: const TextStyle(fontSize: 12),
                    ),
                    TextButton(
                      onPressed: busy ? null : () => toggle(false),
                      child: SacredText(dt('cancelAutoResume')),
                    ),
                  ],
                  if (enabled && until > 0)
                    SacredText(
                      '${dt('scheduleUntil')} ${DateTime.fromMillisecondsSinceEpoch(until).toLocal()}',
                      style: const TextStyle(fontSize: 12),
                    ),
                ],
              ),
            ),
          ),
          SacredText(
            dt('prayerNotice'),
            style: const TextStyle(fontSize: 12, height: 1.6),
          ),
          const SizedBox(height: 12),
          const SacredText(
            'AlAdhan · https://aladhan.com/prayer-times-api',
            style: TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
  }
}

String wallTime(String source, int adjustment) {
  final match = RegExp(r'T(\d\d):(\d\d)').firstMatch(source);
  if (match == null) return '—';
  final minutes =
      (int.parse(match[1]!) * 60 + int.parse(match[2]!) + adjustment) % 1440;
  return '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
}

List<AppRecord> buildPrayerEvents(
  List<AppRecord> days,
  Map<String, int> offsets, {
  DateTime? now,
  Set<String>? enabledPrayers,
}) {
  final events = <AppRecord>[];
  final instant = (now ?? DateTime.now()).millisecondsSinceEpoch;
  for (final day in days) {
    final timings = day['timings'] as Map;
    for (final prayer in prayerNames) {
      if (enabledPrayers != null && !enabledPrayers.contains(prayer)) continue;
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

/// Fingerprints use only calculation settings; choosing an audio never dirties times.
String prayerSectionSignature(AppRecord options, String section) {
  switch (section) {
    case 'location':
      return jsonEncode(
        options['coordinates'] == true
            ? [
                true,
                double.tryParse(
                  options['latitude'].toString().trim().replaceAll(',', '.'),
                ),
                double.tryParse(
                  options['longitude'].toString().trim().replaceAll(',', '.'),
                ),
              ]
            : [
                false,
                options['city'].toString().trim().toLowerCase(),
                options['country'].toString().trim().toLowerCase(),
              ],
      );
    case 'method':
      return jsonEncode([options['method'], options['hanafi'] == true]);
    case 'adjustments':
      return jsonEncode([
        for (final prayer in prayerNames)
          int.tryParse(
            westernDigits(
              (options['adjustments'] as Map?)?[prayer]?.toString() ?? '0',
            ),
          ),
      ]);
    default:
      throw ArgumentError.value(section);
  }
}

String syncLabel(int milliseconds) {
  final t = DateTime.fromMillisecondsSinceEpoch(milliseconds).toLocal();
  return '${t.day.toString().padLeft(2, '0')}-${t.month.toString().padLeft(2, '0')}-${t.year} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
}
