import 'package:flutter/material.dart';
import '../core/app_core.dart';
import '../widgets/sacred_text.dart';
import 'sources.dart';

String get privacyTitle => settings.language == 'ar'
    ? 'سياسة الخصوصية'
    : settings.language == 'en'
    ? 'Privacy policy'
    : 'Politique de confidentialité';
const privacySections = <List<String>>[
  [
    'Responsable et contact',
    'المسؤول والتواصل',
    'Controller and contact',
    'Diraasa (com.tdg.diraasa) est éditée par Aliou Mbengue, Taysir Digital Group (TDG), Sénégal. Contact : taysirdigitalgroup@gmail.com — +221 76 455 03 58. Politique mise à jour le 30 octobre 2026.',
    'يصدر Diraasa (com.tdg.diraasa) عن Aliou Mbengue، Taysir Digital Group (TDG)، السنغال. التواصل: taysirdigitalgroup@gmail.com — +221 76 455 03 58. آخر تحديث: 30 أكتوبر 2026.',
    'Diraasa (com.tdg.diraasa) is published by Aliou Mbengue, Taysir Digital Group (TDG), Senegal. Contact: taysirdigitalgroup@gmail.com — +221 76 455 03 58. Updated 30 October 2026.',
  ],
  [
    'Données enregistrées sur le téléphone',
    'البيانات المحفوظة على الهاتف',
    'Data stored on your phone',
    'Vos notes, thèmes, auteurs et leurs photos, azkar, wird, compteurs, rappels, réglages de lecture, langue et apparence sont enregistrés dans l’espace privé de l’application. Les coordonnées, adresses et horaires de prière mémorisés servent aux fonctionnalités de prière. Les textes religieux et le dictionnaire sont intégrés. Aucune traduction externe automatique n’est effectuée.',
    'تُحفظ الملاحظات والمواضيع والمؤلفون وصورهم والأذكار والأوراد والعدادات والتذكيرات وإعدادات القراءة واللغة والمظهر في مساحة التطبيق الخاصة. تُستخدم المواقع والعناوين ومواقيت الصلاة المحفوظة لوظائف الصلاة. النصوص الدينية والمعجم مضمنة. لا توجد ترجمة خارجية تلقائية.',
    'Notes, themes, authors and their photos, azkar, wird, counters, reminders, reading settings, language and appearance are stored in the app’s private storage. Saved coordinates, addresses and prayer times support prayer features. Religious texts and the dictionary are bundled. No automatic external translation is performed.',
  ],
  [
    'Connexion Google et sauvegardes Drive',
    'اتصال Google ونسخ Drive',
    'Google sign-in and Drive backups',
    'La connexion Google est facultative. Google et Firebase Authentication traitent les informations nécessaires à l’authentification (identifiant de compte, adresse e-mail et informations de profil éventuellement fournies par Google). La session est conservée jusqu’à déconnexion, suppression du compte ou invalidation. Les jetons sont gérés par les SDK Google/Firebase et ne sont pas exportés dans les sauvegardes. L’autorisation drive.file permet de gérer les fichiers créés par Diraasa, sans demander l’accès à tout votre Drive. Les sauvegardes sont envoyées à votre demande dans le dossier Diraasa — Sauvegardes de votre compte. Aucun stockage de vos notes sur un serveur TDG n’est mis en place.',
    'تسجيل Google اختياري. تعالج Google وFirebase Authentication معلومات تسجيل الدخول اللازمة، مثل معرّف الحساب والبريد ومعلومات الملف التي توفرها Google. يبقى الاتصال حتى تسجيل الخروج أو حذف الحساب أو إبطاله. تدير حزم Google/Firebase الرموز ولا تُصدّر في النسخ. يتيح إذن drive.file إدارة الملفات التي أنشأها Diraasa دون طلب الوصول الكامل إلى Drive. تُرفع النسخ بطلبك إلى مجلد Diraasa — Sauvegardes في حسابك. لا تُخزن ملاحظاتك على خادم TDG.',
    'Google sign-in is optional. Google and Firebase Authentication process information needed to authenticate you (account identifier, email and profile information Google may provide). The session persists until sign-out, account deletion or invalidation. Google/Firebase SDKs manage tokens; backups never include them. The drive.file permission manages files created by Diraasa without requesting full Drive access. Backups are uploaded on request to Diraasa — Sauvegardes in your account. TDG does not operate a server storing your notes.',
  ],
  [
    'Contenu et protection des sauvegardes',
    'محتوى النسخ وحمايتها',
    'Backup contents and protection',
    'Les archives comprennent les données utilisateur et préférences, les photos d’auteurs et sons personnels référencés, ainsi que les coordonnées et caches de prière enregistrés. Elles excluent les textes intégrés, identifiants Google et autorisations Android. Elles ne sont pas chiffrées par Diraasa : toute personne ayant le fichier peut lire son contenu. Les transferts Drive utilisent HTTPS. Ne partagez pas ces archives publiquement. Les contrôles SHA-256 détectent une altération mais ne certifient pas l’origine d’une archive. Restaurez seulement des fichiers de confiance. Une copie locale de sécurité est conservée avant chaque restauration.',
    'تضم النسخ بياناتك وإعداداتك وصور المؤلفين والأصوات الشخصية المستخدمة والمواقع ومواقيت الصلاة المحفوظة. لا تضم النصوص المضمنة أو بيانات دخول Google أو أذونات Android. لا يشفر Diraasa الأرشيف، ويمكن لمن يملك الملف قراءته. تستخدم عمليات Drive بروتوكول HTTPS. لا تنشر النسخ علنًا. يكشف SHA-256 التلف ولا يثبت مصدر الملف. استعد الملفات الموثوقة فقط. تُحفظ نسخة أمان محلية قبل كل استعادة.',
    'Archives include user data and preferences, referenced author photos and personal sounds, and saved prayer locations and caches. Bundled texts, Google credentials and Android permissions are excluded. Diraasa does not encrypt archives: anyone with the file can read them. Drive transfers use HTTPS. Do not share archives publicly. SHA-256 checks detect corruption but do not authenticate the archive’s author. Restore only trusted files. A local safety copy is retained before each restore.',
  ],
  [
    'Localisation, réseau et autorisations',
    'الموقع والشبكة والأذونات',
    'Location, network and permissions',
    'La localisation est demandée lors d’une détection que vous lancez ; aucun suivi GPS permanent n’est effectué. Les coordonnées ou la ville, le pays et les paramètres de calcul sont transmis à AlAdhan pour obtenir les horaires. Le géocodage utilise les services Android et peut utiliser Nominatim/OpenStreetMap pour obtenir l’adresse. Ces services reçoivent aussi les données techniques de connexion, dont l’adresse IP. Les horaires mémorisés peuvent être renouvelés en arrière-plan au lieu enregistré, sans redétection GPS. Les notifications, alarmes exactes et fonctionnement en arrière-plan servent aux rappels et azans activés. Photos, sons et sauvegardes sont choisis via le sélecteur système ; aucun accès global aux contacts, messages ou médias n’est demandé.',
    'يُطلب الموقع عند بدء الكشف يدويًا، ولا يوجد تتبع GPS دائم. تُرسل الإحداثيات أو المدينة والبلد وطريقة الحساب إلى AlAdhan للحصول على المواقيت. تستخدم العناوين خدمات Android وقد تستخدم Nominatim/OpenStreetMap. تتلقى الخدمات معلومات الاتصال التقنية ومنها IP. يمكن تحديث المواقيت في الخلفية للموقع المحفوظ دون كشف GPS جديد. تخدم أذونات الإشعارات والمنبهات الدقيقة والخلفية التذكيرات والأذان المفعلة. تُختار الصور والأصوات والنسخ عبر منتقي النظام دون وصول شامل إلى جهات الاتصال أو الرسائل أو الوسائط.',
    'Location is requested when you initiate detection; no continuous GPS tracking occurs. Coordinates or city, country and calculation settings are sent to AlAdhan for prayer times. Address lookup uses Android services and may use Nominatim/OpenStreetMap. These services also receive connection data such as your IP address. Cached prayer times may renew in the background for the saved place without a new GPS lookup. Notifications, exact alarms and background permissions support enabled reminders and adhans. Photos, sounds and backups use the system picker; no broad access to contacts, messages or media is requested.',
  ],
  [
    'Conservation, suppression et vos choix',
    'الاحتفاظ والحذف وخياراتك',
    'Retention, deletion and your choices',
    'Vous pouvez consulter, corriger et supprimer vos contenus dans l’application. Les données locales et copies de sécurité restent jusqu’à leur suppression ou l’effacement des données/désinstallation. Les sauvegardes locales exportées et Drive restent à l’endroit choisi jusqu’à votre suppression ; la déconnexion ou la suppression du compte Diraasa ne les efface pas. Vous pouvez ouvrir le dossier Drive depuis Sauvegarde et Restauration et supprimer ses fichiers dans Drive. La suppression du compte de connexion Firebase est proposée sur cette même page ; elle ne supprime pas votre compte Google. Vous pouvez retirer l’accès Diraasa dans les paramètres de votre compte Google et révoquer les autorisations Android. Pour une demande d’accès ou de suppression concernant les données du compte gérées par TDG/Firebase, écrivez à taysirdigitalgroup@gmail.com depuis l’adresse concernée ; nous pouvons vérifier votre identité. Nous ne conservons pas de copie serveur de vos notes.',
    'يمكنك مراجعة محتواك وتعديله وحذفه داخل التطبيق. تبقى البيانات المحلية ونسخ الأمان حتى حذفها أو مسح بيانات التطبيق أو إزالته. تبقى النسخ المصدرة ومحفوظات Drive حتى تحذفها؛ تسجيل الخروج أو حذف حساب Diraasa لا يمسحها. افتح مجلد Drive من صفحة النسخ واحذف ملفاته في Drive. تتوفر أيضًا إمكانية حذف حساب Firebase دون حذف حساب Google. يمكنك سحب وصول Diraasa من إعدادات Google وأذونات Android. لطلبات الوصول أو حذف بيانات الحساب التي تديرها TDG/Firebase، راسل taysirdigitalgroup@gmail.com من البريد المعني؛ قد نتحقق من هويتك. لا نحتفظ بنسخة خادم من ملاحظاتك.',
    'You can view, edit and delete your content in the app. Local data and safety copies remain until removed or app data is cleared/the app is uninstalled. Exported local files and Drive backups remain where you saved them until you delete them; signing out or deleting your Diraasa account does not remove them. Open the Drive folder from Backup and Restore to delete files in Drive. That page also offers Firebase sign-in account deletion; this does not delete your Google account. You can revoke Diraasa access in your Google Account and Android permissions in system settings. For access or deletion requests about account data managed by TDG/Firebase, email taysirdigitalgroup@gmail.com from the relevant address; identity verification may be needed. We keep no server copy of your notes.',
  ],
  [
    'Services tiers, dons et utilisation limitée',
    'الخدمات الخارجية والتبرعات والاستخدام المحدود',
    'Third parties, donations and limited use',
    'Diraasa ne contient ni publicité ni module Analytics ajouté. Les données Google sont utilisées uniquement pour la connexion et la sauvegarde/restauration demandées, sans vente ni utilisation publicitaire ; l’utilisation respecte la politique Google API Services User Data Policy, y compris les exigences Limited Use. Les liens PayPal, Wave, site TDG et contact ouvrent une application ou un site externe soumis à sa propre politique. Aucun numéro de carte ou mot de passe de paiement n’est collecté dans Diraasa. Ne saisissez pas de données sensibles inutiles dans les champs libres. Pour toute question ou demande concernant un mineur, contactez TDG. Cette politique sera mise à jour si les traitements changent.',
    'لا يضم Diraasa إعلانات أو وحدة Analytics مضافة. تُستخدم بيانات Google لتسجيل الدخول والنسخ والاستعادة المطلوبة فقط دون بيع أو استخدام إعلاني، مع الالتزام بسياسة Google API Services User Data Policy ومتطلبات Limited Use. تفتح روابط PayPal وWave وموقع TDG والتواصل خدمات خارجية بسياساتها الخاصة. لا يجمع Diraasa أرقام بطاقات أو كلمات مرور للدفع. تجنب إدخال بيانات حساسة غير لازمة في الحقول الحرة. لأي سؤال أو طلب يتعلق بقاصر، تواصل مع TDG. سنحدث السياسة عند تغير المعالجة.',
    'Diraasa includes no advertising or added Analytics module. Google data is used only for requested sign-in and backup/restore, without sale or advertising use, following Google API Services User Data Policy including Limited Use requirements. PayPal, Wave, TDG website and contact links open external apps or sites with their own policies. Diraasa does not collect payment card numbers or payment passwords. Avoid unnecessary sensitive information in free-text fields. Contact TDG for questions or requests concerning a minor. This policy will be updated when processing changes.',
  ],
  [
    'Audio du Coran',
    'صوت القرآن',
    'Quran audio',
    'À votre demande, les audios Hafs en arabe, français ou anglais sont diffusés depuis le dépôt public GitHub de TDG via raw.githubusercontent.com. GitHub reçoit les informations techniques de connexion, dont votre adresse IP, ainsi que le chemin du fichier indiquant le verset et la langue demandés. Aucun identifiant Google ni contenu de vos notes ne lui est transmis. Un cache temporaire conserve l’audio en cours et jusqu’à deux suivants ; en mode mixte, les langues du verset courant et du suivant, sous limite de taille. Internet est nécessaire pour les fichiers absents du cache ; ceux déjà chargés peuvent être réutilisés pendant la session. Le cache est renouvelé, ne constitue pas une bibliothèque hors ligne et n’est pas inclus dans les sauvegardes. La lecture lancée peut continuer en arrière-plan et écran éteint avec un service Android et une notification multimédia permettant de la mettre en pause ou de l’arrêter. Le verset et la langue en cours peuvent apparaître sur l’écran verrouillé selon vos réglages Android.',
    'بطلبك تُبث ملفات حفص العربية أو الفرنسية أو الإنجليزية من مستودع TDG العام على GitHub عبر raw.githubusercontent.com. تتلقى GitHub معلومات الاتصال التقنية ومنها عنوان IP ومسار الملف الذي يحدد الآية واللغة. لا تُرسل إليها بيانات دخول Google أو ملاحظاتك. يحفظ تخزين مؤقت الصوت الحالي وما يصل إلى صوتين تاليين؛ وفي الوضع المختلط لغات الآية الحالية والتالية ضمن حد للحجم. يلزم الإنترنت للملفات غير المخزنة؛ ويمكن إعادة استخدام الملفات المحملة أثناء الجلسة. يُجدد التخزين المؤقت ولا يمثل مكتبة دائمة بلا اتصال ولا يدخل في النسخ الاحتياطية. يمكن أن يستمر الصوت الذي تشغله في الخلفية والشاشة مطفأة عبر خدمة Android وإشعار وسائط للإيقاف المؤقت أو الإنهاء. قد تظهر الآية واللغة على شاشة القفل وفق إعدادات Android.',
    'On request, Arabic, French or English Hafs audio streams from TDG’s public GitHub repository via raw.githubusercontent.com. GitHub receives technical connection data, including your IP address and the requested file path identifying the verse and language. No Google credentials or notes content is sent to GitHub. A temporary cache holds the current audio and up to two following recordings; mixed mode retains the languages of the current and next verses, within a size limit. Internet is needed for uncached files; loaded files can be reused during the session. The rotating cache is not a permanent offline library and is excluded from backups. Playback you start can continue in the background and with the screen off using an Android service and media notification with pause and stop controls. The current verse and language may appear on the lock screen according to your Android settings.',
  ],
];

class PrivacyLink extends StatelessWidget {
  const PrivacyLink({super.key});
  @override
  Widget build(BuildContext context) => ListTile(
    key: const ValueKey('privacy-link'),
    leading: const Icon(Icons.shield_outlined),
    title: SacredText(privacyTitle),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PrivacyPage()),
    ),
  );
}

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});
  @override
  Widget build(BuildContext context) {
    final language = settings.language == 'ar'
        ? 1
        : settings.language == 'en'
        ? 2
        : 0;
    return Scaffold(
      appBar: AppBar(title: SacredText(privacyTitle)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          for (final section in privacySections) ...[
            SacredText(
              section[language],
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            SacredSelectableText(section[language + 3]),
            const SizedBox(height: 24),
          ],
          TextButton.icon(
            onPressed: () => openReferenceLink(
              context,
              'mailto:taysirdigitalgroup@gmail.com',
            ),
            icon: const Icon(Icons.mail_outline),
            label: const SacredText('taysirdigitalgroup@gmail.com'),
          ),
        ],
      ),
    );
  }
}
