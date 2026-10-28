# Diraasa 2.3.0 — signature Android, Firebase et Google Drive

Ce guide concerne `com.tdg.diraasa`. Les empreintes demandées sont **SHA-1 et SHA-256** (pas « SHA-255 »). Une empreinte est calculée depuis un certificat de signature ; elle ne remplace pas la clé privée et ne doit pas être inventée.

## 1. Préserver la version déjà installée

1. Installer cette mise à jour sur le même projet et effectuer une **sauvegarde locale** depuis l’application avant tout changement de signature ou de téléphone.
2. Conserver le certificat de signature utilisé pour la version déjà distribuée. Une mise à jour Android doit conserver la même identité de signature et un `versionCode` supérieur ; cette version est `2.3.0+40`.
3. Si une clé release existe déjà, la réutiliser : ne pas en créer une nouvelle pour la remplacer. Une APK debug et une APK release signées par des clés différentes ne se remplacent généralement pas directement. Ne pas désinstaller avant d’avoir exporté et vérifié une sauvegarde locale.
4. Pour vérifier une APK existante, utiliser `apksigner verify --print-certs chemin/vers/app.apk` depuis les Android SDK Build Tools. Le certificat de l’APK installée peut différer de celui de l’APK locale si Google Play App Signing est actif.

## 2. Créer une clé uniquement si aucune clé de publication n’existe

Depuis un terminal utilisant le JDK 17 de votre environnement :

```bash
mkdir -p "$HOME/.keystores"
chmod 700 "$HOME/.keystores"
keytool -genkeypair -v -keystore "$HOME/.keystores/diraasa-upload.jks" -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias diraasa
chmod 600 "$HOME/.keystores/diraasa-upload.jks"
```

Répondre aux questions d’identité et saisir les mots de passe dans les invites interactives. Garder une copie de la clé et des mots de passe dans deux emplacements sûrs distincts. Ne jamais les envoyer dans une conversation, une archive de mise à jour ou Git.

Créer `android/key.properties` avec un éditeur local :

```properties
storePassword=VOTRE_MOT_DE_PASSE_DU_KEYSTORE
keyPassword=VOTRE_MOT_DE_PASSE_DE_LA_CLE
keyAlias=diraasa
storeFile=/home/mbengue/.keystores/diraasa-upload.jks
```

Adapter le chemin à la clé réellement utilisée. Si vous avez choisi le même mot de passe pour la clé et le magasin, mettre la même valeur aux deux lignes. Protéger ce fichier :

```bash
chmod 600 android/key.properties
```

Le projet utilise déjà ce fichier pour `signingConfigs.release`. Ni la clé privée ni ce fichier ne sont fournis dans l’archive.

## 3. Relever les empreintes des bonnes clés

Pour la clé release/upload :

```bash
keytool -list -v -keystore "$HOME/.keystores/diraasa-upload.jks" -alias diraasa
```

Copier les lignes `SHA1` et `SHA256` du **certificat**, pas une somme du fichier `.jks`.

Pour toutes les variantes réellement utilisées par Gradle :

```bash
cd android
./gradlew signingReport
cd ..
```

Le rapport donne le fichier et l’alias effectivement employés, y compris le debug. Avec Flutter Snap, ne pas supposer que le debug keystore est dans un autre HOME : utiliser le chemin du rapport. Si le fichier standard existe, cette commande est également possible :

```bash
keytool -list -v -keystore "$HOME/.android/debug.keystore" -alias androiddebugkey
```

Le magasin debug standard utilise normalement le mot de passe `android`. Ne pas appliquer cette valeur à votre clé de production.

Si Google Play App Signing est activé : dans Play Console → application → Intégrité de l’application / Signature d’application, relever **SHA-1 et SHA-256 du certificat de signature d’application**. Ajouter aussi les certificats de la clé d’importation et de debug utilisés pour vos installations de test. L’APK livrée par Play est signée par la clé d’application Play, pas nécessairement la clé d’upload.

## 4. Créer/configurer le projet Firebase

1. Ouvrir https://console.firebase.google.com/ et créer ou choisir votre projet. Analytics n’est pas utilisé par Diraasa ; ne pas l’activer pour cette fonctionnalité.
2. Paramètres du projet → Général → Ajouter une application Android.
3. Nom du package : **`com.tdg.diraasa`**, exactement. Ajouter la première empreinte SHA-1, puis enregistrer.
4. Paramètres → Général → Vos applications → application Android → Empreintes des certificats SHA : ajouter les **SHA-1 et SHA-256** des certificats utiles : debug, release/installation directe et signature Google Play. Ne pas modifier l’ID de l’app.
5. Authentication → Sign-in method / Méthode de connexion → **Google** : activer, renseigner l’adresse e-mail d’assistance, enregistrer. Aucune connexion par mot de passe, téléphone ou anonyme n’est requise par ce code.
6. Télécharger de nouveau le fichier **`google-services.json` après activation de Google** et l’enregistrer exactement sous :

