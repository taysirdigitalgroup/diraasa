"""Validate bundled clips are audio-only and complete compared with the supplied archive.
Usage: python3 tools/check_audio.py [path/to/adhans.tar.gz]
"""
from pathlib import Path
import json, subprocess,sys,tarfile,tempfile
r=Path(__file__).resolve().parents[1];folder=r/'android/app/src/main/assets/audio'
catalog=json.loads((folder/'catalog.json').read_text());assert len(catalog)==8
serigne='Serigne Mbacké Fall - 🇸🇳 Senegal المسجد طوبي، السنغال'
assert catalog[1]['label']==serigne and Path(catalog[1]['id']).name==serigne+'.m4a'


def probe(path):
 return json.loads(subprocess.check_output(['ffprobe','-v','quiet','-show_streams','-show_format','-of','json',str(path)]))
for item in catalog:
 path=folder/Path(item['id']).name;info=probe(path)
 assert len(info['streams'])==1 and info['streams'][0]['codec_type']=='audio'
 assert info['streams'][0]['channels']==1
 assert float(info['format']['duration'])>30
 assert path.stat().st_size==item['bytes']
assert float(probe(folder/'reminder.ogg')['format']['duration'])>0
reminders=json.loads((folder/'reminders.json').read_text())
assert len(reminders)==6 and len({r['id'] for r in reminders})==6
for item in reminders:
 path=folder/Path(item['id']).name;info=probe(path)
 assert 0<float(info['format']['duration'])<=8.1
 assert len(info['streams'])==1 and info['streams'][0]['codec_type']=='audio'
 if 'bytes' in item:assert path.stat().st_size==item['bytes']
if len(sys.argv)>1:
 with tarfile.open(sys.argv[1]) as t,tempfile.TemporaryDirectory() as tmp:
  original=[m for m in t if m.isfile() and m.name.endswith('.mp3')]
  assert len(original)==len(catalog)
  for i,m in enumerate(original):
   path=Path(tmp)/f'{i}.mp3';path.write_bytes(t.extractfile(m).read())
   before=float(probe(path)['format']['duration']);after=float(probe(folder/Path(catalog[i]['id']).name)['format']['duration'])
   assert abs(before-after)<1,(m.name,before,after)
print('OK : 8 adhans AAC mono et 6 sons de rappel, catalogues et fichiers vérifiés ; durées originales comparées si archive source fournie.')
