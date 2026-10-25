# Diraasa · دراسة — 1.1.3+9
Carnet d’études arabes et dictionnaire مختار الصحاح, Android, hors ligne.
Package : **com.tdg.diraasa**.

## Installer la mise à jour
L’archive Diraasa_MAJ_1.1.3.tar.gz contient **lib/ complet** et les autres fichiers
nécessaires, aux chemins de la racine du projet existant.
Arrêter flutter run, extraire à côté de pubspec.yaml, puis :
```bash
flutter pub get && flutter analyze && flutter test && flutter run
```
flutter_localizations provient du SDK Flutter ; pub get résout ses dépendances.
Ce correctif contient aussi les modifications natives : relancer l’application
complètement, pas seulement un hot reload.
Ne pas désinstaller, effacer les données ou changer la signature de l’application.

## Fonctionnalités
- Notes : création, modification explicite, suppression confirmée, auteur
  facultatif, dates automatiques, catégories, épinglage, modal de lecture.
- Cartes professionnelles ; texte aligné selon sa langue ; menus et épingles
  fixés en haut à droite, indépendamment de la direction du texte.
- Après une sauvegarde réussie, seul le contenu est vidé. Titre, auteur et
  catégorie sont conservés pour la prochaine note et mémorisés entre sessions.
  Le formulaire reste ouvert ; la sauvegarde suivante crée une nouvelle note.
  Une modification sauvegardée passe également en nouvelle saisie, sans risquer
  de réécraser la note précédente. Une erreur ne vide aucun champ.
- Recherche + deux rangées de filtres dans un en-tête sticky : se fixent en haut
  lors du défilement, ou immédiatement au focus. L’accroche ne revient pas
  automatiquement à la perte du focus.
- Notes : filtres catégorie + Tous les champs/Titre/Auteur/Contenu ; harakat ignorés.
- Dictionnaire : préfixe/mot/racine, contient, texte intégral FTS, lettre,
  pagination de 60. Les racines normalisent aussi les variantes d’alif.
- Correspondances surlignées en jaune clair en mode clair et en ocre en sombre.
  L’arabe vocalisé original reste intact. Aperçu recentré sur la correspondance.
  Des témoins des termes FTS sont visibles même si le passage est loin dans
  l’article ; la lecture complète conserve aussi le surlignage.
- Taille de lecture commune aux notes, formulaires et articles, persistante.
- Français, العربية et English ; sélecteur en haut à côté du thème.
- Premier lancement : langue principale du système parmi fr/ar/en, sinon fr.
  Le choix manuel est ensuite mémorisé. Interface RTL complète en arabe ;
  direction des contenus détectée indépendamment de la langue de l’interface.
- Apparence : automatique selon le système **par défaut**, clair ou sombre.
  Le choix reste mémorisé, de même que les filtres.
- Icônes Android, déclinaisons adaptatives, monochrome, splash clair/sombre
  avec marges et version interne conservés.
- À propos TDG et coordonnées copiables.

## Conservation des données
notes.db et com.tdg.diraasa inchangés. Schéma SQLite **version 2**.
NotesDatabase adopte l’ancienne base v0 et ajoute seulement l’index nécessaire.
Aucune base de données n’est incluse dans cette archive de correctif.
Les préférences utilisent un SharedPreferences distinct, versionné dans son nom,
écrit sur le thread natif et confirmé avant la fin de l’enregistrement.
Les écritures sont séquencées côté Dart. Aucun effacement des notes ou du livre.
La désinstallation/effacement système des données supprime toujours les données
locales ; la migration ne remplace pas une sauvegarde. Export non implémenté.

## Traduction automatique
Non intégrée : Google Cloud Translation exige un projet, des identifiants et
la facturation activée malgré son quota NMT gratuit de 500 000 caractères/mois.
Aucune clé Google ni accès détourné à un endpoint non officiel n’est embarqué.
Les langues d’interface traduisent les menus ; elles ne traduisent pas le livre
ni les notes. Pas de faux sélecteur de langue de traduction.
Références vérifiées le 25/10/2026 :
https://cloud.google.com/translate/pricing
https://cloud.google.com/translate/docs/setup

