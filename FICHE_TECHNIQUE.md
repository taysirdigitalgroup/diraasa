# Diraasa — Fiche technique et historique
Version application : **2.2.1+35**  
Date : **27 octobre 2026**  
Application Android : **com.tdg.diraasa**  
Éditeur : Taysir Digital Group — Aliou Mbengue

## 1. Architecture
Flutter Material 3, Dart >=3.9 / Flutter >=3.35.
Cinq onglets : Auteurs / Thèmes / Notes / Dictionnaire / Cultes. Canal natif tdg.diraasa/data.
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
- Version 3 : ajout du catalogue note_references(field, identity, label), sans changer les colonnes de notes.
- Adoption v0 : CREATE TABLE IF NOT EXISTS ne touche pas la table existante ; création de l’index et du catalogue puis user_version=3.
- Migration v1→v2 : ajout de l’index uniquement.
- Migration v1/v2→v3 : création du catalogue et récupération des titres/auteurs, notes inchangées.
- Version 4 (actuelle) : table authors, colonnes author_id/body_format et index notes_author. Récupération des auteurs et liens vers les notes sans modifier leurs champs historiques.
- Réouverture v4 : aucune réinitialisation ni réimportation.
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

### 1.1.4 — Taille de lecture limitée et accroche réversible (25/10/2026)
- La préférence textSize reste persistante (18–36), mais son application est
  limitée aux lecteurs : modal de note, page d’article et introduction du livre.
- Cartes : tailles fixes 21/17 pour Notes, 24/18 pour Dictionnaire ; métadonnées
  14/12. Saisie du contenu : 20, sans picker de lecture dans le formulaire.
- Le sélecteur global reste accessible dans À propos et dans les lecteurs.
- Le facteur d’accessibilité du système reste indépendant et respecté.
- Suppression du drapeau introHidden : l’accroche reste toujours dans le flux.
- Au focus, mesure de la hauteur réelle du bloc via GlobalKey et défilement
  jusqu’à cette hauteur pour fixer la recherche sous l’en-tête.
- En revenant à la position zéro, l’accroche réapparaît progressivement et
  le bloc de recherche redescend ; dans l’autre sens le header redevient pinned.
- Aucun retour automatique à la perte du focus.
- SliverLayoutBuilder ajoute seulement le complément de hauteur nécessaire
  aux listes courtes/vides pour autoriser ce cycle, sans scroll imbriqué.
- Tests adaptés : l’accroche est hors de la zone visible au focus plutôt que
  supprimée de l’arbre ; test du retour manuel, descente et nouvelle fixation.
- Test de typographie : réglage à 36 conservé dans lecteurs/modals, dimensions
  inchangées des cartes et du formulaire.
- Version 1.1.4+10. Notes, préférences et schéma SQLite 2 conservés.
- Contrôles locaux habituels exécutés ; tests Flutter/rendu Android à vérifier
  sur le poste de développement, faute de SDK Flutter ici.

### 1.2.0 — Surlignage arabe et interactions (26/10/2026)
- Le surlignage ne crée plus de TextSpan de styles distincts au milieu d’un mot.
  Il n’ajoute aucun caractère et ne change pas le gras.
- Un RenderProxyBox peint le fond à partir des boîtes de sélection du
  RenderParagraph/RenderEditable réellement utilisé. Un seul texte original
  est rendu ; la géométrie, les ligatures, les diacritiques et la copie sont préservés.
- Le picker ReadingSize possède son propre AnimatedBuilder pour que même une
  instance const réagisse aux valeurs. Mémorisation sur onChangeEnd.
- Taille persistante : lecteurs et modals + champ Contenu du formulaire.
  Taille des cartes et des autres champs inchangée.
- Le défilement vertical principal annule les requêtes différées de focus et
  défocalise la recherche. Le caret ne peut plus repositionner la page après
  un geste volontaire de retour en haut ; onTap volontaire permet de refixer.
- RefreshIndicator Notes, à partir du bord supérieur réel ; relit les données
  sans réinitialiser la recherche, la catégorie ou le filtre de champ.
  NotificationPredicate exclut l’onglet Dictionnaire et les scrolls imbriqués.
- 13 types de note, libellés en 3 langues, valeurs stables : Cours, Vocabulaire,
  Notion, Définition, Grammaire, Conjugaison, Règle, Exemple, Exercice, Résumé,
  Vers, Citation, Autre. Menu de saisie défilant, limité en hauteur.
- Nouveaux tests : texte et boîtes de glyphes identiques avec/sans surlignage,
  sélection du texte intacte, slider animé même const, taille dans Contenu,
  retour d’accroche alors que la recherche est encore focalisée, refresh
  sans perte de filtre et exclusion du Dictionnaire, types persistants.
- NotesDatabase reste version 2 : kind est déjà TEXT libre, pas d’ALTER/DROP.
  Les 4 types historiques et toutes les notes existantes sont conservés.
- Version application 1.2.0+11. Application ID, signature et fichiers de données
  inchangés ; aucun nouvel accès réseau.
- Contrôles SQL/migration/manifestes/échappements exécutés ici ; SDK Flutter
  absent, compilation, tests et rendu sur appareil à confirmer sur le poste.

