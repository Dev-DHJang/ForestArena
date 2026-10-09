#!/usr/bin/env python3
"""Original, sample-free v02 listening previews; never replaces runtime audio."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import wave

import numpy as np

SR = 44100
SEED = 20261009
ROOT = Path(__file__).resolve().parents[2]
DEFAULT_OUTPUT = ROOT / 'assets/audio/v02-preview/source/sfx'
SPECS = {
    'ui_click': (.22, '기계 스위치의 딸각: 밝고 짧은 첫 접촉 뒤 24ms에 낮은 접촉. 음정·종소리 없이 서로 다른 잡음 대역을 사용.'),
    'jump': (.22, '큰 상승음 대신 짧은 공기 추진과 낮은 탄성. 완만한 상승만 남겨 점프 방향을 표현.'),
    'hit_light': (.22, '약한 타격 파악: 강타보다 밝고 넓은 공기층과 짧은 표면 접촉. 금속·목재 공명과 음정 진행 없이 가벼운 몸통을 표현.'),
    'hit_heavy': (.22, '짧고 묵직한 퍽: 살과 둔탁한 타격의 90~135Hz 몸통에 짧은 광대역 접촉을 겹침. 목재 균열·종 공명·상승음 제거.'),
    'guard_break': (.65, '가드 파괴 채앵: 날카로운 첫 접촉과 불규칙한 금속 공명·작은 주파수 차의 떨림·빠른 여운. 목재 붕괴와 발랄한 상승 멜로디는 제거.'),
    'myo-ryung_special_up': (.65, '묘령의 가벼운 공중 감각은 유지하되 상승 아르페지오를 넓은 숨결과 잔잔한 두 공명으로 변경.'),
    'ja-hyun_ultimate': (1.15, '자현의 나무·기류 질감은 유지하고 다섯 음 상승을 세 번의 둔한 목재 힘과 낮은 공기 방출로 변경.'),
}


def _edge(t: np.ndarray, duration: float, attack=.002, release=.025) -> np.ndarray:
    return np.minimum(t / attack, 1) * np.minimum((duration - t) / release, 1).clip(0, 1)


def _noise(rng: np.random.Generator, count: int, width: int) -> np.ndarray:
    kernel = np.hanning(width)
    kernel /= kernel.sum()
    return np.convolve(rng.standard_normal(count), kernel, mode='same') * np.sqrt(width / 3)


def effect(name: str) -> np.ndarray:
    """Render mono floating point waveform from a name-stable random seed."""
    duration, _ = SPECS[name]
    rng = np.random.default_rng(SEED + int.from_bytes(hashlib.sha256(name.encode()).digest()[:4], 'little'))
    t = np.arange(round(duration * SR)) / SR
    out = np.zeros(len(t), dtype=np.float64)

    def tone(freq, gain, decay, offset=0., attack=.0015, ratio=1.):
        age = (t - offset).clip(0)
        active = t >= offset
        phase = 2 * np.pi * freq * (age + (ratio - 1) * age * age / (2 * duration))
        return gain * np.sin(phase) * np.exp(-age * decay) * np.minimum(age / attack, 1) * active

    def wood(gain, offset=0., low=340., decay=34):
        # Inharmonic, damped body modes rather than a tuned bell melody.
        return sum(tone(low * ratio, gain * level, decay * damp, offset)
                   for ratio, level, damp in ((1., 1., 1.), (1.79, .42, 1.5), (3.13, .18, 2.2)))

    def air(gain, width, decay, offset=0., attack=.004):
        age = (t - offset).clip(0)
        return (gain * _noise(rng, len(t), width) * np.exp(-age * decay)
                * np.minimum(age / attack, 1) * (t >= offset))

    if name == 'ui_click':
        # Two brief mechanical contacts: bright "딸", followed by lower "각".
        # Broadband decays avoid pitched/bell ringing and a musical interval.
        out += air(.44, 5, 190, attack=.0005)
        out += air(.20, 15, 135, attack=.0008)
        out += air(.52, 35, 155, .024, attack=.0006)
        out += air(.15, 9, 210, .024, attack=.0005)
    elif name == 'jump':
        out += air(.34, 35, 11, attack=.015)
        out += tone(185, .23, 13, attack=.008, ratio=1.6)
        out += wood(.11, low=310, decay=50)
    elif name == 'hit_light':
        # A brighter surface "파악": broad air/contact rather than a ringing note.
        out += air(.48, 9, 39, attack=.003)
        out += air(.30, 3, 120, .002, attack=.0007)
        out += air(.16, 23, 31, .008, attack=.004)
        out += tone(150, .15, 58, attack=.0015)
    elif name == 'hit_heavy':
        # A short flesh/body thud: no wood modes and no pitched sweep.
        out += tone(90, .67, 38, attack=.001)
        out += tone(135, .23, 65, attack=.001)
        out += air(.46, 5, 155, attack=.0006)
        out += air(.28, 67, 43, .003, attack=.0015)
    elif name == 'guard_break':
        # Simultaneous inharmonic metal modes, not an arpeggio or pitched sweep.
        out += air(.39, 3, 145, attack=.0006)
        for ratio, gain, decay in ((1., .20, 8), (1.414, .19, 9), (1.932, .15, 13),
                                   (2.631, .11, 16), (3.791, .065, 22)):
            freq = 965 * ratio
            out += tone(freq, gain, decay, .001, attack=.001)
            out += tone(freq * 1.0023, gain * .24, decay * 1.15, .001, attack=.001)
        out += air(.11, 5, 90, .043, attack=.0007)
        out += air(.06, 3, 130, .076, attack=.0006)
    elif name == 'myo-ryung_special_up':
        # Airborne character retains a light upper signature, without stepped notes.
        out += air(.27, 49, 4.5, attack=.032)
        out += tone(587.33, .18, 4.8, attack=.035, ratio=1.035)
        out += tone(880, .065, 7., attack=.045)
        out += tone(240, .11, 11, attack=.02, ratio=1.3)
        out += wood(.065, low=420, decay=35)
    elif name == 'ja-hyun_ultimate':
        out += air(.23, 53, 3.6, attack=.025)
        for offset, low, gain in ((.008, 260, .28), (.097, 335, .25), (.206, 210, .44)):
            out += wood(gain, offset, low, decay=17)
        out += tone(92, .42, 5.8, .205, attack=.009, ratio=.65)
        out += air(.21, 17, 9, .207, attack=.006)
        out += tone(440, .075, 5, .21, attack=.04)
    # Suppress DC before final boundary fades, then leave at least 2 dB peak headroom.
    out -= out.mean()
    out *= _edge(t, duration)
    out[-1] = 0
    peak = float(np.max(np.abs(out)))
    out *= (.62 if name.startswith('ui_') else .76) / max(peak, 1e-12)
    return out.astype(np.float32)


def generate(output_dir: Path | str = DEFAULT_OUTPUT) -> list[dict]:
    """Write the seven preview WAVs and return metadata for the parent manifest."""
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    entries = []
    for name, (duration, notes) in SPECS.items():
        target = output_dir / f'{name}.wav'
        data = effect(name)
        pcm = np.rint(data * 32767).astype('<i2')
        with wave.open(str(target), 'wb') as handle:
            handle.setnchannels(1)
            handle.setsampwidth(2)
            handle.setframerate(SR)
            handle.writeframes(pcm.tobytes())
        entries.append({'name': name, 'duration': duration, 'notes': notes,
                        'source': str(target), 'sample_rate_hz': SR, 'channels': 1,
                        'pcm_bits': 16, 'sha256': hashlib.sha256(target.read_bytes()).hexdigest(),
                        'peak': round(float(np.max(np.abs(data))), 6),
                        'rms': round(float(np.sqrt(np.mean(data.astype(float) ** 2))), 6)})
    return entries


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir', type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    print(json.dumps(generate(args.output_dir), ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
