# Audios du Coran — Diraasa 2.4.0

Source configurée : dépôt public `https://github.com/taysirdigitalgroup/diraasa-quran-sounds`, branche `main`. Aucun jeton ni clé GitHub dans l’app. Les fichiers sont lus en HTTPS depuis `raw.githubusercontent.com`.

## Organisation à pousser dans le dépôt

```text
hafs/
  ar/
    001001.mp3
    001002.mp3
    ...
    002000.mp3
    002001.mp3
    ...
    114006.mp3
  fr/
    001001.mp3
    001002.mp3
    ...
    002000.mp3
    002001.mp3
    ...
    114006.mp3
```

Chaque MP3 doit être un vrai fichier audio lisible, pas une page HTML ni un pointeur Git LFS. Le chemin est sensible à la casse. `ar` = récitation arabe, `fr` = audio français de l’entrée/verset fourni par le développeur. Ajouter les noms des récitants, la référence de la traduction française et les droits/source des enregistrements au README du dépôt.

Exemples de liens directs :

- https://raw.githubusercontent.com/taysirdigitalgroup/diraasa-quran-sounds/main/hafs/ar/001001.mp3
- https://raw.githubusercontent.com/taysirdigitalgroup/diraasa-quran-sounds/main/hafs/fr/002001.mp3

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
- Choix AR/FR enregistré parmi les préférences, donc inclus dans les sauvegardes.
- Synchronisation au niveau du verset : le verset en lecture est distingué et la page se repositionne dessus quand aucune recherche n’est active. Pas de synchronisation mot à mot faute de repères temporels.
- Lecteur actif seulement sur la page de sourate au premier plan ; arrêt en quittant la page ou en passant l’app en arrière-plan. Une alarme/azan met la lecture en pause. Pas de service de lecture du Coran en arrière-plan ajouté.
- Streaming en ligne : pas de téléchargement permanent/offline des MP3 dans cette version. Les fichiers audio distants ne gonflent pas les sauvegardes.
- Fichier absent, réseau interrompu ou délai de chargement dépassé : lecture interrompue avec message ; aucun saut silencieux d’un verset manquant. Réessayer après ajout des fichiers dans le dépôt.
- Le développeur fournit les audios. Cette archive ne contient pas d’enregistrements inventés ni de fichiers de test prétendus complets. La disponibilité réelle doit être vérifiée après le push.

Après avoir copié les fichiers dans `hafs/ar` et/ou `hafs/fr` :

```bash
git add hafs/ README.md
git commit -m "Ajout des audios Hafs"
git push
```

Le dépôt doit être public pour les liens raw anonymes de l’app. L’accès au dépôt par clé SSH sert uniquement à publier depuis le PC ; la clé privée n’est jamais intégrée à Diraasa.
