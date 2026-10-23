"""Send personal native build outputs to the owner's private repository only."""
import json
import os
from pathlib import Path
import urllib.parse
import urllib.request

private = 'Kh1zSn0w/gta5-ios-port-private-20261011'
token = os.environ['PRIVATE_DELIVERY_TOKEN']
headers = {'Authorization': 'Bearer ' + token, 'Accept': 'application/vnd.github+json', 'User-Agent': 'Personal-IPA-Delivery'}
def api(path, data=None):
    request = urllib.request.Request('https://api.github.com' + path,
        data=None if data is None else json.dumps(data).encode(), headers=headers)
    with urllib.request.urlopen(request, timeout=120) as response:
        return json.load(response)

assert api('/repos/' + private)['private'], 'Native output destination must remain private'
run_id = os.environ['GITHUB_RUN_ID']
sha = os.environ['GITHUB_SHA']
result = os.environ['BUILD_RESULT']
configuration = json.loads(Path('build-delivery.json').read_text())
version = configuration['version']
private_sha = configuration['private_source_sha']
run_url = 'https://github.com/' + os.environ['GITHUB_REPOSITORY'] + '/actions/runs/' + run_id
release = api('/repos/' + private + '/releases', {
    'tag_name': 'personal-v' + version + '-free-build-' + run_id,
    'target_commitish': private_sha,
    'name': 'GTA V MOBILE',
    'body': 'GTA V MOBILE',
    'draft': False, 'prerelease': True})
report = {'source_sha': sha, 'run_id': run_id, 'run_url': run_url, 'build_result': result,
    'private_source_sha': private_sha, 'version': version}
Path('native-build-report.json').write_text(json.dumps(report, indent=2))
files = [Path('native-build-report.json'), Path('app/Build/xcodebuild.log')]
if result == 'success':
    ipa = Path('GTA5Port.ipa')
    assert ipa.is_file() and ipa.stat().st_size > 10000000
    files.append(ipa)
for file in files:
    if not file.is_file(): continue
    asset_name = configuration['output_name'] if file.suffix == '.ipa' else file.name
    url = release['upload_url'].split('{', 1)[0] + '?name=' + urllib.parse.quote(asset_name)
    assert urllib.parse.urlparse(url).hostname == 'uploads.github.com'
    request = urllib.request.Request(url, data=file.read_bytes(), method='POST',
        headers={**headers, 'Content-Type': 'application/octet-stream'})
    with urllib.request.urlopen(request, timeout=240) as response:
        uploaded = json.load(response)
    print('Privately delivered: ' + uploaded['name'])
print(release['html_url'])
