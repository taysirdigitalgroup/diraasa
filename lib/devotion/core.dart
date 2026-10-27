import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/app_core.dart';
import '../core/search.dart';

String dt(String key) {
  final values = devotionLabels[key];
  return values == null
      ? tr(key)
      : values[settings.language == 'ar'
            ? 1
            : settings.language == 'en'
            ? 2
            : 0];
}

const devotionLabels = <String, List<String>>{
  'cults': ['Cultes', 'العبادات', 'Worship'],
  'sourcesReferences': [
    'Sources et Références',
    'المصادر والمراجع',
    'Sources and References',
  ],
  'dictionaryReferences': [
    'Introduction et références du dictionnaire',
    'مقدمة المعجم ومراجعه',
    'Dictionary introduction and references',
  ],
  'hisnReferences': [
    'Introduction et bienfaits du zikr · حصن المسلم',
    'مقدمة حصن المسلم وفضل الذكر',
    'Hisnul Muslim introduction and virtues of dhikr',
  ],
  'quranReferences': [
    'Textes et polices du Coran',
    'نصوص القرآن وخطوطه',
    'Quran texts and fonts',
  ],
  'prayerReferences': [
    'Références des horaires de prière',
    'مصادر مواقيت الصلاة',
    'Prayer times references',
  ],
  'audioReferences': ['Crédits des sons', 'مصادر الأصوات', 'Sound credits'],
  'quranReferenceText': [
    'Les textes Hafs et Warsh et leurs polices KFGQPC sont ceux fournis pour Diraasa. Chaque lecture est affichée avec sa police et conserve la numérotation de son fichier source.',
    'نصوص حفص وورش وخطوط KFGQPC هي الملفات المرفقة بمشروع دراسة. تعرض كل رواية بخطها وترقيم ملفها الأصلي.',
    'Hafs and Warsh texts and their KFGQPC fonts are the files supplied for Diraasa. Each reading uses its corresponding font and preserves its source numbering.',
  ],
  'prayerReferenceText': [
    'Les horaires sont calculés par AlAdhan selon le lieu, la méthode, le calcul de Asr et les ajustements choisis. Le fuseau des horaires est celui du lieu. Vérifiez les horaires avec votre mosquée et actualisez avant la fin de la période mémorisée.',
    'تحسب المواقيت عبر AlAdhan وفق المكان وطريقة الحساب وحساب العصر والتعديلات المختارة. المنطقة الزمنية للمواقيت تخص المكان. راجع المواقيت مع مسجدك وحدّثها قبل انتهاء الفترة المحفوظة.',
    'Times are calculated by AlAdhan using the selected location, method, Asr calculation and adjustments. Timings use the location’s timezone. Check with your mosque and refresh before the cached period ends.',
  ],
  'audioReferenceText': [
    'Les adhans ont été fournis pour cette application. Les signaux de rappel sont issus de créations publiées sous CC0 ; leurs auteurs et sources figurent ci-dessous.',
    'ملفات الأذان مرفقة بهذا التطبيق. أصوات التذكير منشورة بترخيص CC0، ومؤلفوها ومصادرها مذكورون أدناه.',
    'Adhan files were supplied for this app. Reminder sounds are published under CC0; their authors and sources are listed below.',
  ],
  'donateTitle': ['Faire un don', 'التبرع', 'Donate'],
  'donateHint': [
    'Soutenir le développement de Diraasa et les projets TDG.',
    'دعم تطوير دراسة ومشاريع TDG.',
    'Support Diraasa development and TDG projects.',
  ],
  'donationDetailsOnRequest': [
    'Contactez TDG pour obtenir les coordonnées de don de ce service.',
    'تواصل مع TDG للحصول على بيانات التبرع عبر هذه الخدمة.',
    'Contact TDG for donation details for this service.',
  ],
  'contactTdg': ['Contacter TDG', 'التواصل مع TDG', 'Contact TDG'],

  'refresh': ['Actualiser', 'تحديث', 'Refresh'],
  'chooseAzan': ['Choisir un Azan', 'اختيار أذان', 'Choose an Adhan'],
  'activateAzan': ['Activer l’azan', 'تفعيل الأذان', 'Enable Adhan'],
  'soundBirds': ['Oiseaux du matin', 'عصافير الصباح', 'Morning birds'],
  'soundWater': ['Eau qui coule', 'خرير الماء', 'Flowing water'],
  'soundWaves': ['Vagues douces', 'أمواج هادئة', 'Gentle waves'],
  'soundChime': ['Carillon', 'رنين الجرس', 'Chime'],
  'soundAlarm': ['Signal d’alarme', 'إشارة منبه', 'Alarm signal'],

  'androidSettings': [
    'Réglages Android',
    'إعدادات أندرويد',
    'Android settings',
  ],
  'alarmTest': [
    'Tester dans 10 secondes',
    'اختبار بعد 10 ثوانٍ',
    'Test in 10 seconds',
  ],
  'alarmTestNotice': [
    'Test programmé : vous pouvez verrouiller l’écran. Le son s’arrête après 30 secondes.',
    'تمت جدولة الاختبار. يمكنك قفل الشاشة. يتوقف الصوت بعد 30 ثانية.',
    'Test scheduled: you can lock the screen. Sound stops after 30 seconds.',
  ],
  'alarmAccess': [
    'Autoriser les alarmes',
    'أذونات المنبه',
    'Alarm permissions',
  ],
  'alarmAccessNotice': [
    'Autorisez ces trois accès, puis vérifiez. Le volume des alarmes doit être audible. Sur certains téléphones, autorisez aussi le démarrage automatique dans les réglages du fabricant.',
    'اسمح بهذه الأذونات ثم تحقق. تأكد من مستوى صوت المنبه والسماح بالتشغيل التلقائي إن لزم.',
    'Allow these accesses, then check. Keep alarm volume audible. Some phones also require manufacturer auto-start access.',
  ],
  'notificationAccess': ['Notifications', 'الإشعارات', 'Notifications'],
  'backgroundAccess': [
    'Batterie sans restriction',
    'بطارية بلا قيود',
    'Unrestricted battery',
  ],
  'checkAccess': ['Vérifier et continuer', 'تحقق وتابع', 'Check and continue'],
  'gentleBell': [
    'Signal doux · Kenney CC0',
    'تنبيه لطيف · Kenney CC0',
    'Gentle signal · Kenney CC0',
  ],
  'phoneAudio': [
    'Choisir sur le téléphone',
    'اختيار من الهاتف',
    'Choose from phone',
  ],
  'detectLocation': [
    'Détecter ma position',
    'تحديد موقعي',
    'Detect my location',
  ],
  'locationUnknown': [
    'Adresse indisponible · coordonnées conservées',
    'العنوان غير متاح · تم حفظ الإحداثيات',
    'Address unavailable · coordinates retained',
  ],
  'prayerTimes': ['Heures de prières', 'أوقات الصلاة', 'Prayer times'],
  'localTime': ['Heure locale', 'الوقت المحلي', 'Local time'],
  'location': ['Localisation', 'الموقع', 'Location'],

  'reminders': ['Rappels', 'التذكيرات', 'Reminders'],
  'newReminder': ['Programmer un rappel', 'جدولة تذكير', 'Schedule reminder'],
  'activateReminder': ['Rappel actif', 'تذكير مفعّل', 'Reminder enabled'],
  'deleteReminder': [
    'Supprimer ce rappel ?',
    'حذف هذا التذكير؟',
    'Delete this reminder?',
  ],
  'chooseDays': [
    'Choisissez au moins un jour',
    'اختر يوماً واحداً على الأقل',
    'Choose at least one day',
  ],
  'reminderNotice': [
    'Heure locale du téléphone. Une notification ouvre le compteur. Les autorisations de notifications et alarmes exactes sont nécessaires.',
    'وفق التوقيت المحلي للهاتف. يفتح الإشعار العداد. يلزم السماح بالإشعارات والمنبهات الدقيقة.',
    'Uses phone local time. Notification opens the counter. Notifications and exact alarms permissions are required.',
  ],
  'day1': ['Lun', 'الإثنين', 'Mon'],
  'day2': ['Mar', 'الثلاثاء', 'Tue'],
  'day3': ['Mer', 'الأربعاء', 'Wed'],
  'day4': ['Jeu', 'الخميس', 'Thu'],
  'day5': ['Ven', 'الجمعة', 'Fri'],
  'day6': ['Sam', 'السبت', 'Sat'],
  'day7': ['Dim', 'الأحد', 'Sun'],
  'hub': ['Espace spirituel', 'الفضاء الإيماني', 'Spiritual space'],
  'quran': [
    'Coran · Warsh / Hafs',
    'القرآن الكريم · ورش / حفص',
    'Quran · Warsh / Hafs',
  ],
  'hisn': [
    'Invocations · حصن المسلم',
    'الأذكار والدعوات · حصن المسلم',
    'Duas · Hisnul Muslim',
  ],
  'prayers': [
    'Prières & Azan',
    'مواقيت الصلاة والأذان',
    'Prayer times & Adhan',
  ],
  'tasbih': ['Chapelet et Azkar', 'المسبحة والأذكار', 'Tasbih and Azkar'],
  'reading': ['Lecture', 'الرواية', 'Reading'],
  'warsh': ['Warsh', 'ورش', 'Warsh'],
  'hafs': ['Hafs', 'حفص', 'Hafs'],
  'quranHint': [
    'Sourate, texte, 3, 3: ou 3:23…',
    'سورة، نص، 3 أو 3: أو 3:23…',
    'Surah, text, 3, 3: or 3:23…',
  ],
  'inSurah': [
    'Rechercher dans cette sourate…',
    'البحث في هذه السورة…',
    'Search this surah…',
  ],
  'verse': ['Verset', 'الآية', 'Verse'],
  'noResults': ['Aucun résultat', 'لا توجد نتائج', 'No results'],
  'counterReview': [
    'Définissez le nombre souhaité dans le compteur.',
    'حدّد العدد المطلوب في العداد.',
    'Choose the target count in the counter.',
  ],
  'repeat': ['Répétitions', 'التكرار', 'Repetitions'],
  'counter': ['Compteur', 'العداد', 'Counter'],
  'chains': [
    'Wird (chaîne de zikr)',
    'ورد (سلسلة أذكار)',
    'Wird (dhikr sequence)',
  ],
  'azkar': ['Azkar', 'الأذكار', 'Azkar'],
  'zikr': ['Zikr', 'ذكر', 'Dhikr'],
  'newZikr': ['Ajouter un zikr', 'إضافة ذكر', 'Add dhikr'],
  'newChain': ['Ajouter un wird', 'إضافة ورد', 'Add wird'],
  'formulation': ['Formulation', 'صيغة الذكر', 'Wording'],
  'maximum': ['Nombre maximal', 'العدد الأقصى', 'Target count'],
  'name': ['Nom', 'الاسم', 'Name'],
  'step': ['Étape', 'المرحلة', 'Step'],
  'addStep': ['Ajouter une étape', 'إضافة مرحلة', 'Add step'],
  'complete': ['Terminé', 'اكتمل', 'Completed'],
  'reset': ['Recommencer', 'إعادة البدء', 'Restart'],
  'resetQuestion': [
    'Recommencer ce compteur ?',
    'إعادة هذا العداد؟',
    'Restart this counter?',
  ],
  'deleteZikr': [
    'Supprimer ce zikr et ses étapes dans les wirds ?',
    'حذف هذا الذكر ومراحله في السلاسل؟',
    'Delete this dhikr and its sequence steps?',
  ],
  'deleteChain': ['Supprimer ce wird ?', 'حذف هذا الورد؟', 'Delete this wird?'],
  'invalidNumber': [
    'Saisissez un entier entre 1 et 100 000',
    'أدخل عدداً صحيحاً من 1 إلى 100000',
    'Enter an integer from 1 to 100,000',
  ],
  'chooseZikr': ['Choisir un zikr', 'اختر ذكراً', 'Choose dhikr'],
  'source': ['Source', 'المصدر', 'Source'],
  'useCounter': [
    'Utiliser au compteur',
    'الاستخدام في العداد',
    'Use in counter',
  ],
  'chapter': ['Chapitre', 'الباب', 'Chapter'],
  'city': ['Ville', 'المدينة', 'City'],
  'country': ['Pays', 'البلد', 'Country'],
  'method': ['Méthode de calcul', 'طريقة الحساب', 'Calculation method'],
  'refreshTimes': [
    'Actualiser les horaires',
    'تحديث المواقيت',
    'Refresh times',
  ],
  'latitude': ['Latitude', 'خط العرض', 'Latitude'],
  'longitude': ['Longitude', 'خط الطول', 'Longitude'],
  'coordinatesMode': [
    'Utiliser des coordonnées',
    'استخدام الإحداثيات',
    'Use coordinates',
  ],
  'offset': [
    'Ajustement en minutes',
    'التعديل بالدقائق',
    'Adjustment in minutes',
  ],
  'school': [
    'Asr selon l’école hanafite',
    'العصر وفق المذهب الحنفي',
    'Hanafi Asr calculation',
  ],
  'Fajr': ['Fajr', 'الفجر', 'Fajr'],
  'Dhuhr': ['Dhuhr', 'الظهر', 'Dhuhr'],
  'Asr': ['Asr', 'العصر', 'Asr'],
  'Maghrib': ['Maghrib', 'المغرب', 'Maghrib'],
  'Isha': ['Isha', 'العشاء', 'Isha'],
  'audio': [
    'Choisir un fichier audio d’azan',
    'اختيار ملف صوت الأذان',
    'Choose an Adhan audio file',
  ],
  'testAudio': ['Écouter', 'استماع', 'Preview'],
  'stopAudio': ['Arrêter', 'إيقاف', 'Stop'],
  'activate': [
    'Activer les azans programmés',
    'تفعيل الأذان المجدول',
    'Enable scheduled Adhan',
  ],
  'deactivate': ['Désactiver les azans', 'تعطيل الأذان', 'Disable Adhan'],
  'permissions': [
    'Autoriser notifications et alarmes exactes, puis réessayer.',
    'اسمح بالإشعارات والمنبهات الدقيقة ثم أعد المحاولة.',
    'Allow notifications and exact alarms, then retry.',
  ],
  'exactSettings': [
    'Autoriser les alarmes exactes',
    'السماح بالمنبهات الدقيقة',
    'Allow exact alarms',
  ],
  'chooseAudioFirst': [
    'Choisissez d’abord un audio et actualisez les horaires.',
    'اختر الصوت أولاً وحدّث المواقيت.',
    'Choose audio and refresh times first.',
  ],
  'scheduleUntil': [
    'Horaires programmés jusqu’au',
    'تمت الجدولة حتى',
    'Scheduled through',
  ],
  'prayerNotice': [
    'Horaires calculés à vérifier avec votre mosquée. Actualisez avant la fin de la période programmée. L’audio dépend du volume des alarmes et des restrictions Android.',
    'مواقيت محسوبة تُراجع مع المسجد. حدّثها قبل نهاية الفترة المجدولة. الصوت مرتبط بمستوى صوت المنبه وقيود أندرويد.',
    'Calculated times: verify with your mosque. Refresh before the scheduled period ends. Audio depends on alarm volume and Android restrictions.',
  ],
  'savedOffline': [
    'Données mémorisées sur cet appareil',
    'بيانات محفوظة على هذا الجهاز',
    'Cached on this device',
  ],
  'required': ['Champ obligatoire', 'حقل مطلوب', 'Required field'],
  'notEmptyChain': [
    'Ajoutez au moins une étape',
    'أضف مرحلة واحدة على الأقل',
    'Add at least one step',
  ],
  'emptyCounter': [
    'Ajoutez un zikr pour commencer',
    'أضف ذكراً للبدء',
    'Add a dhikr to begin',
  ],
  'moveUp': ['Monter', 'نقل للأعلى', 'Move up'],
  'moveDown': ['Descendre', 'نقل للأسفل', 'Move down'],
  'networkError': [
    'Connexion impossible. Les données déjà chargées restent disponibles.',
    'تعذر الاتصال. البيانات المحملة سابقاً متاحة.',
    'Unable to connect. Previously loaded data remains available.',
  ],
};

