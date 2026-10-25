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
      value: e.key, checked: settings.language == e.key, child: Text(e.value))).toList(),
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
      value: value, checked: settings.theme == value, child: Text(tr(value)))).toList(),
  );
}
class ReadingSize extends StatelessWidget {
  const ReadingSize({super.key});
  @override
  Widget build(BuildContext context) => Row(children: [
    Tooltip(message: tr('textSize'), child: const Icon(Icons.text_fields)),
    Expanded(child: Slider(
      key: const ValueKey('reading-size'), label: settings.textSize.round().toString(),
      min: 18, max: 36, divisions: 18, value: settings.textSize,
      onChanged: (value) { settings.textSize = value; settings.notifySizeChanged(); },
      onChangeEnd: (value) => savePreference(context, {'textSize': value}),
    )),
    Text(settings.textSize.round().toString()),
  ]);
}
