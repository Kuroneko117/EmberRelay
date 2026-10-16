"""Restore the small visual payload and fetch attributed music for a clean CI build."""
from pathlib import Path
from urllib.request import urlopen
import base64
import hashlib
import io
import json
import shutil
import zipfile

root = Path(__file__).resolve().parents[1]
manifest = json.loads((root/'payload/manifest.json').read_text())
payload = base64.b64decode(''.join(p.read_text() for p in sorted((root/'payload').glob('art-*.b64'))))
assert hashlib.sha256(payload).hexdigest()==manifest['art_sha256']
with zipfile.ZipFile(io.BytesIO(payload)) as archive:
    for name in archive.namelist():
        target = (root/name).resolve()
        assert target.is_relative_to(root.resolve())
        target.parent.mkdir(parents=True,exist_ok=True)
        target.write_bytes(archive.read(name))
for track in manifest['music']:
    print('Fetching attributed music:',track['target'],flush=True)
    with urlopen(track['source'],timeout=90) as response:
        archive_bytes = response.read()
    with zipfile.ZipFile(io.BytesIO(archive_bytes)) as archive:
        candidates = [name for name in archive.namelist() if name.endswith('/'+track['archive_path'].split('/')[-1]) and not name.startswith('__MACOSX/')]
        matches = [archive.read(name) for name in candidates if hashlib.sha256(archive.read(name)).hexdigest()==track['sha256']]
        if not matches: raise RuntimeError('Music source has changed: '+track['target'])
        data = matches[0]
    assert hashlib.sha256(data).hexdigest()==track['sha256']
    target = root/track['target']
    target.parent.mkdir(parents=True,exist_ok=True)
    target.write_bytes(data)
out = root/'build/web'
out.mkdir(parents=True,exist_ok=True)
shutil.copy2(root/'web/index.html',out/'index.html')
shutil.copytree(root/'licenses',out/'licenses',dirs_exist_ok=True)
(out/'.nojekyll').write_text('')
print('CI_WEB_SOURCE_READY',flush=True)