### 1.2.1 — Ancrage au clavier et bouton Retour d’article (26/10/2026)
Retour utilisateur : analyse sans erreur, 17 tests réussis et 3 échecs :
deux mesures d’introduction masquée à 233 px et un retour de page introuvable.
- Les tests sur petit écran mesurent désormais l’en-tête réellement visible,
  à la hauteur de l’AppBar, avant et après fermeture du clavier.
  Ils ne déduisent plus sa position des transformations d’un sliver masqué.
- Ancre keepSearchPinned après focus : au changement de hauteur du viewport
  (ouverture/fermeture du clavier), repositionnement après mise en page.
- La conservation d’ancre est annulée au début d’un défilement vertical
  volontaire et au changement d’onglet. Le retour manuel de l’introduction
  reste possible et prioritaire.
- Les callbacks différés sont invalidés par le compteur de requêtes de focus ;
  les notifications de métriques de scroll imbriqué/horizontal sont exclues.
- Article : BackButton explicite, clé article-back, utilisant Navigator.maybePop.
- Le test clique ce bouton puis vérifie que la route Article a disparu et que
  Home est revenu, sans supposer un type de bouton généré par la plateforme.
- Version 1.2.1+12. Aucun changement métier, de schéma, de base ou de préférences.
- Contrôles SQL, migration, XML et échappements exécutés ici ; les trois parcours
  Flutter corrigés restent à valider sur le poste utilisateur (SDK absent ici).

### 1.2.2 — alignement des réglages et header stable
- Infos : Langue et Apparence sur deux lignes distinctes, chaque libellé et son sélecteur sur la même ligne ; boutons de 48 px alignés au bord droit.
- Header principal : disposition LTR stable pour logo, nom et actions, quelle que soit la langue. Le corps et les textes arabes gardent leur direction RTL.
- Aucun changement du schéma, des notes ou des préférences.
- Vérification statique et contrôles Python ; Flutter absent ici, validation visuelle et tests Flutter à exécuter sur le poste de développement.

### 1.3.0 — contenu prioritaire et catalogues réutilisables
- Cartes Notes : titre discret (14 px), contenu principal (19 px), badge auteur avec couleur déterministe, type en petite étiquette (11 px) sous l’auteur. Taille indépendante du réglage de lecture.
- Deux sélecteurs dans les champs Titre/Auteur : modal recherchable, liste à construction progressive, sélection sans écraser le contenu. Recherche insensible aux harakat et variantes d’alif.
- SQLite notes.db v3 : ajout de note_references, clé unique (field,identity). Migration additive v0/v1/v2 vers v3, récupération des valeurs historiques sans réécriture des notes.
- Titres et auteurs séparés ; déduplication NFC, casse et espaces ; accents et voyelles arabes conservés comme distinctions. Première graphie conservée et réutilisée dans les nouvelles notes. Historique du catalogue conservé après suppression d’une note.
- Ajout au catalogue uniquement lors d’un enregistrement réussi, dans la même transaction que la note. Une saisie abandonnée ne crée aucune entrée.
- Contrôles locaux Python réussis. Test widget ajouté pour sélection/recherche et conservation du contenu ; Flutter/Android absents ici, analyze/test/build restent à exécuter sur le poste utilisateur.

### 1.3.1 — parcours du test des sélecteurs
- Le test défile désormais dans le Scrollable du formulaire avec scrollUntilVisible : les champs hors écran sont construits par le ListView avant calcul de leur position.
- Clic sur les sélecteurs vérifié via hitTestable ; vérification du contenu via son contrôleur, y compris lorsque le champ est hors écran.
- Les assertions de recherche, sélection Titre/Auteur et conservation du contenu sont maintenues. Aucun changement de schéma ou de données.
- Retour utilisateur 1.3.0 : analyze sans erreur, 20 tests réussis, 1 échec dans le parcours corrigé. Flutter absent ici, suite à relancer sur le poste utilisateur.

### 1.4.0 — profils, thèmes et éditeurs
- Quatre onglets dans un ordre physique stable (Auteurs, Notes, Dictionnaire, Thèmes) ; Notes au lancement.
- Profils : nom unique normalisé NFC/casse/espaces, image facultative copiée en stockage privé, naissance/décès facultatifs, vivant, biographie. Ajout depuis Auteurs ou création automatique à l’enregistrement d’une note ; modification depuis la fiche.
- Table authors : id, identity UNIQUE, name, birth, death, alive, bio, bio_format, photo. Les notes utilisent author_id ; affichage du nom/photo actuels par jointure. Renommage du profil synchronisé aux notes liées.
- Migration notes.db v4 : création de authors, ajout author_id/body_format et index. Les noms historiques alimentent les profils et leurs liens. Le dictionnaire reste inchangé, notes et préférences conservées.
- Titre renommé Thème dans les libellés uniquement ; clé title conservée. Livre en tête des types. Thème sur une ligne dans les cartes.
- Page Thèmes recherchable : compteur et navigation vers les notes correspondantes ; filtre de thème appliqué avant recherche/catégorie. Calcul des compteurs en un parcours des notes.
- Nouveau StudyController : texte brut + styles JSON par plages UTF-16 (start/end/attrs). Préservation du texte arabe ; mise en forme explicite seulement, sans balises ajoutées au contenu. Les lecteurs affichent les styles et gardent le surlignage géométrique.
- Toolbar : gras, italique, souligné, titre, puces, collage. Import de styles Android HTML/Spanned par bouton ou menu contextuel. Seuls les styles essentiels fournis par la source sont conservés ; aucun import de tableau/image ou de police. Collage via clavier tiers : le bouton/menu de l’éditeur est la voie garantie pour les styles.
- Photos via ACTION_OPEN_DOCUMENT/onActivityResult, copie en fichiers privés, sans permission ni nouvelle dépendance Flutter ; les fichiers orphelins ne sont pas purgés dans cette version.
- Fichiers nouveaux : lib/screens/catalogs.dart et lib/widgets/rich_editor.dart. Environnement Gradle/Kotlin/SDK inchangé.
- Contrôles Python SQL/migrations/recherche/intégrité/échappements/debug exécutés. Tests Flutter ajoutés pour profils, navigation thèmes, formatage et collage ; Flutter/Android absents ici, pas de build ou de tests Flutter revendiqués.

