# Diraasa — Fiche technique et historique
Version application : **1.1.3+9**  
Date : **25 octobre 2026**  
Application Android : **com.tdg.diraasa**  
Éditeur : Taysir Digital Group — Aliou Mbengue

## 1. Architecture
Flutter Material 3, Dart >=3.9 / Flutter >=3.35.
Deux onglets Notes / Dictionnaire. Canal natif tdg.diraasa/data.
SQLite Android pour la persistance ; requêtes sur un exécuteur dédié.
Gradle 8.14.1, AGP 8.11.1, Kotlin 2.2.20, Java 17, SDK 36.
Ces versions TDG ne sont pas modifiées par cette mise à jour.
Localisation via flutter_localizations (SDK Flutter), fr/ar/en.

## 2. Données et contrat de migration
- notes.db : données utilisateur persistantes ; ne jamais remplacer ce fichier
  par un asset, le supprimer, ni supprimer/recréer la table lors d’une mise à jour.
- Schéma : id, title, body, author, kind, created, updated, pinned.
- SQLiteOpenHelper NotesDatabase gère le numéro PRAGMA user_version.
- Anciennes versions : user_version=0, table existante non versionnée.
- Version 1 : schéma de référence (prévue pour compatibilité).
- Version 2 : même table + index notes_order(pinned DESC,updated DESC).
- Adoption v0 : CREATE TABLE IF NOT EXISTS ne touche pas la table existante ;
  création idempotente de l’index puis user_version=2.
- Migration v1→v2 : ajout de l’index uniquement.
- Réouverture v2 : aucune réinitialisation ni import des notes.
- Migration transactionnelle via SQLiteOpenHelper ; erreur => transaction annulée.
- Retour à une version de schéma antérieure : refus explicite, jamais suppression.
- Toute évolution future doit ajouter une migration incrémentale, vérifier les
  données anciennes et inscrire le changement dans cette fiche.
- dictionary_v1.db : livre en lecture seule, distinct des notes ; copié
  seulement lors de sa première installation. Aucun changement ici.
- ID Android et nom notes.db restent stables ; aucune migration entre applications.
- La mise à jour se fait sur l’installation existante avec la même signature.
  Ne pas désinstaller l’application, effacer ses données ou changer de clé.
- Cela préserve les données lors des migrations ; ce n’est pas une sauvegarde
  contre la perte du téléphone ou une désinstallation. Export non implémenté.

## 3. Historique
### 1.0.0 — Création
Notes ajout/modif/suppression, auteur facultatif, dates automatiques, catégories,
épinglage, dictionnaire complet issu du SQL (3 767 articles + 5 blocs liminaires),
recherches mot/racine, contient et texte intégral, pagination et lecture RTL.
Icônes Android adaptatives, cinq densités, splash clair/sombre et icône interne.

### 1.0.1 — Identité et corrections
Nom Diraasa, identifiant com.tdg.diraasa, nom intégré au logo.
Correction du type Row qui masquait le widget Flutter ; AppRecord à sa place.
DropdownButtonFormField : initialValue.
Regex Unicode Kotlin convertie en chaîne brute pour éviter Unsupported escape sequence.

### 1.0.2 — Recherche, clavier et migrations
- Champ de recherche : direction et alignement à partir de la première lettre
  significative saisie ; arabe RTL et latin LTR dans les deux onglets.
- Champ vide : départ RTL ; indication française affichée en LTR.
- En-tête, filtres et résultats dans un CustomScrollView / SliverList.
  Aucun bloc de hauteur fixe imposé au-dessus d’une liste Expanded.
- Clavier ouvert : accroche repliée, navigation et bouton flottant masqués ;
  contenu défilant. Glisser la liste ou valider la recherche referme le clavier.
- Notes : filtre de champ Tous les champs / Titre / Auteur, combinable aux
  catégories Tout / Cours / Vocabulaire / Vers / Citation.
- Migration non destructive vers la version SQLite 2 et index de classement.
- Initialisation des notes indépendante de celle du dictionnaire pour permettre
  une nouvelle tentative après une erreur d’ouverture.
- Version 1.0.2+3 ; notes existantes et identifiant Android conservés.
- Création de cette fiche technique ; elle doit accompagner chaque évolution.

### 1.0.3 — Lecture des notes et focus de recherche
- Un appui sur une note ouvre un modal de visualisation à 85 % de la hauteur.
- Modal en lecture seule : contenu complet défilant, titre, auteur facultatif,
  catégorie et date ; texte sélectionnable, copie et fermeture.
