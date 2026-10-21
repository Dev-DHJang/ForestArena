"""Serial export retry wrapper. Retry transport failures, never integrity failures."""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import re
import time

from penpot_foreground import TASK, call, export_status, run_exports


def transient_error(error):
    text=str(error)
    if re.search(r'SHA|digest|provenance|integrity|identity|dimension|No current-spec export progress|unavailable|invalid|differs|not ready|refus', text, re.I):return False
    return bool(re.search(r'Failed\s*to\s*fetch|network(?:\s+request)?(?:\s+(?:error|failed|failure))?|ResourceRequest[^\n]*(?:timeout|timed\s*out)|ECONNRESET|ECONNREFUSED|socket hang up', text, re.I))


def resume_exports(rounds=1000,batch=1,invoke=call,task=TASK,runner=run_exports,status_reader=export_status,pause=time.sleep,finish=None):
    if rounds<1:raise ValueError('Positive maximum rounds required')
    task=Path(task);journal_path=task/'export-retry-journal.json';events=[]
    if journal_path.exists():events=json.loads(journal_path.read_text()).get('events',[])
    failures=0;best=None;completed=0;last=None
    def counts(row):return (row['currentNative'],row['current1280']) if row else None
    def journal(error,current,status_error=None):
        row={'at':datetime.now(timezone.utc).isoformat(),'error':str(error)[:800],'errorType':type(error).__name__,'currentNative':current.get('currentNative') if current else None,'current1280':current.get('current1280') if current else None,'failuresWithoutProgress':failures,'retryDelaySeconds':2,'savedVerified':False}
        if status_error:row['statusReadError']=str(status_error)[:400]
        events.append(row);journal_path.write_text(json.dumps({'mode':'foreground-serial-network-retry-only','events':events},ensure_ascii=False,indent=2)+'\n');print(json.dumps(row,ensure_ascii=False),flush=True)
    while completed<rounds:
        try:
            before=status_reader(invoke)
            best=counts(before) if best is None else tuple(max(a,b) for a,b in zip(best,counts(before)))
            last=runner(1,batch,invoke=invoke,task=task)
            completed+=1;failures=0
            best=tuple(max(a,b) for a,b in zip(best,counts(last)))
            if last['currentNative']==last['current1280']==last['total'] and not last['missingNative'] and not last['missingSnapshots']:
                if finish is not None:finish()
                return last
        except Exception as error:
            if not transient_error(error):raise
            current=None;status_error=None
            try:current=status_reader(invoke)
            except Exception as caught:
                if not transient_error(caught):raise
                status_error=caught
            now=counts(current)
            progress=now is not None and best is not None and any(new>old for new,old in zip(now,best))
            if now is not None:best=now if best is None else tuple(max(a,b) for a,b in zip(best,now))
            failures=0 if progress else failures+1
            journal(error,current,status_error)
            if failures>=3:raise RuntimeError('Stopped after three transient failures without current native/preview progress; inspect export-retry-journal.json') from error
            pause(2)
    raise RuntimeError('Export round limit reached before every current native/preview was complete')


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--rounds',type=int,default=1000)
    parser.add_argument('--batch',type=int,choices=(1,2),default=1)
    parser.add_argument('--finish',action='store_true',help='After all current PNGs/imports finish, serially run comparisons, prototypes and actual audit')
    args=parser.parse_args()
    finish=None
    if args.finish:
        from finish_driver import FinishDriver
        finish=lambda:FinishDriver().run('all')
    resume_exports(args.rounds,args.batch,finish=finish)


if __name__=='__main__':main()
