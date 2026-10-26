from pathlib import Path
import xml.etree.ElementTree as ET
root=Path(__file__).resolve().parents[1]
attr='{http://schemas.android.com/apk/res/android}name'
for variant in ('debug','profile'):
    manifest=ET.parse(root/'android/app/src'/variant/'AndroidManifest.xml')
    permissions=[p.get(attr) for p in manifest.findall('uses-permission')]
    assert 'android.permission.INTERNET' in permissions
main=ET.parse(root/'android/app/src/main/AndroidManifest.xml')
assert any(p.get(attr)=='android.permission.INTERNET' for p in main.findall('uses-permission'))
for name in ('SCHEDULE_EXACT_ALARM','POST_NOTIFICATIONS','FOREGROUND_SERVICE_MEDIA_PLAYBACK'):
    assert any(p.get(attr)=='android.permission.'+name for p in main.findall('uses-permission'))
print('OK : INTERNET pour les horaires en release/debug/profile ; permissions notifications/azan déclarées.')
