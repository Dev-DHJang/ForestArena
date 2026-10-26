"""Independently check saved native captures; make QA boards/VFR derivatives only."""
from pathlib import Path
import gzip
import hashlib
import json
import math
import subprocess
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[4]
BASE = ROOT / '_workspace/motion-naturalness-v1/qa'
SOURCE = BASE / 'lan-launch-release-capture-r02'
OUT = BASE / 'lan-launch-release-visual-independent-r01'
OUT.mkdir(exist_ok=False)
SIZE = 640 * 480 * 4
sha = lambda value: hashlib.sha256(value).hexdigest()
run = json.loads((SOURCE / 'run-report.json').read_text())
before = json.loads((SOURCE / 'source-hashes-before.json').read_text())['shared_server_and_clients_source_hashes']
after = json.loads((SOURCE / 'source-hashes-after.json').read_text())
assert len(before) == 2828 and before == after['files'] and after['unchanged'] and not after['changed']
assert all(sha((ROOT / p).read_bytes()) == value for p, value in before.items())
assert run['status'] == 'pass'
for path in [SOURCE / 'auth.log', *SOURCE.glob('*-client.log'), *SOURCE.glob('*-server.log')]:
    text = path.read_text()
    assert not any(mark in text for mark in ['SCRIPT ERROR', 'ERROR:', 'FAIL', 'Traceback'])
