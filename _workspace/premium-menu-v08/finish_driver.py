"""Resume comparison, prototype and audit tasks through awaited Penpot REPL calls.

Run only while the editor is connected and no other producer is active. This
module never starts tasks on import. The default invocation completes all three
stages; a single stage can be selected to inspect a checkpoint first.
"""
import argparse
import json
from datetime import datetime, timezone
from pathlib import Path

from penpot_foreground import TASK, call

ISSUE_KEYS = ('officialIssues', 'baseIdIssues', 'legacyChildIssues', 'outsideChanges', 'componentIssues', 'shapeIssues', 'textIssues', 'sourceControlIssues', 'prototypeIssues', 'touchIssues', 'comparisonIssues', 'statePageIssues')


class FinishDriver:
    def __init__(self, invoke=call, task=TASK):
        self.invoke = invoke
        self.task = Path(task)
        self.progress_path = self.task / 'finish-foreground-progress.json'
        self.progress = {'mode': 'foreground-await-only', 'stages': {}}
        if self.progress_path.exists():
            self.progress.update(json.loads(self.progress_path.read_text()))

    def rpc(self, name, code):
        return self.invoke('/*finish-driver:' + name + '*/\n' + code)

    def record(self, stage, row):
        self.progress['stages'][stage] = row
        self.progress['updatedAt'] = datetime.now(timezone.utc).isoformat()
        temporary = self.progress_path.with_suffix('.json.tmp')
        temporary.write_text(json.dumps(self.progress, ensure_ascii=False, indent=2) + '\n')
        temporary.replace(self.progress_path)
        print(json.dumps({'stage': stage, **row}, ensure_ascii=False), flush=True)

    def load(self, names):
        for name in names:
            self.rpc('load-' + name, (self.task / name).read_text())

    def save(self, label):
        return self.rpc('save-version', 'const N=storage.v08;N.ensureFlags();const v=await penpot.currentFile.saveVersion(' + json.dumps(label, ensure_ascii=False) + ');return {label:v.label,createdAt:v.createdAt};')

    def comparison_status(self):
        return self.rpc('comparison-status', """const N=storage.v08;N.ensureFlags();
const keys=N.comparisonTargets.map(name=>'CMP20 / MENU08 / '+name);
const ready=keys.filter(key=>N.comparisons[key]?.getPluginData('v08-comparison-ready')==='native-center-v1:'+N.nativeSpecHash(key.slice('CMP20 / MENU08 / '.length)));
const exported=ready.filter(key=>N.comparisonExportRecords[key]?.id===N.comparisons[key].id&&N.comparisonExportRecords[key]?.comparisonSignature===N.comparisons[key].getPluginData('v08-comparison-ready'));
return {total:keys.length,created:ready.length,exported:exported.length};""")

    def comparisons(self):
        status = self.comparison_status()
        for stage, count_key, expression in (
            ('comparison-geometry', 'created', 'return await storage.v08.makeComparisonBatch(1);'),
            ('comparison-exports', 'exported', 'return await storage.v08.exportComparisonBatch(1);'),
        ):
            while status[count_key] < status['total']:
                before = status[count_key]
                result = self.rpc(stage, expression)
                status = self.comparison_status()
                if status[count_key] <= before or not result.get('out'):
                    raise RuntimeError(stage + ' made no progress: ' + json.dumps(status))
                self.record(stage, {**status, 'savedVerified': False})
            if stage == 'comparison-geometry':
                # The remote renderer must be able to look up all five real IDs.
                version = self.save('메뉴 v08 · 20:9 비교 편집 원본 ' + str(status['created']) + '/' + str(status['total']))
                self.record('comparison-geometry-saved', {**status, 'version': version, 'savedBeforeExport': True, 'savedVerified': False})
        version = self.save('메뉴 v08 · 20:9 비교 ' + str(status['exported']) + '/' + str(status['total']))
        self.record('comparisons', {**status, 'version': version, 'savedVerified': False})

    def prototype_status(self):
        return self.rpc('prototype-status', 'return storage.v08.protoFastStatus();')

    def prototypes(self):
        status = self.prototype_status()
        for stage, count_key, expression in (
            ('prototype-geometry', 'prepared', 'return await storage.v08.makePrototypeBatch(4);'),
            ('prototype-wiring', 'wired', 'return await storage.v08.wirePrototypeBatch(12);'),
        ):
            saved_at = status[count_key]
            checkpoint_every = 64 if count_key == 'prepared' else 128
            while status[count_key] < status['total']:
                before = status[count_key]
                result = self.rpc(stage, expression)
                status = self.prototype_status()
                if status[count_key] <= before or not result.get('out'):
                    raise RuntimeError(stage + ' made no progress: ' + json.dumps(status))
                row = {**status, 'savedCheckpoint': saved_at, 'checkpointEvery': checkpoint_every, 'savedVerified': False}
                if status[count_key] - saved_at >= checkpoint_every and status[count_key] != status['total']:
                    version = self.save('메뉴 v08 · ' + ('프로토타입 구성 ' if count_key == 'prepared' else '프로토타입 연결 ') + str(status[count_key]) + '/' + str(status['total']))
                    saved_at = status[count_key]
                    row.update(savedCheckpoint=saved_at, version=version)
                self.record(stage, row)
            # Force the complete geometry and complete wiring versions separately.
            version = self.save('메뉴 v08 · ' + ('프로토타입 구성 ' if count_key == 'prepared' else '프로토타입 연결 ') + str(status[count_key]) + '/' + str(status['total']))
            self.record(stage, {**status, 'savedCheckpoint': status[count_key], 'checkpointEvery': checkpoint_every, 'finalForcedSave': True, 'version': version, 'savedVerified': False})
        self.record('prototypes', {**status, 'savedVerified': False})

    def audit(self):
        expected = self.rpc('expected-counts', 'return {scenes:storage.v08.spec.scenes.length,comparisons:storage.v08.comparisonTargets.length};')
        result = self.rpc('actual-audit', 'return await storage.v08.audit();')
        count_issues = {key: {'expected': value, 'actual': result.get(key)} for key, value in (
            ('sourceCount', expected['scenes']), ('prototypeCount', expected['scenes']),
            ('export1280', expected['scenes']), ('export1920', expected['scenes']),
            ('comparisons', expected['comparisons']),
        ) if result.get(key) != value}
        issues = result.get('issues')
        missing_issue_groups = [key for key in ISSUE_KEYS if not isinstance(issues, dict) or key not in issues]
        failed = bool(missing_issue_groups) or not isinstance(issues, dict) or any(value != 0 for value in issues.values()) or bool(count_issues)
        self.record('audit', {**result, 'countIssues': count_issues, 'missingIssueGroups': missing_issue_groups, 'passed': not failed, 'savedVerified': False})
        if failed:
            raise RuntimeError('Actual audit has unresolved issues; inspect final-audit.json and finish-foreground-progress.json')
        return result

    def run(self, stage='all', load=True):
        try:
            if load:
                helpers = []
                if stage in ('all', 'comparisons'):
                    helpers.append('penpot-comparisons.js')
                if stage in ('all', 'prototypes'):
                    helpers.append('penpot-prototype-fast.js')
                if stage in ('all', 'audit'):
                    helpers += ['penpot-comparisons.js'] if not helpers else []
                    helpers.append('penpot-audit.js')
                self.load(helpers)
            if stage in ('all', 'comparisons'):
                self.comparisons()
            if stage in ('all', 'prototypes'):
                self.prototypes()
            if stage in ('all', 'audit'):
                self.audit()
        except Exception as exc:
            self.record('error', {'requestedStage': stage, 'type': type(exc).__name__, 'message': str(exc)[:1600], 'savedVerified': False})
            raise


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('stage', choices=['all', 'comparisons', 'prototypes', 'audit'], nargs='?', default='all')
    parser.add_argument('--no-load', action='store_true', help='Use helpers already loaded in the current Penpot session')
    args = parser.parse_args()
    FinishDriver().run(args.stage, load=not args.no_load)


if __name__ == '__main__':
    main()
