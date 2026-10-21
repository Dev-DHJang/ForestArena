"""Read existing logical IDs only when basename and actual source bytes match."""
import hashlib
import json
from pathlib import Path


def registry_candidates(root):
    root=Path(root).resolve();result={}
    registry=json.loads((root/'forest_arena/data/resource_registry.json').read_text())
    for asset in registry['assets']:
        basename=Path(asset.get('relative_path') or asset.get('path','')).name
        paths=[asset['path']] if asset.get('path') else list(asset.get('variants',{}).values())
        for resource in paths:
            if not resource.startswith('res://'): continue
            path=(root/resource.removeprefix('res://')).resolve()
            if path.is_relative_to(root) and path.is_file():result.setdefault(basename,[]).append((asset['id'],path))
    return result


def existing_runtime_ids(source_path, source_sha256, candidates, digest_cache=None):
    digest_cache={} if digest_cache is None else digest_cache
    matches=set()
    for logical_id,path in candidates.get(Path(source_path).name,[]):
        if path not in digest_cache:digest_cache[path]=hashlib.sha256(path.read_bytes()).hexdigest()
        if digest_cache[path] == source_sha256:matches.add(logical_id)
    return sorted(matches)
