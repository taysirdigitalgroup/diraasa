"""Reconstruct 132 chapters/267 entries from the user's 90 SQL blocks.
Keep the complete original blocks (including every footnote) available in-app.
"""
from pathlib import Path
import sqlite3,re,json,hashlib
r=Path(__file__).resolve().parents[1];source=r/'source/devotion/hisnul_muslim.sql'
db=sqlite3.connect(':memory:');db.execute('CREATE TABLE songs(title,content_raw,category_id,author_id,approval_score,status,last_editor_id,author)');db.executescript(source.read_text())
rows=db.execute('SELECT title,content_raw FROM songs ORDER BY rowid').fetchall();assert len(rows)==90
body=[];notes=[]
for title,raw in rows:
 parts=raw.split('--- الحواشي ---');body.append(parts[0].strip())
 for tail in parts[1:]:
  paragraphs=re.split(r'\n\s*\n',tail.strip(),maxsplit=1)
  notes.append(paragraphs[0])
  if len(paragraphs)>1:body.append(paragraphs[1])
body='\n'.join(body);digits=str.maketrans('٠١٢٣٤٥٦٧٨٩','0123456789')
markers=list(re.finditer(r'^\s*([٠-٩0-9]+)\s*[-–]\s*(.+)$',body,re.M))
heads=[];expected=1
for m in markers:
 n=int(m[1].translate(digits));text=m[2].strip()
 if n==expected and not text.startswith(('(','{','«','"')) and len(text)<200:heads.append(m);expected+=1
assert len(heads)==132
headpositions={m.start() for m in heads};entries=[];expected=1
for m in markers:
 n=int(m[1].translate(digits))
 if n==expected and m.start() not in headpositions:entries.append(m);expected+=1
assert len(entries)==267
chapters=[]
for i,head in enumerate(heads):
 end=heads[i+1].start() if i+1<len(heads) else len(body);found=[]
 selected=[m for m in entries if head.end()<=m.start()<end]
 for j,m in enumerate(selected):
  entry_end=selected[j+1].start() if j+1<len(selected) else end
  found.append({'id':int(m[1].translate(digits)),'text':body[m.start():entry_end].strip(),'count':1,'customCount':True})
 chapters.append({'id':i+1,'title':head[2].strip(),'entries':found,'body':body[head.end():end].strip(),'preface':body[head.end():selected[0].start() if selected else end].strip()})
assert sum(len(c['entries']) for c in chapters)==267
out={'source':'hisnul_muslim.sql fourni par utilisateur','book':'حصن المسلم','chapters':chapters,
 'introduction':body[:heads[0].start()].strip(),'footnotes':notes,'sourceBlocks':[{'title':title,'text':raw} for title,raw in rows]}
(r/'assets/devotion/hisn.json').write_text(json.dumps(out,ensure_ascii=False,separators=(',',':')))
(r/'source/devotion/hisn_provenance.json').write_text(json.dumps({'source':source.name,'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'blocks':90,'chapters':132,'entries':267,'footnote_blocks':len(notes),'counter_counts':'User-defined: default 1, reviewed in editor; never inferred from the book prose.'},indent=2))
print('Hisn utilisateur : 90 blocs, 132 chapitres, 267 entrées ;',len(notes),'blocs de notes conservés.')
