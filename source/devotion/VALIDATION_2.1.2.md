# Validation — Diraasa 2.1.2, 27 octobre 2026

Exécutés :
- Contrôles Python des migrations, du dictionnaire, des recherches, des
  suppressions/renommages, des données Coran/Hisn et des assets audio.
- Hisn : deux parties liminaires complètes, références présentes, continuation
  de la fin du فضل الذكر récupérée avant le chapitre 1 ; 132 chapitres/267 entrées
  conservés ; empreinte du SQL source intacte.
- Syntaxe Dart via Dart 3.9.4 format sur lib/ et test/.
- Échappements Kotlin et vérification de l’archive contre les fichiers sources.

Tests Flutter ajoutés, non exécutés ici : seulement deux parties dans HisnSource,
cinq accès de référence et lien PayPal exactement conforme au DEV ENV.
Flutter analyze/test, compilation APK et essai Android non exécutés ici.

Limite de configuration : le DEV ENV fournit le lien PayPal mais laisse waveUrl
et contactPhone2 vides. Les cartes Wave et Orange Money proposent uniquement de
contacter TDG/copier le numéro de contact pour demander les coordonnées de don.
Aucun lien marchand ou numéro de portefeuille n’a été inventé.

Après mise à jour, relancer complètement flutter run (modification native).
Ne pas désinstaller ni effacer les données de l’application.
