# Sources et intégrité — 2.0.0

Les trois SQL et les deux polices sont ceux fournis par l’utilisateur.
Reproduction : python3 tools/import_quran.py puis python3 tools/import_hisn.py.
Contrôle : python3 tools/check_devotion_data.py (fontTools requis pour les polices).

Coran : 114 sourates par lecture, 6236 versets Hafs et 6214 Warsh selon la
numérotation des fichiers. Hafs Fatiha : basmala de l’en-tête utilisée comme verset 1.
Un préfixe éditorial répété dans les premiers versets Hafs 16/17 est retiré ;
les exceptions et empreintes sont consignées dans import_report.json. Les SQL
originaux restent intacts. Aucun alignement forcé entre les deux numérotations.

Hisn : 90 blocs SQL conservés avec leurs textes originaux. L’import sépare les
notes signalées par الحواشي tout en récupérant le corps reprenant après ces notes.
132 chapitres et 267 entrées numérotées ; 138 blocs de notes conservés.
Les répétitions décrites dans la prose ne sont pas converties automatiquement en
objectifs : l’éditeur demande à l’utilisateur de définir le nombre souhaité.
La vue Source donne accès aux introductions et aux notes originales.

Les recherches suivent la règle globale : saisie vocalisée/majuscule précise,
sinon normalisation des harakat et variantes d’alif. Le texte affiché est conservé.
Les données religieuses ne sont pas téléchargées depuis une source alternative.

Horaires : https://aladhan.com/prayer-times-api ; requêtes explicites HTTPS avec
ville/pays ou coordonnées, méthode et école. Cache du mois courant et suivant.
Les notifications d’azan utilisent les instants ISO du lieu ; actualiser avant
la fin de la période indiquée. Ajustements locaux et comparaison à la mosquée recommandés.
Audio choisi par l’utilisateur, copié en stockage privé (maximum 30 Mo).

Rappels de dhikr : horaires locaux du téléphone et jours sélectionnés, un prochain
événement par rappel, recalcul après déclenchement/redémarrage/changement d’heure.
Autorisations Android notifications/alarmes exactes requises. Le téléphone peut
restreindre les alarmes selon sa politique batterie. Les compteurs, chaînes,
progressions et rappels sont persistants ; pas de modification du schéma notes.db.
