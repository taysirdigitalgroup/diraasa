"""Rebuild the read-only dictionary from the supplied SQL. Python stdlib only."""
import sqlite3, re, json, hashlib, sys
from pathlib import Path
def normalize(s):
    s=re.sub(r'[\u0610-\u061a\u064b-\u065f\u0670\u06d6-\u06edـ]', '',s)
    return s.translate(str.maketrans('أإآٱى','ااااي'))
def build(source, dest):
    raw=Path(source).read_text()
    src=sqlite3.connect(':memory:')
    src.execute('CREATE TABLE songs(title,content_raw,category_id,author_id,approval_score,status,last_editor_id,author)')
    src.executescript(raw)
    Path(dest).unlink(missing_ok=True)
    db=sqlite3.connect(dest)
    db.executescript("""
    CREATE TABLE entries(id INTEGER PRIMARY KEY, word TEXT, root TEXT, definition TEXT, normalized TEXT, letter TEXT, page INTEGER);
    CREATE INDEX entries_word ON entries(normalized);
    CREATE INDEX entries_letter ON entries(letter,normalized);
    CREATE TABLE pages(id INTEGER PRIMARY KEY,title TEXT,content TEXT);
    CREATE VIRTUAL TABLE search USING fts4(terms, tokenize=unicode61);
    """)
    count=0
    for i,(title,content) in enumerate(src.execute('SELECT title,content_raw FROM songs'),1):
        db.execute('INSERT INTO pages VALUES(?,?,?)',(i,title,content))
        if i<=5: continue
        text=content.strip()
        # Source blocks already represent one root article or cross-reference.
        prefix=text.split(':',1)[0]
        root=prefix if ':' in text and len(prefix)<35 else ''
        words=re.findall(r'\(([^()]+)\)',text)
        word=words[0] if root and words else (root or text.split()[0])
        if i==6: word='الألف';root='ا'
        norm=normalize(word)
        aliases=' '.join([normalize(text), normalize(root).replace(' ',''),norm])
        db.execute('INSERT INTO entries VALUES(?,?,?,?,?,?,?)',(i,word,root,text,norm,norm[:1],i))
        db.execute('INSERT INTO search(docid,terms) VALUES(?,?)',(i,aliases))
        count+=1
    db.commit()
    assert db.execute('PRAGMA integrity_check').fetchone()[0]=='ok'
    assert db.execute('SELECT count(*) FROM pages').fetchone()[0]==3772
    for i,text in db.execute('SELECT id,definition FROM entries'):
        assert text==src.execute('SELECT content_raw FROM songs LIMIT 1 OFFSET ?',(i-1,)).fetchone()[0].strip()
    report={'source_blocks':3772,'articles':count,'intro_blocks':5,'source_sha256':hashlib.sha256(Path(source).read_bytes()).hexdigest(),'preserved_text':True}
    Path(dest).with_suffix('.json').write_text(json.dumps(report,ensure_ascii=False,indent=2))
    db.close()
    print(json.dumps(report))
if __name__=='__main__': build(sys.argv[1],sys.argv[2])
