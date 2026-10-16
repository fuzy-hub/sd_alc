"""Publish the requested release using the existing Git credential helper."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
from urllib.error import HTTPError
from urllib.parse import urlencode, urlsplit
from urllib.request import Request, urlopen

root = Path(__file__).resolve().parents[1]
repo = 'fuzy-hub/sd_alc'
version = (root / 'VERSION').read_text(encoding='utf-8').strip()
tag = 'v' + version
env = dict(os.environ, GIT_TERMINAL_PROMPT='0', GCM_INTERACTIVE='never')
credential = subprocess.run(
    ['git', 'credential', 'fill'],
    input='protocol=https\nhost=github.com\n\n',
    text=True, capture_output=True, env=env, cwd=root / 'github-publish-3.0')
if credential.returncode:
    raise SystemExit('GitHub credential unavailable from the configured helper.')
fields = dict(line.split('=', 1) for line in credential.stdout.splitlines() if '=' in line)
token = fields.get('password')
if not token:
    raise SystemExit('GitHub credential helper did not return an authentication token.')
headers = {'Authorization': 'Bearer ' + token, 'Accept': 'application/vnd.github+json',
           'X-GitHub-Api-Version': '2022-11-28', 'User-Agent': 'ALCWALL-release'}

def request(method, url, payload=None, raw=False):
    # Never send the credential outside GitHub's documented API/upload hosts.
    assert urlsplit(url).hostname in ('api.github.com', 'uploads.github.com')
    data = payload if raw else (json.dumps(payload).encode('utf-8') if payload is not None else None)
    h = dict(headers)
    if data is not None:
        h['Content-Type'] = 'application/zip' if raw else 'application/json'
    try:
        with urlopen(Request(url, data=data, headers=h, method=method), timeout=45) as response:
            return json.load(response)
    except HTTPError as error:
        if error.code == 404 and method == 'GET':
            return None
        raise SystemExit(f'GitHub API {method} failed: HTTP {error.code}') from None

base = 'https://api.github.com/repos/' + repo
info = request('GET', base)
if not info:
    raise SystemExit('GitHub repository is not accessible.')
print(json.dumps({'repository': info['html_url'],
                  'push_permission': info.get('permissions', {}).get('push')}, ensure_ascii=False))
if '--check' in sys.argv:
    sys.exit(0)

zip_path = root / f'ALCWALL-{version}.zip'
body = (root / f'RELEASE-{version}.txt').read_text(encoding='utf-8')
commit_result = subprocess.run(
    ['git', 'rev-parse', 'HEAD'], text=True, capture_output=True,
    env=env, cwd=root / 'github-publish-3.0', check=True)
release_commit = commit_result.stdout.strip()
release = request('GET', base + '/releases/tags/' + tag)
if release is None:
    release = request('POST', base + '/releases',
                      {'tag_name': tag, 'target_commitish': release_commit,
                       'name': 'ALCWALL ' + version, 'body': body,
                       'draft': True, 'prerelease': False})
asset = next((a for a in release.get('assets', []) if a['name'] == zip_path.name), None)
zip_bytes = zip_path.read_bytes()
if asset is None:
    upload = release['upload_url'].split('{')[0] + '?' + urlencode({'name': zip_path.name})
    asset = request('POST', upload, zip_bytes, raw=True)
if asset['size'] != len(zip_bytes):
    raise SystemExit('Release asset size does not match the local ZIP.')
digest = asset.get('digest')
if digest and digest != 'sha256:' + hashlib.sha256(zip_bytes).hexdigest():
    raise SystemExit('Release asset digest does not match the local ZIP.')
if release['draft']:
    release = request('PATCH', base + '/releases/' + str(release['id']),
                      {'draft': False, 'make_latest': 'true'})
verified = request('GET', base + '/releases/tags/' + tag)
if verified is None or verified['draft']:
    raise SystemExit('Release publication could not be confirmed.')
published_asset = next((a for a in verified.get('assets', []) if a['name'] == zip_path.name), None)
if not published_asset or published_asset['size'] != len(zip_bytes):
    raise SystemExit('Published release asset could not be confirmed.')
print(json.dumps({'release': verified['html_url'], 'tag': verified['tag_name'],
                  'asset': published_asset['browser_download_url'], 'bytes': published_asset['size']}, ensure_ascii=False))
