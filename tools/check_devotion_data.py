"""Read-only integrity audit of generated assets against the user's sources."""
from pathlib import Path
import json,sqlite3,re,hashlib,xml.etree.ElementTree as ET
from fontTools.ttLib import TTFont
r=Path(__file__).resolve().parents[1]
for reading,total,family in [('hafs',6236,'Hafs'),('warsh',6214,'Warsh')]:
 source=r/'source/devotion'/('quran_'+reading+'.sql')
 data=json.loads((r/'assets/devotion'/('quran_'+reading+'.json')).read_text())
 chapters=data['chapters'];assert [c['number'] for c in chapters]==list(range(1,115))
 assert sum(len(c['verses']) for c in chapters)==total
 assert not chapters[8]['basmala']
 cmap=TTFont(r/'assets/fonts'/('KFGQPC-'+family+'-Uthmanic.ttf')).getBestCmap()
 for c in chapters:
  assert [v['number'] for v in c['verses']]==list(range(1,len(c['verses'])+1))
  for v in c['verses']:
   assert v['text'] and 'مكتوبة كاملة' not in v['text'] and '|' not in v['text']
   assert all(ch.isspace() or ord(ch) in cmap for ch in v['text']),(reading,c['number'],v['number'])
 report=json.loads((r/'source/devotion/import_report.json').read_text())[reading]
 assert report['source_sha256']==hashlib.sha256(source.read_bytes()).hexdigest()
 assert chapters[2]['verses'][22]['number']==23
source=r/'source/devotion/hisnul_muslim.sql'
db=sqlite3.connect(':memory:');db.execute('CREATE TABLE songs(title,content_raw,category_id,author_id,approval_score,status,last_editor_id,author)');db.executescript(source.read_text())
rows=db.execute('SELECT title,content_raw FROM songs ORDER BY rowid').fetchall()
hisn=json.loads((r/'assets/devotion/hisn.json').read_text());assert len(hisn['chapters'])==132
assert [(c['title'],c['text']) for c in hisn['sourceBlocks']]==rows
assert [e['id'] for c in hisn['chapters'] for e in c['entries']]==list(range(1,268))
assert all(e['customCount'] and e['count']==1 for c in hisn['chapters'] for e in c['entries'])
assert len(hisn['footnotes'])==138
entries=[e for c in hisn['chapters'] for e in c['entries']]
assert all(e['references'] for e in entries)
assert sum(len(e['references']) for e in entries)==300
for e in entries:
 assert '\ue000' not in e['text'] and '\ue001' not in e['text']
 for reference in e['references']:
  assert any(reference in block for block in hisn['footnotes'])
assert 'البخاري' in entries[0]['references'][0]
assert '٦٣١٤' in entries[0]['references'][0]
assert '١١٥٤' in entries[1]['references'][0]
assert '\n' not in next(e for e in entries if e['id']==53)['text']


manifest=ET.parse(r/'android/app/src/main/AndroidManifest.xml');name='{http://schemas.android.com/apk/res/android}name'
receivers={e.get(name) for e in manifest.findall('application/receiver')}
assert {'.AzanReceiver','.ZikrReminderReceiver'}<=receivers
assert manifest.find('application/service').get('{http://schemas.android.com/apk/res/android}foregroundServiceType')=='mediaPlayback'
print('OK : Hafs 6236 / Warsh 6214, 114 sourates chacun, glyphes couverts ; Hisn 132 chapitres/267 entrées/138 notes et 90 blocs originaux intacts ; manifest azan/rappels.')
