"""Restore the exact CC0 upstream data recorded in v03-human-sources.json.

Not needed for normal rebuilds: source data is retained in the repository.
No asset packs, third-party clothing, Mixamo assets or upstream code are fetched.
"""
import hashlib, json, urllib.request
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
rows=json.loads((ROOT/'assets/provenance/v03-human-sources.json').read_text())['files']
for row in rows:
 path=ROOT/row['path']
 if path.exists() and hashlib.sha256(path.read_bytes()).hexdigest()==row['sha256']:
  print('MATCH',row['path']);continue
 data=urllib.request.urlopen(row['url'],timeout=60).read()
 if hashlib.sha256(data).hexdigest()!=row['sha256']:raise RuntimeError('Upstream digest mismatch: '+row['path'])
 path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(data);print('RESTORED',row['path'],len(data))
