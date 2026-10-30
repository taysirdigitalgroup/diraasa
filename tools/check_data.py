import sqlite3
from pathlib import Path
p=Path(__file__).resolve().parents[1]
db=sqlite3.connect('file:'+str(p/'assets/dictionary.db')+'?mode=ro',uri=True)
assert db.execute('pragma integrity_check').fetchone()[0]=='ok'
assert db.execute('select count(*) from entries').fetchone()[0]==3767
assert db.execute('select count(*) from pages').fetchone()[0]==5
assert db.execute('pragma user_version').fetchone()[0]==2
assert db.execute('select count(*) from pages where id>5').fetchone()[0]==0
assert db.execute("select count(*) from search where terms match 'علم*'").fetchone()[0]>0
assert db.execute("select count(*) from entries where normalized like 'اب%'").fetchone()[0]>0
assert db.execute("select count(*) from entries where letter='ب'").fetchone()[0]>0
assert db.execute("select count(*) from entries where normalized like ? escape '\\'",('ا%',)).fetchone()[0]>0
assert (p/'assets/dictionary.db').read_bytes()==(p/'android/app/src/main/assets/dictionary.db').read_bytes()
print('OK : intégrité, import, recherche FTS, préfixes, lettres, SQL ESCAPE, asset Android.')
