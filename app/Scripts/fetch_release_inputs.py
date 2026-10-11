"""Fetch and verify just the engine, manifest and shaders required for the build."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import zipfile

root = Path(__file__).resolve().parents[2]
inputs = json.loads((root / 'build-inputs.json').read_text(encoding='utf-8-sig'))
destination = root / 'app/Build/Inputs/mirror'
prefix = 'mirror/playgta5.com/'
with tempfile.TemporaryDirectory(prefix='gta-build-') as scratch:
    for part in inputs['parts']:
        archive = Path(scratch) / part['name']
        subprocess.run(['curl', '--fail', '--location', '--retry', '3',
                        '--silent', '--show-error', '--output', str(archive), part['url']], check=True)
        with archive.open('rb') as source:
            digest = hashlib.file_digest(source, 'sha256').hexdigest()
        if archive.stat().st_size != part['bytes'] or digest != part['sha256']:
            raise SystemExit('Release archive checksum mismatch.')
        records = [record for record in inputs['files'] if record['part'] == part['name']]
        with zipfile.ZipFile(archive) as bundle:
            for record in records:
                relative = record['path'].removeprefix(prefix)
                target = (destination / relative).resolve()
                if not target.is_relative_to(destination.resolve()) or not record['path'].startswith(prefix):
                    raise SystemExit('Unsafe build input path.')
                target.parent.mkdir(parents=True, exist_ok=True)
                with bundle.open(record['path']) as source, target.open('wb') as output:
                    shutil.copyfileobj(source, output)
                with target.open('rb') as source:
                    digest = hashlib.file_digest(source, 'sha256').hexdigest()
                if target.stat().st_size != record['bytes'] or digest != record['sha256']:
                    raise SystemExit('Build input checksum mismatch: ' + relative)
        archive.unlink()
print('Verified engine, manifest and shaders ready.', flush=True)