results = []
for case in run['cases']:
    mode = case['mode']
    folder = SOURCE / mode
    facing = mode.rsplit('-', 1)[1]
    report_path = folder / (facing + '-report.json')
    assert sha(report_path.read_bytes()) == case['report_sha256']
    report = json.loads(report_path.read_text())
    assert report['status'] == 'pass' and not report['errors']
    assert not report['unpaired_sync_packets'] and not report['snapshots_neither_synced_nor_observed_at_draw']
    assert report['all_snapshots_omit_stun'] and report['render_process_priority'] == 10000
    assert report['presentation'] == 'res://scripts/local_fighter_presentation.gd'
    assert report['catalog_sha256'] == '005960d9a5ec54d29a7ca637905eaee64b33ecb6308a527debc53d46bfbed324'
    barriers = report['input_tick_barriers']
    assert len(barriers) == 3
    for barrier in barriers:
        assert barrier['success'] and barrier['required_tick'] == barrier['last_observed_tick_at_input'] + 2
        assert all(tick >= barrier['required_tick'] for tick in barrier['received_ticks_after'])
    inputs = report['inputs']
    assert inputs[4]['observed_tick'] >= barriers[0]['required_tick']
    assert inputs[6]['observed_tick'] >= barriers[1]['required_tick']
    assert inputs[8]['observed_tick'] >= barriers[2]['required_tick'] and inputs[8]['action'] == 'attack_heavy'
    slots = []
    for slot in [1, 2]:
        captures = [row for row in report['capture_manifest'] if row['client_slot'] == slot]
        archive = next(row for row in run['rgba_archives'] if row['archive'].startswith(mode + '/') and row['client_slot'] == slot)
        compressed = SOURCE / archive['archive']
        assert sha(compressed.read_bytes()) == archive['archive_sha256']
        raw_path = folder / f'{facing}-client-{slot}.rgba'
        data = gzip.decompress(compressed.read_bytes())
        assert data == raw_path.read_bytes() and sha(data) == archive['raw_sha256'] and len(data) == SIZE * len(captures)
        pages = []
        for start in range(0, len(captures), 20):
            page = Image.new('RGB', (1280, 1340), '#202126')
            draw = ImageDraw.Draw(page)
            for index, capture in enumerate(captures[start:start + 20], start):
                trace = capture['trace']; observed = trace['draw_observation']
                frame_data = data[index * SIZE:(index + 1) * SIZE]
                assert capture['raw_offset'] == index * SIZE and sha(frame_data) == capture['rgba_sha256']
                png = folder / archive['png_directory'] / f'frame-{index:04d}.png'
                image = Image.open(png).convert('RGBA')
                assert image.size == (640, 480) and image.tobytes() == frame_data
                marker = []
                for byte in range(8):
                    marker.append(sum((1 << bit) for bit in range(8) if min(image.getpixel((5 + (byte * 8 + bit) * 2, 5))[:3]) > 127))
                expected = [165, 90, observed['sync_stamp'] & 255, (observed['sync_stamp'] >> 8) & 255, observed['frame_zero_based'], slot, {'launch': 1, 'jump': 2}.get(observed['animation'], 0) | (128 if observed['flip_h'] else 0)]
                checksum = 0
                for value in expected: checksum ^= value
                assert marker == expected + [checksum] == observed['marker_bytes']
                assert trace['pixel_marker_verified'] and observed['sync_pose_matches_native_draw'] and observed['sync_snapshot_still_current']
                assert trace['snapshot_unchanged'] and trace['remaining_stun_local'] == observed['draw_stun'] == 0
                assert trace['received_snapshot'] == observed['draw_received_snapshot'] == observed['last_sync_packet']['received_snapshot']
                assert trace['frame_zero_based'] == observed['frame_zero_based'] and trace['motion'] == observed['animation']
                assert trace['sprite_scale'] == observed['sprite_scale'] and trace['sprite_position'] == observed['sprite_position']
                assert observed['latest_snapshot_arrival_id'] == trace['snapshot_arrival_id']
                if trace['release_active']:
                    assert trace['state'] == 'FALL' and observed['draw_received_snapshot']['facing'] == (1 if facing == 'normal' else -1)
                    assert trace['frame_zero_based'] == 12 + min(3, math.floor((trace['release_elapsed'] + 1e-10) * 60))
                x = (index - start) % 4 * 320; y = (index - start) // 4 * 268
                page.paste(image.convert('RGB').resize((320, 240)), (x, y + 28))
                draw.text((x + 4, y + 3), f"{mode} C{slot} #{index} {trace['motion']} F{trace['frame_zero_based']+1}", fill='white')
            path = OUT / f'{mode}-client-{slot}-board-{start//20+1}.png'
            page.save(path); pages.append(path.name)
        active = [c['trace'] for c in captures if c['trace']['release_active']]
        order = [t['frame_zero_based'] for i, t in enumerate(active) if i == 0 or t['frame_zero_based'] != active[i-1]['frame_zero_based']]
        assert order == [12, 13, 14, 15]
        assert active[0]['release_elapsed'] == 0
        for prior, current in zip(active, active[1:]):
            assert abs(current['release_elapsed'] - prior['release_elapsed'] - current['delta_for_sync']) < 1e-8
        last_index = next(i for i, row in enumerate(captures) if row['trace'] is active[-1])
        next_trace = captures[last_index + 1]['trace']
        assert not next_trace['release_active'] and next_trace['motion'] == 'jump' and next_trace['release_elapsed'] >= 4/60 - 1e-8
        launch = [row['trace']['frame_zero_based'] + 1 for row in captures if row['trace']['motion'] == 'launch' and not row['trace']['release_active']]
        slots.append({'slot': slot, 'owned': slot == 2, 'frames': len(captures), 'source_boards': pages, 'launch_frames_before_release': launch, 'release_drawn_frames': [t['frame_zero_based'] + 1 for t in active], 'release_elapsed': [t['release_elapsed'] for t in active], 'first_jump_frame': next_trace['frame_zero_based'] + 1, 'next_elapsed': next_trace['release_elapsed'], 'release_start_to_jump_post_draw_seconds': (next_trace['post_draw_usec']-active[0]['post_draw_usec'])/1e6})
    # Four actual-time VFR side-by-side review movies. Last image is a terminal
    # observation only; its preview tail is 1 microsecond, not an invented hold.
    stream1 = [c for c in report['capture_manifest'] if c['client_slot'] == 1]
    stream2 = [c for c in report['capture_manifest'] if c['client_slot'] == 2]
    assert len(stream1) == len(stream2)
    movie_dir = OUT / (mode + '-movie'); movie_dir.mkdir()
    times = [c['trace']['post_draw_usec'] for c in stream1]
    assert all(b > a for a, b in zip(times, times[1:]))
    concat = ['ffconcat version 1.0']
    for i, (one, two) in enumerate(zip(stream1, stream2)):
        assert one['trace']['sync_stamp'] == two['trace']['sync_stamp']
        image = Image.new('RGB', (1280, 512), '#202126'); draw = ImageDraw.Draw(image)
        for slot in [1, 2]:
            png = folder / f'{facing}-client-{slot}-png' / f'frame-{i:04d}.png'
            image.paste(Image.open(png).convert('RGB'), ((slot-1)*640, 32))
            t = (one if slot == 1 else two)['trace']
            draw.text(((slot-1)*640+12, 8), f"{mode} / {'REMOTE' if slot==1 else 'OWNED'} / {t['motion']} F{t['frame_zero_based']+1}", fill='white')
        path = movie_dir / f'frame-{i:04d}.png'; image.save(path)
        concat += [f"file '{path.name}'", 'option framerate 1000000', f"duration {(times[i+1]-times[i])/1e6 if i+1<len(times) else 0.000001:.6f}"]
    listing = movie_dir / 'frames.ffconcat'; listing.write_text('\n'.join(concat)+'\n')
    movie = OUT / (mode + '-actual-vfr.mp4')
    subprocess.run(['ffmpeg', '-v', 'error', '-f', 'concat', '-safe', '0', '-i', str(listing), '-fps_mode', 'vfr', '-c:v', 'libx264', '-crf', '16', '-pix_fmt', 'yuv420p', '-video_track_timescale', '1000000', str(movie)], check=True)
    probe = json.loads(subprocess.check_output(['ffprobe', '-v', 'error', '-show_frames', '-show_entries', 'frame=best_effort_timestamp_time', '-of', 'json', str(movie)]))
    pts = [float(row['best_effort_timestamp_time']) for row in probe['frames']]
    expected_pts = [(stamp-times[0])/1e6 for stamp in times]
    assert len(pts) == len(expected_pts) and max(abs(a-b) for a,b in zip(pts, expected_pts)) < 0.000002
    results.append({'case': mode, 'checks': report['checks'], 'barriers': barriers, 'slots': slots, 'vfr_movie': movie.name, 'vfr_sample_count': len(pts), 'actual_first_to_last_seconds': expected_pts[-1], 'vfr_pts_matches_capture_within_microseconds': 2, 'terminal_preview_tail_seconds': 0.000001, 'vfr_time_source': 'client1 post_draw_usec; both clients matched by same sync stamp'})
proof = {'status':'pass','scope':'saved public-presentation real-socket fixture; independent bytes/markers/source/clock/barrier checks, not app HUD/device QA','source_pins_equal_before_after_current':len(before),'total_checks':sum(r['checks'] for r in results),'total_native_pngs':sum(s['frames'] for r in results for s in r['slots']),'cases':results}
(OUT/'independent-proof.json').write_text(json.dumps(proof, ensure_ascii=False, indent=2)+'\n')
print(json.dumps({k:proof[k] for k in ['status','source_pins_equal_before_after_current','total_checks','total_native_pngs']},ensure_ascii=False))