- Le formulaire de modification est accessible via l’option Modifier du menu.
- Options : Épingler ou Détacher selon l’état, Modifier, Supprimer.
- FocusNode du champ de recherche : replie immédiatement l’accroche,
  puis ramène le défilement au début pour placer le champ sous l’AppBar.
  Fonctionne aussi avec un clavier physique et sur les deux onglets.
- ScrollController et FocusNode correctement libérés à la fermeture de l’écran.
- Version 1.0.3+4 ; schéma SQLite inchangé à 2. Aucun changement de données.
- Tests Flutter ajoutés : clic note en lecture seule, menu Modifier,
  ouverture du formulaire et position du champ après focus.
- Archive de mise à jour cumulative depuis 1.0.1 : inclut aussi le helper de
  migration et les correctifs 1.0.2, sans bases de données.

### 1.0.4 — Petit écran et service de débogage Dart
Retour utilisateur : flutter analyze réussit et l’APK se compile/s’installe.
Le test petit écran signale un RenderFlex overflow horizontal de 5 px.
- En-tête : titre dans Flexible, une seule ligne avec ellipse, logo 32 px,
  espacements réduits ; l’espace réservé aux actions reste disponible.
- Catégorie dans la carte de note également contrainte pour éviter un
  débordement horizontal lorsque la largeur du texte augmente.
- Tests supplémentaires en 320 et 360 px, avec ouverture du clavier.
- Ajout des manifestes android/app/src/debug/AndroidManifest.xml et
  android/app/src/profile/AndroidManifest.xml : permission INTERNET.
- Cette permission permet aux outils Flutter et au Dart VM service de
  communiquer, y compris via une socket locale ; son absence est cohérente
  avec Operation not permitted sur 127.0.0.1.
- Manifeste principal/release inchangé ; fonctionnalités métier hors ligne.
- Ajout de tools/check_android_debug.py pour contrôler ces manifestes.
- Gradle/AGP/Kotlin TDG conservés. L’avertissement de migration Kotlin
  n’a pas empêché le build rapporté ; aucune migration Gradle dans ce correctif.
- Version 1.0.4+5 ; schéma 2 et notes existantes inchangés.
- Contrôles XML, SQL de migration et échappements Kotlin exécutés ici.
  Tests Flutter et validation sur TECNO KL4 à relancer sur le poste utilisateur.

### 1.1.0 — Sticky, cartes, surlignage, localisation et préférences (25/10/2026)
- Recherche + filtres réunis dans un SliverPersistentHeader pinned, conservé
  avec une clé stable quand l’accroche est retirée au focus.
- Intro repliée au focus une fois pour la session, sans réapparition sur blur.
  Défilement naturel : l’intro peut défiler avant fixation du bloc de recherche.
- Cartes de notes : même vocabulaire visuel que le dictionnaire, motif, bordure,
  menus et épingles en Positionned top/right physique ; largeur de texte complète.
- MatchText détecte la direction du contenu et applique aussi un alignement
  à droite/gauche explicite. Modal, article, titres et auteurs suivent leur texte.
- Recherche Notes : normalisation arabe identique aux règles pertinentes du
  dictionnaire ; filtres sur champs indépendants, combinables aux catégories.
- Dictionnaire : modes stables prefix/contains/fulltext, labels localisés séparés ;
  normalisation des alif et de la maqsura dans les racines SQL.
- Surlignage sur le texte original : indices des caractères conservés pendant
  normalisation pour inclure les harakat. Requête entière pour Notes/contient,
  début pour préfixe, début de chaque token pour FTS ; aucune altération du livre.
- Aperçus autour du premier résultat et témoins des tokens FTS recherchés ;
  racines espacées surlignées via une normalisation compacte.
- Couleur de surlignage jaune clair/ocre selon le thème.
- Localisation française, arabe et anglaise pour tous les libellés de l’app.
  Les noms d’auteurs et le contenu du dictionnaire ne sont pas traduits.
- Premier lancement : langue principale du système si fr/ar/en, sinon français.
  Choix manuel mémorisé. Direction générale RTL quand l’interface est en arabe.
- Sélecteur de langue à côté du sélecteur de thème en haut.
- ThemeMode.system par défaut ; modes clair, sombre et automatique persistants.
- Taille de lecture commune persistante, 18–36, pour cartes, lecteurs et saisie.
- Filtres noteCategory/noteField/dictionaryMode/dictionaryLetter persistants.
- Enregistrement réussi : contenu vidé, titre/auteur/catégorie conservés.
  Retour en mode nouvelle note (id=null), y compris après modification ;
  évite l’écrasement du dernier enregistrement lors d’une saisie suivante.
