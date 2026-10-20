"""Local deterministic tests; does not connect to Penpot or a browser."""
import contextlib
import io
import json
import re
import subprocess
import tempfile
from pathlib import Path

from finish_driver import FinishDriver, TASK, ISSUE_KEYS


class Fake:
    def __init__(self, total=237, prepared=0, wired=0, created=0, exported=0, fault=None):
        self.total, self.prepared, self.wired = total, prepared, wired
        self.created, self.exported = created, exported
        self.fault = fault
        self.calls = []
        self.code = []
        self.versions = []

    def __call__(self, code):
        marker = re.search(r'/\*finish-driver:(.*?)\*/', code)[1]
        self.calls.append(marker)
        self.code.append(code)
        if marker.startswith('load-'):
            return {'loaded': True}
        if marker == 'comparison-status':
            return {'total': 5, 'created': self.created, 'exported': self.exported}
        if marker == 'comparison-geometry':
            assert 'await storage.v08.makeComparisonBatch(1)' in code
            self.created += 1
            return {'out': [{'created': True}]}
        if marker == 'comparison-exports':
            assert self.created == 5 and 'await storage.v08.exportComparisonBatch(1)' in code
            self.exported += 1
            return {'out': [{'exported': True}]}
        if marker == 'prototype-status':
            return {'total': self.total, 'prepared': self.prepared, 'wired': self.wired, 'basePrepared': min(14, self.prepared), 'baseWired': min(14, self.wired)}
        if marker == 'prototype-geometry':
            assert 'await storage.v08.makePrototypeBatch(4)' in code
            if self.fault == 'no-progress':
                return {'out': []}
            self.prepared = min(self.total, self.prepared + 4)
            return {'out': [{'prepared': True}]}
        if marker == 'prototype-wiring':
            assert self.prepared == self.total and 'await storage.v08.wirePrototypeBatch(12)' in code
            self.wired = min(self.total, self.wired + 12)
            return {'out': [{'wired': True}]}
        if marker == 'save-version':
            assert 'await penpot.currentFile.saveVersion(' in code
            self.versions.append(code)
            return {'label': 'mock only', 'createdAt': 'mock time'}
        if marker == 'expected-counts':
            assert 'N.spec.scenes.length' not in code  # This branch uses storage directly.
            return {'scenes': self.total, 'comparisons': 5}
        if marker == 'actual-audit':
            assert 'return await storage.v08.audit();' in code
            row = {'sourceCount': self.total, 'prototypeCount': self.total, 'export1280': self.total, 'export1920': self.total, 'comparisons': 5, 'issues': {key: 0 for key in ISSUE_KEYS}}
            if self.fault == 'audit-issue':
                row['issues']['prototypeIssues'] = 1
            elif self.fault == 'audit-count':
                row['prototypeCount'] -= 1
            elif self.fault == 'audit-missing-issues':
                del row['issues']
            return row
        raise AssertionError('Unexpected RPC ' + marker)


def run_case(fake, stage='all'):
    with tempfile.TemporaryDirectory() as temp:
        task = Path(temp)
        for name in ('penpot-comparisons.js', 'penpot-prototype-fast.js', 'penpot-audit.js'):
            (task / name).write_text((TASK / name).read_text())
        with contextlib.redirect_stdout(io.StringIO()):
            driver = FinishDriver(fake, task)
            driver.run(stage)
        progress = json.loads((task / 'finish-foreground-progress.json').read_text())
        return driver, progress


def main():
    rows = []
    all_code = []
    # Count deliberately differs from old 214; the last batch is partial.
    fake = Fake(total=237)
    _, result = run_case(fake)
    assert fake.prepared == fake.wired == 237
    assert fake.created == fake.exported == 5
    assert result['stages']['audit']['passed']
    assert not result['stages']['audit']['savedVerified']
    assert fake.calls.index('prototype-wiring') > max(i for i, x in enumerate(fake.calls) if x == 'prototype-geometry')
    assert sum(x == 'prototype-geometry' for x in fake.calls) == 60
    assert sum(x == 'prototype-wiring' for x in fake.calls) == 20
    assert any('237/237' in code for code in fake.versions)
    all_code.extend(fake.code)
    rows.append({'name': 'dynamic-237-count-serial-all-stages', 'passed': True})

    fake = Fake(total=37, prepared=18, wired=12, created=4, exported=3)
    _, result = run_case(fake)
    assert fake.prepared == fake.wired == 37
    assert fake.calls.count('comparison-geometry') == 1
    assert fake.calls.count('comparison-exports') == 2
    assert result['stages']['audit']['passed']
    all_code.extend(fake.code)
    rows.append({'name': 'resume-partially-completed-stages', 'passed': True})

    fake = Fake(total=9, prepared=9, wired=9, created=5, exported=5)
    run_case(fake)
    assert not any(x in fake.calls for x in ('comparison-geometry', 'comparison-exports', 'prototype-geometry', 'prototype-wiring'))
    all_code.extend(fake.code)
    rows.append({'name': 'idempotent-complete-no-extra-shape-work', 'passed': True})

    for fault, stage in (('no-progress', 'prototypes'), ('audit-issue', 'audit'), ('audit-count', 'audit'), ('audit-missing-issues', 'audit')):
        fake = Fake(fault=fault)
        try:
            run_case(fake, stage)
        except RuntimeError:
            pass
        else:
            raise AssertionError('Fault was not rejected: ' + fault)
        all_code.extend(fake.code)
        rows.append({'name': 'reject-' + fault, 'passed': True})

    # Compile every generated RPC/helper without executing any of its code.
    compiled = subprocess.run(['node', '-e', "const fs=require('fs');const A=Object.getPrototypeOf(async function(){}).constructor;for(const c of JSON.parse(fs.readFileSync(0,'utf8')))new A(c);process.stdout.write('syntax-ok');"], input=json.dumps(all_code), text=True, capture_output=True, check=True)
    assert compiled.stdout == 'syntax-ok'
    rows.append({'name': 'generated-rpc-and-helper-javascript-syntax', 'passed': True})
    report = {'scope': 'local mocks only; no Penpot API, browser, actual save or actual audit executed', 'tests': rows, 'passed': len(rows), 'failed': 0}
    (TASK / 'finish-driver-check.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps(report, ensure_ascii=False))


if __name__ == '__main__':
    main()
