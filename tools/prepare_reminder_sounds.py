"""Optional build-time downloader/converter; never run by the app. Requires FFmpeg.
Sources are CC0 releases by their authors on OpenGameArt; metadata is bundled.
"""
from pathlib import Path
import urllib.request,json,tempfile,subprocess,hashlib
r=Path(__file__).resolve().parents[1];folder=r/'android/app/src/main/assets/audio';credits=[]
base='https://opengameart.org'
items=[
 ('birds','soundBirds','isaiah658','/content/ambient-bird-sounds','/sites/default/files/birds-isaiah658_0.ogg'),
 ('water','soundWater','TyberiusGames','/content/waterflow-sound','/sites/default/files/waterflow.mp3'),
 ('waves','soundWaves','transitking (via qubodup)','/content/water-waves','/sites/default/files/wave_01_cc0-11505__transitking__wavesound.flac'),
 ('chime','soundChime','PWL','/content/bell-dingschimes','/sites/default/files/bell_ding1.wav'),
 ('alarm','soundAlarm','bonzille','/content/alarm-sound-effect','/sites/default/files/alarm_2.wav'),
]
catalog=[{'id':'asset:audio/reminder.ogg','labelKey':'gentleBell'}]
with tempfile.TemporaryDirectory() as tmp:
 for key,label,author,page,url in items:
  raw=urllib.request.urlopen(base+url).read();source=Path(tmp)/Path(url).name;source.write_bytes(raw)
  info=json.loads(subprocess.check_output(['ffprobe','-v','quiet','-show_format','-of','json',str(source)]))
  duration=min(8,float(info['format']['duration']));out=folder/f'reminder_{key}.m4a'
  subprocess.run(['ffmpeg','-v','error','-y','-i',str(source),'-t',str(duration),'-vn','-af',f'loudnorm=I=-20:TP=-2:LRA=7,afade=t=in:d=0.025,afade=t=out:st={max(0,duration-.08)}:d=0.08','-ac','1','-ar','24000','-c:a','aac','-b:a','32k',str(out)],check=True)
  catalog.append({'id':'asset:audio/'+out.name,'labelKey':label,'bytes':out.stat().st_size})
  credits.append({'file':out.name,'author':author,'page':base+page,'download':base+url,'license':'CC0-1.0','license_url':'https://creativecommons.org/publicdomain/zero/1.0/','source_sha256':hashlib.sha256(raw).hexdigest(),'conversion':'First up to 8 seconds, AAC mono 24 kHz 32 kbit/s, loudness -20 LUFS, short fade-in/out'})
(folder/'reminders.json').write_text(json.dumps(catalog,ensure_ascii=False,indent=2))
(r/'source/audio/reminder_sources.json').write_text(json.dumps(credits,ensure_ascii=False,indent=2))
print('5 nouveaux sons :',sum(x['bytes'] for x in catalog[1:]),'octets')
