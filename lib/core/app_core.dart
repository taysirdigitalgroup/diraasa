import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef AppRecord = Map<String, dynamic>;
class Store {
  static const channel = MethodChannel('tdg.diraasa/data');
  static Future<dynamic> call(String method, [AppRecord? args]) => channel.invokeMethod(method, args);
  static Future<List<AppRecord>> rows(String method, [AppRecord? args]) async =>
      (await call(method, args) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
}

String resolveLanguage(Iterable<Locale> locales) {
  // The primary device language is authoritative; unsupported => French.
  final code = locales.isEmpty ? 'fr' : locales.first.languageCode;
  return ['fr', 'ar', 'en'].contains(code) ? code : 'fr';
}

class AppSettings extends ChangeNotifier {
  AppSettings({String? initialLanguage}) : language = initialLanguage ??
      resolveLanguage(WidgetsBinding.instance.platformDispatcher.locales);
  String language;
  String theme = 'system';
  double textSize = 24;
  String draftTitle = '', draftAuthor = '', draftKind = 'Cours';
  String noteCategory = 'all', noteField = 'all', dictionaryMode = 'prefix', dictionaryLetter = '';
  // No bootstrap Future: it can belong to a different scheduling zone than
  // the first update (notably setUp vs widget-test FakeAsync).
  Future<void>? _pending;
  ThemeMode get themeMode => theme == 'dark' ? ThemeMode.dark :
      theme == 'light' ? ThemeMode.light : ThemeMode.system;
  void notifySizeChanged() => notifyListeners();
  Future<void> load() async {
    final raw = await Store.call('preferences');
    if (raw is! Map) return;
    final savedLanguage = raw['language'];
    if (['fr', 'ar', 'en'].contains(savedLanguage)) language = savedLanguage as String;
    if (['system', 'light', 'dark'].contains(raw['theme'])) theme = raw['theme'] as String;
    textSize = ((raw['textSize'] as num?)?.toDouble() ?? 24).clamp(18, 36).toDouble();
    draftTitle = raw['draftTitle']?.toString() ?? '';
    draftAuthor = raw['draftAuthor']?.toString() ?? '';
    final storedKind = raw['draftKind']?.toString();
    if (kinds.contains(storedKind)) draftKind = storedKind!;
    if (['all', ...kinds].contains(raw['noteCategory'])) noteCategory = raw['noteCategory'] as String;
    if (noteSearchFields.contains(raw['noteField'])) noteField = raw['noteField'] as String;
    if (['prefix', 'contains', 'fulltext'].contains(raw['dictionaryMode'])) dictionaryMode = raw['dictionaryMode'] as String;
    final storedLetter = raw['dictionaryLetter'];
    if (storedLetter is String && (storedLetter.isEmpty || 'ابتثجحخدذرزسشصضطظعغفقكلمنهوي'.contains(storedLetter))) dictionaryLetter = storedLetter;
    notifyListeners();
    if (savedLanguage == null) await update({});
  }
  Future<void> update(AppRecord patch) {
    if (patch['language'] is String) language = patch['language'] as String;
    if (patch['theme'] is String) theme = patch['theme'] as String;
    if (patch['textSize'] is num) textSize = (patch['textSize'] as num).toDouble().clamp(18, 36).toDouble();
    if (patch['draftTitle'] is String) draftTitle = patch['draftTitle'] as String;
    if (patch['draftAuthor'] is String) draftAuthor = patch['draftAuthor'] as String;
    if (patch['draftKind'] is String) draftKind = patch['draftKind'] as String;
    if (patch['noteCategory'] is String) noteCategory = patch['noteCategory'] as String;
    if (patch['noteField'] is String) noteField = patch['noteField'] as String;
    if (patch['dictionaryMode'] is String) dictionaryMode = patch['dictionaryMode'] as String;
    if (patch['dictionaryLetter'] is String) dictionaryLetter = patch['dictionaryLetter'] as String;
    notifyListeners();
    final snapshot = <String, dynamic>{
      'language': language, 'theme': theme, 'textSize': textSize,
      'draftTitle': draftTitle, 'draftAuthor': draftAuthor, 'draftKind': draftKind,
      'noteCategory': noteCategory, 'noteField': noteField, 'dictionaryMode': dictionaryMode, 'dictionaryLetter': dictionaryLetter,
    };
    Future<void> persist() async { await Store.call('savePreferences', snapshot); }
    final previous = _pending;
    // Start an idle queue immediately, inside the caller's current zone.
    final result = previous == null ? persist() : previous.then<void>((_) => persist());
    // A failed commit must reach its caller without blocking later commits.
    final tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    _pending = tail;
    unawaited(tail.then<void>((_) {
      if (identical(_pending, tail)) _pending = null;
    }));
    return result;
  }
}
AppSettings settings = AppSettings();
const kinds = ['Cours', 'Vocabulaire', 'Vers', 'Citation'];
const noteSearchFields = ['all', 'title', 'author', 'body'];
const languageLabels = {'fr': 'Français', 'ar': 'العربية', 'en': 'English'};

String tr(String key) {
  final values = labels[key];
  if (values == null) return key;
  return values[settings.language == 'ar' ? 1 : settings.language == 'en' ? 2 : 0];
}
const labels = <String, List<String>>{
  'notes': ['Notes','ملاحظات','Notes'],
  'dictionary': ['Dictionnaire','المعجم','Dictionary'],
  'introNotes': ['Votre savoir,\nun mot à la fois.','معرفتك،\nكلمةً بعد كلمة.','Your knowledge,\none word at a time.'],
  'introDictionary': ['Le sens des mots.\nLa richesse de l’arabe.','معاني الكلمات.\nثراء العربية.','The meaning of words.\nThe richness of Arabic.'],
  'notebook': ['Votre carnet d’études','دفتر دراستك','Your study notebook'],
  'offline': ['3 767 articles · hors ligne','٣٧٦٧ مادة · دون إنترنت','3,767 entries · offline'],
  'searchNotes': ['Rechercher dans mes notes…','ابحث في ملاحظاتك…','Search my notes…'],
  'searchDictionary': ['Rechercher un mot arabe…','ابحث عن كلمة عربية…','Search an Arabic word…'],
  'clear': ['Effacer','مسح','Clear'],
  'all': ['Tout','الكل','All'],
  'allFields': ['Tous les champs','جميع الحقول','All fields'],
  'title': ['Titre','العنوان','Title'],
  'author': ['Auteur','المؤلف','Author'],
  'optionalAuthor': ['Auteur (optionnel)','المؤلف (اختياري)','Author (optional)'],
  'body': ['Contenu de la note','محتوى الملاحظة','Note content'],
  'content': ['Contenu','المحتوى','Content'],
  'type': ['Type de note','نوع الملاحظة','Note type'],
  'Cours': ['Cours','درس','Lesson'],
  'Vocabulaire': ['Vocabulaire','مفردات','Vocabulary'],
  'Vers': ['Vers','أبيات','Verse'],
  'Citation': ['Citation','اقتباس','Quotation'],
  'prefix': ['Mot / racine','كلمة / جذر','Word / root'],
  'contains': ['Contient','يحتوي على','Contains'],
  'fulltext': ['Texte intégral','النص الكامل','Full text'],
  'letters': ['Toutes','كل الحروف','All letters'],
  'new': ['Nouvelle note','ملاحظة جديدة','New note'],
  'editNote': ['Modifier la note','تعديل الملاحظة','Edit note'],
  'edit': ['Modifier','تعديل','Edit'],
  'delete': ['Supprimer','حذف','Delete'],
  'deleteQuestion': ['Supprimer cette note ?','حذف هذه الملاحظة؟','Delete this note?'],
  'deleteWarning': ['Cette suppression est définitive.','لا يمكن التراجع عن الحذف.','This deletion is permanent.'],
  'cancel': ['Annuler','إلغاء','Cancel'],
  'pin': ['Épingler','تثبيت','Pin'],
  'unpin': ['Détacher','إلغاء التثبيت','Unpin'],
  'pinned': ['Épinglée','مثبتة','Pinned'],
  'options': ['Options de la note','خيارات الملاحظة','Note options'],
  'save': ['Enregistrer','حفظ','Save'],
  'saving': ['Enregistrement…','جارٍ الحفظ…','Saving…'],
  'saved': ['Note enregistrée. Le contenu est prêt pour une nouvelle saisie.','تم حفظ الملاحظة. يمكنك إدخال محتوى جديد.','Note saved. Ready for new content.'],
  'requiredTitle': ['Ajoutez un titre','أضف عنوانًا','Add a title'],
  'requiredBody': ['Ajoutez le contenu de la note','أضف محتوى الملاحظة','Add note content'],
  'autoDate': ['Date ajoutée automatiquement','يُضاف التاريخ تلقائيًا','Date added automatically'],
  'created': ['Créée le','تاريخ الإنشاء','Created on'],
  'readNote': ['Lecture de la note','قراءة الملاحظة','Read note'],
  'copy': ['Copier','نسخ','Copy'],
  'copied': ['Texte copié','تم نسخ النص','Text copied'],
  'close': ['Fermer','إغلاق','Close'],
  'retry': ['Réessayer','إعادة المحاولة','Retry'],
  'error': ['Une erreur est survenue','حدث خطأ','Something went wrong'],
  'emptyNotes': ['Aucune note à afficher','لا توجد ملاحظات','No notes to display'],
  'emptyDictionary': ['Aucun article trouvé','لم يتم العثور على مادة','No entries found'],
  'adjustFilters': ['Ajustez la recherche ou les filtres.','غيّر البحث أو المرشحات.','Adjust your search or filters.'],
  'more': ['Charger la suite','تحميل المزيد','Load more'],
  'root': ['Racine','الجذر','Root'],
  'entry': ['Article','المادة','Entry'],
  'study': ['Étudier dans une note','إنشاء ملاحظة دراسية','Study in a note'],
  'textSize': ['Taille de lecture','حجم خط القراءة','Reading size'],
  'theme': ['Apparence','المظهر','Appearance'],
  'system': ['Automatique (système)','تلقائي (النظام)','Automatic (system)'],
  'light': ['Clair','فاتح','Light'],
  'dark': ['Sombre','داكن','Dark'],
  'language': ['Langue','اللغة','Language'],
  'about': ['Infos & À propos','معلومات عن التطبيق','About'],
  'developer': ['Développeur','المطوّر','Developer'],
  'bookIntro': ['Introduction et références du livre','مقدمة الكتاب ومراجعه','Book introduction and references'],
  'aboutText': ['Carnet d’études arabes et مختار الصحاح de الرازي. Les notes restent sur cet appareil.','دفتر للدراسات العربية ومعجم مختار الصحاح للرازي. تُحفظ الملاحظات على هذا الجهاز.','Arabic study notebook and Mukhtar al-Sihah by al-Razi. Notes stay on this device.'],
  'settingsSaveError': ['Préférence non enregistrée','تعذّر حفظ التفضيل','Could not save preference'],
  'match': ['Correspondance','المطابقة','Match'],
};

TextDirection direction(String text, {TextDirection fallback = TextDirection.ltr}) {
  final first = RegExp(r'[A-Za-zÀ-ɏؠ-يٮ-ٯٱ-ۓۺ-ۼ]').firstMatch(text);
  if (first == null) return fallback;
  return RegExp(r'[ؠ-ۼ]').hasMatch(first.group(0)!) ? TextDirection.rtl : TextDirection.ltr;
}
TextAlign textAlignment(String text) =>
    direction(text) == TextDirection.rtl ? TextAlign.right : TextAlign.left;
String date(dynamic ms) {
  final d = DateTime.fromMillisecondsSinceEpoch((ms as num).toInt());
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
void errorMessage(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('error') + ' : ' + error.toString())));
}
Future<void> savePreference(BuildContext context, AppRecord patch) async {
  try { await settings.update(patch); } catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('settingsSaveError'))));
  }
}
