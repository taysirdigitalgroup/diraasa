"""Optional development tool. Requires ffmpeg and internet for the CC0 reminder.
python3 tools/prepare_audio.py /path/to/adhans.tar.gz
Never invoked by setup.sh or the application. Source archive stays untouched.
"""
from pathlib import Path
import io,json,tarfile,subprocess,sys,urllib.request,zipfile,hashlib
r=Path(__file__).resolve().parents[1];source=Path(sys.argv[1])
folder=r/'android/app/src/main/assets/audio';folder.mkdir(parents=True,exist_ok=True)
provenance=r/'source/audio';provenance.mkdir(parents=True,exist_ok=True)
import tempfile
catalog=[]
with tarfile.open(source) as t,tempfile.TemporaryDirectory() as tmp:
 for i,m in enumerate(x for x in t if x.isfile() and x.name.endswith('.mp3')):
  path=Path(tmp)/f'{i}.mp3';path.write_bytes(t.extractfile(m).read());label='Serigne Mbacké Fall - 🇸🇳 Senegal المسجد طوبي، السنغال' if 'Serigne Mbacké Fall' in m.name else Path(m.name).stem;target=folder/((label+'.m4a') if 'Serigne Mbacké Fall' in m.name else f'adhan_{i+1}.m4a')
  subprocess.run(['ffmpeg','-v','error','-y','-i',str(path),'-vn','-ac','1','-ar','24000','-c:a','aac','-b:a','32k',str(target)],check=True)
  catalog.append({'id':'asset:audio/'+target.name,'label':label,'bytes':target.stat().st_size})
url='https://kenney.nl/media/pages/assets/digital-audio/216eac4753-1677590265/kenney_digital-audio.zip'
z=zipfile.ZipFile(io.BytesIO(urllib.request.urlopen(url).read()))
n=next(n for n in z.namelist() if n.lower().endswith('.ogg') and 'powerup' in n.lower())
(folder/'reminder.ogg').write_bytes(z.read(n))
for name in z.namelist():
 if 'license' in name.lower() and not name.endswith('/'):(provenance/'kenney_license.txt').write_bytes(z.read(name))
(folder/'catalog.json').write_text(json.dumps(catalog,ensure_ascii=False,indent=2))
(provenance/'provenance.json').write_text(json.dumps({'adhans':source.name,'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'conversion':'AAC mono 24 kHz 32 kbit/s, durée complète','reminder':{'url':url,'file':n,'license':'CC0','author':'Kenney'}},ensure_ascii=False,indent=2))
