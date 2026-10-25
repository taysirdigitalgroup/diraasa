"""Exercise the actual Kotlin SQL templates on the shipped read-only corpus."""
import json,re,sqlite3
from pathlib import Path
root=Path(__file__).resolve().parents[1]
source=(root/'android/app/src/main/kotlin/com/tdg/diraasa/MainActivity.kt').read_text()
root_expr=re.search(r'val rootExpr = ("[^"\n]+")',source).group(1)
root_expr=json.loads(root_expr)
clause=re.search(r'clauses.add\(("(?:[^"\\]|\\.)*e.normalized LIKE(?:[^"\\]|\\.)*")\)',source).group(1)
clause=json.loads(clause).replace('${rootExpr}',root_expr)
template=re.search(r'query\(dict,("(?:[^"\\]|\\.)*SELECT e.\*(?:[^"\\]|\\.)*")',source).group(1)
template=json.loads(template)
db=sqlite3.connect('file:'+str(root/'assets/dictionary.db')+'?mode=ro',uri=True)
db.row_factory=sqlite3.Row
def normalize(s):
    s=re.sub(r'[\u0610-\u061a\u064b-\u065f\u0670\u06d6-\u06edـ]','',s)
    return s.translate(str.maketrans('أإآٱى','ااااي')).lower()
def search(q='',mode='prefix',letter='',offset=0):
    q=normalize(q)
    clauses=[];args=[]
    if letter:clauses.append('e.letter=?');args.append(normalize(letter))
    if q:
        if mode=='fulltext':
            terms=re.findall(r'[^\W_]+',q)
            if not terms:clauses.append('0')
            else:
                clauses.append('e.id IN (SELECT docid FROM search WHERE terms MATCH ?)')
                args.append(' AND '.join(term+'*' for term in terms))
        else:
            clauses.append(clause)
            esc=q.replace('\\','\\\\').replace('%','\\%').replace('_','\\_')
            pat=('%' if mode=='contains' else '')+esc+'%'
            args.extend([pat,pat])
    where=' WHERE '+' AND '.join(clauses) if clauses else ''
    return db.execute(template.replace('$where',where),args+[str(offset)]).fetchall()
for mode in ('prefix','contains','fulltext'):
    rows=search('علم',mode)
    assert rows,mode
    if mode!='fulltext':
        for row in rows:
            candidates=[normalize(row['word']),normalize(row['root']).replace(' ','')]
            assert any(('علم' in s if mode=='contains' else s.startswith('علم')) for s in candidates)
assert {r['id'] for r in search('عِلْم','contains')}=={r['id'] for r in search('علم','contains')}
assert search('أكل','prefix') and search('اكل','prefix')
for letter in 'ابتثجحخدذرزسشصضطظعغفقكلمنهوي':
    rows=search(letter=letter)
    assert all(row['letter']==letter for row in rows)
assert not ({r['id'] for r in search(offset=0)} & {r['id'] for r in search(offset=60)})
assert not search('%','contains') and not search('_','contains')
assert not search('!!!','fulltext')
assert not search('كلمةغيرموجودةنهائيا')
assert all(token in source for token in ['"fulltext"','"contains"'])
assert 'CREATE INDEX' not in source # No writes to the book database.
print('OK : SQL natif, préfixe/racine, contient, FTS, harakat/alif, lettres, pagination, caractères spéciaux.')
