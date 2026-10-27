from pathlib import Path
import sqlite3,re,json,hashlib
r=Path(__file__).resolve().parents[1];report=json.loads((r/'source/hadith/import_report.json').read_text())
for book,count in [('bukhari',7105),('muslim',5527)]:
 source=r/'source/hadith'/f'sahih_{book}.sql';assert hashlib.sha256(source.read_bytes()).hexdigest()==report[book]['sha256']
 db=sqlite3.connect(':memory:');db.execute('CREATE TABLE songs(title,content_raw,category_id,author_id,approval_score,status,last_editor_id,author,type)');db.executescript(source.read_text())
 rows=db.execute('SELECT title,content_raw,author FROM songs ORDER BY rowid').fetchall()
 data=json.loads((r/'assets/devotion'/f'hadith_{book}.json').read_text());entries=data['entries'];assert len(rows)==len(entries)==count
 assert sorted(e['id'] for e in entries)==list(range(1,count+1))
 for e in entries:
  title,raw,author=rows[e['id']-1]
  assert e['text']==re.sub(r'<<<.*?>>>','',raw,flags=re.S).strip()
  assert e['references']==[re.sub(r'\s+',' ',s).strip() for s in re.findall(r'<<<(.*?)>>>',raw,re.S)]
  assert e['author']==author and e['title']==re.sub(r'\s+',' ',title).strip()
  number=next((m for ref in e['references'] if (m:=re.search(r'رقم الحديث أو الصفحة:\s*([0-9٠-٩]+)',ref))),None)
  assert e['number']==(int(number[1]) if number else None)
 assert sum(e['number'] is None for e in entries)==(1 if book=='muslim' else 0)
 assert [(e['number'] if e['number'] is not None else 10**9,e['id']) for e in entries]==sorted((e['number'] if e['number'] is not None else 10**9,e['id']) for e in entries)
print('OK : 7105 Bukhari / 5527 Muslim, textes et références fidèles, variantes conservées, numéro manquant non inventé.')
