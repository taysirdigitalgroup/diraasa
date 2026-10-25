"""Detect unsupported escapes in ordinary Kotlin string literals."""
from pathlib import Path
import re
root=Path(__file__).resolve().parents[1]
count=0
for path in (root/'android/app/src').rglob('*.kt'):
    source=path.read_text()
    # Kotlin raw strings intentionally allow regex backslashes unchanged.
    stripped=re.sub(r'""".*?"""',lambda m:' '*len(m[0]),source,flags=re.S)
    for match in re.finditer(r'"(?:[^"\\]|\\.)*"',stripped):
        for escape in re.finditer(r'\\(.)',match[0]):
            assert escape[1] in 'tbnr\'"\\$u', (str(path),escape[0])
        count+=1
print('OK : échappements Kotlin ('+str(count)+' chaînes contrôlées).')
