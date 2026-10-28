"""Fail closed on missing final delivery evidence; local files only, no service calls."""
import argparse
from collections import Counter
import csv
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import subprocess

from PIL import Image
from runtime_source_ids import registry_candidates, existing_runtime_ids

TASK = Path(__file__).resolve().parent
ROOT = TASK.parents[1]
EXPECTED_SPEC_SHA = '62cbef087faf9a3c3a00dc52b001ba3243d2a4f82943e87ee33a43e02fc26ffd'
ISSUE_KEYS = ('officialIssues', 'baseIdIssues', 'legacyChildIssues', 'outsideChanges', 'componentIssues', 'shapeIssues', 'textIssues', 'sourceControlIssues', 'prototypeIssues', 'touchIssues', 'comparisonIssues', 'statePageIssues')
WIDE_TARGETS = ('SCR_03_Lobby', 'SCR_05_CharacterDetail', 'SCR_19_Shop', 'SCR_22_Social', 'EXT_06_GeneralSettings')


def require(condition, message):
    if not condition:
        raise ValueError(message)


def read_json(path):
    return json.loads(Path(path).read_text())


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def local_path(base, relative):
    require(isinstance(relative, str) and relative and not Path(relative).is_absolute(), 'Expected a relative local artifact path')
    base = Path(base).resolve()
    path = (base / relative).resolve()
    require(path.is_relative_to(base), 'Artifact path escapes its delivery folder: ' + relative)
    return path


def index_rows(rows, key, label):
    require(isinstance(rows, list), label + ' must be a list')
    index = {row[key]: row for row in rows}
    require(len(index) == len(rows), label + ' contains duplicate ' + key)
    return index


def native_hashes(spec_path):
    # Keep JSON number/string formatting and UTF-16 behavior identical to the actual helper.
    code = "const s=JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'));const out={};for(const scene of s.scenes){let h=2166136261;for(const c of JSON.stringify(scene)){h^=c.charCodeAt(0);h=Math.imul(h,16777619);}out[scene.name]=(h>>>0).toString(16);}process.stdout.write(JSON.stringify(out));"
    result = subprocess.run(['node', '-e', code, str(spec_path)], check=True, capture_output=True, text=True)
    return json.loads(result.stdout)


