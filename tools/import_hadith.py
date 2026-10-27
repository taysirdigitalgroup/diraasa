"""Import supplied hadith SQL, one record per source INSERT; no deduplication.
Source numbers can repeat for variants. Never renumber the religious references.
"""
from pathlib import Path
import sqlite3,re,json,hashlib
r=Path(__file__).resolve().parents[1];report={}
for book in ['bukhari','muslim']:
 source=r/'source/hadith'/f'sahih_{book}.sql'
 db=sqlite3.connect(':memory:');db.execute('CREATE TABLE songs(title,content_raw,category_id,author_id,approval_score,status,last_editor_id,author,type)');db.executescript(source.read_text())
 rows=db.execute('SELECT title,content_raw,author FROM songs ORDER BY rowid').fetchall();entries=[]
 for i,(title,raw,author) in enumerate(rows,1):
  refs=[re.sub(r'\s+',' ',m).strip() for m in re.findall(r'<<<(.*?)>>>',raw,re.S)]
  body=re.sub(r'<<<.*?>>>','',raw,flags=re.S).strip()
  numbers=[re.search(r'رقم الحديث أو الصفحة:\s*([0-9٠-٩]+)',s) for s in refs]
  number=next((int(m[1]) for m in numbers if m),None)
  assert body and refs,(book,i)
  entries.append({'id':i,'number':number,'title':re.sub(r'\s+',' ',title).strip(),'text':body,'references':refs,'author':author})
 entries.sort(key=lambda e:(e['number'] if e['number'] is not None else 10**9,e['id']))
 data={'book':book,'title':'صحيح البخاري' if book=='bukhari' else 'صحيح مسلم','entries':entries}
 (r/'assets/devotion'/f'hadith_{book}.json').write_text(json.dumps(data,ensure_ascii=False,separators=(',',':')))
 report[book]={'source':source.name,'sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'entries':len(entries),'missing_numbers':sum(e['number'] is None for e in entries),'unique_numbers':len({e['number'] for e in entries if e['number'] is not None}),'minimum_number':min(e['number'] for e in entries if e['number'] is not None),'maximum_number':max(e['number'] for e in entries if e['number'] is not None),'numbering':'Source references retained, including variants/repeated numbers; ids are source row positions.'}
(r/'source/hadith/import_report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2))
print(report)
