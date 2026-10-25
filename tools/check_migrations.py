"""Verify the SQL used by NotesDatabase preserves all historical note fields."""
import sqlite3, re
from pathlib import Path
source=(Path(__file__).resolve().parents[1]/'android/app/src/main/kotlin/com/tdg/diraasa/NotesDatabase.kt').read_text()
statements=re.findall(r'db.execSQL\("([^"]+)"\)',source)
assert len(statements)==2
assert not re.search(r'\b(DROP|DELETE|REPLACE)\b',' '.join(statements),re.I)
for old_version in (0,1,2):
    db=sqlite3.connect(':memory:')
    db.execute(statements[0])
    db.execute("insert into notes values(?,?,?,?,?,?,?,?)",(37,'عنوان','نص محفوظ','Auteur','Vers',1700000000000,1700000000200,1))
    db.execute('pragma user_version='+str(old_version))
    before=db.execute('select * from notes').fetchall()
    # Historical user_version=0 enters onCreate; version=1 enters onUpgrade.
    with db:
        if old_version==0: db.execute(statements[0])
        db.execute(statements[1])
        db.execute('pragma user_version=2')
    assert before==db.execute('select * from notes').fetchall()
    assert db.execute('pragma user_version').fetchone()[0]==2
    db.execute(statements[1]) # Idempotence.
    db.execute("insert into notes(title,body,kind,created,updated) values('suite','texte','Cours',1,1)")
    assert db.execute('select count(*) from notes').fetchone()[0]==2
    db.close()
fresh=sqlite3.connect(':memory:')
for sql in statements: fresh.execute(sql)
assert fresh.execute('select count(*) from notes').fetchone()[0]==0
print('OK : création, adoption v0, migration v1→v2, réouverture v2, contenu/IDs/dates/auteur/épinglage conservés.')
