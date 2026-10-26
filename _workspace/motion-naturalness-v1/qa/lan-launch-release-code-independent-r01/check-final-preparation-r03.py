"""Read-only source/delta checks; never import a runner or open a socket/GUI."""
from pathlib import Path
import ast
import hashlib
import json

ROOT = Path(__file__).resolve().parents[4]
QA = ROOT / '_workspace/motion-naturalness-v1/qa'
OLD = QA / 'lan-launch-release-visual-r02'
NEW = QA / 'lan-launch-release-visual-r03'

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def functions(path):
    lines = path.read_text().splitlines(True)
    result = {}
    for index, line in enumerate(lines):
        if not line.startswith(('func ', 'static func ')):
            continue
        name = line.split('func ', 1)[1].split('(')[0]
        end = index + 1
        while end < len(lines):
            current = lines[end]
            if current.strip() and not current[0].isspace() and not current.startswith('#'):
                break
            end += 1
        result[name] = ''.join(lines[index:end]).rstrip()
    return result

old_pins = json.loads((OLD / 'prepared-source-hashes.json').read_text())
pins = json.loads((NEW / 'prepared-source-hashes.json').read_text())
assert len(pins) == 2828
assert all((ROOT / path).is_file() and digest(ROOT / path) == value for path, value in pins.items())
assert all(old_pins[path] == pins[path] for path in old_pins.keys() & pins.keys())
preserved = json.loads((NEW / 'preserved-r02-and-failed-capture-hashes.json').read_text())
assert all(digest(ROOT / path) == value for path, value in preserved.items())
old, new = functions(OLD / 'client-fixture.gd'), functions(NEW / 'client-fixture.gd')
core = ['transform_numbers', 'marker_bytes', 'on_sprite_draw', 'decoded_marker', 'on_frame_post_draw']
assert all(old[name] == new[name] for name in core)
assert old['safe_output_directory'] == new['safe_output_directory']
assert '_process' not in new
render = old['_process'].replace('func _process(delta: float) -> bool:', 'func render_step(delta: float) -> void:').replace('return false', 'return')
assert render == new['render_step']
old_runner = (OLD / 'run.py').read_text()
runner = (NEW / 'run.py').read_text()
assert runner == old_runner.replace("files.add(BASE/'client-fixture.gd')\n", "files.add(BASE/'client-fixture.gd')\nfiles.add(BASE/'render-relay.gd')\n")
ast.parse(runner)
print(json.dumps({
    'status': 'pass',
    'scope': 'read-only source delta/pins; no socket, GUI, Godot, or actual callbacks executed',
    'current_pins_equal': len(pins),
    'shared_source_hashes_equal': len(old_pins.keys() & pins.keys()),
    'preserved_r02_failure_hashes_equal': len(preserved),
    'unchanged_render_functions': core,
    'render_body_changed_only_signature_returns': True,
    'runner_changed_only_add_relay_pin': True,
    'source_sha256': {name: digest(NEW / name) for name in ['client-fixture.gd', 'render-relay.gd', 'run.py', 'prepared-source-hashes.json']},
}, ensure_ascii=False, indent=2))