### 1.4.1 — sous-page Thèmes, citation et cartes communes
- Ordre Notes / Thèmes / Auteurs / Dictionnaire, stable physiquement dans les trois langues.
- ThemeNotesPage est une route dédiée sans Home ni NavigationBar ; requête des notes, filtrage par thème, recherche locale, rafraîchissement et actions explicites. Le modal se ferme sur la sous-page ; retour vers l’onglet Thèmes conservé.
- StudyNoteCard partagé : contenu formaté dans toutes les listes, bandeau oblique miniature supérieur gauche, couleur propre à chaque type, options et épingle à droite. Thème tronqué sur une ligne.
- StudyText accepte un aperçu non sélectionnable avec maxLines. Les plages de styles sont recalées sur l’extrait de recherche ; les surlignages restent peints derrière le texte réellement mis en page.
- Citation : attribut q dans le sidecar existant, bouton format_quote, style en italique et encadré visuel de citation dans cartes/lecteurs. Aucune insertion de guillemets ni modification du texte brut. QuoteSpan du presse-papiers Android reconnu.
- Dates naissance/décès retirées des écrans de profil et formulaire. Colonnes historiques conservées, valeurs préservées à l’enregistrement ; statut vivant conservé. Schéma toujours v4.
- Nouveaux composants : widgets/note_card.dart et widgets/author_avatar.dart ; pas de dépendance ajoutée.
- Tests adaptés : ordre des onglets et navigation confinée à Thèmes ; tests citation et carte formatée. Contrôles Python réussis ; Flutter/SDK Android absents, tests Flutter non exécutés ici.

### 1.4.2 — recherche adaptative et typage du test
- Détection commune Dart/Kotlin : harakat présents ou caractères majuscules => graphie précise ; sinon normalisation tolérante (casse, harakat, tatweel, alif/hamza portés sur alif, ى/ي). Hamza seule sans harakat : saisie tolérante.
- Notes : filtre et plages de surlignage utilisent le même mode ; extraits recalés sur ces plages. Saisie précise = sous-chaîne littérale, sans imposer égalité avec toute la note.
- Dictionnaire : présélection existante, contrainte binaire substr/instr pour Préfixe/Contient précis ; raffinement des mots originaux des candidats FTS avec signes combinatoires conservés, puis pagination. Les termes FTS restent combinés avec ET et préfixe par terme.
- Témoins FTS : mode précis de la requête conservé pour tous les termes.
- Test cartes : accès à children après conversion explicite de InlineSpan en TextSpan.
- Tests SQL : prédicats exacts récupérés du Kotlin, cas vocalisés/casse et jeux contrôlés ; cas Dart ajoutés pour recherche et surlignage. Contrôles locaux réussis. Flutter/Android absents ici, analyse/tests/build non exécutés.
- Schéma v4, données, préférences, profils et dictionnaire conservés ; aucune migration nécessaire.

### 1.4.3 — recherche uniforme
- matchesSearch centralise la règle adaptative côté Dart. Utilisé par Notes, sous-page des notes d’un thème, listes Auteurs/Thèmes et sélecteurs.
- Dictionnaire natif et surlignages conservent la même détection harakat/majuscules. Déduplication des noms/thèmes inchangée : casse et espaces normalisés.
- Aucun changement de schéma ou de données. Contrôles locaux réussis ; Flutter absent ici, tests/analyse Flutter à exécuter sur le poste utilisateur.

### 1.4.4 — correction du constructeur de surlignage
- Retrait de this.precise du constructeur MatchText : ce champ n’existe pas dans ce widget et avait été ajouté par erreur lors de la modification de MappedText.
- MappedText conserve son champ precise ; matchRanges détecte toujours le mode adapté à la requête. Aucun changement fonctionnel, de schéma ou de données.
- Occurrences precise relues, contrôles Python exécutés. Flutter absent ici ; analyse et tests Flutter à relancer sur le poste utilisateur.

