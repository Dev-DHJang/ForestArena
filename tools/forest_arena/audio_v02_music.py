#!/usr/bin/env python3
"""Original four-section 60-second listening sketches rendered with FluidR3 GM / FluidSynth."""
from __future__ import annotations
import ctypes as C
import ctypes.util
import hashlib
import json
import struct
import wave
from pathlib import Path
import numpy as np

SR = 44100
SOUNDFONT_SHA256 = '74594e8f4250680adf590507a306655a299935343583256f3b722c48a1bc1cb0'


def write_wav(path, audio):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    x = np.asarray(audio)
    if np.max(np.abs(x)) >= 1:
        raise ValueError(f'Clipping before PCM conversion: {path}')
    with wave.open(str(path), 'wb') as f:
        f.setnchannels(1 if x.ndim == 1 else x.shape[1])
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes(np.rint(x * 32767).astype('<i2').tobytes())


def note(track, beat, length, pitch, velocity=70):
    if pitch is not None:
        track['notes'].append({'beat': round(beat, 5), 'length': round(length, 5),
                               'pitch': pitch, 'velocity': int(velocity)})


def score(battle=False):
    """Hand-composed four-section sketches; no borrowed score or random notes.

    Bar numbers in section metadata are zero-based, with an exclusive end.
    Melody, harmony, rests and accompaniment changes are explicitly authored.
    """
    bpm, bars = (128, 32) if battle else (96, 24)
    specs = [
        ('lead', 60 if battle else 0, 64, .82 if battle else 1.05, '호른 주선율' if battle else '피아노 주선율'),
        ('answer', 68 if battle else 73, 74, .33 if battle else .24, '오보에 응답' if battle else '플루트 응답'),
        ('strings', 44 if battle else 48, 48, .60 if battle else .28, '트레몰로 현악' if battle else '현악 받침'),
        ('counter', 42, 76, .66 if battle else .22, '첼로 리듬·대선율' if battle else '첼로 대선율'),
        ('harp', 46, 38, .28 if battle else .19, '하프'),
        ('piano', 0, 52, .50 if battle else .64, '피아노 저음 강조' if battle else '피아노 왼손 반주'),
        ('bass', 43, 64, .82 if battle else .34, '더블베이스'),
        ('horn', 60, 57, .45 if battle else .08, '프렌치 호른'),
        ('drums', 0, 64, .65 if battle else .07, '저음 북·타악'),
    ]
    tracks = [{'id': name, 'program': program, 'pan': pan, 'gain': gain,
               'instrument': label, 'channel': 9 if name == 'drums' else i,
               'notes': []} for i, (name, program, pan, gain, label) in enumerate(specs)]
    by = {t['id']: t for t in tracks}
    if battle:
        # A-minor tension: G# in E7 and B-D-F diminished preparations.
        harmony = [
            (45,[57,60,64],'Am'), (40,[57,60,64],'Am/E'),
            (41,[57,60,64,65],'Fmaj7'), (40,[56,59,62,64],'E7'),
            (38,[57,62,65],'Dm'), (47,[59,62,65],'Bdim'),
            (40,[56,59,62,64],'E7'), (45,[57,60,64],'Am'),
            (45,[57,60,64],'Am'), (41,[57,60,65],'F'),
            (38,[57,62,65],'Dm'), (40,[56,59,62,64],'E7'),
            (48,[57,60,64],'Am/C'), (47,[59,62,65],'Bdim'),
            (40,[56,59,62,64],'E7'), (45,[57,60,64],'Am'),
            (38,[57,62,64,65],'Dm(add9)'), (48,[57,60,64],'Am/C'),
            (47,[59,62,65],'Bdim'), (40,[56,59,62,64],'E7'),
            (41,[57,60,64,65],'Fmaj7'), (38,[57,62,65],'Dm'),
            (47,[59,62,65],'Bdim'), (40,[56,59,62,64],'E7'),
            (45,[57,60,64],'Am'), (41,[57,60,65],'F'),
            (38,[57,62,65],'Dm'), (40,[56,59,62,64],'E7'),
            (47,[59,62,65],'Bdim'), (40,[56,59,62,64],'E7'),
            (40,[57,60,64],'Am/E'), (45,[57,60,64],'Am'),
        ]
        phrases = [
            # Introduction: separated lower-register calls, then an expanding pulse.
            [(0,1.2,69),(2,.7,72)],
            [(.5,.65,76),(1.5,.5,72),(2.5,.9,69)],
            [(0,.8,77),(1.25,.5,76),(2.25,1,72)],
            [(0,.65,71),(1,.6,68),(2,1.1,76)],
            [(0,.5,74),(.75,.4,77),(1.5,.5,74),(2.5,.85,69)],
            [(.5,.55,71),(1.5,.55,74),(2.5,.65,77)],
            [(0,.5,76),(.75,.3,74),(1.5,.5,71),(2.5,1,68)],
            [(0,1.4,69),(2.25,.45,72),(3,.55,76)],
            # Theme: original short-short-long cell, with varied answering gestures.
            [(0,.5,76),(.75,.25,76),(1.5,.65,72),(2.5,1,69)],
            [(0,.65,77),(1,.4,72),(1.75,.6,69),(2.75,.7,72)],
            [(.25,.45,74),(1,.4,77),(1.75,.7,81),(3,.5,77)],
            [(0,.55,76),(1,.4,74),(1.75,.5,71),(2.75,.85,68)],
            [(0,.45,72),(.75,.35,76),(1.5,.7,81),(2.75,.75,76)],
            [(.25,.5,77),(1,.4,74),(1.75,.55,71),(2.75,.7,74)],
            [(0,.6,76),(1,.35,71),(1.75,.35,74),(2.5,.9,68)],
            [(0,1.6,69),(2.25,.5,72)],
            # Contrast: broad quiet calls; the gaps belong to oboe and cello.
            [(0,1.8,74)], [(1,1.5,72)],
            [(0,1.2,71),(2,.8,74)], [(0,1.7,68)],
            [(0,.7,77),(1.25,.55,76),(2.25,1.1,72)],
            [(.25,.5,74),(1,.5,77),(2,.65,81),(3,.55,77)],
            [(0,.45,71),(.75,.35,74),(1.5,.5,77),(2.5,.85,74)],
            [(0,.4,76),(.75,.3,74),(1.5,.4,71),(2.25,.35,68),(3,.6,76)],
            # High-register climax and altered reprise, then a deliberate A-minor close.
            [(0,.5,81),(.75,.25,81),(1.5,.55,84),(2.5,1,88)],
            [(0,.65,89),(1,.45,84),(1.75,.6,81),(2.75,.7,84)],
            [(.25,.5,86),(1,.4,89),(1.75,.7,93),(3,.5,89)],
            [(0,.55,88),(1,.4,86),(1.75,.6,83),(2.75,.8,80)],
            [(0,.65,77),(1,.45,74),(2,1.2,71)],
            [(.25,.55,76),(1.25,.55,74),(2.25,1.1,68)],
            [(0,.75,76),(1.25,.5,72),(2.25,1,69)],
            [(0,2.75,69)],
        ]
        sections = [
            {'name':'도입', 'start_bar':0, 'end_bar':8,
             'reason':'낮은 호른의 짧은 호출과 악기 순차 진입으로 긴장을 만들고 주제의 리듬을 예고한다.'},
            {'name':'주제', 'start_bar':8, 'end_bar':16,
             'reason':'짧음·짧음·길음 주제를 연주하되 첼로·북의 악센트와 응답 위치를 바꾼다.'},
            {'name':'대조·재축적', 'start_bar':16, 'end_bar':24,
             'reason':'앞 네 마디의 북·하프·현악을 덜어 긴 호른·오보에·첼로 사이에 공간을 만들고 뒤 네 마디에서 다시 쌓는다.'},
            {'name':'절정·변형 재현', 'start_bar':24, 'end_bar':32,
             'reason':'주제의 상승 변형을 높은 음역과 전체 합주로 연주한 뒤 리듬을 넓혀 A단조로 마무리한다.'},
        ]
        dynamics = [60,62,65,65,70,71,76,73,
                    86,84,87,85,89,86,88,74,
                    59,57,61,61,72,77,82,86,
                    96,94,97,94,86,82,76,66]
    else:
        # G major, inversion/add9 colour, then a true relative E-minor passage.
        harmony = [
            (43,[55,59,62,69],'G(add9)'), (42,[54,57,62,64],'D(add9)/F#'),
            (40,[55,59,62,64],'Em7'), (36,[55,59,60,64],'Cmaj7'),
            (45,[57,60,64,67],'Am7'), (38,[54,57,60,62],'D7'),
            (43,[55,59,62,69],'G(add9)'), (42,[54,57,62,64],'D(add9)/F#'),
            (40,[55,59,64,66],'Em(add9)'), (36,[55,60,62,64],'C(add9)'),
            (45,[57,60,64,67],'Am7'), (38,[54,57,60,62],'D7'),
            (40,[55,59,64],'Em'), (39,[54,57,59,63],'B7/D#'),
            (43,[55,59,62,64],'Em7/G'), (45,[57,60,64,71],'Am(add9)'),
            (36,[55,59,60,64],'Cmaj7'), (38,[54,57,60,62],'D7'),
            (47,[55,59,62,69],'G(add9)/B'), (36,[55,59,60,64],'Cmaj7'),
            (45,[57,60,64,67],'Am7'), (38,[54,57,60,62],'D7'),
            (43,[55,59,62,69],'G(add9)'), (43,[55,59,62],'G'),
        ]
        phrases = [
            # Introduction: short questions with enough room for the flute to answer.
            [(0,1.1,67),(1.75,.65,71)],
            [(.5,.65,69),(1.5,1,66)],
            [(0,.75,67),(1.25,.55,71),(2.25,1,76)],
            [(.5,1.1,72),(2.25,.6,71),(3,.5,67)],
            [(0,.9,69),(1.5,.6,72)],
            [(.5,.65,69),(1.5,.6,66),(2.75,.6,62)],
            # Theme: rising G-B-D contour; longer breaths and a different ending each bar.
            [(0,.75,67),(1,.5,71),(1.75,1.4,74)],
            [(0,1.2,76),(1.75,.55,74),(2.75,.7,69)],
            [(.25,.7,71),(1.25,.5,76),(2.25,1.15,78)],
            [(0,1.2,79),(1.75,.55,76),(2.75,.75,74)],
            [(0,.8,76),(1.25,.55,72),(2.25,1.15,69)],
            [(.25,.65,72),(1.25,.5,69),(2.25,1,66)],
            # Relative-minor contrast: lower, slower lyrical lines and a rising passage.
            [(0,1.5,64),(2.25,.85,67)],
            [(.5,1.25,66),(2.25,.75,63)],
            [(0,1,64),(1.5,.5,67),(2.5,.9,71)],
            [(.25,1.1,72),(1.75,.65,71),(2.75,.6,69)],
            [(0,.65,67),(1,.4,71),(1.75,.4,72),(2.5,.45,76),(3.25,.45,79)],
            [(0,.9,78),(1.5,.65,74),(2.75,.65,69)],
            # Reprise alters register and durations, followed by a spacious cadence.
            [(0,1.1,79),(1.5,.5,74),(2.5,.85,71)],
            [(0,.65,76),(1,.45,79),(1.75,.55,83),(2.75,.75,79)],
            [(.5,.85,76),(1.75,.6,72),(2.75,.65,69)],
            [(0,.85,72),(1.5,.5,69),(2.5,.9,66)],
            [(0,1.4,71),(2,.7,69),(3,.5,67)],
            [(0,2.8,67)],
        ]
        sections = [
            {'name':'도입', 'start_bar':0, 'end_bar':6,
             'reason':'피아노의 짧은 질문·쉼과 플루트 응답으로 숲의 여유를 먼저 제시하고 반주를 차례로 넣는다.'},
            {'name':'주제', 'start_bar':6, 'end_bar':12,
             'reason':'G-B-D 상승 주제와 add9·전위 화음을 쓰며 분산·화음·교대 반주를 번갈아 선율의 호흡을 바꾼다.'},
            {'name':'대조', 'start_bar':12, 'end_bar':18,
             'reason':'상대단조 E단조와 B7의 D#로 색을 바꾸고 낮은 피아노·긴 첼로 후 상승 연결구로 돌아온다.'},
            {'name':'변형 재현', 'start_bar':18, 'end_bar':24,
             'reason':'주제 윤곽을 높은 음역·늘어난 음가로 재해석하고 마지막 두 마디 반주를 덜어 G장조에 쉰다.'},
        ]
        dynamics = [64,62,68,67,66,65,80,78,82,81,78,72,
                    66,64,70,72,80,76,84,86,79,74,69,61]
    assert len(harmony) == len(phrases) == len(dynamics) == bars

    def chord_notes(track, origin, pitches, length, velocity, offset=0):
        for i, pitch in enumerate(pitches):
            note(by[track], origin + offset + .009*i, length, pitch, velocity-i)

    for bar, (root, chord, label) in enumerate(harmony):
        origin = 4 * bar
        dynamic = dynamics[bar]
        for start, length, pitch in phrases[bar]:
            # Fixed articulation and phrase shaping; neither pitches nor timing are random.
            velocity = dynamic + (2 if start == 0 else -3 if start >= 2.5 else 0)
            note(by['lead'], origin+start+.012, length*(.88 if battle else .96), pitch, velocity)
        if battle:
            sparse = 16 <= bar < 20
            opening = bar < 4
            climax = 24 <= bar < 28
            closing = bar >= 30
            # Entry/exit and sustained length change alongside harmony, not every-bar pads.
            if bar not in (0,1,16,17,31):
                chord_notes('strings', origin, [p+12 for p in chord[:3]],
                            2.6 if sparse else 3.55 if bar%2 else 2.95,
                            42 if sparse else 71 if climax else 51 if opening else 60)
            cello_patterns = [
                [(0,0,.55),(1.5,2,.4),(2.5,1,.7)],
                [(0,0,.32),(.5,0,.28),(1.5,2,.32),(2,1,.32),(3,0,.6)],
                [(.5,0,.36),(1,1,.36),(2,2,.48),(3,1,.36),(3.5,0,.3)],
                [(0,0,.6),(1.25,2,.4),(2,1,.55),(3.25,0,.42)],
            ]
            if sparse or closing:
                cello = [(0,0,1.6),(2.5,1,1.05)] if bar%2==0 else [(.5,2,2.2)]
            elif climax:
                cello = [(s*.5,[0,2,1,0,2,1,2,0][s],.30) for s in range(8)]
            else:
                cello = cello_patterns[bar%4]
            for start, index, length in cello:
                note(by['counter'],origin+start+.008,length,chord[index],
                     50 if sparse else 84 if climax else 67 if opening else 75)
            bass_times = [0] if sparse or closing else [0,2.5] if opening else [0,1.5,3] if bar%2 else [0,.75,2,3.25]
            for start in bass_times:
                note(by['bass'],origin+start,1.7 if sparse else .65,root-12,60 if sparse else 86 if climax else 75)
            if not sparse and bar not in (0,1,31):
                for start in ([0,2] if bar%2==0 else [1.5,3]):
                    note(by['piano'],origin+start,.5,root,81 if climax else 65)
            if bar in (2,6,10,14,20,22,24,26,28):
                for step,index in enumerate((0,1,2,1)):
                    note(by['harp'],origin+2+step*.45,.62,chord[index]+12,58 if climax else 47)
            if bar in (1,3,7,9,13,15,16,17,18,19,21,25,29):
                # Single answer in exposed bars; it fits within the lead's rest.
                response = [(2.25,.6,chord[1]+12),(3.1,.65,chord[2]+12)] if sparse else [(3.4,.45,chord[1]+12)]
                for start,length,pitch in response:
                    note(by['answer'],origin+start,length,pitch,56 if sparse else 67)
            if bar in (4,8,12,20,24,26,28,30):
                chord_notes('horn',origin,chord[:3],2.9,75 if climax else 53)
            # Percussion has four distinct groove shapes, silence and composed fills.
            if not sparse and bar != 31:
                kicks = [0,2] if opening or closing else [[0,1.5,2.75],[0,.75,2,3.25],[0,2.5],[0,1.75,3]][bar%4]
                for start in kicks:
                    note(by['drums'],origin+start,.18,36,98 if climax and start==0 else 86 if start==0 else 71)
                if bar>=4 and not closing:
                    for start in ([1,3] if bar%2==0 else [1.5,3]):
                        note(by['drums'],origin+start+.006,.12,38,75 if climax else 62)
                hats = [1,3] if opening or closing else [0,.5,1.5,2,3,3.5] if bar%2 else [0,1,1.5,2.5,3,3.5]
                for step,start in enumerate(hats):
                    note(by['drums'],origin+start,.10,42,34 if opening else 52 if climax else 40+step%2*7)
            elif sparse and bar>=18:
                note(by['drums'],origin,.2,36,54)
            if bar in (6,11,14,22,23,27,29):
                for start,pitch,velocity in [(3,45,52),(3.375,47,60),(3.75,50,68)]:
                    note(by['drums'],origin+start,.13,pitch,velocity+(8 if bar==23 else 0))
            if bar in (8,24):
                note(by['drums'],origin,.5,49,72 if bar==24 else 55)
        else:
            # A authored 24-bar left-hand plan: no unchanged six-note bar repeated.
            piano_modes = ['broken','rest','alternating','chord','broken','sparse',
                           'flow','alternating','broken','chord','flow','sparse',
                           'sparse','chord','alternating','broken','flow','chord',
                           'alternating','flow','chord','broken','sparse','rest']
            mode = piano_modes[bar]
            if mode=='broken':
                accompaniment = [(0,root,1.1),(.75,chord[1],.8),(1.5,chord[2],.85),(2.5,chord[0],1.1),(3.25,chord[-1],.65)]
            elif mode=='alternating':
                accompaniment = [(0,root,1.5),(1.5,chord[1],.85),(2.5,root+12,1.1),(3.25,chord[2],.6)]
            elif mode=='flow':
                accompaniment = [(start,pitch,.72) for start,pitch in zip([0,.5,1,1.75,2.5,3,3.5],
                                   [root,chord[0],chord[1],chord[2],chord[-1],chord[1],chord[0]])]
            elif mode=='sparse':
                accompaniment = [(0,root,1.9),(2.75,chord[1],.9)]
            elif mode=='rest':
                accompaniment = [(0,root,2.6)]  # Leave the remaining phrase in open space.
            else:
                accompaniment = [(0,root,1.35),(2.25,root+12,1.3)]
                chord_notes('piano',origin,chord[:3],1.05,46,offset=.75)
            for step,(start,pitch,length) in enumerate(accompaniment):
                note(by['piano'],origin+start+.01,length,pitch,
                     54 if step==0 else 49 if mode=='flow' else 45)
            if bar not in (0,1,4,12,13,22,23):
                chord_notes('strings',origin,[p+12 for p in chord[:3]],
                            3.3 if bar%2 else 2.5,43 if bar<6 else 51 if bar>=18 else 47)
            if bar in (3,7,9,12,13,14,15,19,21):
                note(by['counter'],origin+.08,2.05,chord[0],47)
                if bar in (12,14,19): note(by['counter'],origin+2.5,1.15,chord[1],43)
            if bar in (2,5,7,11,15,17,19,21):
                for start,index in [(2.75,0),(3.25,1),(3.65,2)]:
                    note(by['harp'],origin+start,.55,chord[index]+12,44 if bar<6 else 48)
            if bar in (2,6,8,9,10,14,16,18,19,20,21):
                note(by['bass'],origin,2.5,root-12,44 if bar<12 else 49)
            # Flute answers exposed question bars instead of doubling the piano.
            responses = {0:[(2.75,.8,74)],1:[(2.9,.75,74)],4:[(2.75,.75,76)],
                         6:[(3.3,.55,81)],8:[(3.5,.4,83)],11:[(3.4,.45,74)],
                         12:[(3.2,.65,71)],13:[(3.25,.55,71)],15:[(3.5,.4,76)],
                         18:[(3.5,.4,81)],20:[(3.5,.4,76)],22:[(3.6,.35,74)]}
            for start,length,pitch in responses.get(bar,[]):
                note(by['answer'],origin+start,length,pitch,51 if bar<6 else 58)
            if bar in (18,19,21):
                chord_notes('horn',origin,chord[:3],2.7,40)
            if bar in (6,8,10,16,18,20):
                note(by['drums'],origin,.17,36,37)
                for start in ([1.5,3.5] if bar in (8,18) else [3]):
                    note(by['drums'],origin+start,.1,42,27)
    return {'version':2,'revision':3,'name':'battle' if battle else 'lobby',
            'tempo_bpm':bpm,'bars':bars,'meter':'4/4',
            'key':'A minor' if battle else 'G major / relative E minor',
            'duration_seconds':60,'stem_duration_seconds':62,'loop':False,
            'sections':sections,
            'harmony':[{'bar':i,'name':h[2],'bass_pitch':h[0],
                        'chord_pitches':h[1]} for i,h in enumerate(harmony)],
            'composition_method':'Original hand-composed melody, harmony, rests, orchestration and fixed dynamics; no reference transcription or random-note generation.',
            'tracks':tracks}


