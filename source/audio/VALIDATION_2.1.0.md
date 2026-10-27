# Validation — 27 octobre 2026

Exécutés :
- Tous les tools/check_*.py : succès, y compris migrations notes v4 et dictionnaire.
- check_audio.py avec adhans.tar.gz : 8 pistes AAC mono audio seul ; catalogue et
  durée complète comparés aux originaux (écart inférieur à une seconde).
- Dart 3.9.4 format --output=none lib test : analyse syntaxique des 25 fichiers.
  Ce contrôle ne remplace pas flutter analyze.
- Kotlin 2.2.20 / Java 17 / android.jar API 36 : compilation des sources Kotlin.
  Les interfaces de l’intégration Flutter ont été simulées pour ce contrôle isolé.
- ReminderScheduleCheckKt sur JVM : jours sélectionnés, passage de semaine,
  changement de fuseau et liste de jours vide.

Non exécutés : flutter analyze, flutter test, Gradle/APK et essais sur appareil.
La compilation native isolée ne valide pas le fonctionnement Android réel.

Après extraction et flutter run complet (pas uniquement hot reload) :
1. Vérifier qu’une note existante, ses auteur/thème et sa mise en forme restent présents.
2. Dans Prières ou un rappel, autoriser notifications, alarmes exactes et exemption
   batterie. Le cas échéant, autoriser aussi l’auto-démarrage TECNO.
3. Sélectionner un audio, vérifier le volume des alarmes et écouter l’aperçu.
4. Utiliser Tester dans 10 secondes, verrouiller l’écran ; vérifier le son et Arrêter.
5. Tester un rappel Zikr puis Wird, puis après redémarrage du téléphone.
6. Vérifier la position/adresse détectées et comparer les horaires à la mosquée.
7. Contrôler activation/désactivation de chaque prière et le calcul Asr hanafite.

Une application arrêtée de force, un téléphone éteint ou certaines restrictions
fabricant peuvent empêcher le déclenchement ; aucune exécution permanente n’est promise.
