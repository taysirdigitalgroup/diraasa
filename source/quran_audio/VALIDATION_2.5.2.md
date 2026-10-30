# Validation 2.5.2

- Extraction FR/EN : 114 sourates, 6 236 versets par langue, aucun numéro manquant ou dupliqué. Les 112 basmalas EN correspondent exactement à la phrase source avec espaces.
- Comparaison des assets 2.5.1 et 2.5.2 : toutes les listes de versets numérotés EN sont strictement identiques ; seules les 112 basmalas séparées ont changé.
- Dart autonome 3.9.4, helper de production quran_text.dart et assets réels : fusion des 114 sourates, affichage FR/EN, repli arabe si texte absent ou vide, sélection audio limitée au numéro du verset actif, basmala=0 indépendante, conservation de la langue manuelle hors lecture. Réussite.
- Parseur/formatteur Dart : quran.dart, quran_text.dart, test/quran_audio_test.dart et tools/quran_translation_check.dart : réussite.
- Test Flutter ajouté : quand le premier verset joue en FR puis EN, la carte voisine reste arabe et ses traductions ne s’affichent pas. Non exécuté ici.
- Aucun changement natif ou de schéma SQLite. Contrôle des archives membre par membre, lib/ complet et absence de secrets.

Non exécuté : flutter analyze, flutter test, APK, rendu sur téléphone et mesure de performances. Le bénéfice attendu est limité aux changements de layout évités sur les cartes voisines ; les textes étaient déjà chargés une seule fois.
