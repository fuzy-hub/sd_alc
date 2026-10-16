"""Explicitly regenerate release integrity metadata after reviewed source edits."""
import hashlib
import json
from validate_project import ROOT, VERSION, MODULES

names=['ALCWALL.lsp', *['src/'+name for name in MODULES], 'src/alc-patterns.dcl']
files={name:{'bytes':len((ROOT/name).read_bytes()),'sha256':hashlib.sha256((ROOT/name).read_bytes()).hexdigest()} for name in names}
(ROOT/'manifest.json').write_text(json.dumps({'version':VERSION,'files':files},indent=2)+'\n',encoding='utf-8')
entries=' '.join(f'  ("{name}" {files[name]["bytes"]})' for name in names if name!='ALCWALL.lsp')
(ROOT/'manifest.lspdata').write_text(f'("{VERSION}" {entries})\n',encoding='utf-8')
print('Manifest refreshed; run validate_project.py before packaging.')
