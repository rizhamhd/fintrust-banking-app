"""Download original assets using the curl instructions from Figma."""
import concurrent.futures
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def download(item):
    local, url = item
    dest = ROOT / local
    dest.parent.mkdir(parents=True, exist_ok=True)
    if not dest.exists() or dest.stat().st_size == 0:
        subprocess.run(['curl', '-f', '-sS', '-L', '--retry', '2', '--max-time', '90', '-o', str(dest), url], check=True)
    return local


if __name__ == '__main__':
    assets = json.loads((ROOT/'design/asset_manifest.json').read_text())
    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
        for local in pool.map(download, assets.items()):
            print(local, flush=True)
