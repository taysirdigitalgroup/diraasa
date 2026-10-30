# Validation Diraasa 2.5.0+49 — 30 octobre 2026

## Vérifications exécutées
- Compilation Kotlin 2.2.20 contre Android API 36 : AlarmDelivery, AlarmSupport, AzanAlarms, AzanService, ZikrReminders, QuranAudio, QuranAudioService, QuranAudioSource, QuranAudioSequence, QuranAudioCache. API Android réelles ; doublures seulement pour MainActivity (Activity vide), PrayerSyncWorker (pont de réarmement), MethodChannel.Result et identifiant R.drawable. Aucune simulation du système de veille ou du son matériel.
- JVM ReminderScheduleCheck : jours choisis, semaine suivante, fuseaux Dakar/Paris, règle de déclenchement ± bornes ; rappel prévu à 21:13 et livré à 01:30 rejeté ; prochaine occurrence correctement calculée pour le soir suivant.
- JVM QuranAudioCacheCheck : fenêtre 3 fichiers mono-langue / 6 AR-FR-EN, bornes et basmala, aucune conservation arrière, réutilisation, invalidation, annulation de requêtes obsolètes.
- JVM QuranAudioSequenceCheck : les 15 modes ordonnés, progression par verset, mode continu et mixte autorisant le saut d’un fichier indisponible, mono-langue isolée restant isolée.
- Dart autonome 3.9.4 : quran_translation_check sur les assets réels, fusion de 114 sourates/6236 versets pour AR/FR/EN, arabe par défaut et repli en cas d’absence/texte vide.
- Contrôleur audio Dart réel avec adaptateurs minimaux (tools/quran_background_check.py) : rattachement, persistance du lecteur hors page, ordre des événements et rejet des statuts anciens, arrêt explicite.
- Parseur/formatteur Dart : lib/ et tests modifiés lus sans erreur de syntaxe. Tests Flutter ajoutés pour l’affichage FR puis EN à la réception d’événements audio, mais non exécutés.
- PDF : extraction des 114 sourates/6236 versets numérotés +112 basmalas séparées dans chaque langue ; aucun doublon/manquant/supplémentaire. Contrôle visuel des colonnes EN et de la première page FR ; références réparties sur les pages conservées dans le rapport. Ce contrôle de numérotation ne constitue pas une relecture linguistique humaine intégrale des deux traductions.
- Manifest parsé : USER_UNLOCKED ajouté, services et permissions existants conservés. Données utilisateur et schéma SQLite inchangés.
- Archive cumulative vérifiée membre par membre, lib/ complet, gitignore fourni inchangé, clés et google-services.json exclus.

## Non exécuté dans cet environnement
flutter analyze, flutter test, Gradle/APK et installation sur TECNO KL4. Le fonctionnement de setAlarmClock en veille prolongée et les restrictions du fabricant doivent être vérifiés sur le téléphone.

## Essai sur téléphone
1. Arrêter complètement flutter run, extraire la mise à jour puis relancer. Ouvrir une fois Diraasa pour convertir/réarmer les alarmes déjà enregistrées. Vérifier notifications, alarmes exactes et batterie sans restriction.
2. Programmer un rappel proche ; verrouiller le téléphone, puis vérifier un rappel après une longue période hors de l’application. Un ancien rappel de plusieurs heures ne doit jamais sonner à l’ouverture.
3. Dans Prières, vérifier le prochain appel programmé et tester un azan normal/Fajr, écran éteint ; les 10 prochaines échéances sont renouvelées à chaque déclenchement.
4. Coran Hafs : Texte FR et EN sans audio ; puis lecture mixte AR/FR/EN pour vérifier le changement du texte sur le même verset. Les basmalas séparées suivent la langue.
5. Tester un MP3 absent et une coupure réseau : message du fichier défaillant et continuation du mode continu/mixte. Arrêter/reprendre pendant un chargement.
6. Vérifier notes, auteurs, thèmes, azkar/wird et préférences existants après mise à jour.

## Sources de la stratégie Android
https://developer.android.com/reference/android/app/AlarmManager
https://developer.android.com/develop/background-work/services/alarms
setAlarmClock est employé pour les alarmes sonores explicitement programmées par l’utilisateur, sans demande de nouvelle permission spéciale. Aucun mécanisme ne contourne un arrêt forcé Android ou ne garantit l’autodémarrage sur tous les firmwares.
