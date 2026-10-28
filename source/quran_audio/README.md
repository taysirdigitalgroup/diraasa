# Audios du Coran — Diraasa 2.4.2

Source configurée : dépôt public `https://github.com/taysirdigitalgroup/diraasa-quran-sounds`, branche `main`. Aucun jeton ni clé GitHub dans l’app. Les fichiers sont lus en HTTPS depuis `raw.githubusercontent.com`.

## Organisation à pousser dans le dépôt

```text
quran-hafs-ar/001001.mp3 ... 001007.mp3 ... 114006.mp3
quran-hafs-fr/001001.mp3 ... 001007.mp3 ... 114006.mp3
quran-hafs-en/001001.mp3 ... 001007.mp3 ... 114006.mp3
```

Chaque MP3 doit être un vrai fichier audio lisible, pas une page HTML ni un pointeur Git LFS. Le chemin est sensible à la casse. `ar` = récitation arabe, `en` = audio anglais, `fr` = audio français de l’entrée/verset fourni par le développeur. Ajouter les noms des récitants, la référence de la traductions française et anglaise et les droits/source des enregistrements au README du dépôt.

Exemples de liens directs :

- https://raw.githubusercontent.com/taysirdigitalgroup/diraasa-quran-sounds/main/quran-hafs-ar/001001.mp3
- https://raw.githubusercontent.com/taysirdigitalgroup/diraasa-quran-sounds/main/quran-hafs-fr/002001.mp3
- https://raw.githubusercontent.com/taysirdigitalgroup/diraasa-quran-sounds/main/quran-hafs-en/114006.mp3

## Contrôle des fichiers avant publication

Une connexion Internet est nécessaire pour les fichiers qui ne sont pas déjà dans le cache temporaire. Le lecteur vérifie la référence Hafs, l’ordre de la liste, l’accès au réseau et le décodage/durée du MP3. Le surlignage suit le verset effectivement préparé/en lecture, et non un simple minuteur estimé. Il n’y a pas de remplacement automatique d’une langue par une autre ou de saut d’un fichier absent.

Depuis le projet Flutter, après avoir installé FFmpeg (qui fournit ffprobe), auditer le dépôt audio local :

```bash
python3 tools/audit_quran_audio.py --root /media/mbengue/SSD/Android_App_Flutter/diraasa-quran-sounds --language ar fr en --output audit_quran_audio.json
```

Pour contrôler seulement Al-Fatiha anglaise pendant l’import :

```bash
python3 tools/audit_quran_audio.py --root /media/mbengue/SSD/Android_App_Flutter/diraasa-quran-sounds --language en --surah 1 --output audit_fatiha_en.json
```

Le rapport liste absences, erreurs, codec, durée, taille et SHA-256 ; il teste aussi le décodage complet. Il exige la numérotation du texte Hafs fourni : 6 236 versets + 112 basmalas séparées = 6 348 fichiers par langue, soit 19 044 pour AR/FR/EN complets. Le code de retour 1 signale un audit incomplet ou invalide.

**Le nom, le hash et le décodage ne prouvent pas le contenu récité ou traduit.** Le rapport conserve semanticMappingVerified=false : une écoute/revue du corpus source doit confirmer que chaque fichier correspond au bon verset, au bon ordre et à la bonne langue avant de le déclarer vérifié sur le fond.

## Basmala et numérotation

- Al-Fatiha : `001001.mp3` est déjà le verset 1. Pas de `001000.mp3`, aucune double lecture.
- Autres sourates sauf At-Tawba : `SSS000.mp3` correspond à la basmala séparée. Elle précède le verset 1 lors d’une lecture continue commencée au verset 1.
- At-Tawba (9) : aucune basmala ajoutée, pas de demande `009000.mp3`.
- Un verset individuel lance seulement ce verset. La basmala séparée a son propre bouton. Une lecture continue commencée plus loin ne recommence pas la basmala.
- Aucun fichier Hafs associé au texte Warsh : leurs numérotations ne sont pas interchangeables.

## Commandes SSH sur le PC du développeur

Dans `~/.ssh/config`, compléter le bloc TDG :