def _vlq(value):
    data=[value & 127]
    while value>>7:
        value>>=7
        data.insert(0,(value&127)|128)
    return bytes(data)


def write_midi(path, data):
    tempo=round(60_000_000/data['tempo_bpm'])
    header=b'\0\xff\x51\x03'+tempo.to_bytes(3,'big')+b'\0\xff\x58\x04\x04\x02\x18\x08\0\xff\x2f\0'
    chunks=[b'MTrk'+struct.pack('>I',len(header))+header]
    for track in data['tracks']:
        ch=track['channel']; events=[(0,bytes([0xc0|ch,track['program']])),(0,bytes([0xb0|ch,10,track['pan']]))]
        for n in track['notes']:
            a=round(n['beat']*480); b=round((n['beat']+n['length'])*480)
            events.extend([(a,bytes([0x90|ch,n['pitch'],n['velocity']])),(b,bytes([0x80|ch,n['pitch'],0]))])
        events.sort(key=lambda e:(e[0],0 if e[1][0]&0xf0==0x80 else 1))
        stream=bytearray();prev=0
        for tick,event in events:
            stream.extend(_vlq(tick-prev)+event);prev=tick
        stream.extend(_vlq(max(0,data['bars']*4*480-prev))+b'\xff\x2f\0')
        chunks.append(b'MTrk'+struct.pack('>I',len(stream))+stream)
    Path(path).write_bytes(b'MThd'+struct.pack('>IHHH',6,1,len(chunks),480)+b''.join(chunks))


