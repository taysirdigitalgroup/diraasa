# Traductions du Coran — PDF fournis

- Français : Muhammad Hamidullah, document coran-francais.com fourni par Aliou Mbengue.
- English : Talal Itani, ClearQuran, édition A utilisant « Allah ». Le PDF mentionne Creative Commons Attribution / NonCommercial / NoDerivs ; cette mention est conservée ici et dans Sources et Références de l’application.
- Les PDF originaux sont conservés sans modification dans ce dossier. Les textes intégrés sont extraits de ces PDF, et non générés par traduction automatique.

## Extraction
`python3 tools/import_quran_translations.py --fr source/quran_translations/quran_fr_source.pdf --en source/quran_translations/quran_en_source.pdf`
Nécessite PyMuPDF et pdftotext. L’anglais est lu colonne gauche puis droite, avec prise en compte des marges alternées ; en-têtes/pieds exclus. Les retours de ligne sont réunis ; les césures de fin de ligne anglaises sont réunies. Aucune reformulation du sens.

EXTRACTION_REPORT.json liste les pages PDF de chaque verset et les SHA-256 des originaux. Contrôle contre les 114 sourates et 6 236 versets numérotés de Hafs : FR 6 236, EN 6 236, aucun numéro manquant, supplémentaire ou dupliqué. Chaque fichier conserve également les 112 basmalas séparées ; Fatiha 1:1 et sourate 9 sans préambule ajouté.

## Affichage
La langue réellement lue commande le texte dans la sourate Hafs. Arabe par défaut et repli si une traduction est absente. Un sélecteur Texte permet aussi la lecture FR/EN sans audio. Recherche FR/EN disponible dans Hafs et dans la sourate. Ces traductions ne sont pas transposées à la numérotation différente de Warsh. Synchronisation par sourate/verset/langue, sans minutage mot à mot. Le texte des PDF n’est pas certifié identique mot pour mot à chaque enregistrement audio.
