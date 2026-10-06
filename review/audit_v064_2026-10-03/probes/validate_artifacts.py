import csv
import json
import re
from html.parser import HTMLParser
from pathlib import Path

audit = Path(__file__).resolve().parents[1]
data = json.loads((audit / 'BACKLOG_100.json').read_text(encoding='utf-8'))
findings = data['findings']
assert len(findings) == len({x['id'] for x in findings}) == len({x['key'] for x in findings}) == 100
assert len(list(csv.DictReader((audit / 'BACKLOG_100.csv').open(encoding='utf-8-sig')))) == 100
assert len(re.findall(r'^### RIM-\d{3}', (audit / 'REVIEW.md').read_text(encoding='utf-8'), re.M)) == 100
assert sum(data['metadata']['counts']['kind'].values()) == 100

class Document(HTMLParser):
    def __init__(self):
        super().__init__()
        self.script_attrs = None
        self.scripts = []
        self.images = []
        self.hrefs = []
        self.ids = []
    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == 'script':
            self.script_attrs = attrs
        if tag == 'img':
            self.images.append(attrs['src'])
        if tag == 'a':
            self.hrefs.append(attrs.get('href', ''))
        if 'id' in attrs:
            self.ids.append(attrs['id'])
    def handle_endtag(self, tag):
        if tag == 'script':
            self.script_attrs = None
    def handle_data(self, value):
        if self.script_attrs is not None:
            self.scripts.append((self.script_attrs, value))

document = Document()
document.feed((audit / 'AUDIT_VIEWER.html').read_text(encoding='utf-8'))
payload = next(json.loads(value) for attrs, value in document.scripts if attrs.get('type') == 'application/json')
assert payload == data
for path in document.images + document.hrefs:
    if path and not path.startswith('#'):
        assert (audit / path).is_file(), path
for x in findings:
    file, line = x['reviewed_source'].rsplit(':', 1)
    assert (audit / file).is_file()
    assert 1 <= int(line) <= len((audit / file).read_text(encoding='utf-8').splitlines())
js = '\n'.join(value for attrs, value in document.scripts if attrs.get('type') != 'application/json')
(audit / 'probes/viewer_code.js').write_text(js, encoding='utf-8')

dom = Document()
dom_path = audit / 'probes/viewer_dom.html'
if dom_path.exists():
    dom.feed(dom_path.read_text(encoding='utf-8-sig'))
    rendered = len([x for x in dom.ids if re.fullmatch(r'RIM-\d{3}', x)])
    assert rendered == 100, f'Browser rendered only {rendered} findings'
else:
    rendered = None
result = dict(json_count=100, csv_count=100, markdown_count=100, unique_findings=100,
              viewer_payload_matches=True, viewer_local_links_valid=True,
              frozen_source_links_valid=True, browser_rendered_findings=rendered)
(audit / 'ARTIFACT_VALIDATION.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
print(json.dumps(result, indent=2))