- Titre/auteur/catégorie réutilisables également conservés entre sessions.
- Erreur d’enregistrement : champs conservés. La liste se recharge au retour.
- Préférences natives dans diraasa_preferences_v1, distinctes de notes.db.
  Commit sur le thread natif, écritures Dart séquencées, retour d’erreur visible.
- Schéma de notes inchangé à 2, aucun remplacement de base.
- Google Translation non intégré : quota NMT gratuit mais facturation et
  authentification requises. Pas de traduction automatique ni sélecteur fictif.
  Sources vérifiées : cloud.google.com/translate/pricing et /translate/docs/setup.
- Réorganisation de lib/ en core/, screens/, widgets/, main.dart et exports.
- Tests remplacés/complétés pour le fonctionnement courant ; contrôle SQL réel
  des filtres dans tools/check_search.py. Les tests Flutter ne sont pas exécutés
  ici, faute de SDK ; aucun résultat de compilation Android revendiqué.

### 1.1.1 — Correction du banc de tests (25/10/2026)
Retour utilisateur : flutter analyze sans erreur, 3 échecs Flutter :
attente de 10 minutes dans le test langue/thème, clic Auteur hors écran,
et assertion de géométrie sur le même filtre masqué horizontalement.
- Test langue/thème : passe par les vrais menus de l’application et avance
  les frames/microtâches via pumpAndSettle, au lieu d’attendre directement
  settings.update() avant toute progression de l’horloge simulée.
- Le test vérifie encore le RTL/LTR, les deux thèmes, les notes conservées
  et les valeurs effectivement écrites dans le stockage simulé.
- Filtres : ensureVisible puis vérification hitTestable avant chaque clic.
- Sticky : vérifie la position du bloc et des rangées complètes. Un bouton
  hors écran dans une rangée horizontale n’est pas un échec de sticky.
  Auteur est ensuite amené dans la zone visible et contrôlé à son tour.
- Clés stables ajoutées aux deux rangées pour mesurer leur vraie géométrie.
- Les clics manqués sont désormais fatals dans les tests : aucun warnIfMissed
  désactivé et aucune assertion supprimée pour dissimuler un échec.
- Limite explicite de 45 secondes par test de widgets pour éviter dix minutes
  d’attente à chaque blocage.
- Version 1.1.1+7 ; logique métier, stockage, préférences et schéma 2 inchangés.
- Les scripts SQL, migrations, permissions et échappements restent valides.
  Le SDK Flutter est absent ici : les tests corrigés doivent être exécutés
  sur le poste utilisateur, aucun passage de flutter test revendiqué.

### 1.1.2 — Filtre Contenu et cible de clic des menus (25/10/2026)
Retour utilisateur : analyse sans erreur, 10 tests réussis et un échec sur
le clic du libellé العربية dans CheckedPopupMenuItem.
- Ajout du filtre Contenu / المحتوى / Content, identifiant stable body.
- Liste canonique noteSearchFields = all, title, author, body.
- Préférence noteField : accepte body à la lecture, aucune suppression des
  anciens réglages ; la sauvegarde native générique reste compatible.
- Fonction noteFieldKeys commune au filtrage et au surlignage :
  all cible titre+contenu+auteur ; les trois autres ciblent leur champ seul.
- noteFieldQuery utilise la même règle dans les cartes et le modal.
  Un contenu ne peut plus déclencher le filtre Auteur ou Titre, ni être
  surligné quand seul un autre champ est sélectionné.
- Tests croisés de tous les champs, auteur null, recherche vide,
  normalisation arabe, persistance body et combinaison avec une catégorie.
- Test UI : le mot Auteur est refusé par Contenu ; العلم retrouve le texte
  vocalisé ; le modal ne surligne alors ni le titre ni l’auteur.
- Clés stables sur les CheckedPopupMenuItem de langues et thèmes.
- Le test clique sur l’élément de menu entier, pas son libellé ignoré par
  le hit test interne de CheckedPopupMenuItem. Visibilité et hitTestable
  contrôlés avant le clic ; les clics manqués restent fatals.
- Version 1.1.2+8. Aucune modification de notes.db, du schéma SQLite 2,
  de la signature ou de l’identifiant Android.
- Contrôles SQL, migration, manifestes et échappements exécutés ici ;
  tests Flutter à relancer sur le poste utilisateur (SDK absent ici).

