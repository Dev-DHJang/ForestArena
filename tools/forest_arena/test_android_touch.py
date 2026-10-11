import tempfile
import unittest
import shutil
import subprocess
import concurrent.futures
import zipfile
from unittest.mock import patch
from pathlib import Path
from android_touch import perform, prepare


class FakeADB:
    def __init__(self, response='FOREST_ARENA_ADB_MULTI_TOUCH_COMPLETE', error=False):
        self.commands, self.response, self.error = [], response, error

    def run(self, *args, **kwargs):
        self.commands.append(args)

    def shell(self, *args, **kwargs):
        self.commands.append(args)
        if self.error and args[0] == 'env':
            raise RuntimeError('Android denied event injection')
        return self.response


class AndroidTouchTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.jar = Path(self.directory.name)/'touch.jar'
        self.jar.write_bytes(b'test-dex-artifact')

    def test_actual_shell_touch_and_remote_cleanup(self):
        adb = FakeADB()
        result = perform(adb, self.jar, (10, 20), (30, 40))
        self.assertEqual(result['source'], 'adb_touch_multi_pointer')
        self.assertEqual(adb.commands[0][0], 'push')
        self.assertIn('app_process', adb.commands[1])
        self.assertEqual(adb.commands[1][-6:], ('10.0','20.0','30.0','40.0','120','160'))
        self.assertEqual(adb.commands[-1][:2], ('rm','-f'))

    def test_no_app_completion_is_not_success(self):
        adb = FakeADB(response='')
        with self.assertRaises(RuntimeError): perform(adb,self.jar,(1,2),(3,4))
        self.assertEqual(adb.commands[-1][:2], ('rm','-f'))

    def test_android_injection_error_still_removes_helper(self):
        adb = FakeADB(error=True)
        with self.assertRaises(RuntimeError): perform(adb,self.jar,(1,2),(3,4))
        self.assertEqual(adb.commands[-1][:2], ('rm','-f'))

    def test_invalid_positions_do_not_operate_device(self):
        for value in (-1,float('nan'),float('inf')):
            adb = FakeADB()
            with self.assertRaises(ValueError): perform(adb,self.jar,(value,2),(3,4))
            self.assertEqual(adb.commands, [])

    def test_unbounded_gesture_do_not_operate_device(self):
        for lead, hold in ((0,160),(120,0),(1001,160),(120,2001)):
            adb = FakeADB()
            with self.assertRaises(ValueError): perform(adb,self.jar,(1,2),(3,4),lead,hold)
            self.assertEqual(adb.commands, [])

    def fake_sdk(self):
        root=Path(self.directory.name)/'sdk'
        for relative in ('platforms/android-36/android.jar','build-tools/36.1.0/d8'):
            path=root/relative;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(b'')
        return root

    @staticmethod
    def fake_compile(command, **kwargs):
        if command[0].endswith('/d8'):
            target=Path(command[command.index('--output')+1])
            with zipfile.ZipFile(target,'w') as archive: archive.writestr('classes.dex',b'dex-fixture')
        return subprocess.CompletedProcess(command,0,b'',b'')

    def test_four_device_build_publishes_one_complete_archive(self):
        sdk=self.fake_sdk();cache=Path(self.directory.name)/'cache'
        with patch.dict('os.environ',{'JAVA_HOME':'test-java'}), patch('android_touch.subprocess.run',side_effect=self.fake_compile) as compiler:
            with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
                jars=list(pool.map(lambda _:prepare(sdk,cache),range(4)))
        self.assertEqual(len(set(jars)),1)
        self.assertEqual(compiler.call_count,2)
        with zipfile.ZipFile(jars[0]) as archive: self.assertIn('classes.dex',archive.namelist())

    def test_interrupted_build_archive_is_repaired(self):
        sdk=self.fake_sdk();cache=Path(self.directory.name)/'cache'
        with patch.dict('os.environ',{'JAVA_HOME':'test-java'}), patch('android_touch.subprocess.run',side_effect=self.fake_compile) as compiler:
            jar=prepare(sdk,cache);jar.write_bytes(b'interrupted-zip')
            repaired=prepare(sdk,cache)
        self.assertEqual(compiler.call_count,4)
        with zipfile.ZipFile(repaired) as archive: self.assertIn('classes.dex',archive.namelist())