### 1.4.5 — données cohérentes dans les tests
- Retour utilisateur : analyze sans erreur, 26 tests réussis, deux échecs d’attente.
- Sélecteurs : recherche vocalisée vérifiée comme absente pour le libellé non vocalisé, puis saisie simple et sélection vérifiées. La règle adaptative reste inchangée.
- Carte : le StudyController de préparation, le sidecar et le texte attendu utilisent tous le body vocalisé de la même note. Vérification du gras et du bandeau conservée.
- Aucun changement métier, de schéma ou de données. Contrôles locaux réussis ; Flutter absent ici, suite Flutter à relancer sur le poste utilisateur.

### 1.5.0 — thèmes et suppressions, styles des noms
- saveTheme réutilise le catalogue title existant. deleteTheme vérifie sous transaction qu’aucune note ne correspond à l’identité normalisée du thème avant de supprimer le catalogue.
- deleteAuthor : transaction de détachement des notes (author vide, author_id NULL), retrait du catalogue auteur et du profil. Les autres champs des notes ne changent pas. Brouillons associés nettoyés si nécessaire.
- confirmDeletion commun : Alerte/Continuer puis Confirmation/Supprimer, annulation possible à chaque étape ; utilisé pour toutes les suppressions UI, y compris le retrait d’une photo du formulaire.
- emphasizeNames analyse le texte complet et applique un style d’affichage rouge/gras pour الله et bleu/gras pour محمد. Reconnaissance des harakat/tatweel/ﷲ et préfixes usuels ; parcours des spans déjà formatés, aucun caractère ajouté ou remplacé.
- SacredText/SacredSelectableText/SacredController communs dans les affichages et champs. StudyController applique les mêmes styles sur ses spans, sans les écrire dans le sidecar JSON. Surlignage des recherches toujours géométrique.
- Nouveaux fichiers : widgets/sacred_text.dart, widgets/delete_confirmation.dart, tools/check_deletions.py. Schéma v4 inchangé, aucune dépendance/permission nouvelle.
- Contrôles SQL : suppression auteur préserve notes/identifiants/dates/épingles/styles, autre auteur intact ; thème non vide refusé. Tests Flutter ajoutés pour étapes de confirmation, création de thème et graphie arabe inchangée.
- Contrôles Python réussis. Flutter/SDK Android absents, analyze/test/build non exécutés ici ; relance complète requise pour le code natif.

### 1.5.1 — rendu simple sans span supplémentaire
- Retour utilisateur : analyze sans erreur, 30 tests réussis, un échec sur un parent TextSpan supplémentaire.
- SacredText utilise Text simple pour une chaîne non enrichie si emphasizeNames renvoie la source inchangée. SacredSelectableText utilise dans ce cas SelectableText simple, préservant également sa propriété data.
- Text.rich/SelectableText.rich réservés aux noms colorés et contenus déjà enrichis. Aucun changement des recherches, couleurs ou données.
- Test de géométrie arabe maintenu sans assouplissement. Contrôles locaux réussis ; Flutter absent ici, analyse et tests Flutter à relancer sur le poste utilisateur.

### 1.6.0 — thèmes modifiables et accès par appui long
- renameTheme sous transaction : vérifie l’ancien catalogue et l’unicité de la nouvelle identité, actualise les titres des notes correspondantes, remplace le libellé du catalogue. Les autres champs ne changent pas. Mise à jour du brouillon correspondant côté Flutter.
- Thèmes : menu explicite et onLongPress, Modifier toujours disponible, Supprimer seulement à zéro note. Double confirmation conservée ; vérification native de vacuité inchangée.
- Notes : onLongPress appelle showButtonMenu sur le même PopupMenuButton, y compris dans ThemeNotesPage. Auteurs : menu et appui long Modifier/Supprimer ; traitement de suppression partagé avec la fiche.
- Dictionnaire : appui long pour Ouvrir/Étudier dans une note. Clic court inchangé.
- Retour depuis une sous-page Thème : rechargement des compteurs et menus. Schéma v4 inchangé.
- Contrôles ajoutés : tools/check_theme_rename.py (SQL réel UPDATE, contenu/dates/styles préservés, casse/espaces et doublons refusés), test widget appui long et renommage. Contrôles Python réussis ; Flutter/SDK Android absents, tests/analyse/build à lancer sur le poste utilisateur.

### 2.0.0 — Coran, Hisn, prières, compteur et notifications
- Hub accessible dans le header fixe ; les quatre onglets existants sont conservés.
- Coran local Hafs/Warsh avec leurs polices, recherches adaptatives et références numériques.
- SQL Hisn fourni importé en 132 chapitres/267 entrées, conservation de 90 blocs originaux.
- Compteurs et chaînes modifiables, progression persistante ; rappels hebdomadaires
  configurables par horloge, ouverture du compteur depuis la notification.
- AlarmManager natif, notifications Android, replanification au redémarrage et
  changement de fuseau ; annulation des rappels lors de suppression de leur cible.
- Horaires HTTPS AlAdhan, cache courant + mois suivant, réglages et corrections.
  Azan audio importé par l’utilisateur, service foreground mediaPlayback et arrêt.
- Permissions ajoutées : INTERNET, POST_NOTIFICATIONS, SCHEDULE_EXACT_ALARM,
  RECEIVE_BOOT_COMPLETED, FOREGROUND_SERVICE, FOREGROUND_SERVICE_MEDIA_PLAYBACK, WAKE_LOCK.