```sshconfig
Host github.com-tdg
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_taysir
    IdentitiesOnly yes
```

Depuis le dossier local `diraasa-quran-sounds` :

```bash
git remote set-url origin git@github.com-tdg:taysirdigitalgroup/diraasa-quran-sounds.git
ssh -T git@github.com-tdg
git push -u origin main
```

Le message SSH doit identifier le compte TDG ou un compte ayant accès au dépôt. GitHub ne fournit pas de shell : un message de bienvenue peut s’accompagner d’un code de sortie 1. Si l’accès reste refusé, vérifier que la clé publique `id_ed25519_taysir.pub` est ajoutée au bon compte et que ce compte possède des droits d’écriture sur le dépôt. Ne jamais envoyer la clé privée.

`origin` existe déjà : utiliser `set-url`, pas `remote add`. Le nom d’alias défini est `github.com-tdg`, pas `tdg`. Ne pas réinitialiser le dépôt ni forcer le push.

## Lecture et limites

- Lecture individuelle, pause/reprise, arrêt, déplacement dans le MP3 et lecture continue de la sourate courante.
- Choix AR/FR/EN enregistré parmi les préférences, donc inclus dans les sauvegardes.
- Synchronisation au niveau du verset : le verset en lecture est distingué et la page se repositionne dessus quand aucune recherche n’est active. Pas de synchronisation mot à mot faute de repères temporels.
- Lecteur actif seulement sur la page de sourate au premier plan ; arrêt en quittant la page ou en passant l’app en arrière-plan. Une alarme/azan met la lecture en pause. Pas de service de lecture du Coran en arrière-plan ajouté.
- Cache glissant : audio courant, trois précédents et trois suivants dans la sourate/langue courante. Le fichier courant est chargé et validé avant lecture locale ; les suivants sont préchargés en priorité. Retour dans la fenêtre sans téléchargement supplémentaire. Fichiers sortis de la fenêtre supprimés. Maximum 32 Mio par MP3 et 128 Mio de fichiers finalisés ; jusqu’à 32 Mio supplémentaires transitoires pendant un téléchargement. Le cache est temporaire, isolé par langue, purgé à la fermeture du lecteur natif/au prochain lancement, et exclu des sauvegardes. Aucun téléchargement intégral du Coran.
- Fichier absent, réseau interrompu ou délai de chargement dépassé : lecture interrompue avec message ; aucun saut silencieux d’un verset manquant. Réessayer après ajout des fichiers dans le dépôt.
- Le développeur fournit les audios. Cette archive ne contient pas d’enregistrements inventés ni de fichiers de test prétendus complets. La disponibilité réelle doit être vérifiée après le push.

Après avoir copié les fichiers dans `quran-hafs-ar`, `quran-hafs-fr` et/ou `quran-hafs-en` :

```bash
git add quran-hafs-ar/ quran-hafs-fr/ quran-hafs-en/ README.md
git commit -m "Ajout des audios Hafs"
git push
```

Le dépôt doit être public pour les liens raw anonymes de l’app. L’accès au dépôt par clé SSH sert uniquement à publier depuis le PC ; la clé privée n’est jamais intégrée à Diraasa.

La synchronisation des changements de verset et d’état est transmise directement du lecteur Android à Flutter. Une identité de session et un numéro de révision ignorent les notifications périmées. L’interrogation toutes les 500 ms ne sert plus de mécanisme unique de suivi : elle actualise surtout la position dans le MP3 et offre un rattrapage d’état.

## Vérification réelle Al-Fatiha du 28 octobre 2026

Les sept fichiers attendus par langue ont été téléchargés depuis les dossiers réels du dépôt : 21 réponses HTTP200, format audio/mpeg, décodage complet, durée et SHA-256 contrôlés sans erreur. Rapport AUDIT_FATIHA_2.4.2.json inclus. Le fichier préalable anglais 001000.mp3, présent lors du premier contrôle puis retiré par le développeur, n’est pas demandé pour Al-Fatiha (dont 001001 est déjà le verset 1). Il ne faut pas renuméroter les fichiers. La vérification sémantique de la récitation/traduction reste distincte de ce contrôle technique.
