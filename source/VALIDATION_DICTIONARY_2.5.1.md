# Validation 2.5.1 — dictionnaire

- Suppression pages.id>5 : 3 767 blocs ; 5 blocs intro restent. Les références id/page des articles ne changent pas.
- Empreintes SHA-256 de toutes les lignes entries, des 5 pages intro et des termes FTS avant/après strictement identiques : source/dictionary_cleanup_2.5.1.json.
- assets/dictionary.db et android/app/src/main/assets/dictionary.db identiques ; intégrité SQLite valide.
- tools/check_data.py : intégrité, nombre d’articles, intro, version, FTS, préfixes, lettres et asset Android : réussite.
- Import du SQL original vers un fichier temporaire avec le nouvel importeur : toutes les lignes entries/pages/search identiques à l’asset nettoyé.
- Base héritée reconstituée avec tous les blocs bruts du SQL original et user_version=0 ; nettoyage transactionnel et VACUUM sur copie temporaire ; conservation intégrale des entrées/intro/FTS et deuxième exécution sans effet : réussite.
- La migration native cible uniquement dictionary_v1.db. Le code NotesDatabase et son schéma ne changent pas.
- Flutter analyze/test, APK et déclenchement sur téléphone non exécutés.
