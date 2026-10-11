"""Two ordinary ADB touch pointers; no game command or app permission changes."""
from pathlib import Path
import hashlib
import math
import os
import subprocess
import threading
import zipfile

_BUILD_LOCK = threading.Lock()


def prepare(sdk, cache):
    # Fleet inputs can arrive concurrently on four devices. Publish only a
    # complete dex archive; an interrupted compiler must not poison the cache.
    with _BUILD_LOCK:
        return _prepare(sdk, cache)


def _prepare(sdk, cache):
    sdk, cache = Path(sdk), Path(cache)
    source = Path(__file__).parent / 'android_fleet_touch/FleetTouch.java'
    jars = sorted((sdk / 'platforms').glob('android-*/android.jar'))
    dexers = sorted((sdk / 'build-tools').glob('*/d8'))
    if not jars or not dexers:
        raise RuntimeError('Android SDK android.jar/d8가 없어 실제 복수 터치를 전달할 수 없습니다.')
    digest = hashlib.sha256(source.read_bytes()+str(jars[-1]).encode()+str(dexers[-1]).encode()).hexdigest()
    work = cache / digest[:16]
    jar = work / 'fleet-touch.jar'
    if jar.exists():
        try:
            with zipfile.ZipFile(jar) as archive:
                if 'classes.dex' in archive.namelist(): return jar
        except zipfile.BadZipFile:
            pass
    work.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    if not env.get('JAVA_HOME') and Path('/usr/libexec/java_home').exists():
        env['JAVA_HOME'] = subprocess.check_output(['/usr/libexec/java_home', '-v', '17'], text=True).strip()
    for command in (
        ['javac', '-source', '8', '-target', '8', '-cp', str(jars[-1]), '-d', str(work), str(source)],
        [str(dexers[-1]), '--min-api', '29', '--lib', str(jars[-1]), '--output', str(work/'fleet-touch-new.jar'), str(work/'FleetTouch.class')],
    ):
        result = subprocess.run(command, capture_output=True, env=env, timeout=60)
        if result.returncode:
            raise RuntimeError('ADB 복수 터치 도구 컴파일 실패: '+result.stderr.decode(errors='replace')[:600])
    with zipfile.ZipFile(work/'fleet-touch-new.jar') as archive:
        if 'classes.dex' not in archive.namelist():
            raise RuntimeError('ADB 터치 도구에 Android 실행 코드가 없습니다.')
    os.replace(work/'fleet-touch-new.jar', jar)
    return jar


def perform(adb, jar, first, second, lead_ms=120, hold_ms=160):
    coordinates = [float(v) for point in (first, second) for v in point]
    if len(coordinates) != 4 or any(not math.isfinite(v) or v < 0 for v in coordinates):
        raise ValueError('실제 터치 좌표는 유한한 양수 네 값이어야 합니다.')
    if not 80 <= lead_ms <= 1000 or not 40 <= hold_ms <= 2000:
        raise ValueError('실제 터치 시간 범위를 벗어났습니다.')
    jar = Path(jar)
    remote = '/data/local/tmp/fa-fleet-touch-'+hashlib.sha256(jar.read_bytes()).hexdigest()[:16]+'.jar'
    adb.run('push', str(jar), remote)
    try:
        result = adb.shell('env', 'CLASSPATH='+remote, 'app_process', '/system/bin', 'FleetTouch',
                           *[str(v) for v in coordinates], str(lead_ms), str(hold_ms), timeout=15)
        if 'FOREST_ARENA_ADB_MULTI_TOUCH_COMPLETE' not in result:
            raise RuntimeError('ADB 복수 터치 완료 응답이 없습니다.')
    finally:
        adb.shell('rm', '-f', remote, timeout=3)
    return {'source': 'adb_touch_multi_pointer', 'first': list(first), 'second': list(second),
            'lead_ms': lead_ms, 'hold_ms': hold_ms, 'release_confirmed_by_injector': True}
