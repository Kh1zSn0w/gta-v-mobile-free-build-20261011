"""Reuse the pinned shader outputs from the last verified build, held privately.

The shader compiler's upstream release is unavailable. These are the exact
device shaders already compiled for this engine and renderer, not a substitute
shader set. Any renderer/compiler change invalidates this cache.
"""
from pathlib import Path
import hashlib
import io
import json
import os
import sys
import urllib.error
import urllib.request
import zipfile

root = Path(__file__).resolve().parents[1]
manifest = json.loads((root / 'Scripts/verified_shaders.json').read_text())
for name, digest in manifest['source'].items():
    actual = hashlib.sha256((root / name).read_bytes().replace(b'\r\n', b'\n')).hexdigest()
    if actual != digest:
        raise RuntimeError('Shader cache no longer matches the source: ' + name)
out = root / 'GeneratedResources'
if '--check' not in sys.argv:
    token = os.environ['PRIVATE_DELIVERY_TOKEN']
    headers = {'Authorization': 'Bearer ' + token, 'Accept': 'application/vnd.github+json', 'User-Agent': 'GTA-V-MOBILE'}
    repo = 'https://api.github.com/repos/Kh1zSn0w/gta5-ios-port-private-20261011'
    with urllib.request.urlopen(urllib.request.Request(repo + '/releases/tags/personal-v2.3-free-build-39483597989', headers=headers), timeout=60) as response:
        release = json.load(response)
    asset = next(a for a in release['assets'] if a['name'] == 'GTA5Port.ipa')
    class NoRedirect(urllib.request.HTTPRedirectHandler):
        def redirect_request(self, req, fp, code, msg, response_headers, newurl):
            return None
    request = urllib.request.Request(repo + '/releases/assets/' + str(asset['id']), headers={**headers, 'Accept': 'application/octet-stream'})
    try:
        with urllib.request.build_opener(NoRedirect).open(request, timeout=60) as response:
            data = response.read()
    except urllib.error.HTTPError as error:
        if error.code not in (301, 302, 303, 307, 308):
            raise
        location = error.headers['Location']
        if not location.startswith('https://'):
            raise RuntimeError('Unexpected asset redirect')
        # Never forward repository credentials to the asset-storage host.
        with urllib.request.urlopen(location, timeout=180) as response:
            data = response.read()
    if hashlib.sha256(data).hexdigest() != manifest['ipa_sha256']:
        raise RuntimeError('Previous IPA checksum mismatch')
    out.mkdir(exist_ok=True)
    with zipfile.ZipFile(io.BytesIO(data)) as bundle:
        for name, digest in manifest['files'].items():
            content = bundle.read('Payload/PlayGTA5Native.app/' + name)
            if hashlib.sha256(content).hexdigest() != digest:
                raise RuntimeError('Verified shader checksum mismatch: ' + name)
            (out / name).write_bytes(content)
for name, digest in manifest['files'].items():
    if hashlib.sha256((out / name).read_bytes()).hexdigest() != digest:
        raise RuntimeError('Shader output changed: ' + name)
print('VERIFIED IPHONE SHADERS READY')
