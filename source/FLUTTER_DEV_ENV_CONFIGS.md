# Environnement Flutter/Android — TDG (référence)

Ce fichier documente la configuration standard utilisée sur les apps TDG
(Sama Boutik, Voice Changer, Arabic Font Studio, ...), pour démarrer un
nouveau projet sans divergence de versions.

## Mise en place automatisée (méthode recommandée)

Ne plus copier les fichiers Gradle à la main projet par projet. Utiliser
le script wrapper stocké dans `~/0-apps/tdg-flutter-template/` :

```bash
~/0-apps/tdg-flutter-template/bin/tdg-flutter-create.sh <nom_app>
```

Ce script fait `flutter create --org com.tdg <nom_app>`, puis remplace
automatiquement les fichiers Gradle générés par les versions de référence
TDG ci-dessous (avec `namespace`/`applicationId` déjà correctement
substitués). Validé le 29/07/2026 sur `test_app` : projet opérationnel en
quelques secondes (contre plusieurs Go de téléchargement et un temps de
build long quand la config Gradle ne correspond pas au cache déjà chaud).

Le dossier `~/0-apps/tdg-flutter-template/` contient :
```
tdg-flutter-template/
├── bin/tdg-flutter-create.sh
└── android/
    ├── settings.gradle.kts
    ├── gradle.properties
    ├── gradle/wrapper/gradle-wrapper.properties
    └── app/build.gradle.kts.template   (avec NOM_APP_PLACEHOLDER)
```

**Repartir de zéro** (`flutter create` sans le script) reste possible mais
n'est plus la méthode par défaut — voir "Checklist manuelle" en bas de ce
fichier si besoin ponctuel.

## Versions de référence

| Composant | Version |
|---|---|
| Gradle | 8.14.1 |
| Android Gradle Plugin (AGP) | 8.11.1 |
| Kotlin | 2.2.20 |
| Java | 17 (source & target) |
| compileSdk / targetSdk | 36 |
| Firebase BOM (si utilisé) | 34.15.0 |
| google-services plugin (si Firebase) | 4.5.0 |
| desugar_jdk_libs | 2.1.4 |

⚠️ **Important** : depuis les versions récentes de Flutter, `flutter
create` génère par défaut des fichiers Gradle en **Kotlin DSL**
(`.gradle.kts`), avec des versions plus neuves d'AGP/Kotlin que celles
ci-dessus (rencontré : AGP 9.0.1 / Kotlin 2.3.20). Utiliser ces versions
plus neuves au lieu des versions de référence force Gradle à retélécharger
des dépendances non partagées avec le cache des autres apps TDG,
et fait perdre un temps de build important sur le premier run. **Toujours
revenir aux versions de référence ci-dessus**, en syntaxe Kotlin DSL
(voir fichiers ci-dessous).

## `android/settings.gradle.kts`

```kotlin
pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
    // Décommente seulement si le projet utilise Firebase :
    // id("com.google.gms.google-services") version "4.5.0" apply false
}

include(":app")
```

## `android/gradle.properties`

```properties
org.gradle.jvmargs=-Xmx4G -XX:MaxMetaspaceSize=2G -XX:+UseParallelGC
android.useAndroidX=true
android.enableJetifier=true
```

## `android/gradle/wrapper/gradle-wrapper.properties`

```properties
distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
distributionUrl=https\://services.gradle.org/distributions/gradle-8.14.1-bin.zip
```

## `android/app/build.gradle.kts`

```kotlin
import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    // id("com.google.gms.google-services")   // <- seulement si Firebase
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.tdg.NOM_APP"        // <- à changer
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlin {
        compilerOptions {
            jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
        }
    }

    sourceSets {
        getByName("main").java.srcDirs("src/main/kotlin")
    }

    defaultConfig {
        applicationId = "com.tdg.NOM_APP"  // <- à changer (même valeur que namespace)
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String?
                keyPassword = keystoreProperties["keyPassword"] as String?
                storeFile = keystoreProperties["storeFile"]?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String?
            }
        }
    }

    buildTypes {
        getByName("debug") {
            isDebuggable = true
        }
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    splits {
        abi {
            isEnable = true
            reset()
            include("armeabi-v7a", "arm64-v8a", "x86_64")
            isUniversalApk = true
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.multidex:multidex:2.0.1")
    implementation("androidx.core:core-ktx:1.13.1")

    // Si Firebase est nécessaire sur ce projet, décommenter :
    // implementation(platform("com.google.firebase:firebase-bom:34.15.0"))
    // implementation("com.google.firebase:firebase-analytics")
    // implementation("com.google.firebase:firebase-messaging")
    // implementation("androidx.work:work-runtime-ktx:2.9.1")
}
```

