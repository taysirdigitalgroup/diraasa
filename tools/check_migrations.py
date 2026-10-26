"""Exercise actual migration SQL and model native catalog/profile operations."""
import sqlite3, re, unicodedata
from pathlib import Path
source=(Path(__file__).resolve().parents[1]/'android/app/src/main/kotlin/com/tdg/diraasa/NotesDatabase.kt').read_text()
sql=re.findall(r'db.execSQL\("([^"]+)"\)',source)
# Ignore bound UPDATE in migration here; execute it with modeled bound IDs below.
schema=[s for s in sql if s.startswith(('CREATE','ALTER'))]
assert len(schema)==7, schema
assert 'null, 4)' in source and 'if (oldVersion < 4) addV4Profiles(db)' in source
assert not any(re.search(r'\b(DROP|DELETE|REPLACE)\b',s,re.I) for s in schema)

def label(raw):return re.sub(r'\s+',' ',unicodedata.normalize('NFC',raw)).strip()
def identity(raw):return label(raw).lower()
def remember(db,field,raw):
    value=label(raw)
    if not value:return ''
    db.execute('INSERT OR IGNORE INTO note_references VALUES(?,?,?)',(field,identity(value),value))
    return db.execute('SELECT label FROM note_references WHERE field=? AND identity=?',(field,identity(value))).fetchone()[0]
def author(db,raw):
    name=remember(db,'author',raw)
    if not name:return None
    db.execute('INSERT OR IGNORE INTO authors(identity,name) VALUES(?,?)',(identity(name),name))
    return db.execute('SELECT id FROM authors WHERE identity=?',(identity(name),)).fetchone()[0]
def seed_refs(db):
    for title,name in db.execute('SELECT title,author FROM notes ORDER BY id').fetchall():
        remember(db,'title',title);remember(db,'author',name)
def seed_authors(db):
    for value, in db.execute("SELECT label FROM note_references WHERE field='author'").fetchall():author(db,value)
    for note_id,name in db.execute('SELECT id,author FROM notes').fetchall():
        db.execute('UPDATE notes SET author_id=? WHERE id=?',(author(db,name or ''),note_id))

for old in (0,1,2,3,4):
    db=sqlite3.connect(':memory:')
    db.execute(schema[0])
    fixtures=[(37,'عنوان','نص محفوظ','Auteur','Vers',1700000000000,1700000000200,1),
              (38,' عنوان ','autre','  AUTEUR ','Cours',1,2,0),
              (39,'Sans auteur','texte','','Livre',1,2,0)]
    db.executemany('INSERT INTO notes VALUES(?,?,?,?,?,?,?,?)',fixtures)
    if old>=2:db.execute(schema[1])
    if old>=3:db.execute(schema[2]);seed_refs(db)
    if old==4:
        for statement in schema[3:]:db.execute(statement)
        seed_authors(db)
    before=db.execute('SELECT id,title,body,author,kind,created,updated,pinned FROM notes').fetchall()
    db.execute('PRAGMA user_version='+str(old))
    with db:
        if old<2:db.execute(schema[1])
        if old<3:db.execute(schema[2]);seed_refs(db)
        if old<4:
            for statement in schema[3:]:db.execute(statement)
            seed_authors(db)
        db.execute('PRAGMA user_version=4')
    assert before==db.execute('SELECT id,title,body,author,kind,created,updated,pinned FROM notes').fetchall()
    assert db.execute('SELECT count(*) FROM authors').fetchone()[0]==1
    first=author(db,'AUTEUR\u00a0')
    assert first==author(db,'  Auteur  ')
    assert db.execute('SELECT author_id FROM notes WHERE id=37').fetchone()[0]==first
    assert db.execute('SELECT author_id FROM notes WHERE id=39').fetchone()[0] is None
    assert db.execute('SELECT body_format FROM notes WHERE id=37').fetchone()[0]==''
    db.execute("UPDATE authors SET name='Nom modifié',identity='nom modifié',photo='photo.img',bio='Biographie' WHERE id=?",(first,))
    assert db.execute('SELECT a.name,a.photo FROM notes n JOIN authors a ON n.author_id=a.id WHERE n.id=37').fetchone()==('Nom modifié','photo.img')
    second=author(db,'Autre auteur')
    try:
        db.execute("UPDATE authors SET identity='nom modifié' WHERE id=?",(second,))
        raise AssertionError('Unique identity not enforced')
    except sqlite3.IntegrityError:pass
    db.execute('DELETE FROM notes')
    assert db.execute('SELECT count(*) FROM authors').fetchone()[0]==2
    db.commit()
    try:
        with db:
            author(db,'Échec');raise ValueError('rollback save')
    except ValueError:pass
    assert db.execute("SELECT count(*) FROM authors WHERE name='Échec'").fetchone()[0]==0
    db.close()
print('OK : SQL v4, migrations v0/v1/v2/v3, réouverture v4, notes préservées, auteurs uniques liés, photo/renommage, rollback.')