```text
android/app/google-services.json
```

7. Vérifier dans le fichier que `package_name` vaut `com.tdg.diraasa` et qu’un client OAuth de **type Web (`client_type: 3`)** existe. Le plugin en tire `default_web_client_id`. L’ID client Android ne doit pas être utilisé à sa place.
8. Si aucun client Web n’existe, créer/associer le client Web dans le même projet Google Cloud, vérifier l’activation du fournisseur Google, puis retélécharger le fichier Firebase mis à jour. Ne pas fabriquer un fichier d’exemple avec de fausses clés.

Le plugin Google Services 4.5.0 est déclaré et appliqué automatiquement lorsque ce fichier existe. Sans fichier, la sauvegarde locale fonctionne et l’écran explique que Google n’est pas configuré. La BoM Firebase reste celle prévue dans le DEV ENV : 34.15.0, avec `firebase-auth` uniquement. SDK Android minimal : 24 pour les nouvelles dépendances d’authentification ; SDK cible/compile 36, Java 17, Kotlin 2.2.20, AGP 8.11.1 et Gradle 8.14.1 restent inchangés.

Aucune base Firestore, Realtime Database, Firebase Storage, Cloud Function, compte de service, clé JSON administrateur ni règle de stockage Firebase n’est utilisée pour ces sauvegardes. Les fichiers vont dans le Drive personnel de l’utilisateur. Les quotas/conditions Google Drive et Firebase applicables au compte/projet restent ceux de Google.

## 5. Activer Google Drive API dans le même projet

1. Depuis Firebase, ouvrir le projet Google Cloud associé, ou sélectionner le **même ID de projet** sur https://console.cloud.google.com/.
2. API et services → Bibliothèque → **Google Drive API** → Activer.
3. Google Auth Platform / Écran de consentement OAuth : renseigner Diraasa, l’e-mail d’assistance TDG et les contacts développeur.
4. Audience : choisir celle de votre distribution. Pour des utilisateurs hors de votre organisation, utiliser une audience externe ; en mode Test, ajouter explicitement les comptes de test.
5. Accès aux données / Scopes : ajouter le périmètre utilisé par le code :

```text
https://www.googleapis.com/auth/drive.file
```

Ce périmètre concerne les fichiers créés/ouverts par l’application, pas tout le Drive. Ne pas ajouter les périmètres Drive complets ou `drive.appdata` : ce dernier cacherait les sauvegardes alors que l’application propose d’ouvrir leur dossier visible.

6. Clients OAuth : vérifier les clients Android pour `com.tdg.diraasa` et leurs SHA-1. Firebase peut les créer lors de l’ajout des empreintes ; ne pas multiplier inutilement des doublons. Le client Web et l’application Android doivent appartenir au même projet.
7. Définir les URL publiques de présentation et de confidentialité sur un domaine que vous contrôlez. Les fichiers `source/privacy/index.html` et `source/privacy/delete-account.html` sont prêts à héberger ; **ils ne sont pas publiés par cette archive**. Ajouter le lien de confidentialité dans l’écran OAuth et, pour Play, le lien de demande de suppression de compte.
8. Lorsque vous publiez pour tous, examiner les exigences d’audience, de marque et de vérification affichées par Google ; compléter les formulaires demandés. Ne pas confondre le mode Test avec une publication publique. Les autorisations et sessions peuvent être révoquées par l’utilisateur ou par Google.

## 6. Compiler, installer et vérifier

