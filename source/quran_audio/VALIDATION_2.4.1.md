# Validation 2.4.1+44 — 28 octobre 2026

## Exécuté

- Compilation Kotlin isolée contre Android API36, JVM17/Kotlin2.2.20 et dépendances réelles. Interfaces Flutter substituées uniquement ; ce contrôle n’est pas un APK.
- QuranAudioSourceCheck JVM : URL EN, AR et FR, références/basmalas et refus d’une référence dépassant le nombre de versets.
- quran_audio_plan_check Dart autonome : 114 sourates / 6 236 versets, URL dans les trois langues et listes individuelles/continues.
- Audit MP3 Python testé avec un MP3 synthétique temporaire de 0,15 s : format/durée/décodage/hash acceptés. Un faux pointeur Git LFS est refusé. Le rapport ne prétend jamais valider le contenu récité.
- Contrôle syntaxique Dart et échappements Kotlin réussis.
- Contrôle HTTP de trois liens raw 001001.mp3 AR/FR/EN : HTTP404 ; le dépôt était public, main, avec des fichiers du projet Flutter. Voir REMOTE_STATUS_2.4.1.json.

## Ajouté mais non exécuté ici

- Tests Flutter de langue EN, bornes du corpus, événements natifs immédiats, rejet d’un événement périmé ou d’une autre session et distinction chargement/lecture.
- Flutter analyze/test, APK et tests téléphone.

## À réaliser lorsque les vrais fichiers sont publiés

- Audit du corpus local avec tools/audit_quran_audio.py, puis essais des URL raw et lecture sur téléphone.
- Vérification du contenu récité/traduit : le nom du fichier et son bon décodage ne prouvent pas qu’il contient le bon verset ni la bonne langue. Cette revue n’a pas été effectuée sur un corpus absent.
- Synchronisation au démarrage/fin des versets, pause/reprise/seek, interruption réseau et changement AR/FR/EN avec les vrais enregistrements.

La lecture nécessite Internet. Aucun corpus MP3 réel n’est inclus dans cette archive ni déclaré entièrement vérifié.