- notes.db reste v4, aucune table ni donnée utilisateur remplacée. Préférences
  devotion/azan/reminders séparées et ajoutées sans clear global.
- Validation : contrôles Python des données et migrations, syntaxe Dart ; compilation
  Kotlin 2.2.20, Java 17, API 36 réussie ; test JVM du calendrier réussi.
  Flutter analyze/test et APK non exécutés : démarrage Flutter rejeté par le contrôle
  automatique après tentative de contact avec une adresse de métadonnées cloud.

### 2.0.1 — références sous les invocations et vocabulaire
- Association des notes par appel dans chaque segment source : les numéros de
  référence se répètent au fil du livre et ne sont pas traités comme des IDs globaux.
- Références séparées du corps et affichées dessous, taille 13 et couleur disabledColor.
- Contrôle des 267 entrées, 300 références liées, aucune altération des 90 blocs originaux.
- Chapelet et Azkar / Azkar / Wird (chaîne de zikr), traductions adaptées.
- Clés de persistance inchangées, notamment chains : aucun impact sur les wirds existants.
- Contrôle des données réussi ; Dart/Flutter indisponibles dans cette session.
  Aucun nouveau résultat analyze/test revendiqué.

### 2.1.0 — audio intégré, horloge, localisation et recherche
- Profil auteur : champ et affichage Vivant retirés ; colonne historique conservée,
  sans migration destructive. Nom/photo/biographie restent disponibles.
- Huit adhans fournis, AAC mono 24 kHz 32 kbit/s, durée complète ; environ 6,7 Mo.
  Sons Android assets/audio/, catalogue natif et choix d’un fichier personnel.
- Signal Kenney Digital Audio CC0 intégré pour les rappels ; lecture en service
  foreground, volume ALARM, répétition au maximum 30 s, action Arrêter.
- Vérification notifications, alarmes exactes et exemption batterie avant activation.
  Réglages Android accessibles ; test différé 10 s sans remplacer les rappels.
- Cadran analogique animé, heure locale, date/fuseau, réglages regroupés,
  choix audio et interrupteur de chaque prière. Asr hanafite reste un réglage de calcul.
- Position ponctuelle via LocationManager, permissions uniquement à la demande.
  Adresse via Geocoder et reverse Nominatim explicite, attribution OpenStreetMap.
  Pas de suivi en arrière-plan, saisie manuelle possible, adresse selon couverture.
- Compteur de résultats dans l’aide sous les recherches ; total dictionnaire natif
  avant pagination et après affinement précis FTS, filtres identiques aux résultats.
- Aperçus Coran : véritable extrait sans troncature de mise en page, indices de
  surlignage calculés sur l’extrait effectivement affiché.
- Hisn : réunification des retours de scraping dans ((…)), en conservant une
  rupture après point ; références toujours séparées, source originale intacte.
- Wird : étapes autonomes text/max ; choix d’un zikr pour préremplir les champs.
  Anciennes étapes itemId encore lues ; aucune réinitialisation de progression.
- Vérifications : scripts Python et audio/durées, syntaxe Dart ; Kotlin natif
  compilé avec API 36, Kotlin 2.2.20 et interfaces Flutter simulées, test JVM du
  calendrier. Ceci ne constitue ni flutter analyze/test ni une compilation APK.
  Validation audio/permissions/écran verrouillé à effectuer sur le TECNO KL4.
- Ajouts : AlarmSupport.kt, lib/devotion/alarm_controls.dart, prayer_clock.dart,
  assets Android audio, source/audio, outils check_audio.py/prepare_audio.py.

### 2.1.1 — sections actualisables et catalogue de rappels
- Section Wird placée avant Azkar.
- Surlignage dans les sourates : sélection de SacredSelectableText (plain/rich)
  explicitement BoxWidthStyle.tight et BoxHeightStyle.tight. Le défaut natif
  EditableText BoxWidthStyle.max prolongeait les boîtes au-delà du texte sélectionné.
  Aucun changement de texte/ligatures. Test de régression ajouté pour le lecteur.

- Signatures des paramètres de calcul par section location/method/adjustments.
  Aucun déclenchement de bouton pour un simple choix audio ; reversion de valeur
  reconnue. Les signatures appliquées sont enregistrées dans prayerBundle et
  adoptées pour les anciens caches fiables ; cache incertain => actualisation requise.
- Boutons Actualiser dans les trois sections, désactivés sans modification ou
  pendant une opération ; état conservé si le téléchargement échoue.
- Suppression des commandes répétées autour du cadran, ligne Localisation /
  Actualiser ; carte audio/activation en bas, libellé Choisir un Azan.
- TimeZone.getDefault().id via localTimezone ; relecture initiale, au retour de
  l’app et toutes les minutes ; date/heure locales via DateTime.
- Cinq clips CC0 (oiseaux, eau, vagues, carillon, alarme), total 100 307 octets,
  maximum 8 s, catalogue reminders.json, labels fr/ar/en et aperçu.
  Ancien signal et identifiants des fichiers personnels conservés.
