# Validation 2.4.0+43 — 28 octobre 2026

## Exécuté

- Compilation de tous les fichiers Kotlin contre Android API36, Kotlin2.2.20/JVM17, WorkManager et bibliothèques Google/Firebase réelles. Seules les interfaces Flutter sont substituées pour ce contrôle isolé. Ce n’est pas un build APK. Avertissement ancien non bloquant dans AlarmSupport.onStatusChanged.
- BackupMediaCheck JVM : vrai lien symbolique simulant deux chemins vers le même dossier, images retrouvées dans les deux sens, URI file: reconnue, traversée/sortie de racine refusée.
- BackupStoreCheck JVM : schéma, références, préférences, chemins d’audio JSON scalaire, préservation du texte des notes, comptes de photos et avertissement des anciennes archives incomplètes.
- BackupArchiveCheck JVM : Unicode, pièces jointes binaires, intégrité ZIP et refus de chemins dangereux/sommes altérées/versions inconnues.
- QuranAudioSourceCheck JVM et quran_audio_plan_check Dart autonome : noms 001001/114006, raw URLs AR/FR, basmala séparée, exclusions Fatiha/Tawba et listes de lecture individuelles/continues.
- PrayerSyncDataCheck / ReminderScheduleCheck JVM : non-régression des appels et rappels.
- Tous les scripts Python check_android_debug, check_audio, check_data, check_deletions, check_devotion_data, check_hadith, check_kotlin_escapes, check_migrations, check_search et check_theme_rename : réussis.
- Syntaxe de lib/ et test/ vérifiée avec le formateur Dart3.9.4 autonome.

## Ajouté mais non exécuté ici

- test/quran_audio_test.dart : plan de lecture, suivi du verset renvoyé par le natif, pause/reprise/seek/arrêt, séparation Hafs/Warsh, contrôles sur écran de 320 px.
- Ensemble flutter analyze/test, build Gradle/APK, streaming réel MediaPlayer, focus Android et comportement sur téléphone.

## Vérifications nécessaires sur le téléphone

1. Refaire une sauvegarde sur l’appareil source avec au moins une photo d’auteur ; vérifier Photos > 0 dans le résumé, puis tester la restauration sur appareil de test.
2. Vérifier un fichier raw public AR et FR après leur ajout au dépôt ; lecture MP3 directe, sans page HTML ou pointeur LFS.
3. Essayer Hafs : un verset, pause/reprise, position, continu depuis le verset 1 (basmala appropriée), continu depuis un autre verset, fin de sourate, absence de fichier et réseau coupé.
4. Vérifier le changement de langue audio persistant, la distinction du verset actif et le suivi de la liste hors recherche.
5. Vérifier interruption par azan/rappel et arrêt lorsque la page est quittée ou l’application passe en arrière-plan.

Cette version ne télécharge pas de MP3 permanent, ne lit pas Warsh avec les fichiers Hafs et n’assure pas de lecture écran verrouillé. Aucun enregistrement réel n’est fourni ni prétendu validé : leur disponibilité dépend du push du développeur.
