import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_core.dart';
import '../core/search.dart';
import '../devotion/core.dart';
import '../devotion/hisn.dart';
import '../widgets/controls.dart';
import '../widgets/sacred_text.dart';

// PayPal from DEV ENV; Wave merchant link supplied by the developer.
const donationWave = 'https://pay.wave.com/m/M_sn_DoZfd98ruV_6/c/sn/';
const donationPaypal = 'https://paypal.me/MBENGUE28';
const developerPhone = '+221 76 455 03 58';
const developerPhoneRaw = '+221764550358';
Future<void> openReferenceLink(BuildContext context, String url) async {
  try {
    await Store.call('openExternal', {'url': url});
  } catch (e) {
    if (context.mounted) errorMessage(context, e);
  }
}

class SourcesSection extends StatelessWidget {
  const SourcesSection({super.key});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: SacredText(
          dt('sourcesReferences'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      Card(
        child: Column(
          children: [
            source(
              context,
              'dictionaryReferences',
              Icons.menu_book,
              () => const DictionarySources(),
            ),
            source(
              context,
              'hisnReferences',
              Icons.auto_stories,
              () => const InvocationSources(),
            ),
            source(
              context,
              'hadithReferences',
              Icons.format_quote,
              () => ReferenceDocument(
                title: dt('hadithReferences'),
                text: dt('hadithReferenceText'),
              ),
            ),
            source(
              context,
              'quranReferences',
              Icons.book,
              () => ReferenceDocument(
                title: dt('quranReferences'),
                text:
                    '${dt('quranReferenceText')}\n\nTraduction FR : Muhammad Hamidullah — PDF coran-francais.com fourni.\nTraduction EN : Talal Itani — ClearQuran, édition Allah — PDF fourni, licence Creative Commons Attribution / NonCommercial / NoDerivs mentionnée dans le document.\n114 sourates et 6 236 versets par langue, référencés selon Hafs.\n\nhttps://github.com/taysirdigitalgroup/diraasa-quran-sounds',
                url:
                    'https://github.com/taysirdigitalgroup/diraasa-quran-sounds',
              ),
            ),
            source(
              context,
              'prayerReferences',
              Icons.schedule,
              () => ReferenceDocument(
                title: dt('prayerReferences'),
                text: dt('prayerReferenceText'),
                url: 'https://aladhan.com/prayer-times-api',
              ),
            ),
            source(
              context,
              'audioReferences',
              Icons.music_note,
              () => const AudioSources(),
            ),
          ],
        ),
      ),
    ],
  );
  Widget source(
    BuildContext context,
    String label,
    IconData icon,
    Widget Function() page,
  ) => ListTile(
    key: ValueKey('source-$label'),
    leading: Icon(icon),
    title: SacredText(dt(label)),
    trailing: const Icon(Icons.chevron_right),
    onTap: () =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => page())),
  );
}

class DictionarySources extends StatefulWidget {
  const DictionarySources({super.key});
  @override
  State<DictionarySources> createState() => _DictionarySourcesState();
}

class _DictionarySourcesState extends State<DictionarySources> {
  late Future<List<AppRecord>> pages;
  @override
  void initState() {
    super.initState();
    pages = Store.rows('intro');
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: settings,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: SacredText(dt('dictionaryReferences'))),
      body: FutureBuilder<List<AppRecord>>(
        future: pages,
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return Center(
              child: TextButton(
                onPressed: () => setState(() => pages = Store.rows('intro')),
                child: SacredText(tr('retry')),
              ),
            );
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const ReadingSize(),
              for (final page in snapshot.data!)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: MatchText(
                    page['content'].toString(),
                    selectable: true,
                    style: TextStyle(fontSize: settings.textSize, height: 1.9),
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}

class InvocationSources extends StatefulWidget {
  const InvocationSources({super.key});
  @override
  State<InvocationSources> createState() => _InvocationSourcesState();
}

class _InvocationSourcesState extends State<InvocationSources> {
  Future<AppRecord> read() async => Map<String, dynamic>.from(
    jsonDecode(await rootBundle.loadString('assets/devotion/hisn.json')) as Map,
  );
  late Future<AppRecord> book;
  @override
  void initState() {
    super.initState();
    book = read();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<AppRecord>(
    future: book,
    builder: (context, snapshot) {
      if (snapshot.hasData) return HisnSource(book: snapshot.data!);
      return Scaffold(
        appBar: AppBar(title: SacredText(dt('hisnReferences'))),
        body: Center(
          child: snapshot.hasError
              ? TextButton(
                  onPressed: () => setState(() => book = read()),
                  child: SacredText(tr('retry')),
                )
              : const CircularProgressIndicator(),
        ),
      );
    },
  );
}

class ReferenceDocument extends StatelessWidget {
  const ReferenceDocument({
    super.key,
    required this.title,
    required this.text,
    this.url,
  });
  final String title, text;
  final String? url;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: settings,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: SacredText(title)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const ReadingSize(),
          MatchText(
            text,
            selectable: true,
            style: TextStyle(fontSize: settings.textSize, height: 1.8),
          ),
          if (url != null)
            TextButton.icon(
              onPressed: () => openReferenceLink(context, url!),
              icon: const Icon(Icons.open_in_new),
              label: SacredText(url!),
            ),
        ],
      ),
    ),
  );
}

class AudioSources extends StatefulWidget {
  const AudioSources({super.key});
  @override
  State<AudioSources> createState() => _AudioSourcesState();
}

class _AudioSourcesState extends State<AudioSources> {
  Future<List<dynamic>> read() async =>
      jsonDecode(
            await rootBundle.loadString('assets/devotion/audio_sources.json'),
          )
          as List;
  late Future<List<dynamic>> credits;
  @override
  void initState() {
    super.initState();
    credits = read();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: SacredText(dt('audioReferences'))),
    body: FutureBuilder<List<dynamic>>(
      future: credits,
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return Center(
            child: TextButton(
              onPressed: () => setState(() => credits = read()),
              child: SacredText(tr('retry')),
            ),
          );
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: SacredText(dt('audioReferenceText')),
            ),
            for (final row in snapshot.data!)
              Card(
                child: ListTile(
                  title: SacredText(dt(row['labelKey'].toString())),
                  subtitle: SacredText('${row['author']} · CC0'),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () =>
                      openReferenceLink(context, row['page'].toString()),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class DonationsSection extends StatelessWidget {
  const DonationsSection({super.key});
  Future<void> copyPhone(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: developerPhoneRaw));
    if (context.mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: SacredText(tr('copied'))));
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 16),
      SacredText(
        dt('donateTitle'),
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 8),
      SacredText(dt('donateHint')),
      Card(
        child: ListTile(
          key: const ValueKey('donate-paypal'),
          leading: const Icon(Icons.favorite_outline),
          title: const SacredText('PayPal'),
          subtitle: const SacredText(
            'paypal.me/MBENGUE28',
            textDirection: TextDirection.ltr,
          ),
          trailing: const Icon(Icons.open_in_new),
          onTap: () => openReferenceLink(context, donationPaypal),
        ),
      ),
      Card(
        child: ListTile(
          key: const ValueKey('donate-wave'),
          leading: const Icon(Icons.favorite_outline),
          title: const SacredText('Wave'),
          subtitle: SacredText(
            settings.language == 'ar'
                ? 'التبرع عبر Wave'
                : settings.language == 'en'
                ? 'Donate with Wave'
                : 'Faire un don avec Wave',
          ),
          trailing: const Icon(Icons.open_in_new),
          onTap: () => openReferenceLink(context, donationWave),
        ),
      ),
    ],
  );
}
