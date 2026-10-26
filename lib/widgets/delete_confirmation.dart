import 'sacred_text.dart';
import 'package:flutter/material.dart';
import '../core/app_core.dart';

Future<bool> confirmDeletion(BuildContext context, {required String question, String? warning}) async {
  final proceed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
    title: SacredText(tr('alert')), content: SacredText(warning ?? tr('deleteWarning')),
    actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: SacredText(tr('cancel'))),
      FilledButton(key: const ValueKey('delete-continue'), onPressed: () => Navigator.pop(context, true), child: SacredText(tr('continue')))]));
  if (proceed != true || !context.mounted) return false;
  return await showDialog<bool>(context: context, builder: (context) => AlertDialog(
    title: SacredText(tr('confirmation')), content: SacredText(question),
    actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: SacredText(tr('cancel'))),
      FilledButton(key: const ValueKey('delete-confirm'), onPressed: () => Navigator.pop(context, true), child: SacredText(tr('delete')))])) == true;
}
