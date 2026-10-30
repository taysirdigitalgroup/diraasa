"""Validate cleanup against an installed/legacy dictionary copy, without editing it."""
import hashlib,json,pathlib,sqlite3,sys,tempfile
source=pathlib.Path(sys.argv[1])
with tempfile.TemporaryDirectory() as folder:
 target=pathlib.Path(folder)/'dictionary.db'
 with sqlite3.connect(source) as old,sqlite3.connect(target) as db:old.backup(db)
 db=sqlite3.connect(target)
 def fingerprint(sql):return hashlib.sha256(json.dumps(db.execute(sql).fetchall(),ensure_ascii=False,separators=(',',':')).encode()).hexdigest()
 queries=['select * from entries order by id','select * from pages where id<=5 order by id','select docid,terms from search order by docid']
 before=[fingerprint(q) for q in queries]
 for attempt in range(2):
  if db.execute('pragma user_version').fetchone()[0]<2:
   with db:
    assert db.execute('select count(*) from pages where id between 1 and 5').fetchone()[0]==5
    db.execute('delete from pages where id>5');db.execute('pragma user_version=2')
   db.execute('vacuum')
  assert [fingerprint(q) for q in queries]==before
  assert db.execute('select count(*) from pages').fetchone()[0]==5
  assert db.execute('select count(*) from entries').fetchone()[0]==3767
  assert db.execute('pragma integrity_check').fetchone()[0]=='ok'
 db.close()
print('OK: legacy cleanup, intro + entries + FTS preserved, idempotence, integrity')
