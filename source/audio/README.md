# Audio intégré
Les huit adhans viennent de adhans.tar.gz fourni par l’utilisateur. Conversion
FFmpeg : suppression du flux vidéo éventuel, AAC mono 24 kHz 32 kbit/s, durée
complète. Aucune coupure, accélération ou boucle dans les adhans.
Le catalogue conserve le nom d’origine pour l’affichage.
Signal de rappel : Kenney Digital Audio, CC0, URL et fichier dans provenance.json,
licence conservée. Répété par le service pendant 30 secondes maximum.
Lecture via USAGE_ALARM, bouton Arrêter ; le volume et les restrictions du système
s’appliquent. Ne garantit pas un son en cas de téléphone éteint ou d’arrêt forcé.
Reproduction facultative : python3 tools/prepare_audio.py /chemin/adhans.tar.gz
Validation : python3 tools/check_audio.py /chemin/adhans.tar.gz
Le script de préparation requiert FFmpeg et télécharge le signal CC0 ; il n’est
jamais exécuté par l’application ni par tools/setup.sh.
