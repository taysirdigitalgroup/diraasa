"""Optional after overlay extraction: remove only the old identical bundled asset.
Never touches installed app data, imported audio, notes or preferences.
"""
from pathlib import Path
import hashlib
r=Path(__file__).resolve().parents[1];folder=r/'android/app/src/main/assets/audio'
old=folder/'adhan_2.m4a';new=folder/'Serigne Mbacké Fall - 🇸🇳 Senegal المسجد طوبي، السنغال.m4a'
if old.is_file() and new.is_file():
 if hashlib.sha256(old.read_bytes()).digest()==hashlib.sha256(new.read_bytes()).digest():
  old.unlink();print('Ancien asset identique supprimé ; fichier renommé conservé.')
 else:raise SystemExit('Contenus différents : aucun fichier supprimé.')
else:print('Aucun doublon ancien à supprimer.')
