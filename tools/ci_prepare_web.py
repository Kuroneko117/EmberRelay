"""Prepare checked-in redistributable assets for the existing Web export."""
from pathlib import Path
import shutil
root=Path(__file__).resolve().parents[1]
assert (root/'assets/ui_font.ttc').is_file()
assert (root/'assets/music/last-light.ogg').is_file()
out=root/'build/web'
out.mkdir(parents=True,exist_ok=True)
shutil.copy2(root/'web/index.html',out/'index.html')
shutil.copytree(root/'licenses',out/'licenses',dirs_exist_ok=True)
shutil.copytree(root/'web/assets',out/'assets',dirs_exist_ok=True)
(out/'.nojekyll').touch()
print('CI_WEB_SOURCE_READY')
