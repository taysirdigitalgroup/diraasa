"""Validate bundled clips are audio-only and complete compared with the supplied archive.
Usage: python3 tools/check_audio.py [path/to/adhans.tar.gz]
"""
from pathlib import Path
import json, subprocess,sys,tarfile,tempfile
r=Path(__file__).resolve().parents[1];folder=r/'android/app/src/main/assets/audio'
catalog=json.loads((folder/'catalog.json').read_text());assert len(catalog)==8

def probe(path):
 return json.loads(subprocess.check_output(['ffprobe','-v','quiet','-show_streams','-show_format','-of','json',str(path)]))
for item in catalog:
 path=folder/Path(item['id']).name;info=probe(path)
 assert len(info['streams'])==1 and info['streams'][0]['codec_type']=='audio'
 assert info['streams'][0]['channels']==1
 assert float(info['format']['duration'])>30
 assert path.stat().st_size==item['bytes']
assert float(probe(folder/'reminder.ogg')['format']['duration'])>0
if len(sys.argv)>1:
 with tarfile.open(sys.argv[1]) as t,tempfile.TemporaryDirectory() as tmp:
  original=[m for m in t if m.isfile() and m.name.endswith('.mp3')]
  assert len(original)==len(catalog)
  for i,m in enumerate(original):
   path=Path(tmp)/f'{i}.mp3';path.write_bytes(t.extractfile(m).read())
   before=float(probe(path)['format']['duration']);after=float(probe(folder/Path(catalog[i]['id']).name)['format']['duration'])
   assert abs(before-after)<1,(m.name,before,after)
print('OK : 8 adhans AAC mono, catalogue vérifié ; son CC0 intégré ; durées vérifiées si archive source fournie.')