def scene_filename(name):
    value=2166136261
    for character in name:
        point=ord(character)
        unit=point if point<=0xffff else 0xd800+((point-0x10000)>>10)
        value=((value^unit)*16777619)&0xffffffff
    units=name.encode('utf-16-le')
    ascii_name=''.join(chr(unit) if chr(unit) in 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-' else '_' for unit in (int.from_bytes(units[i:i+2],'little') for i in range(0,len(units),2)))
    return ascii_name+'-'+format(value,'x')+'-v08.png'


def controls_from_spec(spec):
    rows = []
    for scene in spec['scenes']:
        elements = scene['elements']
        scrim = max((i for i, e in enumerate(elements) if e['name'] == 'MODAL / scrim'), default=-1)
        for i, e in enumerate(elements):
            if e['kind'] in ('button', 'hotspot'):
                rows.append({'scene': scene['name'], 'name': e['name'], 'x': e['x'], 'y': e['y'], 'w': e['w'], 'h': e['h'], 'state': e.get('state', 'default'), 'dest': e.get('dest') or '', 'active': bool(i > scrim and e.get('dest') and e.get('state') != 'disabled')})
    return rows


def control_key(row):
    return (row['scene'], row['name'], *(round(float(row[key]), 3) for key in ('x', 'y', 'w', 'h')))


def png_record(task, record, size):
    filename = record['filename']
    require(re.fullmatch(r'[A-Za-z0-9_.-]+\.png', filename) is not None, 'Unsafe PNG filename: ' + str(filename))
    path = local_path(task / 'exports', filename)
    require(record.get('outputSize') == list(size), 'Recorded PNG dimensions differ: ' + filename)
    require(re.fullmatch(r'[a-f0-9]{64}', record.get('sha256', '')) is not None, 'Missing PNG SHA-256: ' + filename)
    require(digest(path) == record['sha256'], 'Actual PNG SHA-256 differs: ' + filename)
    require(record.get('bytes') == path.stat().st_size, 'Actual PNG byte length differs: ' + filename)
    with Image.open(path) as image:
        require(image.format == 'PNG' and image.size == size, 'Decoded PNG format/size differs: ' + filename)
        image.load()


def validate_outputs(task, spec, hashes, source, records, graph):
    native = index_rows(records['designExports'], 'name', 'native PNG records')
    small = index_rows(records['scenes'], 'name', 'preview PNG records')
    require(set(native) == set(source) == set(small), 'Native/preview PNG names must exactly cover the current source scenes')
    require(len({row['filename'] for row in native.values()}) == len(native) and len({row['filename'] for row in small.values()}) == len(small), 'Different scene records share a single output filename')
    for name, item in source.items():
        large, preview = native[name], small[name]
        require(preview['filename'] == scene_filename(name) and large['filename'] == scene_filename(name).replace('-v08.png','-v08-1920.png'), 'PNG filename differs from the preserved scene name mapping: '+name)
        for row in (large, preview):
            require(row.get('id') == item['id'] and row.get('nativeSpecHash') == hashes[name], 'PNG source ID or current spec hash differs: ' + name)
        png_record(task, large, (1920, 1080)); png_record(task, preview, (1280, 720))
        require(preview.get('sourceFilename') == large['filename'] and preview.get('sourceSha256') == large['sha256'], 'Preview does not derive from current native PNG: ' + name)
        require('pillow' in preview.get('resizeAlgorithm', '').lower() and 'lanczos' in preview['resizeAlgorithm'].lower(), 'Preview resize provenance missing: ' + name)
        require(preview.get('snapshotMediaId') and graph[name]['expectedSnapshotImageId'] == preview['snapshotMediaId'] == graph[name]['snapshotImageId'], 'Snapshot media does not match current preview: ' + name)
        require(not large.get('pixelSource', '').endswith('page-crop') and 'pageCaptureSha256' not in large, 'Rejected aggregate crop was adopted: ' + name)
    wide = index_rows(records['comparisons'], 'name', '20:9 PNG records')
    require(set(wide) == {'CMP20 / MENU08 / ' + name for name in WIDE_TARGETS}, 'Five required 20:9 comparisons are missing or extra')
    require(len({row['filename'] for row in wide.values()}) == len(wide), 'Different comparisons share a single output filename')
    for name, row in wide.items():
        source_name = name.removeprefix('CMP20 / MENU08 / ')
        require(row['filename'] == scene_filename(name), 'Comparison filename differs from scene mapping')
        require(row.get('id') and row.get('nativeSpecHash') == hashes[source_name] and row.get('comparisonSignature') == 'native-center-v1:' + hashes[source_name], '20:9 PNG uses a stale native source: ' + name)
        png_record(task, row, (1600, 720))
    return {'native1920': len(native), 'preview1280': len(small), 'wide20x9': len(wide)}


def validate_manual(plan, actual, source, spec_sha):
    require(plan.get('specSha256') == actual.get('specSha256') == spec_sha, 'Manual click plan/result spec SHA differs')
    planned = index_rows(plan['cases'], 'id', 'planned click cases')
    cases = index_rows(actual['cases'], 'id', 'executed click cases')
    require(planned and set(cases) == set(planned), 'Executed manual cases must exactly cover the nonempty named plan')
    steps = 0
    for case_id, case in cases.items():
        expected = planned[case_id]
        require(case.get('executionStatus') == 'PASS', 'Manual case is unexecuted or failed: ' + case_id)
        require(case.get('startScene') == expected['startScene'], 'Manual start scene differs: ' + case_id)
        planned_steps = index_rows(expected['steps'], 'step', 'planned steps ' + case_id)
        actual_steps = index_rows(case['steps'], 'step', 'executed steps ' + case_id)
        require(planned_steps and set(planned_steps) == set(actual_steps), 'Manual step coverage differs: ' + case_id)
        for step_id, step in actual_steps.items():
            original = planned_steps[step_id]
            require(step.get('executionStatus') == 'PASS', f'Manual step is unexecuted or failed: {case_id}/{step_id}')
            for key in ('fromScene', 'controlName', 'expectedArrivalScene'):
                require(step.get(key) == original[key], f'Manual planned {key} changed: {case_id}/{step_id}')
            destination = original['expectedArrivalScene']
            require(destination in source and step.get('actualArrivalFrameId') == source[destination]['prototypeId'], f'Observed arrival frame differs: {case_id}/{step_id}')
            steps += 1
    return {'manualCases': len(cases), 'manualSteps': steps}


def check_delivery(root=ROOT, task=TASK):
    root, task = Path(root), Path(task)
    report = {'status': 'FAIL', 'checkedAt': datetime.now(timezone.utc).isoformat(), 'scope': 'Final local delivery evidence; Android physical testing is reported separately', 'errors': [], 'checks': [], 'stats': {}, 'recordedLimits': []}
    context = {}
    def section(name, function):
        try:
            result = function()
            if isinstance(result, dict): report['stats'].update(result)
            report['checks'].append(name)
        except Exception as error:
            report['errors'].append({'check': name, 'reason': str(error)})

    def inputs():
        spec_path = task / 'scene-spec.json'
        spec_sha = digest(spec_path)
        require(spec_sha == EXPECTED_SPEC_SHA, 'Final approved scene-spec SHA differs')
        spec = read_json(spec_path); scenes = index_rows(spec['scenes'], 'name', 'scene spec')
        require(len(spec['base']) == 14 and set(spec['base']).issubset(scenes), 'Expected the preserved fourteen base screens')
        context.update(spec=spec, spec_sha=spec_sha, scenes=scenes, hashes=native_hashes(spec_path), controls=controls_from_spec(spec), audit=read_json(task/'final-audit.json'), baseline=read_json(task/'baseline-audit.json'), source=index_rows(read_json(task/'actual-source-index.json'), 'name', 'actual source index'), actual_controls=read_json(task/'actual-controls.json'), hotspots=read_json(task/'actual-prototype-hotspots.json'), records=read_json(task/'export-records.json'))
        require(set(context['source']) == set(scenes), 'Actual source index does not exactly cover current scene spec')
        return {'scenes': len(scenes), 'baseScreens': len(spec['base']), 'specSha256': spec_sha}
    section('required current-spec inputs', inputs)
    if not {'source', 'records', 'controls'}.issubset(context): return report

    def audit_check():
        a, baseline, source, scenes = (context[k] for k in ('audit', 'baseline', 'source', 'scenes'))
        for key in ISSUE_KEYS: require(key in a and a[key] == [], 'Actual Penpot audit has missing/nonempty ' + key)
        require(a.get('file') == baseline.get('file') and a.get('checkedAt'), 'Actual audit file identity or time missing')
        require(a.get('sourceCount') == a.get('prototypeCount') == len(scenes), 'Actual native/prototype audit counts differ')
        require(a.get('sourceIndex') == list(source.values()), 'Separate source index differs from actual audit')
        for key, separate in (('actualControls', context['actual_controls']), ('actualPrototypeHotspots', context['hotspots'])):
            require(a.get(key) == separate, key + ' differs from actual audit')
        official = index_rows(a['official'], 'name', 'official screens')
        old_official = {row['name']: row for row in baseline['boards'] if re.match(r'^SCR_\d{2}_', row['name'])}
        require(len(official) == len(old_official) == 24 and set(official) == set(old_official), 'Official twenty-four screen names differ')
        for name, row in official.items(): require(row['id'] == old_official[name]['id'] and [row['width'], row['height']] == [1920,1080], 'Official screen ID/size changed: ' + name)
        old_boards = {row['name']: row for row in baseline['boards']}
        for name in context['spec']['base']:
            require(source[name]['id'] == old_boards[name]['id'] and source[name]['prototypeId'] == old_boards['PROTO / '+name]['id'], 'Base native/prototype ID changed: ' + name)
        require(a.get('originalComponents') == len(baseline['components']) and a.get('currentComponents', 0) >= a['originalComponents'], 'Original component preservation audit missing')
        usage = index_rows(a['componentUsage'], 'name', 'component usage')
        require(set(usage) == set(scenes) and all(row.get('instances',0)>0 for row in usage.values()), 'A scene lacks actual v08 component instances')
        graph = index_rows(a['prototypeGraph'], 'scene', 'actual prototype graph')
        require(set(graph) == set(scenes), 'Prototype graph does not cover all scenes')
        for name, row in graph.items():
            require(row.get('snapshots') == 1 and row.get('snapshotId') and row.get('snapshotImageId') == row.get('expectedSnapshotImageId') and row.get('snapshotImageId'), 'Actual prototype snapshot identity differs: ' + name)
            require(source[name]['width'] == 1920 and source[name]['height'] == 1080 and source[name]['prototypeId'], 'Actual native size or prototype ID missing: ' + name)
        for section_name in ('scenes','designExports','comparisons'): require(a.get(section_name) == context['records'].get(section_name), 'Actual audit/export records differ: ' + section_name)
        context['graph'] = graph
        return {'officialScreens': len(official), 'originalComponents': a['originalComponents']}
    section('actual Penpot preservation, twelve issue arrays and snapshot graph', audit_check)

    def controls_check():
        expected = context['controls']; actual = context['actual_controls']; source = context['source']
        require(Counter(control_key(row) for row in actual) == Counter(control_key(row) for row in expected), 'Actual control geometry/coverage differs from spec')
        by_key = {control_key(row): row for row in actual}
        destinations = {name: row['prototypeId'] for name,row in source.items()}
        destinations.update({row['name'][8:]:row['id'] for row in context['baseline']['boards'] if row['name'].startswith('PROTO / ') and row['name'][8:] not in destinations})
        active = []
        for row in expected:
            observed = by_key[control_key(row)]
            require(observed.get('active') is row['active'] and observed.get('destinationName') == (row['dest'] or None), 'Actual control state/destination differs: ' + row['scene']+'/'+row['name'])
            if row['active']:
                require(observed.get('id') and observed.get('hidden') is False and observed.get('interactionCount') == 1 and observed.get('trigger') == 'click' and observed.get('actionType') == 'navigate-to' and observed.get('destinationId') == destinations.get(row['dest']) and destinations.get(row['dest']), 'Actual clickable target differs: ' + row['scene']+'/'+row['name'])
                require(observed.get('animation',{}).get('type') == 'dissolve' and observed['animation'].get('duration') == 200, 'Actual click transition differs')
                active.append(row)
        hits = context['hotspots']
        require(Counter(control_key({**row,'name':row['name'].removeprefix('HIT08 / ')} ) for row in hits) == Counter(control_key(row) for row in active), 'Actual hotspot list differs from active controls')
        active_by_key={control_key(row):row for row in active}
        for hit in hits:
            expected_row=active_by_key[control_key({**hit,'name':hit['name'].removeprefix('HIT08 / ')})]
            links=hit.get('interactions',[])
            require(hit.get('hidden') is False and hit.get('expectedMatches') == 1 and hit.get('interactionCount') == len(links) == 1, 'Actual hotspot is hidden, ambiguous or has extra interactions')
            link=links[0];animation=link.get('animation') or {}
            require(link.get('trigger') == 'click' and link.get('type') == 'navigate-to' and link.get('destinationId') == destinations[expected_row['dest']] and animation.get('type') == 'dissolve' and animation.get('duration') == 200, 'Actual hotspot link differs')
        with (task/'control-coordinates.csv').open() as stream: csv_controls=list(csv.DictReader(stream))
        normalized=[{'scene':row['scene'],'name':row['control'],'x':row['x1920'],'y':row['y1920'],'w':row['w1920'],'h':row['h1920']} for row in csv_controls]
        require(Counter(map(control_key,normalized)) == Counter(map(control_key,expected)), 'Click coordinate table geometry/coverage differs')
        for expected_row, csv_row in zip(expected,csv_controls):
            require(csv_row['state'] == expected_row['state'] and csv_row['dest'] == expected_row['dest'] and csv_row['enabled'].lower() == str(expected_row['active']).lower() and float(csv_row['transition_ms']) == 200, 'Click coordinate table state or transition differs')
            require(abs(float(csv_row['centerX1280'])-(expected_row['x']+expected_row['w']/2)*2/3)<.001 and abs(float(csv_row['centerY720'])-(expected_row['y']+expected_row['h']/2)*2/3)<.001, '1280 click coordinate center differs')
        with (task/'component-state-table.csv').open() as stream: states=list(csv.DictReader(stream))
        expected_states={'surface-'+state for state in ('default','primary','ghost','selected','pressed','disabled','owned','equipped','danger')}
        require({row['component'] for row in states} == expected_states and len(states) == len(expected_states), 'Component state table missing, duplicate or extra states')
        uses=Counter(element.get('state','default') for scene in context['spec']['scenes'] for element in scene['elements'] if element['kind']=='button')
        for row in states:require(row['namespace']=='Premium Menu v08' and int(row['uses'])==uses[row['component'].removeprefix('surface-')], 'Component state usage differs from spec')
        return {'controls': len(expected), 'activeHotspots': len(active)}
    section('actual controls, active clicks and coordinate mapping', controls_check)

    section('decoded current native, preview and five wide PNGs', lambda: validate_outputs(task,context['spec'],context['hashes'],context['source'],context['records'],context.get('graph',{})))

    def sources_check():
        manifest = read_json(root/'assets/ui/premium-menu-v08/manifest.json')
        require(manifest.get('new_raster_assets') == 0, 'Unexpected new menu source artwork')
        require(manifest.get('runtime_registration_changed_by_v08') is False, 'Menu v08 runtime registration change metadata missing')
        assets = index_rows(manifest['reused_assets'], 'path', 'reused source assets')
        by_key = {row['id'].split('.')[-1]:row for row in assets.values()}
        candidates=registry_candidates(root);runtime_digest_cache={}
        expected = [];used_keys=set()
        for scene in context['spec']['scenes']:
            for element in scene['elements']:
                if element['kind'] not in ('image','svg'): continue
                asset = by_key[element['key']]
                used_keys.add(element['key'])
                slot=element.get('slot',('DESIGN/bg/' if element['kind']=='image' else 'DESIGN/icon/')+element['key'])
                expected.append((scene['name'],slot,element['key'],asset['path'],asset['sha256'],'false',';'.join(asset['existing_runtime_ids'])))
        for row in assets.values():
            require('runtime_registered' not in row and row.get('runtime_registration_changed_by_v08') is False and digest(local_path(root,row['path'])) == row['sha256'], 'Reused menu source hash/registration metadata differs: ' + row['path'])
            require(row.get('existing_runtime_ids') == existing_runtime_ids(row['path'],row['sha256'],candidates,runtime_digest_cache), 'Existing runtime IDs lack exact basename and runtime-file SHA match: '+row['path'])
        require(set(by_key) == used_keys and len(by_key) == len(assets), 'Reused source manifest does not match the distinct current image/icon keys')
        with (task/'image-mapping.csv').open() as stream: mapping=list(csv.DictReader(stream))
        require(Counter((r['scene'],r['slot'],r['key'],r['path'],r['sha256'],r['runtime_registration_changed_by_v08'].lower(),r['existing_runtime_ids']) for r in mapping) == Counter(expected), 'IMG/design image mapping differs from spec/source manifest')
        return {'reusedSourceAssets':len(assets),'imageMappings':len(expected)}
    section('reused source SHA-256 and IMG mapping', sources_check)
    section('all named actual manual click cases and observed frame IDs', lambda: validate_manual(read_json(task/'manual-click-plan.json'),read_json(task/'manual-click-results.json'),context['source'],context['spec_sha']))

    def verification_check():
        result=read_json(task/'verify-final-result.json')
        require(all(result.get(key) == 0 for key in ('exitCode','docsExitCode','resourceExitCode')), 'Required verify/docs/resource command failed or missing')
        require(result.get('logicalAssets') == 519 and result.get('qualityVariants') == 25, 'Godot resource verification totals differ')
        require(result.get('verifyCommand') in ('./scripts/verify.sh', './scripts/verify.sh --full') and result.get('docsCommand') == './scripts/verify-docs.sh' and 'verify_godot_resources.py' in result.get('resourceCommand',''), 'Verification command provenance missing')
        require(local_path(task,result['log']).stat().st_size>0, 'Final verification log empty')
        return {'logicalGodotAssets':519,'qualityVariants':25}
    section('successful final verify/docs/Godot resource evidence', verification_check)

    def branding_check():
        folder=root/'_workspace/myoryung-app-branding-v02'
        checks=read_json(folder/'branding-checks.json'); provenance=read_json(folder/'input-provenance.json'); manifest=read_json(root/'assets/branding/myo-ryung-v02/manifest.json')
        require(checks.get('status') == 'PASS' and checks.get('issues') == [], 'Icon/APK checks failed or missing')
        require(len(checks.get('native_icon_checks',[])) == 3 and all(row.get('valid') is True for row in checks['native_icon_checks']), 'Packaged regular/adaptive icon checks incomplete')
        boot=checks['packed_boot_settings']; require(boot.get('show_image') is False and boot.get('minimum_display_time') == 0 and boot.get('icon') == 'res://assets/branding/myo-ryung-v02/app-icon-1024.png', 'Packaged Godot boot logo/icon settings differ')
        for row in manifest['assets']:
            path=local_path(root,row['path']);require(digest(path) == row['sha256'], 'Icon asset SHA differs')
            with Image.open(path) as image: require(list(image.size) == row['size'], 'Icon dimensions differ')
        for key in ('reference','foreground','forest'):
            row=provenance[key];require(digest(local_path(root,row['path'])) == row['sha256'], 'Icon input provenance SHA differs: '+key)
        device=read_json(folder/'android-device-recheck.json')
        if device.get('physicalVerified') is False:
            require(device.get('installed') is False and device.get('checks') and all(row.get('exitCode') == 0 for row in device['checks']), 'Physical device unavailable evidence incomplete')
            report['recordedLimits'].append({'scope':'Android physical device','status':'UNVERIFIED','physicalVerified':False,'reason':'No connected physical Android; launcher icon, first launch and relaunch are not device-tested','evidence':'_workspace/myoryung-app-branding-v02/android-device-recheck.json','planException':True})
        else: require(device.get('physicalVerified') is True, 'Physical device verification status missing')
        return {'iconAssetFiles':len(manifest['assets']),'physicalVerified':device['physicalVerified']}
    section('icon assets, APK/boot evidence and explicit physical-device limit', branding_check)
    report['status']='PASS' if not report['errors'] else 'FAIL'
    return report


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root',type=Path,default=ROOT)
    parser.add_argument('--task',type=Path,default=TASK)
    args=parser.parse_args()
    report=check_delivery(args.root,args.task)
    (args.task/'delivery-check.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps(report,ensure_ascii=False))
    raise SystemExit(0 if report['status']=='PASS' else 1)


if __name__=='__main__': main()
