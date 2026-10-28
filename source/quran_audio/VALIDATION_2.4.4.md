# Validation 2.4.4+47 — 28 octobre 2026

## Exécuté
- Compilation Kotlin 2.2.20 contre le vrai android.jar de la plateforme Android 36 : QuranAudioService, QuranAudio, QuranAudioSource, QuranAudioSequence, QuranAudioCache. Les seules doublures de cette compilation sont MainActivity (Activity vide) et AzanService.activeKind ; les API Service, MediaPlayer, MediaSession, Notification, WakeLock et réseau viennent de la plateforme réelle. Réussite, avertissements de dépréciation des flags MediaSession historiques uniquement.
- Vérification du contrôleur Dart réel extrait du fichier source avec adaptateurs minimaux ChangeNotifier/stockage/canal : quitter ne stoppe pas, rattachement limité à la même sourate, récupération du mode et de la langue, événements de progression, rejet de statut ancien après rattachement, arrêt explicite. Réussite. Commande : python3 tools/quran_background_check.py /chemin/vers/dart
- Vérifications JVM existantes des 15 séquences et du cache multilingue ±3 : réussite.
- Parseur/formatteur Dart autonome 3.9.4 : lib/ et test/quran_audio_test.dart lus sans erreur de syntaxe.
- Manifest Android parsé, service privé mediaPlayback avec stopWithTask=false ; permissions FOREGROUND_SERVICE, FOREGROUND_SERVICE_MEDIA_PLAYBACK, WAKE_LOCK et POST_NOTIFICATIONS présentes.
- Archive cumulative : chaque membre comparé aux sources, lib/ complet, aucun secret ni base de notes utilisateur, gitignore fourni conservé.

## Non exécuté ici
flutter analyze, flutter test, compilation Gradle/APK complète, exécution des notifications et de MediaPlayer sur Android. La compilation isolée ne valide pas le branchement Flutter/Activity complet ni le comportement matériel.

## À vérifier sur le TECNO KL4
1. Lancer Hafs en mode mixte AR/FR/EN et autoriser les notifications si demandé. Vérifier les références et langue affichées dans le lecteur système.
2. Revenir à la liste, changer d’application, éteindre l’écran : la séquence doit continuer, sans doublon ni saut de langue.
3. Mettre en pause/reprendre depuis la notification et l’écran verrouillé ; essayer le déplacement temporel système si proposé par le téléphone.
4. Toucher la notification : retrouver la sourate, le verset et le même son en cours.
5. Retirer l’activité des applications récentes : continuer puis rouvrir via notification.
6. Débrancher un casque et déclencher un rappel/azan : la récitation doit se mettre en pause.
7. Arrêter depuis la notification : son et notification disparaissent ; relancer fonctionne.
8. Fin de sourate ou fichier absent : libération du service. Un arrêt forcé Android ne doit pas relancer le son.

## Références techniques
- https://developer.android.com/media/media3/session/background-playback (séparation service/activité, notification et cycle de vie)
- https://developer.android.com/about/versions/15/behavior-changes-15 (service de premier plan ou application au premier plan pour demander le focus audio)
Implémentation avec les API natives MediaSession/MediaPlayer déjà disponibles, sans ajout de Media3 ou modification du Dev Env.
