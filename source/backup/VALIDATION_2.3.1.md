# Correctif 2.3.1+41 — 28 octobre 2026

## Cause et correction

Le verrou `busy` couvre toute l’opération d’import, y compris les deux demandes de confirmation. L’indicateur indéterminé affiché dès que `busy` était vrai continuait donc à produire des frames derrière les boîtes de dialogue : `pumpAndSettle` ne pouvait pas terminer.

Le verrou est conservé, et un second état `awaitingDecision` suspend uniquement l’indicateur durant les choix de l’utilisateur. Le même mécanisme couvre les confirmations de suppression du compte. Les `finally` rétablissent les états après choix, annulation ou exception. Aucun timeout du test n’est augmenté.

## Contrôles

- Contrôle syntaxique avec le formateur Dart 3.9.4 autonome sur les fichiers modifiés.
- Tests widgets renforcés : absence de progression durant les confirmations ; actions toujours désactivées ; progression durant un transfert bloqué par Completer ; annulation du premier avertissement et du résumé ; réimport possible après annulation ; confirmation conserve les attentes de sauvegarde des préférences.
- **Tests Flutter et build APK non exécutés ici.** La compilation Kotlin n’est pas répétée : aucun fichier natif ni aucune dépendance n’a changé.
- Aucun changement de schéma ou de données ; configuration Firebase, clés et google-services.json non modifiés et non inclus dans l’archive.
