# Diraasa · دراسة — 2.2.1+35
Carnet d’études arabes et dictionnaire مختار الصحاح, Android, hors ligne.
Package : **com.tdg.diraasa**.

## Installer la mise à jour
L’archive Diraasa_MAJ_2.2.1.tar.gz contient **lib/ complet** et les autres fichiers
nécessaires, aux chemins de la racine du projet existant.
Arrêter flutter run, extraire à côté de pubspec.yaml, puis :
```bash
python3 tools/cleanup_legacy_adhan.py
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
- Après une sauvegarde réussie, seul le contenu est vidé. Thème, auteur et
  catégorie sont conservés pour la prochaine note et mémorisés entre sessions.
  Le formulaire reste ouvert ; la sauvegarde suivante crée une nouvelle note.
  Une modification sauvegardée passe également en nouvelle saisie, sans risquer
  de réécraser la note précédente. Une erreur ne vide aucun champ.
- Recherche + deux rangées de filtres dans un en-tête sticky : se fixent en haut
  lors du défilement, ou immédiatement au focus. L’accroche ne revient pas
  automatiquement à la perte du focus. Un retour en haut par défilement permet
  toutefois de la révéler et de faire redescendre la recherche.
- Notes : filtres catégorie + Tous les champs/Thème/Auteur/Contenu ; recherche adaptative selon la saisie.
- Dictionnaire : préfixe/mot/racine, contient, texte intégral FTS, lettre,
  pagination de 60. Les racines normalisent aussi les variantes d’alif.
- Correspondances surlignées en jaune clair en mode clair et en ocre en sombre.
  L’arabe vocalisé original reste intact. Aperçu recentré sur la correspondance.
  Des témoins des termes FTS sont visibles même si le passage est loin dans
  l’article ; la lecture complète conserve aussi le surlignage.
- Taille de lecture persistante pour pages/modals de visualisation et le seul
  champ Contenu du formulaire. Le picker réagit indépendamment de son parent.
  Cartes fixes : notes thème 14 px / contenu 19 px, dictionnaire 24/18 px ; auteurs et autres
  éléments d’interface gardent une taille normale. Accessibilité système respectée.
- Français, العربية et English ; sélecteur en haut à côté du thème.
- Premier lancement : langue principale du système parmi fr/ar/en, sinon fr.
  Le choix manuel est ensuite mémorisé. Contenu RTL en arabe ; header et ordre des onglets gardent leur disposition ;
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
Le manifeste principal autorise désormais HTTPS pour télécharger les horaires AlAdhan.
Les lectures Coran/Hisn, notes et compteurs restent locales.

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


## Mise à jour 1.1.4 — typographie et retour de l’accroche
Le réglage de taille mémorisé ne redimensionne plus les cartes ni le formulaire.
Il reste appliqué aux modals de notes, aux articles et aux pages de lecture.
La valeur enregistrée n’est ni effacée ni modifiée par ce changement.

L’accroche reste dans le flux de défilement. Au focus, on défile jusqu’à la
recherche, sans supprimer l’accroche. En revenant en haut / tirant vers le bas,
l’accroche se révèle et la recherche descend naturellement. En repartant vers
le bas de la liste, la recherche et ses filtres se fixent de nouveau sous l’AppBar.
La perte du focus ne déclenche aucun retour automatique. Les listes courtes
ou vides reçoivent uniquement l’espace de défilement minimum nécessaire.


## Mise à jour 1.2.0 — arabe lié, focus, taille et types
- Surlignage peint derrière le paragraphe réellement rendu, sans découpage de
  spans ni changement de gras. Texte original, liaison arabe et copie préservés.
- Le picker de lecture écoute directement les préférences : curseur, valeur et
  texte réagissent pendant le déplacement. La valeur est mémorisée à la fin.
- La taille s’applique aux lecteurs/modals et au champ Contenu du formulaire,
  pas aux cartes ni aux champs Titre/Auteur.
- Un geste vertical prend la priorité sur le focus : ferme le clavier et annule
  tout repositionnement automatique différé. Retour manuel en haut disponible.
- Étirement vers le bas depuis le vrai haut de Notes : relit les notes sans
  modifier la recherche, les filtres ou les données. Pas de refresh du dictionnaire.
- Types : Cours, Vocabulaire, Notion, Définition, Grammaire, Conjugaison, Règle,
  Exemple, Exercice, Résumé, Vers, Citation, Autre. Libellés fr/ar/en.
  Les anciens identifiants sont conservés ; aucun remplacement des types existants.
- Aucun changement de schéma SQLite (version 2), aucune base dans le correctif.
- Tests supplémentaires : géométrie de texte arabe avant/après surlignage,
  source sélectionnable intacte, mouvement du slider constant, retour après
  focus sans unfocus manuel, rafraîchissement et persistance des nouveaux types.
- Contrôles SQL locaux exécutés ; tests Flutter et rendu Android à valider sur
  votre poste, faute de SDK Flutter dans cet environnement.


## Correctif 1.2.1 — trois tests restants
L’ancrage de la recherche est conservé lors de la fermeture du clavier ;
un défilement volontaire annule cet ancrage et permet de révéler l’accroche.
Les tests mesurent le bloc sticky visible, pas le texte masqué d’un sliver.
La page d’article fournit un bouton Retour explicite ; le test utilise sa clé
et contrôle le retour effectif à la liste.
Aucun changement de note, préférence, type ou taille enregistrée.

## Correctif 1.2.2 — Infos et header
Les sélecteurs Langue et Apparence sont alignés sur leur libellé, à droite dans Infos. Le header principal conserve sa disposition lors du passage en arabe ; le contenu arabe reste RTL. Notes et préférences conservées.

## Évolution 1.3.0 — Notes et réutilisation
Le contenu est prioritaire dans les cartes Notes ; le titre reste discret. Les auteurs ont un badge de couleur stable, et le type une petite étiquette sous l’auteur.

Les boutons à côté de Titre et Auteur ouvrent leurs listes avec recherche. Après un enregistrement réussi, les nouvelles valeurs sont disponibles dans ces listes. Casse et espaces ne créent pas de doublons ; les titres et auteurs ont des catalogues distincts. Les entrées restent réutilisables après suppression d’une note.

La migration additive notes.db v3 récupère les titres et auteurs des notes déjà présentes sans réécrire celles-ci. Garder l’identifiant com.tdg.diraasa et la même signature ; ne pas désinstaller ni effacer les données.

## Correctif 1.3.1 — test des sélecteurs
Le test défile pour construire les champs hors écran avant de cliquer sur leurs sélecteurs. Les assertions restent actives ; aucune modification des notes, catalogues ou préférences.

## Évolution 1.4.0 — Auteurs, Thèmes et texte mis en forme
- Navigation, de gauche à droite : Auteurs, Notes, Dictionnaire, Thèmes. Notes reste l’onglet ouvert au lancement.
- Auteurs : recherche, fiche de consultation, ajout et modification du profil. Nom complet unique (casse/espaces normalisés), photo facultative, naissance/décès saisis librement comme date ou année, statut vivant, biographie facultative.
- Enregistrer une note avec un nouveau nom crée son profil. Les profils ajoutés depuis Auteurs sont immédiatement proposés dans le sélecteur de Notes. Les profils existants sont récupérés depuis les anciens noms d’auteurs.
- Le lien auteur/notes repose sur un identifiant stable : renommer le profil actualise le nom dans ses notes. La photo apparaît à la place de l’icône dans les cartes associées ; repli sur l’icône si le fichier n’est pas disponible.
- Photo choisie par le sélecteur de documents Android et copiée dans le stockage privé, sans nouvelle permission ni dépendance Flutter. Les fichiers non utilisés ne sont pas purgés automatiquement.
- Titre devient Thème dans l’interface ; la clé technique title est conservée pour la compatibilité. Les thèmes sont tronqués sur une ligne dans les cartes. Livre est ajouté avant Cours.
- Thèmes : recherche, nombre de notes et navigation vers les notes du thème, puis vers leur lecture. Le regroupement ignore casse et espaces multiples. Les filtres de notes se combinent ensuite à ce thème.
- Éditeurs Notes/Biographie : gras, italique, souligné, titre de paragraphe, listes à puces, collage formaté via bouton ou menu contextuel. Sélectionnez du texte pour le mettre en forme ; sans sélection, le style vise le paragraphe courant. Le contenu mis en forme est affiché dans les lecteurs ; les aperçus de cartes restent sobres.
- Le collage importe les styles essentiels fournis par le presse-papiers Android (HTML ou texte Spanned). Une source ne fournissant que du texte brut ne permet pas de récupérer sa mise en forme ; tableaux, images et polices personnalisées ne sont pas importés. Pour garantir l’import, utilisez le bouton Coller de l’éditeur ou son menu contextuel.
- Texte brut conservé pour recherche/copie, styles enregistrés séparément. Les surlignages sont peints sur la géométrie réelle et ne découpent pas le texte arabe. Pas de format propriétaire dans le contenu des notes.
- Migration additive notes.db v4 : table authors, index notes_author, colonnes author_id et body_format. Les colonnes historiques ne sont ni supprimées ni réécrites pendant la migration. Notes sans auteur inchangées ; catalogue des thèmes et préférences conservés.

Décompresser l’archive à la racine du projet, puis arrêter l’exécution précédente et relancer :
```bash
flutter pub get && flutter analyze && flutter test && flutter run
```
Le code Android ayant changé, un hot reload ne suffit pas. Conserver la même signature et com.tdg.diraasa, sans désinstallation ni effacement des données.

Contrôles SQL/Python exécutés ici ; tests Flutter ajoutés pour navigation, profils, formatage, sélection et collage. Flutter/SDK Android absents de cet environnement : analyze, tests Flutter, compilation Android et essai du sélecteur photo/collage réel restent à exécuter sur le poste de développement.

## Évolution 1.4.1 — navigation Thèmes et cartes formatées
- Ordre fixe : Notes | Thèmes | Auteurs | Dictionnaire.
- Un thème ouvre ThemeNotesPage, une sous-page dédiée sans barre d’onglets. Lecture en modal, modification, épinglage et suppression se font depuis cette sous-page. Retour vers Thèmes, sans bascule vers Notes.
- Cartes partagées entre Notes et sous-page Thème : styles gras/italique/souligné/titres/citation visibles dans le contenu, taille d’aperçu fixe, aperçu de recherche recentré en conservant les styles. Surlignage géométrique sans découpage supplémentaire des mots arabes.
- Type en bandeau oblique miniature au coin supérieur gauche, palette fixe distincte pour les 14 types ; thème sur une ligne. Les commandes restent en haut à droite.
- Citation (double guillemet) dans les deux éditeurs : style citation, italique et encadré avec icône de guillemets dans les affichages, sans ajout de caractères au contenu. Sélectionnez le passage ou placez le curseur dans le paragraphe, puis utilisez Citation. Le même bouton désactive ce style.
- Dates de naissance/décès retirées du formulaire et de l’affichage des profils. Les valeurs historiques restent en base et sont préservées lors d’une modification. Le statut vivant/décédé reste disponible.
- Schéma v4 inchangé : aucun effacement, aucune migration supplémentaire nécessaire. Après extraction, relancer complètement l’application (import de citation native mis à jour).

Contrôles locaux Python réussis. Tests Flutter ajoutés/adaptés pour vérifier ordre des onglets, sous-page Thèmes, retour après lecture, rendu formaté et citation. Flutter et SDK Android absents ici : analyse, tests et compilation à exécuter sur le poste de développement.

## Correctif 1.4.2 — recherche adaptative
- Sans harakat ni majuscules : recherche normalisée, insensible à la casse, aux harakat et au tatweel ; ا/أ/إ/آ/ٱ sont équivalents, ainsi que ى/ي. Une hamza seule ne déclenche pas le mode précis.
- Avec au moins un haraka ou une majuscule : recherche littérale sur la graphie originale, sensible à la casse et aux signes saisis. Exemple : علم trouve عِلْم et عَلَم ; عِلْم exige cette suite de lettres/signes. cours ignore la casse ; Cours la respecte.
- Cette règle concerne Notes, Dictionnaire, leurs extraits, surlignages et témoins FTS. Depuis 1.4.3, les sélecteurs et pages Auteurs/Thèmes appliquent également la recherche adaptative ; leur déduplication reste inchangée.
- Les modes Préfixe/Contient/Texte intégral conservent leur fonction : « précis » signifie caractères exacts, pas égalité obligatoire avec tout le texte. En texte intégral, les termes restent des préfixes de mots combinés avec ET.
- Dictionnaire : candidats via index existants, raffinement sur les champs originaux. En FTS précis, raffinement avant pagination pour ne pas masquer de résultats entre les pages. Aucun changement du fichier du livre ou du schéma notes.db v4.
- Correction du test : conversion InlineSpan vers TextSpan avant lecture de children.
- Contrôles SQL et Python réussis, nouveaux cas de recherche ajoutés aux tests Flutter. Flutter/SDK Android absents ici : analyse, tests Flutter et compilation restent à exécuter sur le poste utilisateur. Relance complète nécessaire pour le changement Kotlin.

## Correctif 1.4.3 — règle commune à toutes les recherches
La recherche adaptative s’applique aussi aux listes Auteurs/Thèmes et aux sélecteurs de Thèmes/Auteurs. Saisie sans harakat ni majuscules : tolérante ; avec harakat ou majuscules : précise. La comparaison pour éviter les doublons reste insensible à la casse et aux espaces multiples. Données et schéma v4 inchangés.

## Correctif 1.4.4 — constructeur MatchText
Suppression du paramètre initialisant inexistant precise dans MatchText. La précision reste détectée par matchRanges à partir de la saisie. Règles de recherche, données et schéma inchangés.

## Correctif 1.4.5 — cohérence des données de tests
Le test des sélecteurs vérifie désormais qu’une requête vocalisée ne trouve pas une entrée non vocalisée, puis qu’une requête simple la trouve. Le test des cartes crée les styles et vérifie le rendu sur le même contenu vocalisé que la note. Assertions conservées ; aucune modification du comportement de recherche ou des données.

## Évolution 1.5.0 — thèmes, suppression et noms mis en valeur
- Ajouter un thème depuis l’onglet Thèmes, même sans note. Les variantes de casse/espaces réutilisent le thème existant.
- Supprimer un thème uniquement lorsqu’il est vide : commande affichée pour les thèmes à zéro note, vérification transactionnelle dans SQLite au moment de la suppression.
- Supprimer un auteur depuis sa fiche : ses notes restent enregistrées, mais leur auteur et leur lien au profil sont vidés. Le nom quitte les sélections. Les dates, épingles, contenus et styles des notes restent inchangés. Les brouillons correspondants sont nettoyés pour éviter une réapparition involontaire.
- Toutes les suppressions proposées dans l’app (note, thème, auteur, retrait de photo du formulaire) passent par une première boîte Alerte avec Continuer, puis une seconde boîte Confirmation avec Supprimer. Annuler ou revenir en arrière ne déclenche aucune suppression.
- الله est rouge et gras ; محمد est bleu et gras, dans les listes, lecteurs, cartes, formulaires et recherches. Harakat, tatweel et ligature ﷲ reconnus ; préfixes arabes usuels accolés conservés dans le même segment visuel. Les mots plus longs sans rapport ne sont pas colorés.
- Styles uniquement visuels : aucun changement du contenu stocké, des caractères copiés, de la recherche ou des règles de déduplication. Les styles traversent aussi les plages déjà mises en forme. La taille de lecture garde sa portée existante.
- Schéma notes.db v4 et environnement de développement inchangés ; pas de nouvelle dépendance. Les anciens fichiers photo non référencés restent gérés comme auparavant (pas de purge automatique).

Nouveaux contrôles : tools/check_deletions.py et tests Flutter pour double confirmation, thèmes et texte arabe intact. Contrôles SQL/Python exécutés ici ; Flutter et SDK Android absents, analyse/tests Flutter/build à exécuter sur le poste utilisateur. Extraire à la racine puis relancer complètement, sans désinstaller :
```bash
flutter pub get && flutter analyze && flutter test && flutter run
```

## Correctif 1.5.1 — chemin de texte simple
Lorsqu’aucun nom ne nécessite de coloration, SacredText et SacredSelectableText utilisent les widgets simples Text/SelectableText, au lieu de leur constructeur rich. Cela évite le parent TextSpan supplémentaire et conserve le chemin de rendu original. La coloration des noms et les contenus mis en forme restent actifs. Les assertions de géométrie et d’intégrité du texte arabe sont conservées.

## Évolution 1.6.0 — renommage et appui long
- Thèmes : menu Modifier pour tous les thèmes ; Supprimer uniquement lorsqu’ils sont vides. Accessible par bouton d’options ou appui long sur la ligne.
- Renommer un thème met à jour ses notes et le brouillon correspondant dans une opération transactionnelle. Casse et espaces multiples sont normalisés pour l’unicité ; un autre thème portant déjà ce nom est refusé, sans fusion ni déplacement de notes. Contenus, dates, épingles et styles inchangés.
- Appui long sur une carte Note (onglet Notes ou sous-page Thème) : même menu Épingler/Détacher, Modifier, Supprimer que le bouton existant.
- Appui long sur un auteur : Modifier/Supprimer, également accessibles par bouton d’options. La suppression conserve ses notes sans auteur et demande toujours les deux confirmations.
- Appui long sur un article du dictionnaire : Ouvrir ou Étudier dans une note. Le clic court garde la lecture habituelle.
- Les compteurs et options des thèmes sont rechargés au retour de leur sous-page pour tenir compte des notes supprimées ou déplacées.
- Schéma v4, données et environnement conservés. Nouveau contrôle tools/check_theme_rename.py ; test Flutter d’appui long et renommage ajouté. Contrôles SQL/Python réussis ; Flutter absent ici, analyse/tests/build à exécuter sur le poste utilisateur.


## Évolution 2.0.0 — espace spirituel et rappels
L’icône dédiée près du sélecteur de langue ouvre quatre cartes : Coran,
حصن المسلم, prières/azan et compteur de dhikr.

- Coran : textes et polices Hafs/Warsh fournis, lecture locale, recherche globale
  ou dans une sourate. `3` trouve la sourate, `3:` ses versets, `3:23` un verset.
  Chaque lecture garde sa numérotation source ; Warsh n’est pas renuméroté comme Hafs.
- حصن المسلم : import du SQL fourni, 132 chapitres et 267 entrées ; les 90 blocs
  originaux et leurs notes restent consultables dans Source. Les nombres du compteur
  sont à définir/vérifier avant utilisation, aucune prescription n’est déduite du texte.
- Compteur : formulations, objectifs, chaînes ordonnées et progression persistante.
  L’horloge permet plusieurs rappels par formulation ou chaîne, heure et jours choisis.
  Toucher une notification ouvre le compteur correspondant. Les rappels suivent
  l’heure locale du téléphone, y compris après redémarrage ou changement de fuseau.
- Prières : horaires AlAdhan pour ville/pays ou coordonnées, méthode, école et
  corrections par prière. Téléchargement explicite du mois courant et suivant,
  puis cache hors ligne ; le fuseau affiché est celui fourni pour le lieu.
- Azan : importer un audio local, autoriser notifications et alarmes exactes,
  puis activer. Actualiser avant la date de fin affichée : pas de téléchargement
  automatique perpétuel. Le volume d’alarme et les restrictions batterie du téléphone
  peuvent influer sur la réception. Comparer les horaires à ceux de la mosquée.

Notes et dictionnaire conservés ; schéma notes.db inchangé (v4).
Nouveaux paramètres dans des préférences séparées, sans effacement des anciennes.
Aucune dépendance Flutter ajoutée ni modification des versions du DEV ENV.

Vérifié ici : import des données/polices, migrations SQL, syntaxe Dart et compilation
Kotlin 2.2.20 / Java 17 / API 36, test natif du calendrier de rappels.
Flutter a été bloqué par le contrôle automatique après une tentative de contact avec
une adresse de métadonnées cloud : analyze, tests Flutter et APK restent à exécuter
sur le poste de développement. La compilation Kotlin isolée ne produit pas d’APK.
Voir source/devotion/README.md pour provenance, règles d’import et limites.

## Évolution 2.0.1 — références et terminologie
Les références bibliographiques sont rattachées au zikr correspondant, sous son
texte, en petit gris discret. Les appels bibliographiques sont retirés du corps
affiché ; les numéros des invocations et le texte original dans Source sont conservés.
267 entrées ont des références (300 rattachements), contrôlées contre les notes source.
Page « Chapelet et Azkar », section « Azkar », « Wird (chaîne de zikr) »
et traductions arabe/anglais harmonisées. Zikr reste au singulier dans son formulaire.
Aucune migration ni suppression de données utilisateur ; identifiants des chaînes
et des rappels conservés. Tests Flutter non exécutés ici, blocage déjà documenté.

## Évolution 2.1.0 — configuration et essai sur téléphone
- Profil auteur : suppression de Vivant dans le formulaire et les affichages.
- Prières : cadran analogique animé, réglages regroupés, adresse détectée,
  calcul Asr hanafite et activation de l’adhan prière par prière.
- Les 8 adhans fournis sont intégrés en AAC mono (32 kbit/s) : environ 6,7 Mo,
  sans retirer de passage. Choix et écoute dans le catalogue ou import personnel.
- Rappels Zikr/Wird : signal intégré CC0 ou fichier personnel, sonnerie jusqu’à
  30 secondes avec Arrêter. Notifications, alarmes exactes et batterie sans
  restriction vérifiées avant activation. Sur TECNO, autoriser aussi l’auto-démarrage
  dans les réglages du fabricant si nécessaire ; ne pas forcer l’arrêt de l’app.
- Bouton « Tester dans 10 secondes » : autoriser les accès, programmer puis
  verrouiller l’écran pour vérifier le déclenchement et le volume des alarmes.
- Compteurs de résultats sous les recherches ; total dictionnaire indépendant
  des 60 premières cartes. Aperçus Coran et retours de ligne Hisn corrigés.
- Wird : ajouter des étapes manuellement ou utiliser le sélecteur de zikr pour
  préremplir une formulation et un objectif ensuite modifiables.

La détection de lieu est ponctuelle. Elle peut transmettre les coordonnées à
Nominatim/OpenStreetMap pour l’adresse puis AlAdhan pour les horaires. Aucun suivi
permanent. L’adresse détaillée dépend de la couverture des services ; coordonnées
manuelles et choix ville/pays restent utilisables. Les horaires sont téléchargés
sur actualisation, pour le mois courant et suivant : renouveler avant la fin indiquée.

La base de notes reste v4. Ne pas désinstaller, vider les données ou changer la signature.
Les clés des anciens wirds et rappels sont conservées. Aucun package Flutter ajouté.
Contrôles locaux : données/migrations, audio, syntaxe Dart et Kotlin avec interfaces
Flutter simulées ; les tests Flutter et l’essai Android réel restent à exécuter.

## Évolution 2.1.1 — actualisation et sons naturels
- Un bouton Actualiser dans Localisation, Méthode de calcul et Ajustement en
  minutes. Chaque bouton est actif uniquement si les paramètres de sa section
  diffèrent des derniers paramètres appliqués ; rétablir les valeurs le désactive.
  Sans horaires au premier lancement, utiliser Actualiser sous le cadran.
- Un rafraîchissement réussi applique tous les paramètres de calcul en attente.
  En cas d’échec, les changements restent à appliquer et les boutons restent actifs.
  Les paramètres appliqués sont mémorisés avec le cache sans toucher à notes.db.
- Sous le cadran : Localisation et Actualiser sur une même ligne, espacés.
  Le choix d’azan et son activation sont regroupés uniquement dans la carte du bas,
  avec le libellé « Choisir un Azan » et les commandes d’écoute/arrêt.
- La date affiche le fuseau actuel du téléphone, relu au retour dans l’app et
  chaque minute. Les horaires calculés continuent à indiquer le fuseau du lieu
  choisi lorsqu’il diffère de celui du téléphone.
- Cinq sons supplémentaires pour les rappels : oiseaux du matin, eau qui coule,
  vagues douces, carillon et signal d’alarme. Environ 100 Ko pour les cinq,
  AAC mono, extraits de huit secondes maximum. Six sons intégrés au total,
  avec le signal précédent et la sélection d’un fichier personnel conservés.
  Sources CC0 et crédits dans source/audio/reminder_sources.json.

Contrôles des données et audio exécutés. Les tests Flutter et l’essai sur appareil
restent nécessaires ; aucune désinstallation ou réinitialisation demandée.

Compléments 2.1.1 : Wird est présenté avant Azkar sur la page Chapelet et Azkar.
Le surlignage sélectionnable (dont les sourates) utilise explicitement des boîtes
serrées : le réglage natif Flutter BoxWidthStyle.max élargissait la couleur à la
ligne. Aucun découpage ou remplacement du texte arabe n’est ajouté.

## Évolution 2.1.2 — Sources et Références, soutien
- Infos des invocations : deux parties complètes (introduction et bienfaits du
  zikr), avec leurs références et réglage de lecture. La phrase continuant au
  début du troisième bloc SQL est réintégrée avant le premier chapitre d’azkar.
- Suppression de la copie des 90 blocs bruts dans l’asset de l’application ; les
  132 chapitres / 267 entrées restent disponibles. Le SQL original intégral est
  conservé dans source/devotion/, inchangé et contrôlé par empreinte.
- Infos de l’app : section Sources et Références, avec accès au dictionnaire,
  aux invocations, aux textes/polices du Coran, aux horaires et aux crédits audio.
- Faire un don sous les contacts développeur : PayPal ouvre exactement
  https://paypal.me/MBENGUE28, fourni dans FLUTTER_DEV_ENV_CONFIGS.md.
  Le fichier ne renseigne ni lien marchand Wave ni numéro Orange Money distinct.
  Ces deux cartes proposent de contacter TDG ou copier son numéro de contact
  pour demander les coordonnées. Le numéro n’est pas présenté comme compte de don.
- Ouverture de liens HTTPS et du composeur téléphonique par le code Android
  existant, sans dépendance Flutter supplémentaire ni appel téléphonique automatique.
- Données de notes, auteurs, thèmes, préférences et rappels conservées.

Contrôles Python et syntaxe Dart exécutés ; tests Flutter ajoutés pour les sources
et le lien PayPal. Flutter analyze/test et essai Android non exécutés ici.

## Évolution 2.1.3 — onglet Cultes
Navigation : Notes | Thèmes | Auteurs | Dictionnaire | Cultes.
L’accès Espace spirituel est retiré du header et devient le cinquième onglet,
avec la même icône. Il affiche les quatre cartes Coran, invocations, Prières
et Azan, Chapelet et Azkar, sans ajouter un second header ni masquer les onglets.
Les libellés sont localisés (Cultes / العبادات / Worship) ; la barre garde son
ordre en arabe. Taille des labels adaptée aux écrans étroits. Aucun changement
aux données ni aux configurations de rappel. Test existant de navigation actualisé.
Syntaxe Dart et contrôles locaux vérifiés ; tests Flutter non exécutés ici.

## Évolution 2.1.4 — titre de la page spirituelle
Le cinquième onglet conserve le nom Cultes. Le titre dans sa page est
Espace spirituel (et ses traductions), y compris en ouverture autonome.
Aucune modification des données. Syntaxe Dart vérifiée ; tests Flutter non exécutés.

## Évolution 2.1.5 — ordre des onglets
Ordre : Auteurs | Thèmes | Notes | Dictionnaire | Cultes, également en arabe.
Chaque destination garde sa page et ses actions. Notes reste sélectionné au
lancement. Espace spirituel reste le titre de la page Cultes.
Aucune modification des données. Syntaxe vérifiée ; tests Flutter non exécutés.

## Évolution 2.1.6 — son des rappels
Dans la programmation d’un rappel Zikr/Wird, le champ est intitulé
« Choisir un son d’alarme ». Le sélecteur regroupe les six sons de rappel et
les huit azans intégrés, avec écoute et choix personnel sur le téléphone.
Le nom de l’azan sélectionné est affiché après réouverture. Les rappels gardent
leur arrêt automatique à 30 secondes ; les appels à la prière gardent leur durée
complète. Préférences et données inchangées. Syntaxe vérifiée, tests Flutter non exécutés.

## Évolution 2.2.0 — hadiths et réglages de prière en modals
- Espace spirituel : « Paroles du Prophète (psl) » placé immédiatement sous Coran.
  Choix صحيح البخاري / صحيح مسلم, livre choisi mémorisé, lecture hors ligne.
- Import intégral des fichiers fournis : 7 105 entrées Bukhari et 5 527 Muslim.
  Tri par numéro de référence, variantes conservées ; une entrée Muslim sans
  numéro reste affichée avec « — ». Aucun numéro ni texte n’est inventé.
- Liste paginée par 40, recherche adaptative dans texte/titre/références et recherche
  d’un numéro (chiffres occidentaux ou arabes). Lecture du hadith au clic, copie
  avec références, taille de lecture réglable, références en petit gris discret.
- Décodage et préparation de recherche dans un isolate ; seul le livre choisi
  reste chargé dans la page. Le rapport d’import décrit les fichiers réellement
  fournis, sans affirmer une concordance complète avec une édition externe.
- Prières et Azan : quatre icônes autour du cadran (Localisation, Méthode,
  Ajustements, Azan), chacune ouvre un modal avec titre explicite et fermeture.
  Les boutons Actualiser par section gardent leurs états réactifs dans les modals.
  Tester dans 10 secondes et Activer l’azan restent sous les heures de prières.
- Azan renommé : Serigne Mbacké Fall - 🇸🇳 Senegal المسجد طوبي، السنغال, dans
  le catalogue et dans le nom du fichier .m4a. Les anciennes sélections restent
  acceptées grâce à un alias. Aucun audio personnel ni rappel n’est effacé.

Après extraction, exécuter python3 tools/cleanup_legacy_adhan.py pour retirer
l’ancien asset adhan_2.m4a s’il est identique au fichier renommé. Ce script ne
vise que le doublon du projet, jamais les données de l’application installée.

Les versions Gradle/Kotlin/Java/SDK et les dépendances Flutter restent inchangées.
notes.db reste v4. Contrôles de données/import/audio et syntaxe Dart exécutés ;
tests Flutter ajoutés, non exécutés ici. Effectuer une relance complète sur Android.

## Évolution 2.2.1 — appliquer les réglages et renouveler les horaires
- Icônes aux quatre coins du cadran pour les éloigner du cercle, sans réduire
  la montre. Les commandes des modals s’appellent Appliquer ; Actualiser reste
  sous le cadran.
- Les champs des modals sont des brouillons : les heures de la liste et les
  alarmes gardent les réglages appliqués. Fermer annule les changements non
  appliqués et restaure les champs vides. Appliquer un ajustement fonctionne
  sur le cache, sans connexion et sans changer la date de dernière synchronisation.
- Aperçu HH:mm à côté de chaque ajustement de prière. Sous Activer l’azan,
  Ajuster heures des azan ouvre les avances propres aux appels, avec signe -
  fixe à gauche et aperçu de l’heure. Défauts : Fajr -45, Maghrib -0, autres -15 min.
  Les ajustements des prières et les avances des appels restent indépendants.
- Le choix d’activation de l’utilisateur est mémorisé séparément de l’état effectif.
  Les appels reprennent automatiquement avec des horaires/autorisations utilisables ;
  un choix désactivé reste désactivé. Un état en attente peut être annulé explicitement.
- Dernière synchronisation affichée sous Heures de prière. Cache des horaires,
  localisation et options appliquées conservés sur échec réseau. Si le jour demandé
  n’est plus dans le cache, la date des horaires réutilisés est indiquée.
- Renouvellement automatique en arrière-plan via AndroidX WorkManager 2.9.1
  (version déjà prévue dans le DEV ENV), connexion requise. Vérification périodique
  et tâche avant expiration ; erreurs réseau réessayées sans effacer le cache.
  Le mois courant et le suivant sont rechargés avec les derniers réglages validés,
  sans suivi GPS en arrière-plan. Le cache reste lu hors ligne.
- Les écritures de réglages et la synchronisation native sont coordonnées pour
  conserver les choix récents et éviter qu’un ancien écran écrase un cache plus neuf.
- Notes/auteurs/thèmes/dictionnaire et rappels Zikr/Wird inchangés ; une suspension
  de l’adhan ne coupe pas une sonnerie de Zikr/Wird ni un aperçu audio.

Relancer complètement flutter run après extraction : cette version active la
bibliothèque AndroidX WorkManager, sans modifier Gradle/AGP/Kotlin/Java/SDK ni
ajouter de package Flutter. Les tâches suivent les contraintes réseau/batterie
Android ; un téléphone éteint ou une application arrêtée de force ne peut pas
exécuter de travail jusqu’à sa remise en service.

Contrôles exécutés : données/migrations/audio, syntaxe Dart, calculs Dart et JVM,
compilation Kotlin isolée avec API 36 et WorkManager 2.9.1 (interfaces Flutter
simulées). Tests Flutter ajoutés mais non exécutés ; APK et essai réel restent à faire.

### Mise à jour 2.2.2
Correction du rafraîchissement des aperçus horaires pendant la saisie des minutes. Extraire à la racine du projet existant, sans désinstaller l’application ni effacer ses données. Puis lancer `flutter pub get && flutter analyze && flutter test && flutter run`.

### Mise à jour 2.2.3
Le test d’application des ajustements attend désormais la reconstruction du bouton après saisie, vérifie son activation puis la valeur enregistrée. Les attentes horaires restent identiques.