### 1.1.3 — Amorçage fiable des écritures de préférences (25/10/2026)
Retour utilisateur : analyse sans erreur et 10 tests réussis ; valeurs persistées
language et noteField null dans deux tests de widgets malgré l’interface mise à jour.
- Cause dans AppSettings : Future<void>.value() créé à la construction dans
  setUp, puis utilisé comme prérequis de la première écriture dans FakeAsync.
  Le constructeur imposait une dépendance à un contexte d’exécution antérieur.
- File initialement vide (Future nullable). La première écriture est déclenchée
  directement dans le contexte de l’appelant ; seules les écritures suivantes
  sont chaînées derrière un commit en cours.
- Chaque snapshot est conservé et écrit dans l’ordre, sans fusion destructrice.
- Le résultat réel est renvoyé à l’appelant. Une erreur ne bloque pas la suite.
- Le marqueur de file est libéré uniquement si le commit terminé est encore
  le dernier, afin de ne pas perdre le suivi d’un commit ajouté entre-temps.
- Tests ajoutés : première écriture avec settings créé hors de FakeAsync,
  second commit bloqué jusqu’à l’accusé du premier, ordre et dernier snapshot,
  conservation de langue+thème+Contenu ; reprise après échec de stockage.
- Les assertions persisted['language']=='ar' et persisted['noteField']=='body'
  sont conservées, ainsi que les clics réellement testables et les filtres.
- Version 1.1.3+9. Schéma SQLite 2, notes.db, fichier de préférences natif et
  identifiant Android inchangés ; aucune migration ou réinitialisation.
- Contrôles SQLite, migration, XML et échappements exécutés ici. SDK Flutter
  absent : nouveaux tests à exécuter sur le poste utilisateur, sans présumer
  de leur résultat.

## 4. Fichiers de cette mise à jour
Archive cumulative depuis 1.0.1 : **Diraasa_MAJ_1.1.3.tar.gz**.
- lib/ complet : main.dart, core/app_core.dart, core/search.dart,
  screens/home.dart, screens/editor.dart, screens/readers.dart, widgets/controls.dart.
- android/app/src/main/kotlin/com/tdg/diraasa/MainActivity.kt
- android/app/src/main/kotlin/com/tdg/diraasa/NotesDatabase.kt
- android/app/src/debug/AndroidManifest.xml
- android/app/src/profile/AndroidManifest.xml
- pubspec.yaml
- test/widget_test.dart
- tools/check_migrations.py, check_search.py, check_android_debug.py,
  check_kotlin_escapes.py, check_data.py.
- README.md et FICHE_TECHNIQUE.md.
Aucune base, aucun asset ni changement Gradle dans le correctif.
Les icônes et données déjà installées sont réutilisées.

## 4 bis. Préférences : format et évolution
Fichier Android SharedPreferences nommé diraasa_preferences_v1 :
language, theme, textSize, draftTitle, draftAuthor, draftKind,
noteCategory, noteField, dictionaryMode, dictionaryLetter.
Champs optionnels : absence => valeur par défaut ; aucune table de notes touchée.
Lecture et validation au démarrage. Les nouveaux champs sont ajoutés sans clear().
Le booléen system est représenté par theme="system", pas une copie du thème du
téléphone : les changements du système sont suivis automatiquement.
Le contenu de note n’est jamais stocké comme préférence ; il reste dans notes.db.
Une erreur d’écriture de préférences n’annule pas une note déjà enregistrée.

## 5. Vérifications
Exécutés ici :
- check_migrations.py : SQL réel du helper sur données historiques v0/v1/v2 ;
  comparaison de toutes les valeurs avant/après, index idempotent, insertion.
- check_kotlin_escapes.py : échappements des sources Kotlin.
- check_data.py : intégrité et recherche dans le dictionnaire inchangé.

Tests Flutter ajoutés : localisation, préférences, saisie successive,
surlignage, filtres, sticky au défilement, RTL/LTR, focus et clavier simulé
sur écran 360×640 dans les deux onglets, filtres Titre/Auteur, notes/article/formulaire.
Flutter et SDK Android absents ici : ces tests, flutter analyze, la compilation
et l’exécution Android doivent être lancés sur le poste de développement.
Le test SQL ne remplace pas un essai de mise à jour sur appareil.

## 6. Procédure pour les prochaines évolutions
1. Garder com.tdg.diraasa, notes.db et la signature existante.
2. Écrire une migration additive si le schéma change ; incrémenter sa version.
3. Vérifier un jeu de notes existantes, IDs, dates, auteurs et épinglage inclus.
4. Mettre à jour cette fiche, la version et les tests concernés.
5. Livrer au minimum lib/ complet + tous les autres fichiers modifiés,
   aux mêmes chemins relatifs, dans une archive de mise à jour.
