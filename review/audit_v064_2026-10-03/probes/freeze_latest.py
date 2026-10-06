import hashlib
import json
import shutil
from pathlib import Path

audit = Path(__file__).resolve().parents[1]
workspace = audit.parents[1]
manifest = []
paths = [workspace / 'project.godot']
for folder in ['scripts', 'scenes']:
    paths.extend(p for p in (workspace / folder).rglob('*') if p.is_file())
target = audit / 'source_v066'
assert not target.exists(), 'Never overwrite a reviewed snapshot'
target.mkdir()
for p in paths:
    relative = p.relative_to(workspace)
    content = p.read_bytes()
    manifest.append(dict(path=str(relative), sha256=hashlib.sha256(content).hexdigest().upper()))
    destination = target / relative
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(content)
session = target / 'scripts/session.gd'
session.write_text(session.read_text(encoding='utf-8').replace('user://rim_save.json', 'res://audit_save.json').replace('user://rim_save.bak.json', 'res://audit_save.bak.json'), encoding='utf-8')
settings = target / 'scripts/settings.gd'
settings.write_text(settings.read_text(encoding='utf-8').replace('user://rim_settings.json', 'res://audit_settings.json'), encoding='utf-8')
for name in ['audit_save.json', 'audit_save.bak.json', 'audit_settings.json']:
    p = audit / 'source' / name
    if p.exists():
        shutil.copy2(p, target / name)
(audit / 'source_v066_manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
capture = (audit / 'probes/interface_states.gd').read_text(encoding='utf-8').replace('/screenshots/', '/screenshots_v066/').replace('/interface_states.json', '/interface_states_v066.json')
(audit / 'probes/interface_states_v066.gd').write_text(capture, encoding='utf-8')
(audit / 'screenshots_v066').mkdir(exist_ok=True)
print(f'Frozen {len(manifest)} files at {target}')
