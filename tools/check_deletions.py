"""Check delete SQL preserves notes and refuses a nonempty theme."""
import sqlite3,re,json,unicodedata
from pathlib import Path
r=Path(__file__).resolve().parents[1]
helper=(r/'android/app/src/main/kotlin/com/tdg/diraasa/NotesDatabase.kt').read_text()
native=(r/'android/app/src/main/kotlin/com/tdg/diraasa/MainActivity.kt').read_text()
db=sqlite3.connect(':memory:')
for sql in re.findall(r'db.execSQL\("([^"]+)"\)',helper):
    if sql.startswith(('CREATE','ALTER')):db.execute(sql)
db.execute("INSERT INTO authors(id,identity,name) VALUES(1,'auteur','Auteur'),(2,'autre','Autre')")
db.execute("INSERT INTO note_references VALUES('author','auteur','Auteur'),('title','theme','Theme'),('title','vide','Vide')")
db.executemany('INSERT INTO notes(id,title,body,author,kind,created,updated,pinned,author_id,body_format) VALUES(?,?,?,?,?,?,?,?,?,?)',[
    (1,'Theme','texte','Auteur','Cours',1,2,1,1,'[]'),(2,'Theme','نص','Autre','Vers',3,4,0,2,'[]')])
before=db.execute('SELECT id,title,body,kind,created,updated,pinned,body_format FROM notes').fetchall()
block=native.split('"deleteAuthor" ->',1)[1].split('"saveAuthor" ->',1)[0]
clear=json.loads(re.search(r'notes.execSQL\(("[^"]+")',block).group(1))
with db:
    db.execute(clear,(1,))
    db.execute("DELETE FROM note_references WHERE field='author' AND identity=?",('auteur',))
    db.execute('DELETE FROM authors WHERE id=?',(1,))
assert db.execute('SELECT author,author_id FROM notes WHERE id=1').fetchone()==('',None)
assert db.execute('SELECT author,author_id FROM notes WHERE id=2').fetchone()==('Autre',2)
assert before==db.execute('SELECT id,title,body,kind,created,updated,pinned,body_format FROM notes').fetchall()
def identity(s):return re.sub(r'\s+',' ',unicodedata.normalize('NFC',s)).strip().lower()
def delete_theme(label):
    with db:
        key=identity(label)
        if any(identity(row[0] or '')==key for row in db.execute('SELECT title FROM notes')):raise ValueError('Not empty')
        db.execute("DELETE FROM note_references WHERE field='title' AND identity=?",(key,))
try:delete_theme(' THEME ');raise AssertionError('Should refuse nonempty theme')
except ValueError:pass
delete_theme('VIDE')
assert db.execute("SELECT count(*) FROM note_references WHERE identity='vide'").fetchone()[0]==0
assert db.execute("SELECT count(*) FROM note_references WHERE identity='theme'").fetchone()[0]==1
assert 'NotesDatabase.identity(c.getString(0) ?: "") != identity' in native
print('OK : auteur supprimé, notes préservées/auteur vide, autre auteur intact ; thème occupé refusé, thème vide supprimé.')
