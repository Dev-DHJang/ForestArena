#!/usr/bin/env python3
"""승인 아이콘 원본·설정과 선택적으로 APK에 포함된 실제 픽셀을 검사한다."""
from pathlib import Path
from PIL import Image
import argparse
import hashlib
from datetime import datetime, timezone
import os
import io
import json
import re
import subprocess
import tempfile
import zipfile
import numpy as np
ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / 'assets/branding/myo-ryung-v02'
def compare_icon(original, packed):
    if original.size != packed.size:
        return {"valid": False, "size_equal": False}
    a = np.asarray(original, dtype=np.int16)
    b = np.asarray(packed, dtype=np.int16)
    delta = np.abs(a - b)
    alpha_equal = bool(np.array_equal(a[:, :, 3], b[:, :, 3]))
    opaque = a[:, :, 3] == 255
    opaque_rgb_equal = bool(np.array_equal(a[:, :, :3][opaque], b[:, :, :3][opaque]))
    premultiplied = delta[:, :, :3] * (a[:, :, 3:4] / 255.0)
    mean_delta = float(premultiplied.mean())
    changed = np.any(delta > 0, axis=2)
    return {
        "valid": alpha_equal and opaque_rgb_equal and mean_delta < 0.05,
        "rgba_bytes_equal": original.tobytes() == packed.tobytes(),
        "alpha_equal": alpha_equal,
        "opaque_rgb_equal": opaque_rgb_equal,
        "changed_pixels": int(changed.sum()),
        "changed_visible_pixels": int(np.count_nonzero(changed & (a[:, :, 3] > 0))),
        "changed_alpha_range": [int(a[:, :, 3][changed].min()), int(a[:, :, 3][changed].max())] if changed.any() else None,
        "premultiplied_mean_channel_delta_255": mean_delta,
        "premultiplied_max_channel_delta_255": float(premultiplied.max()),
    }


def verify_assets(root=ROOT):
    assets=root/'assets/branding/myo-ryung-v02'
    manifest=json.loads((assets/'manifest.json').read_text())
    issues=[]
    source=root/Path(manifest['source_record']).parent/'source/approved-myo-ryung.png'
    if not source.is_file() or hashlib.sha256(source.read_bytes()).hexdigest()!=manifest['approved_source_sha256']:
        issues.append('승인 원본 지문 불일치')
    for row in manifest['assets']:
        path=root/row['path']
        if not path.is_file():
            issues.append('누락: '+row['path']);continue
        if hashlib.sha256(path.read_bytes()).hexdigest()!=row['sha256']:issues.append('해시 불일치: '+row['path'])
        with Image.open(path) as im:
            if list(im.size)!=row['size']:issues.append('크기 불일치: '+row['path'])
            if row['alpha'] and im.convert('RGBA').getchannel('A').getextrema()!=(0,255):issues.append('투명도 불일치: '+row['path'])
    foreground=Image.open(assets/'adaptive-foreground-432.png').convert('RGBA')
    alpha=np.asarray(foreground)[:,:,3]
    if int(np.count_nonzero(alpha[345:360,140:292]>128))<=1500:issues.append('목·어깨·옷이 런처 아래쪽까지 이어져야 함')
    settings=(root/'project.godot').read_text()
    if 'config/icon="res://assets/branding/myo-ryung-v02/app-icon-1024.png"' not in settings:issues.append('프로젝트 아이콘 경로')
    if 'boot_splash/show_image=false' not in settings:issues.append('Godot 시작 로고 설정')
    presets=(root/'export_presets.cfg').read_text()
    android=0
    for section in re.split(r'(?=\[preset\.\d+\]\s)',presets):
        if 'platform="Android"' not in section:continue
        android+=1
        for key,name in [('main_192x192','main-192.png'),('adaptive_foreground_432x432','adaptive-foreground-432.png'),('adaptive_background_432x432','adaptive-background-432.png')]:
            if f'launcher_icons/{key}="res://assets/branding/myo-ryung-v02/{name}"' not in section:issues.append('Android 아이콘 경로: '+key)
    if android<2:issues.append('Android Debug·Demo 설정 누락')
    return issues,manifest


