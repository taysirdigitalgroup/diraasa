"""Deterministic import of the user's SQL, preserving Uthmanic text and numbering."""
from pathlib import Path
import sqlite3,re,json,hashlib
r=Path(__file__).resolve().parents[1]
report={}
for reading in ['hafs','warsh']:
 source=r/'source/devotion'/('quran_'+reading+'.sql')
 db=sqlite3.connect(':memory:');db.execute('CREATE TABLE songs(title,content_raw,category_id,author_id,approval_score,status,last_editor_id)');db.executescript(source.read_text())
 rows=db.execute('SELECT title,content_raw FROM songs ORDER BY rowid').fetchall();assert len(rows)==114
 chapters=[];total=0
 for number,(title,raw) in enumerate(rows,1):
  title=re.sub(r'\s+مكتوبة.*$','',title).strip()
  lines=raw.splitlines();basmala='';body=[]
  for line in lines:
   if line.strip().startswith('<<<'):continue
   if line.strip().startswith('+++'):basmala=line.strip()[3:].strip();continue
   body.append(line)
  body='\n'.join(body).strip()
  editorial=title+' مكتوبة كاملة بالتشكيل | كتابة وقراءة '
  if reading=='hafs' and number in (16,17):
   assert body.startswith(editorial)
   body=body[len(editorial):]
  verses=[];cursor=0
  for marker in re.finditer(r'\((\d+)\)',body):
   text=body[cursor:marker.start()].strip();assert text,(reading,number,marker[0])
   verses.append({'number':int(marker[1]),'text':text});cursor=marker.end()
  assert not body[cursor:].strip(),(reading,number,'trailing content')
  if reading=='hafs' and number==1:
   assert verses[0]['number']==2 and basmala
   verses.insert(0,{'number':1,'text':basmala});basmala=''
  assert [v['number'] for v in verses]==list(range(1,len(verses)+1)),(reading,number)
  assert number!=9 or not basmala
  total+=len(verses);chapters.append({'number':number,'title':title,'basmala':basmala,'verses':verses})
 book={'reading':reading,'chapters':chapters}
 (r/'assets/devotion'/('quran_'+reading+'.json')).write_text(json.dumps(book,ensure_ascii=False,separators=(',',':')))
 report[reading]={'editorial_prefixes_removed':[16,17] if reading=='hafs' else [],'chapters':114,'verses':total,'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest()}
assert report['hafs']['verses']==6236 and report['warsh']['verses']==6214
(r/'source/devotion/import_report.json').write_text(json.dumps(report,indent=2))
print(report)
