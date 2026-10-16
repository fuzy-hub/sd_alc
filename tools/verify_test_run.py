"""Require completed, session-specific suite logs; reject partial/stale results."""
import argparse
import json
from pathlib import Path
import re

def verify(directory, label, suites):
    if (directory/'run.complete').read_text(encoding='utf-8-sig').strip()!=label:
        raise ValueError('Test script did not finish in the expected session')
    summaries=[]
    for suite, minimum in suites.items():
        data=json.loads((directory/(suite+'.done.json')).read_text(encoding='utf-8-sig'))
        lines=(directory/(suite+'.log')).read_text(encoding='utf-8-sig').splitlines()
        count=sum(line=='PASS' or line.startswith('PASS ') or line.endswith('=PASS') for line in lines)
        if data.get('session')!=label or data.get('status')!='complete' or data.get('failed')!=0:
            raise ValueError(f'Incomplete/failed/wrong-session suite: {suite}')
        if data.get('checks')!=count or count<minimum or any(re.search(r'(^FAIL(?:\s|$)|=FAIL(?:\s|$))', line) for line in lines):
            raise ValueError(f'Failed/truncated suite log: {suite} ({count} checks; minimum {minimum})')
        summaries.append({'suite':suite,'checks':count})
    return summaries

if __name__=='__main__':
    p=argparse.ArgumentParser()
    p.add_argument('directory',type=Path)
    args=p.parse_args()
    metadata=json.loads((args.directory/'expected.json').read_text(encoding='utf-8-sig'))
    result=verify(args.directory,metadata['session'],metadata['suites'])
    (args.directory/'verified.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(result))
