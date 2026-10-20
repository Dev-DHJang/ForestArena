"""Local fake callbacks only; does not connect to Penpot."""
import contextlib
import io
import json
from pathlib import Path
import tempfile

from penpot_foreground import TASK
from resume_exports import resume_exports, transient_error


def row(native=1,small=1):
    return {'total':2,'currentNative':native,'current1280':small,'missingNative':[] if native==2 else ['B'],'missingSnapshots':[] if small==2 else ['B']}


def main():
    checks=[]
    for text in ('Failed to fetch','Failedtofetch','Network request failed','ResourceRequest timeout','ResourceRequest timed out','ECONNRESET'):
        assert transient_error(RuntimeError(text))
    for text in ('SHA differs after network failed','Invalid provenance Failed to fetch','No current-spec export progress','missing native PNG','ResourceRequest completed with wrong dimensions','Task execution timeout'):
        assert not transient_error(RuntimeError(text))
    checks.append('only known network/Failedtofetch/ResourceRequest timeouts retry; integrity and unknown task timeouts stop')
    with tempfile.TemporaryDirectory() as folder:
        task=Path(folder);attempts=[];pauses=[];finished=[]
        def runner(*args,**kwargs):
            attempts.append(True)
            if len(attempts)==1:raise RuntimeError('Failed to fetch')
            return row(2,2)
        with contextlib.redirect_stdout(io.StringIO()):result=resume_exports(5,task=task,runner=runner,status_reader=lambda _:row(),pause=pauses.append,finish=lambda:finished.append(True))
        assert result['currentNative']==2 and len(attempts)==2 and pauses==[2] and finished==[True]
        assert json.loads((task/'export-retry-journal.json').read_text())['events'][0]['failuresWithoutProgress']==1
        checks.append('one transient failure journals counts, pauses two seconds, then resumes and finishes serially')
    with tempfile.TemporaryDirectory() as folder:
        pauses=[];attempts=[]
        def fail(*args,**kwargs):attempts.append(True);raise RuntimeError('ResourceRequest timeout')
        try:
            with contextlib.redirect_stdout(io.StringIO()):resume_exports(10,task=Path(folder),runner=fail,status_reader=lambda _:row(),pause=pauses.append)
        except RuntimeError as error:assert 'three transient failures' in str(error)
        else:raise AssertionError('Unbounded retries accepted')
        assert len(attempts)==3 and pauses==[2,2]
        checks.append('exactly three consecutive failures without native/preview progress stop')
    with tempfile.TemporaryDirectory() as folder:
        state={'native':0,'attempts':0};pauses=[]
        def status(_):return row(state['native'],0)
        def progress_then_fail(*args,**kwargs):
            state['attempts']+=1
            if state['attempts']<=2:state['native']+=1;raise RuntimeError('Failedtofetch')
            return row(2,2)
        with contextlib.redirect_stdout(io.StringIO()):resume_exports(5,task=Path(folder),runner=progress_then_fail,status_reader=status,pause=pauses.append)
        events=json.loads((Path(folder)/'export-retry-journal.json').read_text())['events']
        assert len(events)==2 and all(e['failuresWithoutProgress']==0 for e in events)
        checks.append('actual current-spec progress resets the consecutive failure counter')
    with tempfile.TemporaryDirectory() as folder:
        pauses=[]
        def integrity(*args,**kwargs):raise RuntimeError('Actual source SHA differs: Failed to fetch')
        try:
            with contextlib.redirect_stdout(io.StringIO()):resume_exports(5,task=Path(folder),runner=integrity,status_reader=lambda _:row(),pause=pauses.append)
        except RuntimeError as error:assert 'SHA differs' in str(error)
        else:raise AssertionError('Integrity failure retried')
        assert not pauses and not (Path(folder)/'export-retry-journal.json').exists()
        checks.append('integrity/provenance failures stop immediately without retry journal or sleep')
    report={'passed':True,'tests':len(checks),'checks':checks,'note':'Synthetic callbacks only. No Penpot API, browser, actual export, save or finish stage executed.'}
    (TASK/'export-retry-wrapper-check.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');print(json.dumps(report,ensure_ascii=False))


if __name__=='__main__':main()
