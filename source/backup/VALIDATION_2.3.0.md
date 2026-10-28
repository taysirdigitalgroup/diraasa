# Validation Diraasa 2.3.0+40 — 28 octobre 2026

## Exécuté

- Compilation de tous les fichiers Kotlin de l’application avec Kotlin 2.2.20 / JVM17, Android API36 et les bibliothèques Google/Firebase/Credential Manager/WorkManager réelles. Les seules interfaces substituées sont FlutterActivity/FlutterEngine/MethodChannel, pour contrôler les signatures natives sans lancer Flutter. Cela ne remplace pas un build Gradle/APK ou l’exécution Android. Avertissement ancien non bloquant sur `LocationListener.onStatusChanged` dans AlarmSupport.
- `BackupArchiveCheckKt` : export/import ZIP, Unicode arabe/français, pièces jointes binaires, rejet des chemins traversants, sommes incorrectes et format futur.
- `BackupStoreCheckKt` : schéma attendu, identité d’auteur, références, périmètre des préférences, résumé des compteurs, refus de pièce jointe manquante ; remappage du chemin audio JSON scalaire ; préservation des contenus JSON et chemins saisis dans une note.
- `PrayerSyncDataCheckKt` et `ReminderScheduleCheckKt` : calcul natif des appels et planification calendaire des rappels.
- Scripts Python `check_android_debug`, `check_audio`, `check_data`, `check_deletions`, `check_devotion_data`, `check_hadith`, `check_kotlin_escapes`, `check_migrations`, `check_search`, `check_theme_rename` : réussis.
- Analyse syntaxique de tous les fichiers Dart de `lib/` et `test/` par le formateur Dart 3.9.4 autonome. Ce contrôle syntaxique n’est pas `flutter analyze`.

## Ajouté mais non exécuté ici

- `test/backup_test.dart` : export local sans Firebase, annulation sans import, double confirmation avec résumé, chargement des préférences après import, navigation confidentialité.
- `test/sources_test.dart` : Wave avec URL exacte sous libellé et suppression Orange Money, PayPal conservé.
- Ensemble `flutter analyze` et `flutter test` ; APK/AAB Gradle ; installation téléphone.

## À valider avec la configuration du développeur

- `google-services.json` du vrai projet et empreintes de la clé effectivement installée.
- Choix de compte Credential Manager, persistance Firebase entre lancements, consentement Drive distinct, listage/envoi/téléchargement dans le compte connecté et ouverture du dossier.
- Export/import via les fournisseurs documentaires du téléphone (stockage local, fournisseur Drive système, carte SD si disponible).
- Restauration réelle et interruption contrôlée entre transaction et fin des préférences sur appareil de test ; les tests JVM ne simulent pas le système de fichiers Android et SQLite en production.
- Images, sons personnels, affichage FR/AR/EN, rappel après réautorisation et signatures debug/release/Play.

Aucune clé privée, aucun google-services.json fictif, aucune session ou autorisation d’un utilisateur n’est fournie. Le contenu du guide et les pages web de confidentialité sont prêts à publier mais ne sont pas hébergés par cette mise à jour.