⚠️ Ne pas appliquer le plugin `com.google.gms.google-services` (ni les
dépendances Firebase ci-dessus) si le projet n'a pas de
`google-services.json` — ça fait planter le build immédiatement.

## Convention de nommage

- **Package Android** : `com.tdg.<nom_app_en_snake_ou_sans_espace>`
  (ex : `com.tdg.sama_boutik`, `com.tdg.voicechanger`,
  `com.tdg.arabic_font_studio`).
- Le `namespace` et l'`applicationId` doivent toujours être identiques.

## Convention pour un moteur Rust embarqué (flutter_rust_bridge)

Si le projet embarque un moteur Rust (ex. Arabic Font Studio) :
- le dossier Rust s'appelle `rust/` et vit **au même niveau que
  `pubspec.yaml`** (pas dans un dossier conteneur externe) — c'est
  l'emplacement par défaut attendu par `flutter_rust_bridge_codegen`
- les assets (fonts, images de référence, etc.) vont dans `assets/` du
  projet Flutter, déclarés dans `pubspec.yaml` sous `flutter: assets:`
- toute donnée de test lue par les tests Rust doit utiliser
  `env!("CARGO_MANIFEST_DIR")` pour construire un chemin absolu vers
  `assets/`, jamais un chemin relatif en dur (casse selon le dossier
  d'où `cargo test` est lancé)

## Écran de démarrage Android (splash, API 31+)

Rencontré sur Daaray Kaamil (5 tentatives avant de trouver la vraie
cause) — à appliquer directement dès le départ sur les prochains projets
plutôt que de re-tâtonner par la taille.

### Deux choses distinctes, souvent confondues

1. **Le conteneur** (taille en dp de l'icône affichée par l'OS au
   démarrage) — se règle via `flutter_native_splash` / les thèmes
   `values-v31`.
2. **L'image source elle-même** (a-t-elle une marge interne ou
   remplit-elle tout son cadre ?) — c'est elle qui détermine si le
   résultat a l'air "posé avec de l'air autour" ou "zoomé/collé aux
   bords", **indépendamment de la taille du conteneur choisie**.

Le piège : passer du temps à ajuster le conteneur (1) alors que le
problème vient de (2). Symptôme reconnaissable : "trop petit" à une
taille, "trop grand/zoomé" à une taille plus grande, sans qu'aucune
valeur intermédiaire n'ait l'air correcte — signe que l'image manque de
marge propre, pas que la taille est mal réglée.

### Cause technique de la partie "conteneur"

Depuis Android 12 (API 31+), l'OS affiche **son propre** écran de
démarrage natif (SplashScreen API) et **ignore totalement**
`android:windowBackground` / `drawable/launch_background.xml` (le
mécanisme `flutter_native_splash` historique, < API 31 seulement). Sans
configuration explicite pour API 31+, l'OS synthétise sa propre icône
depuis `mipmap/ic_launcher` et lui applique le rétrécissement
automatique prévu pour la "safe zone" des icônes adaptatives (~2/3 de la
zone) — d'où une icône qui semble "à moitié de sa zone, fond blanc
autour", quelle que soit la taille du fichier launcher.

**Fix** : deux fichiers de thème dédiés, à créer systématiquement dès
qu'un projet a une icône de splash personnalisée :

`android/app/src/main/res/values-v31/styles.xml` :
```xml
<resources>
    <style name="LaunchTheme" parent="@android:style/Theme.Light.NoTitleBar">
        <item name="android:windowBackground">@drawable/launch_background</item>
        <item name="android:windowSplashScreenBackground">@android:color/white</item>
        <item name="android:windowSplashScreenAnimatedIcon">@drawable/launch_image</item>
    </style>
    <style name="NormalTheme" parent="@android:style/Theme.Light.NoTitleBar">
        <item name="android:windowBackground">?android:colorBackground</item>
    </style>
</resources>
```
+ son miroir `values-night-v31/styles.xml` (mêmes clés, fond noir /
`Theme.Black.NoTitleBar`). Le nom `windowSplashScreenAnimatedIcon` est
trompeur : un PNG statique (non animé) est parfaitement accepté.

Dans `pubspec.yaml`, le bloc `android_12:` de `flutter_native_splash`
est **obligatoire** pour que ceci soit généré automatiquement — sans
lui, le package ne produit rien pour Android 12+ et le symptôme
"icône trop petite" revient malgré un `launch_image.png` correct.

### Cause technique de la partie "image source"