class DevStore {
  static Future<void>? _pending;
  static Future<dynamic> read(String key) async {
    final raw = await Store.call('devotionRead', {'key': key});
    if (raw is! String || raw.isEmpty) return null;
    return jsonDecode(raw);
  }

  static Future<void> write(String key, dynamic value) {
    final encoded = jsonEncode(value);
    Future<void> persist() async {
      await Store.call('devotionWrite', {'key': key, 'value': encoded});
    }

    final old = _pending;
    final result = old == null ? persist() : old.then((_) => persist());
    final tail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    _pending = tail;
    unawaited(
      tail.then((_) {
        if (identical(_pending, tail)) _pending = null;
      }),
    );
    return result;
  }
}

Future<dynamic> fetchJson(Uri uri) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  try {
    final request = await client
        .getUrl(uri)
        .timeout(const Duration(seconds: 20));
    request.headers.set(
      HttpHeaders.userAgentHeader,
      'Diraasa/2.1 (com.tdg.diraasa)',
    );
    final response = await request.close().timeout(const Duration(seconds: 20));
    if (response.statusCode != 200)
      throw HttpException('HTTP ${response.statusCode}');
    final body = await response
        .transform(utf8.decoder)
        .join()
        .timeout(const Duration(seconds: 30));
    return jsonDecode(body.replaceFirst('\uFEFF', ''));
  } finally {
    client.close(force: true);
  }
}

