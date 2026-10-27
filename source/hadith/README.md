# Recueils fournis — import 2.2.0

sahih_bukhari.sql et sahih_muslim.sql sont conservés sans modification.
Chaque INSERT donne une entrée ; les variantes partageant un numéro ne sont pas
fusionnées. Les références <<<…>>> sont séparées du texte et conservées à l’affichage.
L’id interne correspond à la position de la ligne source et n’est pas un numéro
religieux. Les listes sont triées par référence, puis id. Une entrée Muslim porte
un tiret au lieu d’un numéro dans la source : elle reste non numérotée.

Import : python3 tools/import_hadith.py
Contrôle : python3 tools/check_hadith.py
Comptages, numéros uniques/min/max et empreintes : import_report.json.
Ces métriques décrivent les fichiers fournis ; aucune numérotation externe ou
complétude d’édition n’est déduite. Textes et références sont comparés au SQL.

L’application charge le livre choisi hors ligne et prépare ses champs de recherche
via compute. Aucun accès réseau et aucune modification de notes.db pour la lecture.
