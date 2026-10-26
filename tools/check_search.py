"""Exercise the actual Kotlin SQL templates on the shipped read-only corpus."""
import json,re,sqlite3,unicodedata
from pathlib import Path
root=Path(__file__).resolve().parents[1]
source=(root/'android/app/src/main/kotlin/com/tdg/diraasa/MainActivity.kt').read_text()
root_expr=re.search(r'val rootExpr = ("[^"\n]+")',source).group(1)
root_expr=json.loads(root_expr)
clause=re.search(r'clauses.add\(("(?:[^"\\]|\\.)*e.normalized LIKE(?:[^"\\]|\\.)*")\)',source).group(1)
clause=json.loads(clause).replace('${rootExpr}',root_expr)
template=json.loads(re.search(r'val baseSql = ("[^"\n]+")',source).group(1))
exact_contains=json.loads(re.search(r'clauses.add\(("\(instr[^"\n]+")\)',source).group(1))
exact_prefix=json.loads(re.search(r'clauses.add\(("\(substr[^"\n]+")\)',source).group(1))
db=sqlite3.connect('file:'+str(root/'assets/dictionary.db')+'?mode=ro',uri=True)
db.row_factory=sqlite3.Row
def normalize(s):
    s=re.sub(r'[\u0610-\u061a\u064b-\u065f\u0670\u06d6-\u06edـ]','',s)
    return s.translate(str.maketrans('أإآٱى','ااااي')).lower()
def precise(q):
    return bool(re.search(r'[\u0610-\u061a\u064b-\u065f\u0670\u06d6-\u06ed]',q)) or q!=q.lower()
def tokens(text):
    parts=[];part=''
    for char in text:
        if unicodedata.category(char)[0] in 'LNM':part+=char
        elif part:parts.append(part);part=''
    if part:parts.append(part)
    return parts

def search(q='',mode='prefix',letter='',offset=0):
    raw=q.strip();strict=precise(raw);q=normalize(raw)
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
    if strict and mode!='fulltext' and raw:
        clauses.append(exact_contains if mode=='contains' else exact_prefix)
        root_query=raw.replace(' ','')
        args.extend([raw,root_query] if mode=='contains' else [raw,raw,root_query,root_query])
    where=' WHERE '+' AND '.join(clauses) if clauses else ''
    base=template.replace('$where',where)
    if strict and mode=='fulltext':
        terms=tokens(raw)
        rows=db.execute(base,args).fetchall()
        rows=[row for row in rows if terms and all(any(word.startswith(term) for word in tokens(' '.join(row[k] or '' for k in ('word','definition','root')))) for term in terms)]
        return rows[offset:offset+60]
    return db.execute(base+' LIMIT 60 OFFSET ?',args+[str(offset)]).fetchall()
for mode in ('prefix','contains','fulltext'):
    rows=search('علم',mode)
    assert rows,mode
    if mode!='fulltext':
        for row in rows:
            candidates=[normalize(row['word']),normalize(row['root']).replace(' ','')]
            assert any(('علم' in s if mode=='contains' else s.startswith('علم')) for s in candidates)
for mode in ('prefix','contains','fulltext'):
    for raw in ('عِلْم','أَكَلَ'):
        for row in search(raw,mode):
            if mode=='contains':assert raw in row['word'] or raw.replace(' ','') in row['root'].replace(' ','')
            elif mode=='prefix':assert row['word'].startswith(raw) or row['root'].replace(' ','').startswith(raw.replace(' ',''))
            else:assert all(any(word.startswith(term) for word in tokens(' '.join(row[k] or '' for k in ('word','definition','root')))) for term in tokens(raw))
assert not precise('أكل') and precise('عِلْم') and precise('Cours') and not precise('cours')
# Controlled rows verify strict predicates independently of the book spelling.
fixture=sqlite3.connect(':memory:')
fixture.execute('CREATE TABLE entries(word TEXT,root TEXT)')
fixture.executemany('INSERT INTO entries VALUES(?,?)',[('عِلْم','ع ل م'),('عَلَم','ع ل م'),('علم','ع ل م'),('Cours',''),('cours','')])
assert fixture.execute('SELECT count(*) FROM entries e WHERE '+exact_contains,['عِلْم','عِلْم']).fetchone()[0]==1
assert fixture.execute('SELECT count(*) FROM entries e WHERE '+exact_prefix,['Cours','Cours','Cours','Cours']).fetchone()[0]==1
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
print('OK : SQL natif adaptatif, préfixe/contient/FTS, harakat exacts, casse exacte, alif tolérant, pagination et caractères spéciaux.')