- Nouveau outil prepare_reminder_sounds.py facultatif ; téléchargement uniquement
  pendant la préparation des assets, aucun téléchargement de sons dans l’application.
- Test ajouté sur les signatures des trois sections. Contrôles audio/données et
  syntaxe Dart ; pas d’exécution Flutter/analyze ni de compilation APK ici.
- Schéma notes v4 inchangé. Préférences enrichies sans clear ni suppression.

### 2.1.2 — infos des ouvrages et soutien
- HisnSource affiche frontMatter : introduction et فضل الذكر uniquement, avec
  leurs références. L’import récupère la continuation avant le chapitre 1.
- Suppression de sourceBlocks dans l’asset JSON pour éviter une copie intégrale
  inutile ; source SQL intégrale inchangée dans l’archive, 267 entrées conservées.
- SourcesSection remplace l’ancien bouton d’introduction dans About ; cinq
  références ouvrent des sous-pages adaptées, chargées à la demande.
- DonationsSection sous les coordonnées développeur. PayPal exact du DEV ENV ;
  Wave/OM : coordonnées non fournies, accès au contact TDG explicitement indiqué.
- Canal openExternal : HTTPS ou tel uniquement, ACTION_VIEW / ACTION_DIAL ;
  pas de permission CALL_PHONE ni de nouvelle dépendance.
- Localisation fr/ar/en des nouveaux libellés. Taille de lecture dans les sources.
- Nouveaux fichiers sources.dart, audio_sources.json, sources_test.dart.
- Version 2.2.1+35 ; notes.db reste v4, aucun effacement ni migration destructive.
- Contrôles d’intégrité, données et syntaxe ; tests Flutter non exécutés ici.

### 2.1.3 — Espace spirituel dans Cultes
- Cinquième destination Cultes, après Dictionnaire ; retrait de l’icône du header.
- Hub intégré au corps de Home, sans Scaffold/AppBar imbriqué ; les quatre
  fonctionnalités continuent à ouvrir leurs sous-pages avec retour vers Cultes.
- Ordre fixe en arabe ; labels fr/ar/en et taille adaptée aux petits écrans.
- Test de navigation existant actualisé : ordre des cinq destinations, sélection
  de Cultes, présence des cartes et absence de second header.
- notes.db v4 et toutes les préférences inchangées ; aucun changement Android.
- Vérifications : syntaxe Dart et contrôles locaux. Tests Flutter non exécutés ici.

### 2.1.4 — distinction onglet / page
- Onglet : Cultes ; titre du hub : Espace spirituel, avec traductions existantes.
- Libellés de navigation, routes et données inchangés.
- Contrôle syntaxique Dart ; tests Flutter non exécutés ici.

### 2.1.5 — ordre de navigation
- Auteurs / Thèmes / Notes / Dictionnaire / Cultes ; mapping des indices actualisé.
- Notes reste la sélection initiale. Titre Espace spirituel conservé.
- Attente du test de navigation actualisée. Syntaxe vérifiée, tests Flutter non exécutés.
- Données et préférences inchangées.

### 2.1.6 — azans dans le sélecteur des alarmes
- Champ et modal : Choisir un son d’alarme, avec traductions fr/ar/en.
- Catalogue fusionné en mode rappel : six sons + huit azans, deux sections,
  écoute, choix et import personnel conservés. Pas de duplication des fichiers audio.
- Nom de l’azan restauré depuis le catalogue ; identifiants audio persistants inchangés.
- Limite de sonnerie des rappels à 30 s maintenue, horaires de prière inchangés.
- Syntaxe Dart vérifiée ; tests Flutter non exécutés ici. Aucun changement de base.

### 2.2.0 — hadiths, icônes de configuration et nom d’azan
- Import SQL Bukhari (7105) / Muslim (5527) en assets JSON, ids de lignes stables,
  numéros source et variantes conservés ; un numéro Muslim absent non inventé.
- Page HadithPage : choix de livre persistant, compute pour le décodage/index,
  pagination 40, recherche adaptative et numérique, lecture/copier/références grises.
- Carte sous Coran dans Espace spirituel ; référence ajoutée aux infos de l’app.
- Réglages de prières dans quatre modals déclenchés par icônes autour du cadran.
  Suppression des dépliants, Form uniquement dans le modal, synchronisation des
  changements et opérations asynchrones entre page et modal ; validation conservée.
- Test différé et activation d’azan maintenus sous les horaires.
- Fichier/label Serigne Mbacké Fall renommés ; alias natif et affichage acceptent
  l’ancien id asset:audio/adhan_2.m4a. Nettoyage optionnel du doublon de projet
  uniquement après comparaison SHA-256 ; aucun fichier utilisateur touché.
- Assets audio non réencodés ; identifiants des notes, rappels et compteurs conservés.
- Nouveaux fichiers hadith.dart, test/hadith_test.dart, tools/import_hadith.py,
  check_hadith.py, cleanup_legacy_adhan.py, source/hadith/ et deux assets JSON.
- Schéma notes v4 inchangé ; seule une préférence hadithBook est ajoutée.
- Vérifications Python et syntaxe Dart ; tests Flutter et compilation APK non exécutés ici.

