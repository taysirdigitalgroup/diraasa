# Validation 2.4.2+45 — 28 octobre 2026

## Fichiers réels du dépôt

Les 21 fichiers d’Al-Fatiha (001001 à 001007) ont été téléchargés depuis le dépôt public, sous quran-hafs-ar, quran-hafs-fr et quran-hafs-en. Chaque réponse HTTP200 indiquait audio/mpeg. L’audit FFprobe + FFmpeg a validé le codec MP3, la durée positive et le décodage complet sans erreurs ; taille et SHA-256 sont enregistrés dans AUDIT_FATIHA_2.4.2.json. Aucun MP3 réel n’est incorporé à l’archive de l’app.

Ce contrôle ne certifie pas le contenu récité/traduit. Le fichier préalable anglais 001000 présent au premier constat, puis retiré par le développeur, ne fait pas partie des 21 fichiers attendus ni de la lecture d’Al-Fatiha.

## Cache

QuranAudioCacheCheck JVM réussi :

- Fenêtre actuelle ±3, limites des sourates, basmala séparée sauf Fatiha/Tawba.
- Suppression hors fenêtre, un seul téléchargement d’un fichier prêt, réutilisation après stop/reprise.
- Isolation AR/EN lors d’un changement de langue.
- Annulation d’une requête en cours : aucun résultat périmé délivré au nouveau lecteur.
- Invalidation et nouveau téléchargement d’un fichier rejeté par le lecteur.

La logique cache/disque/concurrence est testée avec un transport contrôlé. Ce test ne remplace pas une mesure du réseau/MediaMetadataRetriever/MediaPlayer sur Android.

## Autres contrôles exécutés

- Compilation de tous les fichiers Kotlin contre Android API36 et dépendances réelles, Kotlin2.2.20/JVM17. Seules les interfaces Flutter sont substituées pour ce contrôle isolé ; aucun APK généré. Avertissement ancien dans AlarmSupport.
- QuranAudioSourceCheck JVM et plan de lecture Dart autonome : nouvelles URL des dossiers réels, AR/FR/EN, numérotation Hafs et règles de basmala.
- Syntaxe Dart et échappements Kotlin.

## Non exécuté ici

Flutter analyze/test, APK et lecture réelle sur téléphone. À tester : démarrage/cache, avance/retour rapide, passage AR/FR/EN, coupure réseau avec/sans fichier prêt, suppression du cache Android, arrêt et nouvelle session, interruption par azan. Le cache reste temporaire, pas une bibliothèque hors ligne permanente.