@unittest.skipUnless(shutil.which('javac') and shutil.which('java'), 'Java runtime unavailable')
class NativeTouchReleaseTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.directory = tempfile.TemporaryDirectory()
        cls.root = Path(cls.directory.name)
        stubs = {
            'android/os/SystemClock.java': '''package android.os;
public class SystemClock { public static long uptimeMillis(){return 1;}
public static void sleep(long value){} }''',
            'android/view/InputDevice.java': '''package android.view;
public class InputDevice { public static final int SOURCE_TOUCHSCREEN=4098; }''',
            'android/view/InputEvent.java': 'package android.view; public class InputEvent {}',
            'android/view/MotionEvent.java': '''package android.view;
public class MotionEvent extends InputEvent {
 public static final int ACTION_UP=1,ACTION_DOWN=0,ACTION_CANCEL=3,
 ACTION_POINTER_DOWN=5,ACTION_POINTER_UP=6,ACTION_POINTER_INDEX_SHIFT=8,TOOL_TYPE_FINGER=1;
 public int action,count;
 public static class PointerProperties { public int id,toolType; }
 public static class PointerCoords { public float x,y,pressure,size; }
 public static MotionEvent obtain(long down,long event,int action,int count,
 PointerProperties[] props,PointerCoords[] coords,int meta,int buttons,float xp,float yp,
 int device,int edge,int source,int flags) {
  for(int i=0;i<count;i++) if(props[i].id!=i || source!=4098) throw new AssertionError();
  MotionEvent e=new MotionEvent();e.action=action;e.count=count;return e;
 }
 public void recycle(){} }''',
            'android/hardware/input/InputManagerGlobal.java': '''package android.hardware.input;
import android.view.InputEvent; import android.view.MotionEvent;
public class InputManagerGlobal {
 private int calls=0;
 public static InputManagerGlobal getInstance(){return new InputManagerGlobal();}
 public boolean injectInputEvent(InputEvent input,int mode){
  MotionEvent e=(MotionEvent)input; calls++;
  if(mode!=2) throw new AssertionError();
  System.out.println("EVENT:"+e.action+":"+e.count);
  if(calls==2 && "throw".equals(System.getProperty("fault"))) throw new IllegalStateException();
  return !(calls==2 && "reject".equals(System.getProperty("fault")));
 } }''',
        }
        paths = []
        for relative, source in stubs.items():
            path=cls.root/relative; path.parent.mkdir(parents=True,exist_ok=True)
            path.write_text(source); paths.append(str(path))
        paths.append(str(Path(__file__).parent/'android_fleet_touch/FleetTouch.java'))
        subprocess.run(['javac','-d',str(cls.root),*paths],check=True,capture_output=True,timeout=30)

    @classmethod
    def tearDownClass(cls): cls.directory.cleanup()

    def inject(self, fault='none'):
        return subprocess.run(['java','-cp',str(self.root),'-Dfault='+fault,'FleetTouch',
                               '10','20','30','40','120','160'],capture_output=True,text=True,timeout=10)

    def test_native_sequence_releases_both_pointer_ids(self):
        result=self.inject()
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertEqual([s for s in result.stdout.splitlines() if s.startswith('EVENT:')],
                         ['EVENT:0:1','EVENT:261:2','EVENT:262:2','EVENT:1:1'])
        self.assertIn('FOREST_ARENA_ADB_MULTI_TOUCH_COMPLETE',result.stdout)

    def test_android_rejection_sends_cancel_for_both_contacts(self):
        result=self.inject('reject')
        self.assertNotEqual(result.returncode,0)
        self.assertEqual(result.stdout.splitlines()[-1],'EVENT:3:2')
        self.assertNotIn('FOREST_ARENA_ADB_MULTI_TOUCH_COMPLETE',result.stdout)

    def test_android_exception_sends_cancel_for_both_contacts(self):
        result=self.inject('throw')
        self.assertNotEqual(result.returncode,0)
        self.assertEqual(result.stdout.splitlines()[-1],'EVENT:3:2')


if __name__ == '__main__': unittest.main()
