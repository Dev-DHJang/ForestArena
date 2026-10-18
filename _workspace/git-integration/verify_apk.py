"""실기기 없이 실제 APK의 새 아이콘·부트·승인 자산 연결을 확인한다."""
from pathlib import Path
import hashlib
import io
import json
import re
import subprocess
import tempfile
import zipfile
from PIL import Image
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
APK = ROOT / 'build/android/ForestArena-debug.apk'


def compare(original, packed):
    assert original.size == packed.size
    a = np.asarray(original, dtype=np.int16)
    b = np.asarray(packed, dtype=np.int16)
    opaque = a[:, :, 3] == 255
    alpha_equal = bool(np.array_equal(a[:, :, 3], b[:, :, 3]))
    opaque_equal = bool(np.array_equal(a[:, :, :3][opaque], b[:, :, :3][opaque]))
    # Use float before multiplication: int16 overflow would invalidate the test.
    delta = np.abs(a[:, :, :3].astype(float) - b[:, :, :3]) * (a[:, :, 3:4] / 255.0)
    mean = float(delta.mean())
    assert alpha_equal and opaque_equal and mean < 0.05
    return {'alpha_equal': alpha_equal, 'opaque_rgb_equal': opaque_equal,
            'premultiplied_mean_channel_delta_255': mean}


with zipfile.ZipFile(APK) as apk:
    names = set(apk.namelist())
    manifest_path = 'assets/character/manifest.json'
    assert apk.read('assets/' + manifest_path) == (ROOT / manifest_path).read_bytes()
    layout_path = 'forest_arena/data/character_display_layout_v01.json'
    assert apk.read('assets/' + layout_path) == (ROOT / layout_path).read_bytes()
    entries = json.loads(apk.read('assets/' + manifest_path))['assets']
    count = 0
    for entry in entries:
        if entry.get('type') != 'animation-runtime':
            continue
        remap = apk.read('assets/' + entry['path'] + '.import').decode()
        texture = re.search(r'^path="res://([^"\n]+)"', remap, re.M).group(1)
        assert apk.read('assets/' + texture) == (ROOT / texture).read_bytes(), entry['asset_id']
        frames = entry['sprite_frames_path'].removeprefix('res://')
        assert 'assets/' + frames in names or 'assets/' + frames + '.remap' in names
        count += 1
    assert count == 120
    icon_results = {}
    for source, target in [('main-192.png', 'res/mipmap-xxxhdpi-v4/icon.webp'),
                           ('adaptive-foreground-432.png', 'res/mipmap-xxxhdpi-v4/icon_foreground.webp'),
                           ('adaptive-background-432.png', 'res/mipmap-xxxhdpi-v4/icon_background.webp'),
                           ('adaptive-foreground-432.png', 'res/drawable/splash_icon.webp')]:
        original = Image.open(ROOT / 'assets/branding/myo-ryung-v01' / source).convert('RGBA')
        packed = Image.open(io.BytesIO(apk.read(target))).convert('RGBA')
        icon_results[target] = compare(original, packed)
    with tempfile.TemporaryDirectory(prefix='forest-integration-boot-') as temporary:
        Path(temporary, 'project.binary').write_bytes(apk.read('assets/project.binary'))
        script = ROOT / '_workspace/myoryung-app-branding/inspect_packaged_boot.gd'
        result = subprocess.run(['godot', '--headless', '--path', temporary, '--script', str(script)],
                                capture_output=True, text=True, timeout=30, check=True)
        assert 'SCRIPT ERROR' not in result.stderr
        line = next(line for line in result.stdout.splitlines() if line.startswith('PACKAGED_BOOT '))
        boot = json.loads(line.removeprefix('PACKAGED_BOOT '))
        assert boot['show_image'] is False and boot['minimum_display_time'] == 0
        assert boot['main_scene'] == 'res://scenes/startup_title.tscn'
        assert boot['icon'] == 'res://assets/branding/myo-ryung-v01/app-icon-1024.png'
    assert 'res/mipmap-anydpi-v26/icon.xml' in names

report = {'status': 'PASS', 'apk': str(APK), 'apk_bytes': APK.stat().st_size,
          'apk_sha256': hashlib.sha256(APK.read_bytes()).hexdigest(),
          'runtime_source_commit': subprocess.check_output(['git', '-C', str(ROOT), 'rev-parse', 'HEAD']).decode().strip(),
          'runtime_texture_count': count, 'manifest_and_layout_bytes_equal': True,
          'native_icons': icon_results, 'packaged_boot': boot,
          'physical_device': '사용자 요청으로 검증 제외; 설치·실행·조작 없음'}
(OUT / 'apk-checks.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
print('APK-INTEGRATION: PASS (120 packaged textures; exact manifest/layout; 4 native icons; title entry; Godot logo disabled).')
print('SHA-256:', report['apk_sha256'])
