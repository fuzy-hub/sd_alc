"""Static release validation, usable without AutoCAD or GitHub access."""
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
VERSION = (ROOT / 'VERSION').read_text(encoding='utf-8').strip()
MODULES = ['alc-settings.lsp', 'alc-styles.lsp', 'alc-patterns.lsp',
           'alc-geometry.lsp', 'alc-safety.lsp', 'alc-wall.lsp', 'alc-trim.lsp',
           'alc-schedule.lsp', 'alc-door-schedule.lsp', 'alc-dim-schedule.lsp',
           'alc-count.lsp', 'alc-text-copy.lsp', 'alc-align.lsp', 'alc-commands.lsp']

def validate():
    files = [ROOT/'ALCWALL.lsp', *sorted((ROOT/'src').glob('*.lsp')), *sorted((ROOT/'tests').glob('*.lsp'))]
    for path in files:
        depth = 0
        quoted = escaped = comment = False
        for c in path.read_text(encoding='utf-8-sig'):
            if comment:
                if c == '\n': comment = False
            elif quoted:
                if escaped: escaped = False
                elif c == '\\': escaped = True
                elif c == '"': quoted = False
            elif c == ';': comment = True
            elif c == '"': quoted = True
            elif c == '(': depth += 1
            elif c == ')':
                depth -= 1
                if depth < 0: raise ValueError(f'Extra closing parenthesis: {path}')
        if depth or quoted: raise ValueError(f'Unbalanced Lisp: {path} depth={depth}')
    commands = (ROOT/'src/alc-commands.lsp').read_text(encoding='utf-8')
    public = re.findall(r'\(defun c:([A-Z0-9]+)\s', commands, re.I)
    for name in public:
        if name.startswith('ALC'):
            alias = 'VV'+name[3:]
            if not re.search(r'\(defun c:'+alias+r' \(\) \(c:'+name+r'\)\)', commands):
                raise ValueError(f'Missing alias: {alias}')
    manifest = json.loads((ROOT/'manifest.json').read_text(encoding='utf-8'))
    if manifest['version'] != VERSION: raise ValueError('Manifest version mismatch')
    expected = ['ALCWALL.lsp', *['src/'+m for m in MODULES], 'src/alc-patterns.dcl']
    if set(manifest['files']) != set(expected): raise ValueError('Manifest file set mismatch')
    for name, info in manifest['files'].items():
        data=(ROOT/name).read_bytes()
        if info != {'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()}:
            raise ValueError(f'Manifest mismatch: {name}')
    loader_manifest=f'("{VERSION}" '+ ' '.join(f'("{name}" {manifest["files"][name]["bytes"]})' for name in expected if name!='ALCWALL.lsp')+')'
    if ' '.join(loader_manifest.split())!=' '.join((ROOT/'manifest.lspdata').read_text(encoding='utf-8').split()):
        raise ValueError('Loader manifest does not match SHA-256 manifest')
    for name in MODULES:
        if f'(setq *alc-module-version* "{VERSION}")' not in (ROOT/'src'/name).read_text(encoding='utf-8'):
            raise ValueError(f'Module version mismatch: {name}')
    if f'ALCWALL {VERSION}' not in (ROOT/'README.md').read_text(encoding='utf-8'):
        raise ValueError('README version mismatch')
    if f'## {VERSION}' not in (ROOT/'CHANGELOG.md').read_text(encoding='utf-8'):
        raise ValueError('CHANGELOG version mismatch')
    print(f'Static validation PASS: {len(files)} Lisp files, {len(public)} commands, manifest {VERSION}')
    return manifest

if __name__ == '__main__': validate()