class Renderer:
    def __init__(self, soundfont, library=None):
        libpath=library or ctypes.util.find_library('fluidsynth')
        if not libpath:
            raise RuntimeError('FluidSynth shared library not found; install official fluidsynth package.')
        self.lib=C.CDLL(str(libpath));self.soundfont=str(soundfont)
        signatures={
            'new_fluid_settings':(C.c_void_p,[]),
            'delete_fluid_settings':(None,[C.c_void_p]),
            'fluid_settings_setnum':(C.c_int,[C.c_void_p,C.c_char_p,C.c_double]),
            'fluid_settings_setint':(C.c_int,[C.c_void_p,C.c_char_p,C.c_int]),
            'new_fluid_synth':(C.c_void_p,[C.c_void_p]),
            'delete_fluid_synth':(None,[C.c_void_p]),
            'fluid_synth_sfload':(C.c_int,[C.c_void_p,C.c_char_p,C.c_int]),
            'fluid_synth_noteon':(C.c_int,[C.c_void_p,C.c_int,C.c_int,C.c_int]),
            'fluid_synth_noteoff':(C.c_int,[C.c_void_p,C.c_int,C.c_int]),
            'fluid_synth_cc':(C.c_int,[C.c_void_p,C.c_int,C.c_int,C.c_int]),
            'fluid_synth_program_change':(C.c_int,[C.c_void_p,C.c_int,C.c_int]),
            'fluid_synth_write_float':(C.c_int,[C.c_void_p,C.c_int,C.c_void_p,C.c_int,C.c_int,C.c_void_p,C.c_int,C.c_int]),
        }
        for name,(ret,args) in signatures.items():
            fn=getattr(self.lib,name);fn.restype=ret;fn.argtypes=args

    def render(self, track, tempo, duration=62):
        l=self.lib;settings=l.new_fluid_settings();synth=None
        try:
            for key,value in [('synth.sample-rate',SR),('synth.gain',.5)]:
                if l.fluid_settings_setnum(settings,key.encode(),value)!=0:
                    raise RuntimeError(f'FluidSynth setting failed: {key}')
            for key,value in [('synth.reverb.active',0),('synth.chorus.active',0),('synth.cpu-cores',1)]:
                if l.fluid_settings_setint(settings,key.encode(),value)!=0:
                    raise RuntimeError(f'FluidSynth setting failed: {key}')
            synth=l.new_fluid_synth(settings)
            if not synth or l.fluid_synth_sfload(synth,self.soundfont.encode(),1)<0:
                raise RuntimeError('SoundFont load failed')
            ch=track['channel'];l.fluid_synth_program_change(synth,ch,track['program'])
            l.fluid_synth_cc(synth,ch,10,track['pan'])
            l.fluid_synth_cc(synth,ch,91,0);l.fluid_synth_cc(synth,ch,93,0)
            total=round(duration*SR);audio=np.zeros((total,2),np.float32)
            events=[]
            for n in track['notes']:
                a=round(n['beat']*60/tempo*SR); b=round((n['beat']+n['length'])*60/tempo*SR)
                events.extend([(a,1,n['pitch'],n['velocity']),(b,0,n['pitch'],0)])
            events.sort();cursor=0
            def draw(end):
                nonlocal cursor
                end=min(end,total)
                while cursor<end:
                    count=min(4096,end-cursor);left=np.empty(count,np.float32);right=np.empty(count,np.float32)
                    code=l.fluid_synth_write_float(synth,count,left.ctypes.data,0,1,right.ctypes.data,0,1)
                    if code!=0: raise RuntimeError('FluidSynth render failed')
                    audio[cursor:cursor+count,0]=left;audio[cursor:cursor+count,1]=right;cursor+=count
            for frame,on,pitch,velocity in events:
                draw(frame)
                code=l.fluid_synth_noteon(synth,ch,pitch,velocity) if on else l.fluid_synth_noteoff(synth,ch,pitch)
                if on and code!=0: raise RuntimeError(f'FluidSynth note-on failed: {track["id"]}, {pitch}')
            draw(total)
            return audio
        finally:
            if synth: l.delete_fluid_synth(synth)
            l.delete_fluid_settings(settings)


