import json
import shutil
from pathlib import Path

audit = Path(__file__).resolve().parents[1]
source = audit / 'source_v066'
target = audit / 'source_latest'
assert not target.exists(), 'Latest evidence snapshot must not be overwritten'
target.mkdir()
manifest = json.loads((audit / 'source_v066_manifest.json').read_text(encoding='utf-8-sig'))
for entry in manifest:
    relative = Path(entry['path'])
    destination = target / relative
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source / relative, destination)
for name in ['audit_save.json', 'audit_save.bak.json', 'audit_settings.json']:
    if (source / name).is_file():
        shutil.copy2(source / name, target / name)
shutil.copy2(audit / 'source_v066_manifest.json', audit / 'source_latest_manifest.json')
(audit / 'screenshots_latest').mkdir(exist_ok=True)
for p in (audit / 'screenshots_v066').glob('*.png'):
    shutil.copy2(p, audit / 'screenshots_latest' / p.name)
print('Preserved final snapshot and fresh screenshots without changing production')
