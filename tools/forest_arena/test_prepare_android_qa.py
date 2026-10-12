"""Generated-template and executable Java launch-adapter contract tests."""
import shutil
import subprocess
import tempfile
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path
from prepare_android_qa import ADAPTER, END, START, prepare, prepare_manifest

TEMPLATE = '''package com.godot.game;
public class GodotApp extends GodotActivity {
	// existing customization stays intact
	public void onCreate(Bundle savedInstanceState) {
		SplashScreen splashScreen = SplashScreen.installSplashScreen(this);
		super.onCreate(savedInstanceState);
	}
}
'''


class PrepareTests(unittest.TestCase):
    def test_idempotent_update_keeps_existing_customization(self):
        once = prepare(TEMPLATE)
        self.assertEqual(prepare(once), once)
        self.assertEqual(once.count(START), 1)
        self.assertEqual(once.count(END), 1)
        self.assertEqual(once.count('\t\treadForestArenaQaArgs();'), 1)
        self.assertIn('// existing customization stays intact', once)
        self.assertLess(once.index('\t\treadForestArenaQaArgs();'), once.index('super.onCreate(savedInstanceState)'))

    def test_unsupported_template_rejected(self):
        for source in ('', TEMPLATE.replace('GodotActivity', 'OtherActivity'), TEMPLATE.replace('SplashScreen.installSplashScreen(this)', 'otherSplash()'), TEMPLATE+TEMPLATE):
            with self.subTest(source=source[:40]), self.assertRaises(ValueError):
                prepare(source)

    def test_corrupt_or_duplicate_adapter_rejected(self):
        for source in (TEMPLATE.replace('// existing customization stays intact', START.strip()), prepare(TEMPLATE).replace(END, ''), prepare(TEMPLATE).replace(START, START+'\n'+START)):
            with self.subTest(source=source[:40]), self.assertRaises(ValueError):
                prepare(source)

    def test_manifest_preserves_permissions_activity_customization(self):
        source = '''<manifest xmlns:android="http://schemas.android.com/apk/res/android" xmlns:tools="http://schemas.android.com/tools" package="com.forest.example">
        <uses-permission android:name="android.permission.INTERNET"/>
        <application android:label="Forest" tools:replace="android:label">
        <activity android:name=".GodotApp" android:exported="true"/>
        <meta-data android:name="custom.setting" android:value="keep"/>
        </application></manifest>'''
        actual = prepare_manifest(source)
        root = ET.fromstring(actual)
        android = '{http://schemas.android.com/apk/res/android}'
        self.assertEqual(root.get('package'), 'com.forest.example')
        self.assertEqual(root.find('uses-permission').get(android+'name'), 'android.permission.INTERNET')
        app = root.find('application')
        self.assertEqual(app.get(android+'label'), 'Forest')
        self.assertEqual(app.get('{http://schemas.android.com/tools}replace'), 'android:label')
        self.assertEqual(app.find('activity').get(android+'exported'), 'true')
        self.assertTrue(any(child.get(android+'name')=='custom.setting' and child.get(android+'value')=='keep' for child in app))
        self.assertEqual(prepare_manifest(actual), actual)
        markers = [child for child in app if child.get(android+'name')=='org.forest_arena.qa_launch_adapter']
        self.assertEqual(len(markers), 1)
        self.assertEqual(markers[0].get(android+'value'), '1')
        self.assertIsNone(app.get(android+'debuggable'))  # Presence does not activate QA/release debug.

    def test_manifest_replaces_stale_duplicate_markers(self):
        source = '''<manifest xmlns:android="http://schemas.android.com/apk/res/android"><application>
        <meta-data android:name="org.forest_arena.qa_launch_adapter" android:value="old"/>
        <meta-data android:name="org.forest_arena.qa_launch_adapter" android:value="older"/>
        </application></manifest>'''
        result = prepare_manifest(source)
        root = ET.fromstring(result)
        self.assertEqual(len(root.find('application')), 1)
        self.assertEqual(prepare_manifest(result), result)

    def test_missing_application_and_malformed_manifest_rejected(self):
        with self.assertRaises(ValueError):
            prepare_manifest('<manifest/>')
        with self.assertRaises(ET.ParseError):
            prepare_manifest('<manifest><application>')

    def test_release_guard_and_exact_allowlist_static_contract(self):
        self.assertIn('if (!BuildConfig.DEBUG) return;', ADAPTER)
        self.assertIn('if (BuildConfig.DEBUG) args.addAll(forestArenaQaArgs);', ADAPTER)
        self.assertIn('args.length != 3', ADAPTER)
        self.assertIn('!"--".equals(args[0])', ADAPTER)
        self.assertIn('--qa-run=[A-Za-z0-9_-]{1,64}', ADAPTER)
        self.assertIn('--qa-device=[A-Za-z0-9_-]{1,64}', ADAPTER)
        self.assertNotIn('Runtime.getRuntime', ADAPTER)

    @unittest.skipUnless(shutil.which('javac') and shutil.which('java'), 'Java compiler/runtime unavailable; static contract still runs')
    def test_java_debug_release_and_malformed_intents(self):
        # Compile the exact emitted adapter against minimal Android/Godot stubs.
        source = '''
import java.util.*;
class BuildConfig { static boolean DEBUG; }
class Intent { String[] values; String[] getStringArrayExtra(String key) { return values; } }
class GodotActivity {
 Intent intent = new Intent(); Intent getIntent() { return intent; }
 public List<String> getCommandLine() { return Arrays.asList("--existing"); }
}
class GodotApp extends GodotActivity {
''' + ADAPTER + '''
 void read() { readForestArenaQaArgs(); }
}
public class AdapterTest {
 static void check(boolean value) { if (!value) throw new AssertionError(); }
 static List<String> run(boolean debug, String[] values) {
  BuildConfig.DEBUG = debug; GodotApp app = new GodotApp();
  app.intent.values = values; app.read(); return app.getCommandLine();
 }
 public static void main(String[] unused) {
  String[] valid = {"--", "--qa-run=run_123", "--qa-device=device-1"};
  check(run(true, valid).equals(Arrays.asList("--existing", "--", "--qa-run=run_123", "--qa-device=device-1")));
  check(run(false, valid).equals(Arrays.asList("--existing")));
  String[][] bad = {null, {}, {"--"}, {"--", "--qa-run=ok"},
   {"--", "--qa-run=ok", "--qa-device=one", "--db-profile"},
   {"other", "--qa-run=ok", "--qa-device=one"},
   {"--", "--qa-run=../escape", "--qa-device=one"},
   {"--", "--qa-run=ok", "--qa-device=one,two"},
   {"--", "--qa-run=", "--qa-device=one"},
   {"--", "--qa-run="+"x".repeat(65), "--qa-device=one"},
   {"--", null, "--qa-device=one"}, {"--", "--qa-run=ok", null},
   {"--", "--qa-device=one", "--qa-run=ok"}};
  for (String[] values : bad) check(run(true, values).equals(Arrays.asList("--existing")));
  check(run(true, new String[]{"--", "--qa-run="+"x".repeat(64), "--qa-device="+"y".repeat(64)}).size()==4);
  BuildConfig.DEBUG=true; GodotApp app=new GodotApp(); app.intent.values=valid; app.read();
  BuildConfig.DEBUG=false; check(app.getCommandLine().equals(Arrays.asList("--existing")));
  System.out.println("ANDROID_QA_JAVA_ADAPTER: PASS");
 }
}
'''
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / 'AdapterTest.java'
            target.write_text(source)
            compile_result = subprocess.run(['javac', str(target)], capture_output=True, text=True, timeout=30)
            self.assertEqual(compile_result.returncode, 0, compile_result.stderr)
            result = subprocess.run(['java', '-cp', directory, 'AdapterTest'], capture_output=True, text=True, timeout=10)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn('ANDROID_QA_JAVA_ADAPTER: PASS', result.stdout)


if __name__ == '__main__':
    unittest.main()
