from pathlib import Path
import zipfile

root = Path(__file__).resolve().parents[1]
version = (root / 'VERSION').read_text(encoding='utf-8').strip()

# Check parentheses outside strings and comments, for all shipped Lisp sources.
for p in [root / 'ALCWALL.lsp', *(root / 'src').glob('*.lsp'), *(root / 'tests').glob('*.lsp')]:
    s = p.read_text(encoding='utf-8-sig')
    depth, quoted, escaped, comment = 0, False, False, False
    for c in s:
        if comment:
            if c == '\n': comment = False
        elif quoted:
            if escaped: escaped = False
            elif c == '\\': escaped = True
            elif c == '"': quoted = False
        elif c == ';': comment = True
        elif c == '"': quoted = True
        elif c == '(' : depth += 1
        elif c == ')':
            depth -= 1
            assert depth >= 0, f'Extra closing parenthesis: {p}'
    assert depth == 0 and not quoted, f'Unbalanced source: {p}'

out = root / f'ALCWALL-{version}.zip'
files = [root / n for n in ('ALCWALL.lsp', 'README.md', 'CHANGELOG.md', 'VERSION', 'REVIEW.txt')]
files += sorted((root / 'src').glob('*'))
with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as z:
    for p in files:
        if p.is_file(): z.write(p, f'ALCWALL-{version}/' + p.relative_to(root).as_posix())
print(f'Checked sources. Packaged {len(files)} files: {out}')