List<AppRecord> decodeChapters(String raw) {
  final data = jsonDecode(raw) as Map;
  return (data['chapters'] as List).map((row) {
    final chapter = Map<String, dynamic>.from(row as Map);
    chapter['_normalized'] = normalize(chapter['title'].toString());
    for (final verse in chapter['verses'] as List) {
      verse['_normalized'] = normalize(verse['text'].toString());
    }
    return chapter;
  }).toList();
}

class QuranData {
  static final Map<String, Future<List<AppRecord>>> _books = {};
  static Future<List<AppRecord>> book(String reading) => _books.putIfAbsent(
    reading,
    () async => compute(
      decodeChapters,
      await rootBundle.loadString('assets/devotion/quran_$reading.json'),
    ),
  );
}

String westernDigits(String text) {
  const arabic = '٠١٢٣٤٥٦٧٨٩', persian = '۰۱۲۳۴۵۶۷۸۹';
  for (var i = 0; i < 10; i++) {
    text = text.replaceAll(arabic[i], '$i').replaceAll(persian[i], '$i');
  }
  return text;
}

({int chapter, int? verse, bool list})? parseReference(String text) {
  final match = RegExp(
    r'^(\d{1,3})(?:(:)(\d{0,3}))?$',
  ).firstMatch(westernDigits(text.trim()));
  if (match == null) return null;
  return (
    chapter: int.parse(match[1]!),
    verse: match[3]?.isNotEmpty == true ? int.parse(match[3]!) : null,
    list: match[2] != null,
  );
}