def generate(soundfont, output_dir, library=None):
    soundfont=Path(soundfont)
    if hashlib.sha256(soundfont.read_bytes()).hexdigest()!=SOUNDFONT_SHA256:
        raise ValueError('Expected pinned FluidR3_GM.sf2; soundfont SHA256 mismatch')
    output_dir=Path(output_dir);output_dir.mkdir(parents=True,exist_ok=True)
    renderer=Renderer(soundfont,library);results=[]
    for battle in (False,True):
        data=score(battle);name=data['name'];folder=output_dir/name;folder.mkdir(exist_ok=True)
        (folder/'score.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
        write_midi(folder/'score.mid',data)
        mix=np.zeros((round(data['stem_duration_seconds']*SR),2),np.float32)
        for track in data['tracks']:
            rendered=renderer.render(track,data['tempo_bpm'],data['stem_duration_seconds'])*track['gain']
            write_wav(folder/f'{track["id"]}.wav',rendered)
            mix+=rendered
        # Fixed stereo room reflections; no randomized rendering or hidden plugins.
        room=np.zeros_like(mix)
        for delay,gain in [(.037,.13),(.071,.11),(.113,.09),(.179,.075),(.251,.06),(.337,.045),(.457,.032),(.613,.02)]:
            d=round(delay*SR);room[d:]+=mix[:-d,::-1]*gain
        mix+=room
        mix=mix[:round(data['duration_seconds']*SR)]
        # Preview excerpts have deliberate fades, rather than pretending to be loops.
        mix[:round(.025*SR)]*=np.linspace(0,1,round(.025*SR))[:,None]
        mix[-round(.65*SR):]*=np.linspace(1,0,round(.65*SR))[:,None]
        mix-=mix.mean(axis=0)
        mix*=min(1.,.85/max(float(np.max(np.abs(mix))),1e-9))
        mix[0]=0;mix[-1]=0
        write_wav(output_dir/f'{name}_mix.wav',mix)
        results.append({'name':name,'duration_seconds':data['duration_seconds'],'stem_duration_seconds':data['stem_duration_seconds'],'tempo_bpm':data['tempo_bpm'],
                        'key':data['key'],'bars':data['bars'],'stems':len(data['tracks'])})
    return results
