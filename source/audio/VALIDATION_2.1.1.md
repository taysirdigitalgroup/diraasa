# Validation — Diraasa 2.1.1, 27 octobre 2026

Exécutés :
- Tous les contrôles tools/check_*.py : données, migrations et sources Kotlin.
- check_audio.py : six sons de rappel présents, lisibles, durée <= 8,1 secondes,
  catalogue sans doublon ; huit adhans existants conservés.
- Dart 3.9.4 format : syntaxe des fichiers Dart modifiés.
- Vérification des empreintes et du contenu de l’archive cumulative.

Ajouté : test Flutter des signatures de paramètres (isolation des trois sections,
normalisation des coordonnées et de la casse, choix audio indépendant).
Non exécutés : flutter analyze, flutter test, Gradle/APK et essai sur téléphone.

Sur appareil :
1. Charger les horaires. Les trois boutons de section doivent être désactivés.
2. Modifier la ville : seul Actualiser de Localisation devient actif ; rétablir
   la ville précédente le désactive. Essayer aussi coordonnées et école hanafite.
3. Actualiser après plusieurs changements : les horaires/cache et les trois
   états de bouton sont mis à jour ensemble après réussite uniquement.
4. Changer le fuseau du téléphone et revenir dans la page : le fuseau de la date
   suit le téléphone ; le fuseau des horaires du lieu choisi reste explicite.
5. Dans un rappel Zikr/Wird, écouter et sélectionner chacun des cinq nouveaux sons.
   Vérifier le nom choisi après fermeture/réouverture et le test différé.

Aucune base de notes n’est incluse ni réinitialisée.

Compléments : section Wird déplacée avant Azkar ; test Flutter de régression du
lecteur de sourate (texte inchangé, largeur/hauteur tight) ajouté, non exécuté ici.
Défaut identifié dans Flutter 3.35 : EditableText.defaultSelectionWidthStyle=max
sur plateformes natives. La configuration explicite tight corrige l’extension.
Source : https://github.com/flutter/flutter/blob/3.35.0/packages/flutter/lib/src/widgets/editable_text.dart
