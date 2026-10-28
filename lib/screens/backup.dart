import 'package:flutter/material.dart';
import '../core/app_core.dart';
import '../widgets/sacred_text.dart';
import '../widgets/delete_confirmation.dart';
import 'privacy.dart';

String bt(String key) {
  final value = backupLabels[key];
  return value == null
      ? tr(key)
      : value[settings.language == 'ar'
            ? 1
            : settings.language == 'en'
            ? 2
            : 0];
}

const backupLabels = <String, List<String>>{
  'backupTitle': [
    'Sauvegarde et Restauration',
    'النسخ الاحتياطي والاستعادة',
    'Backup and Restore',
  ],
  'backupIntro': [
    'Gardez une copie de vos notes, auteurs, thèmes, azkar, wird et préférences, avec vos photos et sons personnels utilisés.',
    'احتفظ بنسخة من ملاحظاتك ومؤلفيك ومواضيعك وأذكارك وأورادك وإعداداتك مع الصور والأصوات الشخصية المستخدمة.',
    'Keep a copy of your notes, authors, themes, azkar, wird and preferences, including your used personal photos and sounds.',
  ],
  'local': ['Sur cet appareil', 'على هذا الجهاز', 'On this device'],
  'export': [
    'Créer une sauvegarde locale',
    'إنشاء نسخة محلية',
    'Create local backup',
  ],
  'import': ['Restaurer un fichier', 'استعادة ملف', 'Restore a file'],
  'drive': ['Google Drive', 'Google Drive', 'Google Drive'],
  'connect': [
    'Se connecter avec Google',
    'تسجيل الدخول باستخدام Google',
    'Sign in with Google',
  ],
  'disconnect': ['Se déconnecter', 'تسجيل الخروج', 'Sign out'],
  'driveBackup': [
    'Sauvegarder sur Drive',
    'النسخ إلى Drive',
    'Back up to Drive',
  ],
  'driveList': ['Mes sauvegardes Drive', 'نسخي على Drive', 'My Drive backups'],
  'driveFolder': [
    'Ouvrir le dossier sur Drive',
    'فتح المجلد على Drive',
    'Open folder in Drive',
  ],
  'notConfigured': [
    'La sauvegarde locale est disponible. La connexion Google nécessite la configuration Firebase décrite dans le guide fourni.',
    'النسخ المحلي متاح. يتطلب تسجيل Google إعداد Firebase الموضح في الدليل.',
    'Local backup is available. Google sign-in needs the Firebase setup described in the included guide.',
  ],
  'manual': [
    'Les sauvegardes sont lancées à votre demande. Une connexion conservée ne signifie pas une synchronisation automatique.',
    'تبدأ النسخ بطلبك. بقاء الاتصال لا يعني مزامنة تلقائية.',
    'Backups run on request. Staying signed in does not mean automatic synchronization.',
  ],
  'privateFile': [
    'Les archives ne sont pas chiffrées par Diraasa. Conservez-les dans un emplacement privé. Les identifiants Google et les autorisations Android ne sont jamais exportés.',
    'لا يشفر Diraasa الأرشيف. احفظه في مكان خاص. لا تُصدّر بيانات دخول Google أو أذونات Android.',
    'Diraasa does not encrypt the archives. Keep them in a private location. Google credentials and Android permissions are never exported.',
  ],
  'restoreWarning': [
    'La restauration remplace les données enregistrées dans l’application par celles de la sauvegarde. Une copie de sécurité locale est créée avant toute modification. Cette opération ne fusionne pas les notes.',
    'ستستبدل الاستعادة بيانات التطبيق ببيانات النسخة. تُنشأ نسخة أمان محلية قبل أي تعديل. لا تُدمج الملاحظات.',
    'Restore replaces the app’s saved data with this backup. A local safety copy is created before any changes. Notes are not merged.',
  ],
  'restore': ['Restaurer', 'استعادة', 'Restore'],
  'summary': ['Contenu de la sauvegarde', 'محتوى النسخة', 'Backup contents'],
  'azkar': ['Azkar', 'الأذكار', 'Azkar'],
  'wird': ['Wird', 'الأوراد', 'Wird'],
  'attachments': ['Photos et sons', 'الصور والأصوات', 'Photos and sounds'],
  'done': ['Sauvegarde créée.', 'تم إنشاء النسخة.', 'Backup created.'],
  'restored': [
    'Données restaurées. Vérifiez les autorisations de rappel et d’azan sur cet appareil.',
    'تمت الاستعادة. تحقق من أذونات التذكير والأذان على هذا الجهاز.',
    'Data restored. Check reminder and adhan permissions on this device.',
  ],
  'recovery': [
    'Copies de sécurité avant restauration',
    'نسخ الأمان قبل الاستعادة',
    'Safety copies before restore',
  ],
  'emptyBackup': [
    'Aucune sauvegarde dans cette liste.',
    'لا توجد نسخ في هذه القائمة.',
    'No backups in this list.',
  ],
  'deleteAccount': [
    'Supprimer mon compte Diraasa',
    'حذف حسابي في Diraasa',
    'Delete my Diraasa account',
  ],
  'deleteAccountWarning': [
    'Supprime le compte de connexion Firebase. Vos données locales et les fichiers de votre Drive restent sous votre contrôle : supprimez les sauvegardes depuis le dossier Drive si vous le souhaitez. Une reconnexion récente peut être demandée.',
    'يحذف حساب تسجيل الدخول في Firebase. تبقى البيانات المحلية وملفات Drive تحت سيطرتك؛ يمكنك حذف النسخ من مجلد Drive. قد يلزم تسجيل دخول حديث.',
    'Deletes the Firebase sign-in account. Your local data and Drive files remain under your control; delete backups from the Drive folder if desired. Recent sign-in may be required.',
  ],
};

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});
  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  bool busy = false, awaitingDecision = false;
  Map<String, dynamic> status = {};
  List<AppRecord>? driveFiles, recoveryFiles;
  String? message, error;
  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    try {
      final value = await Store.call('driveStatus');
      final files = await Store.rows('backupRecoveryList');
      if (mounted)
        setState(() {
          status = value is Map ? Map<String, dynamic>.from(value) : {};
          recoveryFiles = files;
        });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Future<void> run(Future<void> Function() job) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
      message = null;
    });
    try {
      await settings.flush();
      await job();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  // Keep the operation locked while the user decides, but do not run an
  // indeterminate progress animation behind an interactive confirmation.
  Future<T> withDecision<T>(Future<T> Function() show) async {
    if (mounted) setState(() => awaitingDecision = true);
    try {
      return await show();
    } finally {
      if (mounted) setState(() => awaitingDecision = false);
    }
  }

  Future<bool?> ask(WidgetBuilder builder) =>
      withDecision(() => showDialog<bool>(context: context, builder: builder));

  Future<void> restore(String method, [AppRecord? args]) async {
    final summary = await Store.call(method, args);
    if (summary is! Map || !mounted) return;
    try {
      final proceed = await ask(
        (ctx) => AlertDialog(
          title: SacredText(tr('alert')),
          content: SacredText(bt('restoreWarning')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: SacredText(tr('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: SacredText(tr('continue')),
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
      final confirm = await ask(
        (ctx) => AlertDialog(
          title: SacredText(bt('summary')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SacredText(
                  DateTime.fromMillisecondsSinceEpoch(
                    (summary['createdAt'] as num).toInt(),
                  ).toLocal().toString(),
                ),
                for (final key in [
                  'notes',
                  'authors',
                  'themes',
                  'azkar',
                  'wird',
                  'attachments',
                ])
                  SacredText('${bt(key)} : ${summary[key] ?? 0}'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: SacredText(tr('cancel')),
            ),
            FilledButton(
              key: const ValueKey('confirm-restore'),
              onPressed: () => Navigator.pop(ctx, true),
              child: SacredText(bt('restore')),
            ),
          ],
        ),
      );
      if (confirm != true || !mounted) return;
      await Store.call('backupApply');
      await settings.load();
      await refresh();
      if (mounted)
        setState(() {
          driveFiles = null;
          message = bt('restored');
        });
    } finally {
      await Store.call('backupCancel');
    }
  }

  Widget action(
    String key,
    IconData icon,
    VoidCallback callback, {
    String? subtitle,
  }) => Card(
    child: ListTile(
      key: ValueKey(key),
      leading: Icon(icon),
      title: SacredText(bt(key)),
      subtitle: subtitle == null ? null : SacredText(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: busy ? null : callback,
    ),
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(title: SacredText(bt('backupTitle'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SacredText(bt('backupIntro')),
          const SizedBox(height: 12),
          if (busy && !awaitingDecision) const LinearProgressIndicator(),
          if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: SacredText(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (message != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: SacredText(message!),
            ),
          const SizedBox(height: 16),
          SacredText(
            bt('local'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          action(
            'export',
            Icons.save_alt,
            () => run(() async {
              final result = await Store.call('backupExportLocal');
              if (mounted && result != null)
                setState(() => message = bt('done'));
            }),
          ),
          action(
            'import',
            Icons.restore,
            () => run(() => restore('backupPrepareLocal')),
          ),
          const SizedBox(height: 20),
          SacredText(
            bt('drive'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (status['configured'] == false)
            SacredText(
              bt('notConfigured'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (status['connected'] == true) ...[
            ListTile(
              leading: const Icon(Icons.account_circle_outlined),
              title: SacredText(
                status['email']?.toString() ?? '',
                textDirection: TextDirection.ltr,
              ),
              trailing: IconButton(
                tooltip: bt('disconnect'),
                icon: const Icon(Icons.logout),
                onPressed: busy
                    ? null
                    : () => run(() async {
                        await Store.call('driveDisconnect');
                        driveFiles = null;
                        await refresh();
                      }),
              ),
            ),
            action(
              'driveBackup',
              Icons.cloud_upload_outlined,
              () => run(() async {
                await Store.call('driveBackup');
                await refresh();
                if (mounted)
                  setState(() {
                    message = bt('done');
                    driveFiles = null;
                  });
              }),
            ),
            action(
              'driveList',
              Icons.cloud_download_outlined,
              () => run(() async {
                final files = await Store.rows('driveList');
                if (mounted) setState(() => driveFiles = files);
              }),
            ),
            action(
              'driveFolder',
              Icons.folder_open,
              () => run(() async {
                final folder = await Store.call('driveOpenFolder');
                if (folder is Map && folder['url'] is String) {
                  await Store.call('openExternal', {'url': folder['url']});
                }
              }),
            ),
            if (driveFiles != null) ...[
              if (driveFiles!.isEmpty) SacredText(bt('emptyBackup')),
              for (final file in driveFiles!)
                ListTile(
                  leading: const Icon(Icons.inventory_2_outlined),
                  title: SacredText(file['name'].toString()),
                  subtitle: SacredText(file['createdTime']?.toString() ?? ''),
                  trailing: const Icon(Icons.restore),
                  onTap: busy
                      ? null
                      : () => run(
                          () => restore('drivePrepare', {'id': file['id']}),
                        ),
                ),
            ],
            TextButton.icon(
              onPressed: busy
                  ? null
                  : () => run(() async {
                      if (!await withDecision(
                        () => confirmDeletion(
                          context,
                          question: bt('deleteAccount'),
                          warning: bt('deleteAccountWarning'),
                        ),
                      ))
                        return;
                      await Store.call('driveDeleteAccount');
                      driveFiles = null;
                      await refresh();
                    }),
              icon: const Icon(Icons.person_remove_outlined),
              label: SacredText(bt('deleteAccount')),
            ),
          ] else
            action(
              'connect',
              Icons.account_circle_outlined,
              () => run(() async {
                await Store.call('driveConnect');
                await refresh();
              }),
            ),
          const SizedBox(height: 10),
          SacredText(
            bt('manual'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          SacredText(
            bt('privateFile'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (recoveryFiles?.isNotEmpty == true) ...[
            const SizedBox(height: 20),
            SacredText(
              bt('recovery'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            for (final file in recoveryFiles!)
              ListTile(
                title: SacredText(file['name'].toString()),
                trailing: const Icon(Icons.restore),
                onTap: busy
                    ? null
                    : () => run(
                        () => restore('backupPrepareRecovery', {
                          'id': file['id'],
                        }),
                      ),
              ),
          ],
          const SizedBox(height: 28),
          const PrivacyLink(),
        ],
      ),
    ),
  );
}