Depuis la racine du projet :

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
flutter build appbundle --release
```

Le projet conserve les splits ABI. L’APK universelle se trouve normalement sous `build/app/outputs/flutter-apk/app-release.apk`, et l’AAB sous `build/app/outputs/bundle/release/app-release.aab`.

Après toute modification Firebase/Gradle/Kotlin, arrêter complètement l’ancienne session puis relancer. Le hot reload ne recharge pas les SDK Android.

Test fonctionnel sur un téléphone avec Google Play services :

1. Créer une note de test avec thème, auteur/photo, mise en forme ; créer un zikr et un wird, sélectionner un son personnel et modifier une préférence.
2. Icône de sauvegarde à côté de Langue → Sauvegarde et Restauration → Créer une sauvegarde locale. Conserver le `.diraasa.zip` et vérifier qu’il peut être sélectionné pour afficher son résumé. Annuler à ce stade si vous ne voulez pas remplacer vos données.
3. Se connecter avec Google : Credential Manager choisit le compte et Firebase conserve la session.
4. Sauvegarder sur Drive : accepter **séparément** l’autorisation Drive. Firebase Authentication ne donne pas, à lui seul, accès à Drive.
5. Mes sauvegardes Drive : retrouver le fichier. Ouvrir le dossier : vérifier le bon compte et le dossier **Diraasa — Sauvegardes**.
6. Fermer puis rouvrir l’app : le compte doit encore apparaître. L’app redemande un jeton Drive court au SDK lors d’une action Drive ; elle n’exporte ni jeton ni clé. Aucun serveur de rafraîchissement personnalisé n’est requis.
7. Sur un appareil de test ou après une sauvegarde de sécurité, restaurer : deux confirmations, validation de l’archive et des empreintes, copie automatique de l’état courant, transaction SQLite et application des préférences. Vérifier note/photo, auteurs, thèmes, azkar/wird, préférences et sons.
8. Les autorisations notifications/alarmes/batterie sont propres à l’appareil : les réaccorder dans les pages correspondantes si nécessaire. Les jobs natifs sont recalculés ; les fichiers de jobs d’un ancien appareil ne sont pas importés.

## 7. Comportement et limites à connaître

- Sauvegardes **manuelles** : la connexion persistante n’active pas une sauvegarde Drive automatique. La resynchronisation automatique des horaires de prière reste indépendante.
- Chaque sauvegarde crée un fichier daté ; pas d’écrasement automatique de la précédente.
- La restauration **remplace**, elle ne fusionne pas. Une copie de sécurité de l’état précédent est créée et accessible dans la page de sauvegarde. Les migrations normales de base restent non destructives.
- Format ZIP versionné, JSON Unicode, médias et sommes SHA-256 ; archive non chiffrée par Diraasa. Le hash détecte une corruption, pas l’identité de son auteur.
- Limites de validation : 512 Mio décompressés au total, 64 Mio pour les données JSON, 2 000 pièces/données hors manifeste. Une archive incompatible ou endommagée est refusée avant remplacement.
- Les textes et sons intégrés se réinstallent avec l’app et ne sont pas recopiés dans chaque sauvegarde. Les médias personnels réellement référencés sont inclus s’ils existent dans le stockage privé de l’app.
- Interruption réseau : la copie locale et les données de l’app restent intactes. Un envoi Drive interrompu est signalé, à relancer manuellement ; la session d’envoi utilise l’API resumable mais l’app ne persiste pas son état entre deux lancements.
- Déconnexion : arrête l’accès depuis l’app sans supprimer vos fichiers Drive. « Supprimer mon compte Diraasa » supprime le compte Firebase ; les fichiers que vous avez exportés restent sous votre contrôle. Supprimer les fichiers dans Drive si vous souhaitez aussi les retirer. Une connexion récente peut être nécessaire pour supprimer le compte.

## 8. Dépannage

- **Google non configuré** : mauvais emplacement/nom de `google-services.json`, fournisseur Google inactif, client Web absent ou relance native non effectuée.
- **Developer error / mauvais client** : vérifier package, SHA-1 du certificat réellement installé, projet Google Cloud associé et client Web du fichier mis à jour. Ajouter les SHA-256 également dans Firebase.
- **Drive 403 / accès refusé** : vérifier Drive API activée dans le même projet, périmètre `drive.file`, consentement accordé, compte de test autorisé, quota/espace et politiques éventuelles du compte Workspace.
- **Drive 401 / session expirée** : réessayer l’action pour redemander un jeton ; si nécessaire se déconnecter puis reconnecter le même compte.
- **Aucun fichier** : vérifier le compte affiché, le projet OAuth utilisé et que les fichiers sont encore dans le dossier de sauvegarde. Une archive déplacée peut toujours être téléchargée via Drive puis restaurée avec le sélecteur local.
- **Suppression du compte exige une connexion récente** : se déconnecter puis se reconnecter, et refaire la suppression.
- **Restauration refusée** : ne pas éditer les fichiers ou recalculer les empreintes pour forcer l’import. Garder l’archive d’origine ; contacter TDG si un format futur est en cause.

## Références officielles consultées le 28 octobre 2026

- https://developer.android.com/identity/sign-in/credential-manager-siwg-implementation
- https://developer.android.com/identity/authorization
- https://firebase.google.com/docs/auth/android/google-signin
- https://firebase.google.com/docs/auth/android/manage-users
- https://firebase.google.com/docs/android/setup
- https://developers.google.com/workspace/drive/api/guides/manage-uploads
- https://developers.google.com/workspace/drive/api/reference/rest/v3/files/list
- https://developers.google.com/identity/protocols/oauth2/production-readiness/policy-compliance
- https://support.google.com/googleplay/android-developer/answer/13327111