def verify_apk(apk,root=ROOT):
    assets=root/'assets/branding/myo-ryung-v02';issues=[];results=[]
    paths={'main-192.png':'res/mipmap-xxxhdpi-v4/icon.webp','adaptive-foreground-432.png':'res/mipmap-xxxhdpi-v4/icon_foreground.webp','adaptive-background-432.png':'res/mipmap-xxxhdpi-v4/icon_background.webp'}
    with zipfile.ZipFile(apk) as archive:
        for filename,packed in paths.items():
            comparison=compare_icon(Image.open(assets/filename).convert('RGBA'),Image.open(io.BytesIO(archive.read(packed))).convert('RGBA'))
            results.append({'source':filename,'apk_path':packed,**comparison})
            if not comparison['valid']:issues.append('APK 아이콘 불일치: '+filename)
        foreground=Image.open(assets/'adaptive-foreground-432.png').convert('RGBA')
        splash=Image.open(io.BytesIO(archive.read('res/drawable/splash_icon.webp'))).convert('RGBA')
        if not compare_icon(foreground,splash)['valid']:issues.append('Android 시작 아이콘 불일치')
        branding=Image.open(io.BytesIO(archive.read('res/drawable/splash_branding_image.webp'))).convert('RGBA')
        if branding.getchannel('A').getextrema()!=(0,0):issues.append('Android branding image는 투명해야 함')
        packed_icon=archive.read('assets/assets/branding/myo-ryung-v02/app-icon-1024.png')
        if packed_icon!=(assets/'app-icon-1024.png').read_bytes():issues.append('APK 프로젝트 아이콘 불일치')
        with tempfile.TemporaryDirectory(prefix='fa-packaged-settings-') as folder:
            Path(folder,'project.binary').write_bytes(archive.read('assets/project.binary'))
            result=subprocess.run(['godot','--headless','--path',folder,'--script',str(root/'tools/forest_arena/inspect_packaged_boot.gd')],text=True,capture_output=True,timeout=30)
            line=next((x for x in result.stdout.splitlines() if x.startswith('PACKAGED_BOOT ')),None)
            if result.returncode or not line or 'SCRIPT ERROR' in result.stderr:raise RuntimeError('APK 설정을 읽을 수 없음')
            boot=json.loads(line.removeprefix('PACKAGED_BOOT '))
            if boot.get('show_image') is not False or boot.get('minimum_display_time')!=0:issues.append('APK Godot 시작 로고 설정')
            if boot.get('main_scene')!='res://scenes/startup_title.tscn':issues.append('APK 시작 장면')
            if boot.get('icon')!='res://assets/branding/myo-ryung-v02/app-icon-1024.png':issues.append('APK 프로젝트 아이콘 경로')
    sdk=Path(os.environ.get('ANDROID_SDK_ROOT') or os.environ.get('ANDROID_HOME') or Path.home()/'Library/Android/sdk')
    candidates=list((sdk/'build-tools').glob('*/aapt'))
    if not candidates:raise RuntimeError('APK 버전 확인을 위한 Android aapt가 없음')
    aapt=max(candidates,key=lambda p:tuple(int(n) for n in re.findall(r'\d+',p.parent.name)))
    badging=subprocess.check_output([str(aapt),'dump','badging',str(apk)],text=True)
    def field(name):
        match=re.search(name+r"='([^']*)'",badging)
        if not match:raise RuntimeError('APK 버전 메타데이터 누락: '+name)
        return match.group(1)
    return issues,{'native_icons':results,'packed_boot_settings':boot,'apk_sha256':hashlib.sha256(apk.read_bytes()).hexdigest(),
        'version_code':field('versionCode'),'version_name':field('versionName'),
        'source_commit':subprocess.check_output(['git','-C',str(root),'rev-parse','HEAD'],text=True).strip(),
        'source_status':subprocess.check_output(['git','-C',str(root),'status','--porcelain','--untracked-files=no'],text=True).splitlines(),
        'icon_manifest_sha256':hashlib.sha256((assets/'manifest.json').read_bytes()).hexdigest(),
        'verified_at_utc':datetime.now(timezone.utc).isoformat()}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apk',type=Path)
    parser.add_argument('--output',type=Path)
    args=parser.parse_args()
    try:
        issues,manifest=verify_assets()
        report={'status':'PASS','issues':issues,'icon_version':manifest['version'],'physical_device':'not-run'}
        if args.apk:
            more,details=verify_apk(args.apk.resolve());issues.extend(more);report.update(details)
        report['status']='FAIL' if issues else 'PASS'
    except (OSError,ValueError,KeyError,RuntimeError,zipfile.BadZipFile) as error:
        report={'status':'FAIL','issues':[str(error)]}
    if args.output:
        args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    print('BRANDING: '+report['status']+'; '+'; '.join(report['issues']))
    return int(report['status']!='PASS')

if __name__=='__main__':raise SystemExit(main())
