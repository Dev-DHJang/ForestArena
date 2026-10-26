"""Archive every raw RGBA frame after checking pixel-exact restoration."""
import argparse
import hashlib
import json
import subprocess
from pathlib import Path


def digest(path):
    result = hashlib.sha256()
    with path.open('rb') as source:
        for chunk in iter(lambda: source.read(8 * 1024 * 1024), b''):
            result.update(chunk)
    return result.hexdigest()


def rgba_hashes(arguments):
    data = subprocess.check_output(['ffmpeg', '-v', 'error', *arguments,
                                   '-pix_fmt', 'rgba', '-f', 'framemd5', '-']).decode()
    return [line.rsplit(',', 1)[1].strip() for line in data.splitlines()
            if line and not line.startswith('#')]


parser = argparse.ArgumentParser()
parser.add_argument('capture', type=Path)
parser.add_argument('--remove-verified-raw', action='store_true')
args = parser.parse_args()
base = args.capture.resolve()
assert base.is_relative_to(Path(__file__).resolve().parent / "qa")
report_path = base / 'state-report.json'
report = json.loads(report_path.read_text())
assert report['errors'] == [] and report['scenarios']
receipt = base / 'raw-archive.json'
assert not receipt.exists()
records = []
for clip in report['scenarios']:
    assert not clip['state_only'] and clip['actual_fixed_tick'] and not clip['synthetic_phases']
    assert clip['capture_stride'] == 1 and clip['raw_capture']
    source = base / clip['name'] / 'frames.rgba'
    dimensions = clip['capture_dimensions']
    count = clip['frame_count']
    assert source.stat().st_size == dimensions[0] * dimensions[1] * 4 * count
    source_digest = digest(source)
    input_args = ['-f', 'rawvideo', '-pixel_format', 'rgba', '-video_size',
                  f'{dimensions[0]}x{dimensions[1]}', '-framerate', '60', '-i', str(source)]
    original = rgba_hashes(input_args)
    movie = base / f"{clip['name']}-lossless-rgb.mkv"
    assert not movie.exists()
    subprocess.run(['ffmpeg', '-v', 'error', *input_args, '-c:v', 'libx264rgb',
                    '-crf', '0', '-preset', 'fast', '-pix_fmt', 'rgb24', str(movie)], check=True)
    restored = rgba_hashes(['-i', str(movie)])
    assert len(original) == count and original == restored, f"RGBA mismatch {clip['name']}"
    preview = base / f"{clip['name']}.mp4"
    subprocess.run(['ffmpeg', '-v', 'error', '-i', str(movie), '-c:v', 'libx264',
                    '-crf', '18', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', str(preview)], check=True)
    row = {'clip': clip['name'], 'source_ticks': count, 'fps': 60, 'dimensions': dimensions,
           'source_raw_sha256': source_digest, 'source_raw_bytes': source.stat().st_size,
           'archive': movie.name, 'archive_sha256': digest(movie), 'rgba_md5': original,
           'all_rgba_frames_equal': True, 'source_raw_removed': False,
           'restoration': 'ffmpeg -i ARCHIVE -pix_fmt rgba -f rawvideo restored.rgba'}
    records.append(row)
    # Write a receipt before removing duplicate temporary bytes.
    receipt.write_text(json.dumps({'capture_report_sha256': digest(report_path),
                                  'status': 'all captured RGBA frames restore exactly from lossless MKV',
                                  'clips': records}, ensure_ascii=False, indent=2) + '\n')
    if args.remove_verified_raw:
        source.unlink()
        row['source_raw_removed'] = True
        receipt.write_text(json.dumps({'capture_report_sha256': digest(report_path),
                                      'status': 'all captured RGBA frames restore exactly from lossless MKV',
                                      'clips': records}, ensure_ascii=False, indent=2) + '\n')
    print(f"archived {clip['name']}: {count} exact RGBA frames", flush=True)
print(f"finished {len(records)} clips / {sum(row['source_ticks'] for row in records)} frames")
