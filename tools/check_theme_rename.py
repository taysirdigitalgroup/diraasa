"""Exercise the native rename UPDATE and its preservation/uniqueness contract."""
import sqlite3,re,json,unicodedata
from pathlib import Path
r=Path(__file__).resolve().parents[1]
source=(r/'android/app/src/main/kotlin/com/tdg/diraasa/MainActivity.kt').read_text()
helper=(r/'android/app/src/main/kotlin/com/tdg/diraasa/NotesDatabase.kt').read_text()
db=sqlite3.connect(':memory:')
for sql in re.findall(r'db.execSQL\("([^"]+)"\)',helper):
    if sql.startswith(('CREATE','ALTER')):db.execute(sql)
db.execute("INSERT INTO note_references VALUES('title','theme','Theme'),('title','autre','Autre')")
db.executemany('INSERT INTO notes(id,title,body,author,kind,created,updated,pinned,body_format) VALUES(?,?,?,?,?,?,?,?,?)',[
    (1,'Theme','texte','Auteur','Cours',1,2,1,'[]'),(2,' THEME ','نص','Autre','Vers',3,4,0,'[]')])
db.commit()
block=source.split('"renameTheme" ->',1)[1].split('"deleteTheme" ->',1)[0]
update=json.loads(re.search(r'notes.execSQL\(("[^"]+")',block).group(1))
def label(s):return re.sub(r'\s+',' ',unicodedata.normalize('NFC',s)).strip()
def identity(s):return label(s).lower()
def rename(old,new):
    with db:
        key=identity(old);value=label(new);target=identity(new)
        if not target:raise ValueError('empty')
        if not db.execute("SELECT 1 FROM note_references WHERE field='title' AND identity=?",(key,)).fetchone():raise ValueError('missing')
        if key!=target and db.execute("SELECT 1 FROM note_references WHERE field='title' AND identity=?",(target,)).fetchone():raise ValueError('duplicate')
        ids=[row[0] for row in db.execute('SELECT id,title FROM notes').fetchall() if identity(row[1])==key]
        for note_id in ids:db.execute(update,(value,note_id))
        db.execute("DELETE FROM note_references WHERE field='title' AND identity=?",(key,))
        db.execute("INSERT INTO note_references VALUES('title',?,?)",(target,value))
before=db.execute('SELECT id,body,author,kind,created,updated,pinned,body_format FROM notes').fetchall()
rename('theme',' Sujet   partagé ')
assert db.execute('SELECT DISTINCT title FROM notes').fetchall()==[('Sujet partagé',)]
assert before==db.execute('SELECT id,body,author,kind,created,updated,pinned,body_format FROM notes').fetchall()
rename('sujet partagé','SUJET PARTAGÉ')
assert db.execute('SELECT DISTINCT title FROM notes').fetchall()==[('SUJET PARTAGÉ',)]
try:rename('sujet partagé','Autre');raise AssertionError('duplicate accepted')
except ValueError:pass
assert db.execute('SELECT DISTINCT title FROM notes').fetchall()==[('SUJET PARTAGÉ',)]
assert 'identity == oldIdentity || !it.moveToFirst()' in block
print('OK : renommage thème transactionnel, notes associées actualisées, contenu/dates/épingles/styles préservés, doublons refusés.')
