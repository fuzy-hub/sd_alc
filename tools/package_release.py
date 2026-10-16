"""Package one reviewed checkout; validation never refreshes hashes."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import zipfile
from validate_project import ROOT, VERSION, validate
p=argparse.ArgumentParser()
p.add_argument('--output',type=Path)
args=p.parse_args()
manifest=validate()
out=args.output or ROOT/f'ALCWALL-{VERSION}.zip'
out.parent.mkdir(parents=True,exist_ok=True)
names=['ALCWALL.lsp','README.md','CHANGELOG.md','VERSION','REVIEW.txt',
       'manifest.json','manifest.lspdata',f'RELEASE-{VERSION}.txt','tools/install.ps1']
names+=sorted(name for name in manifest['files'] if name!='ALCWALL.lsp')
if (ROOT/f'tests/validation-{VERSION}.txt').exists(): names.append(f'tests/validation-{VERSION}.txt')
with zipfile.ZipFile(out,'w',zipfile.ZIP_DEFLATED) as z:
    for name in names:
        info=zipfile.ZipInfo(f'ALCWALL-{VERSION}/'+name,date_time=(2026,10,16,0,0,0))
        info.compress_type=zipfile.ZIP_DEFLATED
        z.writestr(info,(ROOT/name).read_bytes())
with zipfile.ZipFile(out) as z:
    if z.testzip() is not None: raise ValueError('ZIP integrity failure')
    for item in z.infolist():
        if z.read(item)!=(ROOT/item.filename.split('/',1)[1]).read_bytes():
            raise ValueError(f'Archive source mismatch: {item.filename}')
try:
    commit=subprocess.check_output(['git','-C',str(ROOT),'rev-parse','HEAD'],text=True).strip()
    dirty=bool(subprocess.check_output(['git','-C',str(ROOT),'status','--porcelain'],text=True).strip())
except (subprocess.CalledProcessError,FileNotFoundError): commit=None;dirty=None
metadata={'version':VERSION,'source_commit':commit,'source_dirty':dirty,
          'manifest_sha256':hashlib.sha256((ROOT/'manifest.json').read_bytes()).hexdigest(),
          'archive':out.name,'bytes':out.stat().st_size,'sha256':hashlib.sha256(out.read_bytes()).hexdigest()}
out.with_suffix('.zip.json').write_text(json.dumps(metadata,indent=2)+'\n',encoding='utf-8')
print(json.dumps(metadata))
