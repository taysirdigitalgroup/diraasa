import 'package:flutter/material.dart';

import '../widgets/sacred_text.dart';
import 'core.dart';
import 'quran.dart';
import 'hadith.dart';
import 'hisn.dart';
import 'tasbih.dart';
import 'prayers.dart';

class DevotionHub extends StatelessWidget {
  const DevotionHub({super.key, this.embedded = false});
  final bool embedded;
  @override
  Widget build(BuildContext context) {
    final body = ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (embedded)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: SacredText(
              dt('hub'),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
          ),
        for (final feature in <({String label, IconData icon, Widget page})>[
          (
            label: 'quran',
            icon: Icons.auto_stories_outlined,
            page: const QuranPage(),
          ),
          (label: 'hadith', icon: Icons.format_quote, page: const HadithPage()),
          (label: 'hisn', icon: Icons.favorite_outline, page: const HisnPage()),
          (
            label: 'prayers',
            icon: Icons.access_time,
            page: const PrayersPage(),
          ),
          (
            label: 'tasbih',
            icon: Icons.radio_button_checked,
            page: const TasbihPage(),
          ),
        ])
          Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => feature.page),
              ),
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      child: Icon(feature.icon, size: 28),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: SacredText(
                        dt(feature.label),
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
    return embedded
        ? body
        : Scaffold(
            appBar: AppBar(title: SacredText(dt('hub'))),
            body: body,
          );
  }
}