### 2.2.1 — brouillons de réglages, avances et synchronisation automatique
- appliedOptions indépendant des contrôleurs de saisie ; fermeture du modal =>
  restauration, champs vides restaurés, validation avant Appliquer. Aucun calcul
  d’heure principale ni événement natif à partir d’un brouillon non confirmé.
- Ajustement des prières sur cache et aperçus ; avances d’azan séparées, défauts
  Fajr 45 / Dhuhr 15 / Asr 15 / Maghrib 0 / Isha 15 minutes avant l’heure ajustée.
- prayerBundle ajoute syncedAt, adhanWanted, azanLeads sans clear ni migration SQL.
  Choix activé/désactivé conservé indépendamment de l’état effectif et repris avec
  les horaires disponibles ; dernier cache/localisation toujours utilisables.
- Dernière synchronisation et date de cache de secours affichées ; une modification
  locale d’ajustement ne falsifie pas l’horodatage d’une synchronisation réseau.
- PrayerSyncWorker (WorkManager 2.9.1 du DEV ENV), tâche avant expiration et
  contrôle périodique 12 h, réseau connecté et réessais exponentiels. Téléchargement
  des mois courant/suivant avec réglages appliqués, validation puis commit atomique.
- Classe du Worker conservée par R8 pour les tâches persistantes entre mises à jour.
- Protection contre cache plus récent et choix modifiés pendant un téléchargement ;
  azanSchedule peut dériver ses événements du cache natif validé. Calendrier ISO,
  ajustements et chiffres arabes cohérents entre Dart et Kotlin.
- Replanification depuis le cache au lancement/redémarrage et après mise à jour des
  données. Séparation de lecture adhan / rappel / aperçu pour les arrêts de service.
- Ajout permission normale ACCESS_NETWORK_STATE ; pas de GPS en arrière-plan.
- Schéma notes.db v4 inchangé. Versions Gradle/AGP/Kotlin/Java/SDK inchangées.
- Nouveaux fichiers prayer_settings.dart, PrayerSyncWorker.kt, tests des brouillons,
  de l’activation/cache, PrayerSyncDataCheck.kt et prayer_settings_check.dart.
- Contrôles locaux, calculs et compilation Kotlin isolée exécutés ; Flutter/tests/APK
  non exécutés ici, essais Android nécessaires pour réseau coupé/reprise et alarmes.

## 4. Fichiers de cette mise à jour
Archive cumulative depuis 1.0.1 : **Diraasa_MAJ_2.2.1.tar.gz**.
- lib/ complet, dont lib/devotion/ et les modifications de navigation/rendu.
- Sources Kotlin de MainActivity, NotesDatabase, DevotionNative, AzanAlarms,
  AzanService et ZikrReminders ; manifestes main/debug/profile.
- assets/devotion/ : données importées ; assets/fonts/ : polices fournies.
- source/devotion/ : SQL originaux, rapports et documentation de provenance.
- pubspec.yaml, test/ et outils de validation/import modifiés.
- README.md, FICHE_TECHNIQUE.md et MANIFEST_MAJ_2.2.1.txt.
Aucune base utilisateur n’est incluse. Les nouvelles données sont des assets distincts.

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
- check_migrations.py : SQL réel du helper sur données historiques v0/v1/v2/v3/v4 ;
  comparaison de toutes les valeurs avant/après, index idempotent, insertion.
- check_kotlin_escapes.py : échappements des sources Kotlin.
- check_data.py : intégrité et recherche dans le dictionnaire inchangé.

Tests Flutter ajoutés : localisation, préférences, saisie successive,
surlignage, filtres, sticky au défilement, RTL/LTR, focus et clavier simulé
sur écran 360×640 dans les deux onglets, filtres Titre/Auteur, notes/article/formulaire.
Pour 2.0.0, la syntaxe Dart et la compilation Kotlin isolée ont été contrôlées.
Flutter analyze, les tests Flutter et la compilation/exécution Android complète
restent à lancer sur le poste de développement (blocage automatique décrit ci-dessus).
Le test SQL ne remplace pas un essai de mise à jour sur appareil.

## 6. Procédure pour les prochaines évolutions
1. Garder com.tdg.diraasa, notes.db et la signature existante.
2. Écrire une migration additive si le schéma change ; incrémenter sa version.
3. Vérifier un jeu de notes existantes, IDs, dates, auteurs et épinglage inclus.
4. Mettre à jour cette fiche, la version et les tests concernés.
5. Livrer au minimum lib/ complet + tous les autres fichiers modifiés,
   aux mêmes chemins relatifs, dans une archive de mise à jour.

## 2.2.2+36 — 27 octobre 2026

- Aperçus des ajustements de prière et des avances d’azan directement abonnés au contrôleur de saisie via ValueListenableBuilder : leur actualisation ne dépend plus du rafraîchissement du modal.
- Horaires principaux et programmation restent liés aux valeurs appliquées ; aucune modification de la base de données.
- Flutter indisponible dans cet environnement : analyse, tests widgets et APK à exécuter sur le poste de développement.

## 2.2.3+37 — 27 octobre 2026

