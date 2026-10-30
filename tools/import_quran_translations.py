#!/usr/bin/env python3
"""Extract the supplied FR/EN PDFs by verse; fail on ambiguous numbering."""
import argparse, collections, hashlib, json, pathlib, re, subprocess
import fitz

ROOT=pathlib.Path(__file__).resolve().parents[1]
COUNTS=[len(c['verses']) for c in json.loads((ROOT/'assets/devotion/quran_hafs.json').read_text())['chapters']]
def clean(lines, english=False):
    text='\n'.join(lines)
    if english:
        # PDF discretionary hyphenation at line endings; keep ordinary in-line hyphens.
        text=re.sub(r'(?<=[A-Za-z])-\s*\n\s*(?=[a-z])','',text)
    return re.sub(r'\s+',' ',text.replace('\u00ad','')).strip()
def parse(lines,lang):
    chapters={}; current=0; verse=None; content=[]; pages=[]; source_pages={}; errors=[]
    def finish():
        nonlocal content
        if current and verse is not None:
            value=clean(content,lang=='en')
            if value:
                target=chapters[current]['entries']
                if verse in target:errors.append(f'duplicate {current}:{verse}')
                target[verse]=value
                source_pages[f'{current}:{verse}']=sorted(set(pages))
        content=[]
    for page,line in lines:
        line=line.strip()
        if not line:continue
        heading=re.match(r'^Sourate\s+(\d+)\s*-\s*(.+?)(?:\s+en français)?$',line) if lang=='fr' else re.match(r'^(\d+)\.\s+([A-Z][A-Z\s’\x27,()\-]+)$',line)
        if heading:
            finish();number=int(heading[1]);verse=None;pages=[]
            if number!=current+1:errors.append(f'chapter jump {current} -> {number} page {page}')
            current=number;chapters[current]={'number':current,'title':heading[2],'entries':{}};continue
        if not current:continue
        if lang=='en' and verse is None and re.match(r'^\([^)]*\)$',line):continue # chapter transliteration
        m=re.match(r'^(\d{1,3})\.\s*(.+)$',line) if lang=='en' else re.match(r'^(\d{1,3})\s+(.+)$',line)
        if m:
            finish();verse=int(m[1]);content=[m[2]];pages=[page]
        elif verse is not None:content.append(line);pages.append(page)
        else:
            # Unnumbered opening formula, deliberately separate from verse 1.
            if current not in (1,9):
                old=chapters[current]['entries'].get(0,'')
                chapters[current]['entries'][0]=clean([old,line],lang=='en')
    finish()
    missing=[];extra=[];empty=[]
    for c,count in enumerate(COUNTS,1):
        row=chapters.get(c,{'entries':{}})
        missing.extend(f'{c}:{v}' for v in range(1,count+1) if v not in row['entries'])
        extra.extend(f'{c}:{v}' for v in row['entries'] if v<0 or v>count or (v==0 and c in (1,9)))
    output={'language':lang,'reading':'hafs','translator':'Muhammad Hamidullah' if lang=='fr' else 'Talal Itani — ClearQuran (edition Allah)', 'chapters':[
      {'number':c,'title':r['title'],'basmala':r['entries'].get(0,''),'verses':[{'number':v,'text':t} for v,t in sorted(r['entries'].items()) if v>0]} for c,r in sorted(chapters.items())]}
    return output,{'language':lang,'chapters':len(chapters),'numberedVerses':sum(len(c['verses']) for c in output['chapters']),'missing':missing,'extra':extra,'errors':errors,'sourcePages':source_pages}
def extract_fr(path):
    text=subprocess.check_output(['pdftotext','-layout',str(path),'-']).decode('utf-8')
    return [(p+1,line) for p,page in enumerate(text.split('\f')) for line in page.splitlines()]
def extract_en(path):
    doc=fitz.open(path);lines=[]
    for i in range(11,252):
        page=doc[i]
        # Mirrored page margins: the footer page-number centre is also the gutter.
        footer=[b for b in page.get_text('blocks') if b[1]>620 and re.fullmatch(r'\s*\d+\s*',b[4])]
        assert len(footer)==1,(i,footer)
        split=(footer[0][0]+footer[0][2])/2
        for x0,x1 in [(0,split),(split,page.rect.width)]:
            text=page.get_text('text',clip=fitz.Rect(x0,44,x1,620),sort=True)
            lines.extend((i+1,line) for line in text.splitlines())
    return lines

def main():
    a=argparse.ArgumentParser();a.add_argument('--fr',required=True,type=pathlib.Path);a.add_argument('--en',required=True,type=pathlib.Path);args=a.parse_args()
    report={'reference':'bundled Hafs: 114 surahs / 6236 numbered verses','sources':[]}
    for lang,path,extract in [('fr',args.fr,extract_fr),('en',args.en,extract_en)]:
        output,audit=parse(extract(path),lang)
        audit.update(source=path.name,sha256=hashlib.sha256(path.read_bytes()).hexdigest(),pages=len(fitz.open(path)))
        report['sources'].append(audit)
        (ROOT/f'assets/devotion/quran_{lang}.json').write_text(json.dumps(output,ensure_ascii=False,separators=(',',':')))
        print(lang,audit['chapters'],audit['numberedVerses'],'missing',audit['missing'][:30],'errors',audit['errors'][:20],'extra',audit['extra'][:10])
    (ROOT/'source/quran_translations/EXTRACTION_REPORT.json').write_text(json.dumps(report,ensure_ascii=False,indent=2))
    if any(x['errors'] or x['extra'] for x in report['sources']):raise SystemExit('Ambiguous extraction: fix before shipping')
if __name__=='__main__':main()
