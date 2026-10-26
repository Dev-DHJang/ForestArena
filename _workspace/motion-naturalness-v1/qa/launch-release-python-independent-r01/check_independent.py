"""Independent tests use only temporary artificial projects; no real approval/asset writes."""
import contextlib,copy,hashlib,io,json,math,sys,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[4]
sys.path.insert(0,str(ROOT/'tools/forest_arena'))
import test_motion_action_review as fixture_module
from motion_layout import layout
from register_motion_candidates import install,MANIFEST,plan_digest
read,write=fixture_module.read,fixture_module.write
boundary_checks=0
class IndependentLayout(unittest.TestCase):
 def test_every_legal_span_int_and_float_json(self):
  global boundary_checks
  for count in (16,24,32):
   for begin in range(count):
    for end in range(begin+1,min(count,begin+12)+1):
     for ticks in {end-begin,12}:
      for floating in (False,True):
       row={'visual_state_id':'launch','frame_count':count,'launch_release_frame_range':[float(begin),float(end)] if floating else [begin,end],'launch_release_ticks':float(ticks) if floating else ticks}
       row=json.loads(json.dumps(row));before=copy.deepcopy(row)
       self.assertEqual(layout(row)['frame_count'],count);self.assertEqual(row,before);boundary_checks+=1
 def test_rejected_boundaries_do_not_mutate(self):
  global boundary_checks
  base={'visual_state_id':'launch','launch_release_frame_range':[12,16],'launch_release_ticks':4}
  bad=[None,True,False,'4',{},[],math.nan,math.inf,-math.inf,4.5,10**400,-10**400]
  rows=[]
  for value in bad:
   for field in ('ticks','begin','end'):
    row=copy.deepcopy(base)
    if field=='ticks':row['launch_release_ticks']=value
    else:row['launch_release_frame_range'][0 if field=='begin' else 1]=value
    rows.append(row)
  for span,ticks in (([12,16],3),([12,16],13),([16,16],4),([-1,16],12),([12,17],5),([16,12],4),([0,16],12)):
   rows.append(dict(base,launch_release_frame_range=span,launch_release_ticks=ticks))
  for missing in base:
   if missing!='visual_state_id':row=copy.deepcopy(base);row.pop(missing);rows.append(row)
  rows += [dict(base,visual_state_id=m) for m in ('guard','jump','fall','special_side',None)]
  rows += [{'landing_down_frame_range':v} for v in (None,[0,17],[16,16],[False,16],[0.5,16],[0,math.inf])]
  rows += [{'state_duration_ticks':v} for v in (0,-1,False,None,1.5,math.nan,math.inf,'18')]
  rows += [{'state_hold_frame':v} for v in (-1,16,True,None,0.5,math.inf)]
  for row in rows:
   with self.subTest(row=row),self.assertRaises(ValueError):layout(row)
   boundary_checks+=1
 def test_existing_fields_and_legacy(self):
  self.assertEqual(layout({}),layout({'frame_count':16}))
  self.assertEqual(layout({'path':'assets/launch_16f.png','launch_release_frame_range':[12.,16.],'launch_release_ticks':4.})['frame_count'],16)
  row={'state_duration_ticks':18.,'state_hold_frame':15.,'landing_down_frame_range':[12.,16.]};before=copy.deepcopy(row)
  self.assertEqual(layout(row)['frame_count'],16);self.assertEqual(row,before)
class IndependentRegistration(unittest.TestCase):
 def setUp(self):
  self.c=fixture_module.MotionRegistrationTest();self.c.setUp();self.addCleanup(self.c.doCleanups)
 def configure(self,motion='launch',**fields):
  self.c.fixture.update_catalog(lambda d:d['assets'][0].update(visual_state_id=motion,**fields))
  self.c.prepare_art(16,motion)
 def row(self,pending,motion):return next(x for x in json.loads(pending[MANIFEST])['assets'] if x.get('visual_state_id')==motion)
 def test_full_float_pair_and_state_fields_plan_approved_fixture_install(self):
  fields={'launch_release_frame_range':[12.,16.],'launch_release_ticks':4.,'state_duration_ticks':18.,'state_hold_frame':15.,'landing_down_frame_range':[12.,16.]}
  self.configure(**fields);before=self.c.snapshot();plan,pending=self.c.plan();self.assertEqual(before,self.c.snapshot())
  self.assertEqual(plan_digest(plan),plan_digest(self.c.plan()[0]))
  self.assertEqual({k:self.row(pending,'launch')[k] for k in fields},fields)
  with self.assertRaisesRegex(ValueError,'human approval.*missing'):install(self.c.root,plan,pending,self.c.backup)
  self.assertEqual(before,self.c.snapshot());self.assertFalse(self.c.backup.exists())
  self.c.fixture_approval(plan) # Artificial approval ONLY in tempfile fixture.
  install(self.c.root,plan,pending,self.c.backup)
  row=next(x for x in read(self.c.fixture.fixture.manifest)['assets'] if x.get('visual_state_id')=='launch')
  self.assertEqual({k:row[k] for k in fields},fields)
 def test_explicit_false_decision_never_creates_backup_or_target(self):
  self.configure(launch_release_frame_range=[12,16],launch_release_ticks=4);plan,pending=self.c.plan()
  approval=self.c.fixture_approval(plan);approval['motions'][0]['user_approved']=False;write(self.c.approval,approval)
  before=self.c.snapshot()
  with self.assertRaisesRegex(ValueError,'per-motion approval'):install(self.c.root,plan,pending,self.c.backup)
  self.assertEqual(before,self.c.snapshot());self.assertFalse(self.c.backup.exists())
 def test_display_edit_after_plan_invalidates_approval_before_write(self):
  self.configure(launch_release_frame_range=[12,16],launch_release_ticks=4);plan,pending=self.c.plan();self.c.fixture_approval(plan)
  self.c.fixture.update_catalog(lambda d:d['assets'][0].update(launch_release_ticks=5))
  before=self.c.snapshot()
  with self.assertRaises(ValueError):install(self.c.root,plan,pending,self.c.backup)
  self.assertEqual(before,self.c.snapshot());self.assertFalse(self.c.backup.exists())
 def test_down_fields_survive_as_exact_json_numbers(self):
  fields={'state_duration_ticks':18.,'state_hold_frame':15.,'landing_down_frame_range':[12.,16.]}
  self.configure('knock_down',**fields);before=self.c.snapshot();plan,pending=self.c.plan();self.assertEqual(before,self.c.snapshot())
  self.assertEqual({k:self.row(pending,'knock_down')[k] for k in fields},fields)
if __name__=='__main__':
 suite=unittest.TestSuite([unittest.defaultTestLoader.loadTestsFromTestCase(IndependentLayout),unittest.defaultTestLoader.loadTestsFromTestCase(IndependentRegistration)])
 with contextlib.redirect_stdout(io.StringIO()):result=unittest.TextTestRunner(verbosity=2).run(suite)
 print('independent scalar/span boundary cases:',boundary_checks)
 sys.exit(0 if result.wasSuccessful() else 1)
