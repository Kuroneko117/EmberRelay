"""Fetch only the matching Web template from the official release archive."""
from pathlib import Path
from urllib.request import Request, urlopen
import io
import zipfile

URL = 'https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz'
class RemoteArchive(io.RawIOBase):
    def __init__(self):
        with urlopen(Request(URL, headers={'Range':'bytes=0-0'}), timeout=60) as response:
            self.size = int(response.headers['Content-Range'].split('/')[-1])
            self.url = response.url
        self.pos = 0
    def seekable(self): return True
    def tell(self): return self.pos
    def seek(self, offset, whence=0):
        self.pos = offset if whence==0 else self.pos+offset if whence==1 else self.size+offset
        return self.pos
    def read(self, count=-1):
        count = min(count if count>=0 else self.size-self.pos, self.size-self.pos)
        if not count: return b''
        request = Request(self.url, headers={'Range':f'bytes={self.pos}-{self.pos+count-1}'})
        with urlopen(request, timeout=120) as response:
            if response.status!=206: raise RuntimeError('Server does not support selective download')
            data = response.read()
        if len(data)!=count: raise RuntimeError('Incomplete archive range')
        self.pos += len(data)
        return data

target = Path(__file__).resolve().parents[1] / 'build/web-templates'
target.mkdir(parents=True,exist_ok=True)
with zipfile.ZipFile(RemoteArchive()) as archive:
    names = [name for name in archive.namelist() if 'web' in name.lower()]
    print('Official Web templates:', names, flush=True)
    for name in names:
        if name.endswith('.zip') and 'release' in name and 'nothreads' in name:
            data = archive.read(name)
            assert zipfile.is_zipfile(io.BytesIO(data))
            path = target / Path(name).name
            path.write_bytes(data)
            print('TEMPLATE_READY:',path.name,len(data),'bytes',flush=True)

