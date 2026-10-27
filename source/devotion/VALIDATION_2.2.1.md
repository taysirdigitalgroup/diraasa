# Validation 2.2.1 — 27 octobre 2026

Exécutés :
- Scripts Python existants : données Coran/Hisn/hadiths/dictionnaire, migrations,
  suppressions/renommages et audio, échappements Kotlin.
- Dart 3.9.4 format : syntaxe de lib/ et test/.
- prayer_settings_check.dart : avances par défaut/personnalisées, valeur vide,
  chiffres arabes et séparation des heures de prière/appel.
- Règle R8 explicite pour conserver la classe du Worker entre versions.
- Kotlin 2.2.20 / Java 17 / android.jar API 36 / vrai work-runtime 2.9.1 : compilation
  des sources natives ; interfaces d’intégration Flutter simulées, sans APK.
- PrayerSyncDataCheckKt et ReminderScheduleCheckKt sur JVM : mathématiques des
  appels, fuseau ISO, chiffres arabes, fin du cache et calendrier des rappels.

Ajoutés, non exécutés : tests Flutter pour brouillon/Appliquer, fermeture avec
champ vide, aperçus et avances, activation souhaitée reprise après disponibilité,
choix désactivé respecté, cache/localisation/sync conservés sur échec réseau.
Flutter analyze/test, compilation Gradle/APK et essai Android non exécutés ici.

Sur appareil : modifier sans appliquer puis fermer, vider un champ puis fermer,
appliquer sans réseau, vérifier Fajr -45 et Maghrib -0, couper le réseau à
l’expiration puis le rétablir ; la synchronisation doit reprendre et l’état
souhaité de l’adhan être respecté. Vérifier la réception écran verrouillé.
Les tâches WorkManager dépendent des conditions réseau et de la planification
Android ; aucun déclenchement en téléphone éteint/arrêt forcé n’est garanti.
