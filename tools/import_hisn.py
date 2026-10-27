"""Reconstruct 132 chapters/267 entries from the user's 90 SQL blocks.
Keep the complete original blocks (including every footnote) available in-app.
"""
from pathlib import Path
import sqlite3,re,json,hashlib
r=Path(__file__).resolve().parents[1];source=r/'source/devotion/hisnul_muslim.sql'
db=sqlite3.connect(':memory:');db.execute('CREATE TABLE songs(title,content_raw,category_id,author_id,approval_score,status,last_editor_id,author)');db.executescript(source.read_text())
rows=db.execute('SELECT title,content_raw FROM songs ORDER BY rowid').fetchall();assert len(rows)==90
body=[];notes=[];linked=[]
for title,raw in rows:
 parts=raw.split('--- الحواشي ---')
 pending=parts[0].strip()
 for tail in parts[1:]:
  paragraphs=re.split(r'\n\s*\n',tail.strip(),maxsplit=1)
  foot=paragraphs[0];notes.append(foot)
  matches=list(re.finditer(r'^\(([٠-٩0-9]+)\)\s*',foot,re.M))
  refs={m[1]:foot[m.start():matches[i+1].start() if i+1<len(matches) else len(foot)].strip() for i,m in enumerate(matches)}
  def attach(m):
   # A leading parenthesized entry number is not a bibliographic callout.
   before=pending[pending.rfind('\n',0,m.start())+1:m.start()]
   if re.fullmatch(r'\s*[٠-٩0-9]+\s*[-–]\s*',before) or m[1] not in refs:return m[0]
   linked.append(refs[m[1]])
   return '\ue000'+str(len(linked)-1)+'\ue001'
  body.append(re.sub(r'\(([٠-٩0-9]+)\)',attach,pending))
  pending=paragraphs[1] if len(paragraphs)>1 else ''
 body.append(pending)
def clean(text):
 text=re.sub(r'\ue000[0-9]+\ue001','',text).strip()
 # Only join scraping line breaks inside invocation delimiters. Keep prose/entries apart.
 def flow(m):
  return re.sub(r'\s+([.،؛])',r'\1',re.sub(r'(?<![.])\n\s*',' ',m[0]))
 return re.sub(r'\s+([.،؛])',r'\1',re.sub(r'\(\(.*?\)\)',flow,text,flags=re.S))
def references(text):
 return list(dict.fromkeys(linked[int(n)] for n in re.findall(r'\ue000([0-9]+)\ue001',text)))
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
  found.append({'id':int(m[1].translate(digits)),'text':clean(body[m.start():entry_end]),'references':references(body[m.start():entry_end]),'count':1,'customCount':True})
 chapters.append({'id':i+1,'title':clean(head[2]),'entries':found,'body':clean(body[head.end():end]),'preface':clean(body[head.end():selected[0].start() if selected else end])})
assert sum(len(c['entries']) for c in chapters)==267
out={'source':'hisnul_muslim.sql fourni par utilisateur','book':'حصن المسلم','chapters':chapters,
 'introduction':clean(body[:heads[0].start()]),'footnotes':notes,'sourceBlocks':[{'title':title,'text':raw} for title,raw in rows]}
(r/'assets/devotion/hisn.json').write_text(json.dumps(out,ensure_ascii=False,separators=(',',':')))
(r/'source/devotion/hisn_provenance.json').write_text(json.dumps({'source':source.name,'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'blocks':90,'chapters':132,'entries':267,'footnote_blocks':len(notes),'counter_counts':'User-defined: default 1, reviewed in editor; never inferred from the book prose.'},indent=2))
print('Hisn utilisateur : 90 blocs, 132 chapitres, 267 entrées ;',len(notes),'blocs de notes conservés.')