Si l'icône source du projet est un **badge plein cadre** (fond +
forme + texte déjà intégrés jusqu'au bord de l'image — le cas typique
d'une icône de launcher fournie par un designer, pensée pour qu'un
launcher applique lui-même son masque par-dessus), alors :
- **ne jamais la réutiliser telle quelle** comme
  `windowSplashScreenAnimatedIcon` : la redimensionner ne change que sa
  taille globale, jamais la sensation de "zoom", puisque l'image
  elle-même n'a aucune marge à donner.
- **Générer un dérivé dédié une seule fois**, avec une vraie marge
  transparente :
  1. Rendre transparents les éventuels coins/fonds unis de l'image
     d'origine qui ne font pas partie du motif (flood-fill depuis les 4
     coins du canevas, tolérance sur la couleur, sans toucher l'intérieur
     du motif — non connecté au bord).
  2. Redimensionner ce motif détouré à ~65-70 % d'un nouveau canevas
     carré **transparent** plus grand, centré (30-35 % de marge répartie
     tout autour).
  3. Vérifier par composition sur fond blanc ET noir (simulation des deux
     thèmes) avant de générer les 5 densités — une marge qui a l'air
     propre en clair peut rester un carré blanc visible en sombre si
     l'étape 1 a été sautée (coins blancs opaques au lieu de transparents).
  4. Pointer `flutter_native_splash.image` (et son bloc `android_12`)
     vers ce dérivé, jamais vers l'icône launcher d'origine — sinon toute
     régénération future (`dart run flutter_native_splash:create`)
     réintroduit le même défaut.
- Conteneur de départ raisonnable une fois la marge en place : ~180-200dp
  (mdpi), à ajuster ensuite en un seul paramètre (le dp du conteneur)
  si besoin — jamais en retouchant à nouveau l'image.

## Écran « Infos & À propos » (page TDG standard)

Toutes les apps TDG doivent proposer un écran interne "Infos & À propos"
(logo TDG, à propos de l'app, développeur, contacts, soutien, copyright).
Ne pas ressaisir ces informations à chaque nouveau projet — les reprendre
telles quelles depuis ce bloc.

### Coordonnées TDG (fixes, identiques sur tous les projets)

| Champ | Valeur |
|---|---|
| Société | Taysir Digital Group (TDG) |
| Slogan | « Vos rêves, nos défis » |
| PDG / Développeur | Aliou Mbengue |
| Téléphone | +221 76 455 03 58 (raw pour `tel:`/copie : `+221764550358`) |
| E-mail | taysirdigitalgroup@gmail.com |

| Site web | https://taysirdigitalgroup.github.io/ |

### `AppConstants` réutilisable

```dart
class AppConstants {
  // Identité de l'app — à adapter par projet
  static const String appName = 'NOM_APP';
  static const String appVersion = '1.0.0';
  static const String appSlogan = 'Vos rêves, nos défis';

  // TDG — fixe, ne pas modifier d'un projet à l'autre
  static const String appDeveloper = 'Aliou Mbengue';
  static const String appCompany = 'Taysir Digital Group (TDG)';
  static const String contactPhone1 = '+221 76 455 03 58';
  static const String contactPhone1Raw = '+221764550358';
  static const String contactEmail = 'taysirdigitalgroup@gmail.com';
  // Site web officiel TDG
  static const String websiteUrl = 'https://taysirdigitalgroup.github.io/';

  // Dons — uniquement si le projet en propose (voir écran modèle)
  static const String contactPhone2 = '';       // ex. Orange Money, si différent du tél. principal
  static const String contactPhone2Raw = '';
  static const String paypalUrl = 'https://paypal.me/MBENGUE28';
  static const String waveUrl = '';             // lien marchand Wave du projet
}
```

### Écran modèle

`info_screen.dart` (fourni séparément, à conserver dans
`~/0-apps/tdg-flutter-template/lib/templates/`) contient l'écran complet
prêt à copier dans `lib/screens/` d'un nouveau projet : cartes "À propos
de l'application", "Développeur", "Contacts" et "Nous soutenir" (PayPal +
Wave + numéros copiables), plus le bloc copyright en bas de page. En le
réutilisant sur un nouveau projet :

- adapter les imports (`provider`/thème/constants) à la structure du
  projet cible — le fichier fourni suppose un `AppConstants` comme
  ci-dessus et un `kNavy`/`kGold` définis dans `app_theme.dart`
- s'assurer que `assets/images/<nom_du_logo>.png` existe et est déclaré
  dans `pubspec.yaml` sous `flutter: assets:` (voir convention de nom
  ci-dessous)
- brancher `_launch()` sur un vrai appel `url_launcher`
  (`launchUrl(Uri.parse(url))`) — le fichier fourni utilise volontairement
  un stub `debugPrint` pour ne pas imposer la dépendance par défaut
