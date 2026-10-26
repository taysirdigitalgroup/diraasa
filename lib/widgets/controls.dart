import 'sacred_text.dart';
import 'package:flutter/material.dart';
import '../core/app_core.dart';

class LanguageMenu extends StatelessWidget {
  const LanguageMenu({super.key});
  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    key: const ValueKey('language-menu'), tooltip: tr('language'), icon: const Icon(Icons.translate, size: 22),
    onSelected: (value) => savePreference(context, {'language': value}),
    itemBuilder: (_) => languageLabels.entries.map((e) => CheckedPopupMenuItem<String>(
      key: ValueKey('language-option-' + e.key),
      value: e.key, checked: settings.language == e.key, child: SacredText(e.value))).toList(),
  );
}
class ThemeMenu extends StatelessWidget {
  const ThemeMenu({super.key});
  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    key: const ValueKey('theme-menu'), tooltip: tr('theme'),
    icon: Icon(settings.theme == 'system' ? Icons.brightness_auto :
      settings.theme == 'dark' ? Icons.dark_mode_outlined : Icons.light_mode_outlined, size: 22),
    onSelected: (value) => savePreference(context, {'theme': value}),
    itemBuilder: (_) => ['system', 'light', 'dark'].map((value) => CheckedPopupMenuItem<String>(
      key: ValueKey('theme-option-' + value),
      value: value, checked: settings.theme == value, child: SacredText(tr(value)))).toList(),
  );
}
class ReadingSize extends StatelessWidget {
  const ReadingSize({super.key});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: settings, builder: (context, _) => Row(children: [
    Tooltip(message: tr('textSize'), child: const Icon(Icons.text_fields)),
    Expanded(child: Slider(
      key: const ValueKey('reading-size'), label: settings.textSize.round().toString(),
      min: 18, max: 36, divisions: 18, value: settings.textSize,
      onChanged: (value) { settings.textSize = value; settings.notifySizeChanged(); },
      onChangeEnd: (value) => savePreference(context, {'textSize': value}),
    )),
    SacredText(settings.textSize.round().toString()),
  ]));
}

/// Keep both menu buttons on the physical right, including in Arabic.
class SettingsMenuRow extends StatelessWidget {
  const SettingsMenuRow({super.key, required this.label, required this.menu});
  final String label;
  final Widget menu;
  @override
  Widget build(BuildContext context) {
    final labelDirection = Directionality.of(context);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(children: [
        Expanded(child: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: SacredText(label, textDirection: labelDirection,
            textAlign: labelDirection == TextDirection.rtl ? TextAlign.right : TextAlign.left),
        )),
        SizedBox(width: 48, height: 48, child: menu),
      ]),
    );
  }
}

Future<String?> showQuickOptions(BuildContext context, List<({String value, String label, IconData icon})> items) =>
  showModalBottomSheet<String>(context: context, showDragHandle: true,
    builder: (context) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: items.map((item) => ListTile(
      leading: Icon(item.icon), title: SacredText(item.label),
      onTap: () => Navigator.pop(context, item.value))).toList())));