## Environnement TDG
Gradle 8.14.1, AGP 8.11.1, Kotlin 2.2.20, Java 17, SDK Android 36,
desugar 2.1.4. Versions conservées.
Flutter >=3.35 / Dart >=3.9. Aucun Firebase ni plugin natif tiers.
Pour un projet neuf provenant de l’archive complète :
```bash
bash tools/setup.sh
```
Pour une mise à jour, ne pas régénérer le projet : utiliser les commandes du haut.
Les manifestes debug/profile incluent INTERNET pour le service de débogage Dart.
La release garde le manifeste principal hors ligne.

## Dictionnaire et vérifications
3 772 blocs SQL, dont 3 767 articles et renvois et cinq blocs liminaires.
Un article conserve sa racine et ses dérivés avec leur contexte, sans découpage
artificiel. Les numéros sont ceux des blocs source.
```bash
python3 tools/check_migrations.py
python3 tools/check_search.py
python3 tools/check_android_debug.py
python3 tools/check_kotlin_escapes.py
python3 tools/check_data.py
```
L’import reproductible reste dans tools/import_dictionary.py ; le SQL d’origine
est dans source/ dans l’archive complète. Ne pas réimporter pour cette mise à jour.

Exécutés ici : intégrité du livre, SQL réel des recherches, contrôle de conservation
des notes lors des migrations, manifestes et échappements Kotlin.
Tests Flutter ajoutés : préférences, langues, surlignage, filtres, sauvegarde,
modal, clavier petit écran et en-tête sticky.
**Flutter/Android SDK absents de l’environnement de création : flutter analyze,
flutter test, la compilation et le rendu sur appareil restent à vérifier sur
votre poste.** Voir FICHE_TECHNIQUE.md pour l’historique.


## Correctif 1.1.1 — tests
Le test de changement de langue/thème utilise les menus réels puis pumpAndSettle,
sans bloquer l’horloge du test sur une écriture asynchrone non pompée.
Les boutons défilants sont rendus visibles avant les clics.
La géométrie sticky est testée sur les rangées, puis sur le bouton Auteur après
défilement horizontal. Les clics manqués sont fatals et chaque test de widgets
est limité à 45 secondes. Les assertions de persistance, langue, thème, filtrage
et conservation des notes sont maintenues.
Aucun changement de schéma, aucun effacement de préférences.
Après extraction, relancer la chaîne de vérification complète indiquée en haut.


## Correctif 1.1.2 — Contenu et menus testables
Recherche Notes et surlignage utilisent une règle commune :
- Tous les champs : titre, auteur, contenu.
- Titre : uniquement le titre.
- Auteur : uniquement l’auteur.
- Contenu : uniquement le corps de la note.

Le choix Contenu est mémorisé et traduit en arabe et anglais.
Les tests ciblent maintenant les éléments de menu par clé stable, plutôt que
le texte interne de CheckedPopupMenuItem qui ignore les pointeurs.
Ils conservent les contrôles de clic effectif, persistance, langue et thème.
Aucun changement de base de données ; installer sur l’app existante.


## Correctif 1.1.3 — file de sauvegarde des préférences
La première écriture ne dépend plus d’un Future créé au démarrage :
elle part immédiatement dans le contexte de l’appelant. Les écritures suivantes
restent ordonnées et une erreur de commit ne bloque pas la file.
Les tests conservent les assertions sur les valeurs stockées et contrôlent
l’amorçage, les accusés de sauvegarde, leur ordre et la reprise après erreur.
Aucun effacement de notes ou de préférences. Schéma SQLite inchangé.
Après extraction du correctif cumulatif, relancer les vérifications du haut.