- Diagnostic corrigé : l’échec signalé à la ligne 160 concerne l’application du brouillon, pas son aperçu. Le test cliquait sur Appliquer avant la reconstruction activant le bouton après saisie.
- Ajout d’un pump avant clic, assertion du callback actif et vérification de la valeur persistée (Dhuhr : 20 minutes). Aucune attente arbitraire, aucun assouplissement des résultats attendus.
- Aucun changement de données ou de logique de programmation. Tests Flutter non exécutés ici.

## 2.2.4+38 — 27 octobre 2026

- Correction du cycle de vie des modals Prières : un rebuild pendant l’animation de sortie pouvait réenregistrer le callback après le nettoyage et bloquer la prochaine ouverture.
- Verrou d’ouverture explicite, désactivé au retour de la route ; les rebuilds de sortie ne réenregistrent plus les callbacks.
- Test : vérification explicite de la présence du champ après réouverture. Aucune modification de la base.
- Tests Flutter et APK non exécutés ici.

## 2.2.5+39 — 28 octobre 2026

- Deux choix audio persistants : azan général et azan du Fajr (Ali Ibn Ahmed Mala, adhan_5.m4a). Ce dernier est exclu du catalogue général et réservé au catalogue Fajr ; les imports personnels restent disponibles. Les rappels gardent accès à tous les sons.
- Sélection effective par prière dans les alarmes Android, y compris après redémarrage et renouvellement WorkManager ; choix Fajr ajouté aux préférences sans effacement. Ancien choix général adhan_5 reclassé et remplacé par adhan_1 pour les autres prières.
- Préécoute : bouton lecture/pause avec reprise au même endroit, état lu depuis le service, retour lecture en fin de fichier. Fermeture du sélecteur arrête seulement la préécoute. Suppression du bouton Arrêter en bas de liste et des contrôles redondants du modal Azan.
- Sous-titres discrets Thèmes et Auteurs, traduits FR/AR/EN.
- Test widget ajouté pour séparation des listes et lecture/pause ; non exécuté ici (Flutter indisponible). Contrôle des échappements Kotlin réussi. Compilation Android et tests Flutter à exécuter sur le poste de développement.

## 2.3.0+40 — 28 octobre 2026

- Nouvelle page Sauvegarde et Restauration depuis une icône adjacente à Langue. Sauvegarde locale via le sélecteur Android, sans permission de stockage globale ; format ZIP portable versionné, JSON Unicode, pièces jointes et SHA-256.
- Données : notes/styles/épingles/dates, auteurs/photos, références/thèmes, azkar/wird/compteurs/rappels, préférences, coordonnées/cache prière et sons personnels utilisés. Pas de textes intégrés, de jetons Google ni d’autorisations Android exportés. Les chemins privés de médias sont rétablis sur l’appareil cible sans réécrire les contenus textuels.
- Restauration explicite de remplacement après avertissement puis résumé et confirmation. Validation avant modification, copie de sécurité privée accessible dans l’écran, transaction SQLite et journal de finalisation des préférences pour reprise après interruption. Migrations v4 conservées, ajout non destructif de la table technique backup_restore_journal, aucun remplacement automatique de notes.db à la mise à jour.
- Drive : Firebase Authentication Google + Credential Manager ; AuthorizationClient distinct avec scope drive.file. Session persistante gérée par SDK, jeton d’accès redemandé lors de chaque action. Dossier visible Diraasa — Sauvegardes, liste paginée, import/export et lien d’ouverture avec le compte connecté. Envoi par session resumable ; reprise d’un transfert interrompu entre deux lancements non implémentée (relancer manuellement).
- Drive exige le propre google-services.json du développeur et l’activation Google/Firebase + Drive API. Plugin Google Services 4.5.0 conditionnel, Firebase BoM 34.15.0 conservée du DEV ENV, firebase-auth seulement. Nouvelles dépendances : credentials/credentials-play-services-auth 1.3.0, googleid 1.1.1, play-services-auth 22.0.0. SDK minimal 24 pour l’authentification ; SDK36/Java17/Kotlin2.2.20/AGP8.11.1/Gradle8.14.1 conservés.
- Déconnexion et suppression du compte Firebase depuis la page (la suppression ne retire pas les fichiers exportés que l’utilisateur possède dans Drive). Politique de confidentialité intégrée FR/AR/EN, lien bouclier en bas des pages sauvegarde et infos, exports HTML/Markdown et page de demande de suppression prêts à héberger.
- Téléphone en ACTION_DIAL, e-mail en ACTION_SENDTO mailto ; aucune permission d’appel direct. Wave : lien marchand fourni sous libellé ; Orange Money retiré. Version Infos actualisée.
- Tests : compilation Kotlin isolée contre Android API36 et bibliothèques réelles (interfaces Flutter substituées), contrôles JVM ZIP/schéma/chemins médias et prière/rappels réussis ; scripts Python de données, migrations, recherche et audio réussis ; syntaxe Dart vérifiée. Tests widgets ajoutés pour confirmations/import, sauvegarde locale, confidentialité et don Wave. Flutter analyze/test et build APK non exécutés ici ; connexion/consentement/Drive réels à valider avec configuration propre sur téléphone.
- Guide détaillé SIGNATURE_FIREBASE_DRIVE.md inclus : clés existantes, SHA-1/SHA-256, debug/release/Play, Firebase, OAuth, Drive API, installation et validation.