- retirer ou adapter la carte "Nous soutenir" si le projet ne propose pas
  de dons

### Convention de nom du logo TDG

⚠️ Le nom de fichier a varié selon les projets : `tdg_logo.png` (Scango,
`info_screen.dart`) vs `logo_tdg.png` (Wave Market, Daaray Kaamil, Arabic
Font Studio). **Pour les nouveaux projets, standardiser sur
`assets/images/logo_tdg.png`** (nom majoritaire sur les projets récents)
et mettre à jour `info_screen.dart` en conséquence lors de la prochaine
copie du template.

## Pièges déjà rencontrés (à éviter dès le départ)

1. **`ffmpeg_kit_flutter` est discontinué** (retiré de pub.dev, plus
   maintenu) — ne pas l'utiliser pour du traitement audio/vidéo. Les libs
   Android de pitch-shifting type SoundTouch (JNI/NDK) sont souvent
   anciennes et cassent avec AGP 8.11 / Gradle 8.14 / Kotlin 2.2 (plugin
   `maven` obsolète, vieux CMake). Préférer une implémentation pur Dart
   quand c'est possible (plus lent, mais zéro risque de build natif), ou
   une lib activement maintenue vérifiée au cas par cas.
2. **`record` (plugin fédéré)** : la partie `record_linux` traîne parfois
   une version en retard par rapport à `record_platform_interface`, ce qui
   fait échouer le build même sur un projet Android-only (Flutter résout
   quand même l'implémentation desktop). Fixer avec
   `dependency_overrides: record_linux: ^X.Y.Z` si `flutter pub get`
   échoue là-dessus.
3. **`google_mobile_ads` — `AdSize.getAnchoredAdaptiveBannerAdSize`** est
   asynchrone (`Future<AnchoredAdaptiveBannerAdSize?>`) et prend 2
   arguments **positionnels** (`orientation, width`) — pas d'argument
   nommé `width:`. Toujours `await` cet appel.
4. **`share_plus`** : l'API `SharePlus.instance.share(ShareParams(...))`
   n'existe qu'à partir d'une certaine version récente (10.x+). Sur une
   version plus ancienne, utiliser `Share.share(...)` /
   `Share.shareXFiles(...)`. Vérifier la version réellement résolue avec
   `flutter pub deps` si erreur `SharePlus isn't defined`.
5. **`flutter: generate: true`** dans `pubspec.yaml` active la génération
   l10n/intl et exige un `l10n.yaml` + des fichiers `.arb` sous `lib/l10n/`
   — ne l'activer que si l10n est vraiment mis en place, sinon le build
   échoue pour rien.
6. **Icônes (`flutter_launcher_icons`)** : le fichier `image_path` déclaré
   dans `pubspec.yaml` doit exister avant de lancer
   `flutter pub run flutter_launcher_icons`, sinon erreur immédiate.
7. **Flutter installé via Snap** : le confinement Snap redirige souvent
   `$HOME` vers un dossier propre à la révision installée
   (`~/snap/flutter/<numéro>/...`), pas `~/snap/flutter/common/...` ni
   `~/.gradle`/`~/.pub-cache` classiques. Pour localiser les vrais caches
   Gradle/pub avant un nettoyage : `ls -la ~/snap/flutter/` et inspecter
   chaque dossier numéroté plutôt que de supposer l'emplacement standard.
8. **Icône d'écran de démarrage "trop petite" puis "trop grande/zoomée"
   quel que soit le dp essayé** : ne pas re-tâtonner sur la taille du
   conteneur — voir la section dédiée "Écran de démarrage Android
   (splash, API 31+)" plus haut. Deux causes distinctes à vérifier dans
   l'ordre : (1) thèmes `values-v31`/`values-night-v31` absents/mal
   configurés, (2) icône source plein cadre sans marge interne réutilisée
   telle quelle au lieu d'un dérivé détouré+marge dédié.

## Checklist manuelle (si on ne passe pas par le script)

1. `flutter create --org com.tdg <nom_app>`
2. Remplacer `android/settings.gradle.kts`, `android/gradle.properties`,
   `android/gradle/wrapper/gradle-wrapper.properties`,
   `android/app/build.gradle.kts` par les blocs ci-dessus (adapter
   `namespace`/`applicationId`).
3. Décider si Firebase est nécessaire ; sinon, laisser les lignes
   commentées.
4. `flutter pub get`, puis vérifier tout de suite qu'un `flutter run` /
   `flutter build apk --debug` passe avant d'ajouter des dépendances
   métier.
5. Ajouter les dépendances une par une plutôt qu'en bloc, en re-testant le
   build à chaque ajout sensible (plugins avec partie native/NDK
   notamment).
