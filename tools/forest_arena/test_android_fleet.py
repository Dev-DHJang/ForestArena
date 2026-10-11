"""Deterministic host runner tests: no physical-device claims and no waiting."""
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import android_fleet as fleet
from android_fleet_auth_fixture import GuestFixture


class Clock:
    def __init__(self): self.now = 0.
    def time(self): return self.now
    def sleep(self, seconds): self.now += seconds


class FakeADB:
    serial, package, executable = 'physical-one', 'com.example.game', 'adb'
    def __init__(self, states):
        self.states = iter(states)
        self.last = {}
        self.commands = []
        self.disconnected = False
    def read_state(self, _run):
        if self.disconnected: raise fleet.Blocked('ADB 연결이 끊겼습니다.')
        self.last = next(self.states, self.last)
        return self.last
    def write_command(self, run, command, timeout=30):
        self.commands.append(command)
        self.last = {**self.last, 'command_seq': command['seq'], 'command_error': ''}
        if command.get('op') == 'autoplay': self.last['autocontrol'] = command['args']['enabled']
    def screenshot(self, _path): pass
    def shell(self, *args, **_kwargs):
        self.commands.append(list(args))
        return ''
    def touch(self, *args): self.commands.append(list(args))
    def launch(self, *_args): self.commands.append('launch')


class RunnerTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.output = Path(self.tmp.name)
    def tearDown(self): self.tmp.cleanup()
    def device(self, states):
        self.clock = Clock()
        self.adb = FakeADB(states)
        return fleet.DeviceRun(self.adb, 'device-1', 'test-run', self.output, 'Game', screen_timeout=1,
                               match_timeout=5, stall_timeout=1, clock=self.clock.time, sleep=self.clock.sleep)
    def test_serials_explicit_limit_and_duplicates(self):
        self.assertEqual(fleet.selected_serials(['one,two', 'three']), ['one', 'two', 'three'])
        self.assertEqual(fleet.selected_serials([]), [])
        for values in (['one,one'], ['a,b,c,d,e'], ['bad;command']):
            with self.assertRaises(ValueError): fleet.selected_serials(values)
    def test_28_jobs_round_robin_no_duplication(self):
        for count in range(1, 5):
            jobs = fleet.combination_jobs(count)
            flat = [(job['character'], job['accessory']) for group in jobs for job in group]
            self.assertEqual(len(flat), 28)
            self.assertEqual(len(set(flat)), 28)
            self.assertLessEqual(max(map(len, jobs))-min(map(len, jobs)), 1)
            self.assertIn(('yu-ran', ''), flat)
    def test_aggregation_never_promotes_blocked_or_skipped(self):
        self.assertEqual(fleet.aggregate([])['status'], 'blocked')
        self.assertEqual(fleet.aggregate([{'status':'미실행'}])['status'], 'blocked')
        self.assertEqual(fleet.aggregate([{'status':'pass'}, {'status':'blocked'}])['status'], 'blocked')
        self.assertEqual(fleet.aggregate([{'status':'fail'}, {'status':'blocked'}])['status'], 'fail')
    def test_wait_deadline_no_hanging(self):
        d = self.device([{'screen':'loading'}])
        with self.assertRaisesRegex(fleet.Failure, '시간 초과'): d.screen('home')
        self.assertGreaterEqual(self.clock.now, 1)
        self.assertLess(self.clock.now, 1.3)
    def test_disconnection_recorded_blocked_preserves_previous(self):
        d = self.device([{'screen':'home'}])
        d.mark('DEV-01', 'pass', 'first attempt')
        self.adb.disconnected = True
        self.assertEqual(d.case('UI-01', lambda: d.screen('shop')), 'blocked')
        self.assertEqual([r['status'] for r in d.results], ['pass', 'blocked'])
        self.assertEqual(json.loads((self.output/'results.json').read_text())[1]['status'], 'blocked')
    def test_combat_stall_is_fail(self):
        d = self.device([{'screen':'match', 'snapshot': {'fighters':[{'id':'player','current_hp':100,'stocks':3}]}}])
        with self.assertRaisesRegex(fleet.Failure, '피해'): d.combat_result()
    def test_practice_not_stall_checked_by_navigation(self):
        d = self.device([{'screen':'result', 'snapshot':{'fighters':[{'id':'player'}]}, 'latest_result': {'winner_id':'player','final_tick':10,'snapshot_hash':'a'*64}}])
        self.assertEqual(d.combat_result()['winner_id'], 'player')
    def test_soak_cutoff_returns_incomplete_not_failure(self):
        d = self.device([{'screen':'match', 'snapshot': {'fighters':[{'id':'player','current_hp':100,'stocks':3}]}}])
        d.stall_timeout = 30
        self.assertIsNone(d.combat_result(deadline=.5))
    def test_round_timeout_before_soak_end_is_failure(self):
        d = self.device([{'screen':'match', 'snapshot': {'fighters':[{'id':'player','current_hp':100,'stocks':3}]}}])
        d.stall_timeout = 30
        with self.assertRaisesRegex(fleet.Failure, '한 판'): d.combat_result(deadline=20)
    def test_command_schema_identity_and_ack(self):
        d = self.device([{'screen':'home'}])
        d.read()
        d.command('context')
        command = self.adb.commands[0]
        self.assertEqual(command, {'schema_version':1,'run_id':'test-run','seq':1,'case_id':'DEV-01','op':'context','args':{}})
    def test_physical_coordinate_scaling_uses_center(self):
        d = self.device([])
        d.physical_size = (2400,1080)
        self.assertEqual(d.center({'x':.25,'y':.75,'width':.2,'height':.1}), (600,810))
    def test_boot_freshness_rejects_old_file(self):
        old = {'screen':'home','boot_id':'old'}
        new = {'screen':'first','boot_id':'new'}
        d = self.device([old, old, old, new])
        d.launch()
        self.assertEqual(d.state['boot_id'], 'new')
        self.assertGreater(self.clock.now, 0)
    def test_rematch_checks_reset_snapshot_not_later_damage(self):
        d = self.device([{'snapshot':{'fighters':[{'current_hp':80,'max_hp':100,'stocks':3}]},
                         'touch':{'active':[]}, 'reset_snapshot':{'fighters':[{'id':'player','current_hp':100,'max_hp':100,'stocks':3,'input_direction':0,'buffered_action':''}]}}])
        d.assert_reset()
    def test_sensitive_nested_data_is_redacted(self):
        value = fleet.redact({'access_token':'private','nested':[{'reconnect_token':'private2'}], 'log':'Authorization Bearer secretvalue'})
        self.assertNotIn('private', json.dumps(value))
        self.assertNotIn('secretvalue', json.dumps(value))
    def test_summary_partial_combinations_not_pass(self):
        d = self.device([])
        d.combos = [{'character':'ja-hyun', 'accessory':''}]
        d.mark('OFF-02','pass','observed')
        fleet.write_summary(self.output,'test-run',{},[d],[])
        result = json.loads((self.output/'results.json').read_text())
        self.assertEqual(sum(c['status']=='pass' for c in result['combination_coverage']),1)
        self.assertEqual(sum(c['status']=='미실행' for c in result['combination_coverage']),27)
    def test_no_device_records_blocked_and_nonzero(self):
        with patch.object(fleet, 'run_process') as proc:
            proc.return_value.stdout = b'head'
            self.assertEqual(fleet.main(['--output',str(self.output)]),2)
        artifact = next(self.output.glob('*/results.json'))
        self.assertEqual(json.loads(artifact.read_text())['summary']['status'],'blocked')
    def test_same_physical_device_rejected_before_install(self):
        with patch.object(fleet, 'inspect_apk', return_value={'package':'com.example','activity':'Game'}), \
             patch.object(fleet, 'ADB') as adb_type, patch.object(fleet, 'run_process') as proc:
            adb_type.return_value.inspect.return_value = {'ro.serialno':'same-phone'}
            adb_type.return_value.shell.return_value = ''
            proc.return_value.stdout = b'head'
            code = fleet.main(['--serial','one,two','--output',str(self.output)])
            self.assertEqual(code,1)
            adb_type.return_value.run.assert_not_called()
        artifact = next(self.output.glob('*/results.json'))
        self.assertIn('같은 물리 기기', json.loads(artifact.read_text())['cases'][0]['message'])
    def test_command_json_never_interpolated_as_shell_code(self):
        adb = fleet.ADB('adb','phone','com.example')
        with patch.object(fleet, 'run_process') as process:
            process.return_value.returncode = 0
            process.return_value.stdout = b''
            payload = {'args':{'value':'$(secret) `secret` ; touch bad'}}
            adb.write_command('safe_run',payload)
            called = process.call_args.args
            self.assertNotIn('secret', ' '.join(called[0]))
            self.assertEqual(json.loads(called[2]),payload)
    def test_android_launch_flags_delivered_as_string_array(self):
        adb = fleet.ADB('adb','phone','com.example')
        with patch.object(adb, 'shell', return_value='Status: ok') as shell:
            adb.launch('Game','safe_run','device-1')
        self.assertEqual(shell.call_args.args[-3:], ('--esa','command_line_params','--,--qa-run=safe_run,--qa-device=device-1'))

    def test_manifest_launcher_alias_when_badging_omits_activity(self):
        manifest = """    E: application (line=24)
      A: android:debuggable(0x0101000f)=(type 0x12)0xffffffff
      E: activity (line=42)
        A: android:name(0x01010003)="com.godot.game.GodotApp"
        A: android:exported(0x01010010)=(type 0x12)0x0
      E: activity-alias (line=55)
        A: android:name(0x01010003)="com.godot.game.GodotAppLauncher"
        A: android:exported(0x01010010)=(type 0x12)0xffffffff
        A: android:targetActivity(0x01010202)="com.godot.game.GodotApp"
        E: intent-filter (line=59)
          E: action (line=60)
            A: android:name(0x01010003)="android.intent.action.MAIN"
          E: category (line=63)
            A: android:name(0x01010003)="android.intent.category.LAUNCHER"
      E: meta-data (line=70)
        A: android:name(0x01010003)="org.forest_arena.qa_launch_adapter"
        A: android:value(0x01010024)=(type 0x10)0x1
      E: provider (line=80)
        A: android:name(0x01010003)="Other"
"""
        self.assertEqual(fleet.launcher_from_manifest(manifest), 'com.godot.game.GodotAppLauncher')
        apk = self.output/'debug.apk'
        apk.write_bytes(b'fake fixture')
        with patch.object(fleet, 'run_process') as process:
            from types import SimpleNamespace
            process.side_effect = [SimpleNamespace(returncode=0,stdout=b"package: name='com.example'"), SimpleNamespace(returncode=0,stdout=manifest.encode())]
            inspected = fleet.inspect_apk(apk,'aapt')
        self.assertEqual(inspected['activity'],'com.godot.game.GodotAppLauncher')

    def test_repeated_runtime_performance_sample_is_not_duplicated(self):
        d = self.device([{'performance':{'seq':1,'fps':60}},{'performance':{'seq':1,'fps':60}},{'performance':{'seq':2,'fps':59}}])
        d.read(); d.read(); d.read()
        self.assertEqual(len(d.metrics),2)
    def test_cleanup_turns_off_autoplay_without_clearing_saves(self):
        d = self.device([{'boot_id':'boot','command_seq':12,'autocontrol':True}])
        d.read()
        d.stop_autoplay()
        self.assertEqual(d.cleanup_autoplay,'confirmed_disabled')
        self.assertEqual(self.adb.commands[-1]['seq'],13)
        self.assertEqual(self.adb.commands[-1]['args'],{'enabled':False})
    def test_permission_denied_system_metrics_remain_unknown(self):
        d = self.device([])
        self.adb.shell = lambda *_args, **_kwargs: 'Permission Denial: missing permission'
        d.sample_system_metrics()
        self.assertEqual(d.system_metrics[0]['memory']['status'],'미확인')
        self.assertEqual(d.system_metrics[0]['thermal']['status'],'미확인')
    def test_input_release_requires_observed_active_field(self):
        d = self.device([])
        with self.assertRaisesRegex(fleet.Failure,'진단'): d.assert_released({'touch':{}})
        with self.assertRaises(fleet.Failure): d.assert_released({'touch':{'active':['move_right']}})
        d.assert_released({'touch':{'active':[]}})

    def test_original_stores_use_only_hashes_and_known_paths(self):
        adb = fleet.ADB('adb','phone','com.example')
        digest = 'a'*64
        with patch.object(adb, 'shell', side_effect=['package:/data/app/game.apk','/data/user/0/game']), patch.object(adb, 'run', side_effect=[b'device',(digest+'  files/local_player.json\nFOREST_ARENA_STORE_HASHES_DONE').encode(),b'device']) as command:
            result = adb.original_store_hashes()
        self.assertEqual(result,{'files/local_player.json':digest})
        checksum_args = command.call_args_list[1].args
        self.assertTrue(any('sha256sum' in arg for arg in checksum_args))
        self.assertNotIn('cat',checksum_args)
    def test_empty_transient_checksum_output_is_blocked_not_deleted(self):
        adb = fleet.ADB('adb','phone','com.example')
        with patch.object(adb,'shell',side_effect=['package:/data/app/game.apk','/data/user/0/game']), patch.object(adb,'run',side_effect=[b'device',b'',b'device']):
            with self.assertRaisesRegex(fleet.Blocked,'파일 삭제로 판단하지 않습니다'): adb.original_store_hashes()
    def test_disconnected_save_probe_is_blocked_before_package_lookup(self):
        adb = fleet.ADB('adb','phone','com.example')
        with patch.object(adb,'run',side_effect=fleet.Blocked('disconnected')),patch.object(adb,'shell') as shell:
            with self.assertRaises(fleet.Blocked): adb.original_store_hashes()
            shell.assert_not_called()
    def test_proven_absent_files_return_empty_with_completion_marker(self):
        adb = fleet.ADB('adb','phone','com.example')
        with patch.object(adb,'shell',side_effect=['package:/data/app/game.apk','/data/user/0/game']),patch.object(adb,'run',side_effect=[b'device',b'FOREST_ARENA_STORE_HASHES_DONE',b'device']):
            self.assertEqual(adb.original_store_hashes(),{})

    def test_original_store_changed_is_failure_at_close(self):
        d = self.device([])
        d.original_hashes = {'files/local_player.json':'before'}
        self.adb.original_store_hashes = lambda: {'files/local_player.json':'after'}
        d.close()
        self.assertEqual(d.results[-1]['case_id'],'UI-01')
        self.assertEqual(d.results[-1]['status'],'fail')
        artifact = json.loads((self.output/'original-stores.json').read_text())
        self.assertIs(artifact['unchanged'],False)
    def test_original_store_disconnect_preserves_before_as_unknown(self):
        d = self.device([])
        d.original_hashes = {'files/local_player.json':'before'}
        def disconnected(): raise fleet.Blocked('disconnected')
        self.adb.original_store_hashes = disconnected
        d.close()
        artifact = json.loads((self.output/'original-stores.json').read_text())
        self.assertEqual(artifact['before'],d.original_hashes)
        self.assertIsNone(artifact['after'])
        self.assertIsNone(artifact['unchanged'])
        self.assertEqual(d.results[-1]['status'],'blocked')
    def test_shop_scroll_avoids_right_purchase_button_column(self):
        hidden = {'id':'purchase/ultimate','x':.75,'y':1.03,'visible':False}
        shown = {**hidden,'y':.70,'visible':True}
        d = self.device([{'ui':[hidden]},{'ui':[shown]}])
        d.physical_size = (3088,1440)
        self.assertEqual(d.node(id='purchase/ultimate'),shown)
        swipe = self.adb.commands[0]
        self.assertEqual(swipe[:2],['input','swipe'])
        self.assertEqual(swipe[2],str(round(3088*.19)))
        self.assertEqual(swipe[2],swipe[4])
        self.assertLess(int(swipe[2]),3088*.4)
    def test_server_reset_log_ignores_other_records_and_corrupt_lines(self):
        server = fleet.LanServer('127.0.0.1','127.0.0.0/8',1,2,self.output,'godot','run')
        (self.output/'server.raw').write_text('FOREST_ARENA_QA_LAN_INPUT_RESET bad\nFOREST_ARENA_QA_LAN_INPUT_RESET {"slot":1,"tick":30,"input_direction":0,"buffered_action":""}\n')
        self.assertEqual(server.input_resets(),[{'slot':1,'tick':30,'input_direction':0,'buffered_action':''}])

    def test_install_timeout_is_separate_from_screen_and_match(self):
        args = fleet.parser().parse_args(['--install-timeout','450'])
        self.assertEqual(args.install_timeout,450)
        self.assertEqual(args.screen_timeout,30)
        self.assertEqual(args.match_timeout,300)
        d = self.device([])
        self.assertEqual(d.install_timeout,600)

    def test_android_zero_exit_error_stdout_is_not_accepted(self):
        adb = fleet.ADB('adb','phone','com.example')
        for output in ('Error type 3\nError: Activity class does not exist.', 'java.lang.SecurityException: not exported', 'Status: timeout'):
            with patch.object(adb,'shell',side_effect=['',output]), self.assertRaises(fleet.Failure):
                adb.launch('Game','safe_run','device-1')

    def test_adapter_marker_required_before_install(self):
        apk = self.output/'ordinary-debug.apk'
        apk.write_bytes(b'fixture')
        from types import SimpleNamespace
        ordinary_manifest = '    E: application (line=24)\n      A: android:debuggable(0x0101000f)=(type 0x12)0xffffffff\n'
        with patch.object(fleet,'run_process') as process:
            process.side_effect = [SimpleNamespace(returncode=0,stdout=b"package: name='com.example'\nlaunchable-activity: name='Game'"), SimpleNamespace(returncode=0,stdout=ordinary_manifest.encode())]
            with self.assertRaisesRegex(fleet.Blocked,'adapter'): fleet.inspect_apk(apk,'aapt')
        marked = ordinary_manifest+'      E: meta-data (line=70)\n        A: android:name(0x01010003)="org.forest_arena.qa_launch_adapter"\n        A: android:value(0x01010024)="1"\n'
        self.assertTrue(fleet.has_launch_adapter_marker(marked))
        self.assertFalse(fleet.has_launch_adapter_marker(marked.replace('="1"','="0"')))

    def test_source_apk_changed_before_install_blocks_without_mutation(self):
        d = self.device([])
        apk = self.output/'debug.apk'; apk.write_bytes(b'new')
        d.apk_sha256 = fleet.hash_file(apk)
        apk.write_bytes(b'changed')
        with self.assertRaisesRegex(fleet.Blocked,'원본 APK'): d.setup(apk)
        self.assertEqual(self.adb.commands,[])
    def test_source_apk_changed_during_install_blocks_before_launch(self):
        d = self.device([])
        apk = self.output/'debug.apk'; apk.write_bytes(b'before')
        d.apk_sha256 = fleet.hash_file(apk)
        self.adb.inspect = lambda: {}
        self.adb.original_store_hashes = lambda: {}
        self.adb.run = lambda *_args, **_kwargs: apk.write_bytes(b'after')
        with self.assertRaisesRegex(fleet.Blocked,'설치 중'): d.setup(apk)
        self.assertNotIn('launch', self.adb.commands)
    def test_installed_apk_hash_mismatch_blocks(self):
        d = self.device([])
        d.apk_sha256 = 'a'*64
        self.adb.shell = lambda *args, **kwargs: 'package:/data/app/~~build/com.example-ID/base.apk' if args[0]=='pm' else 'b'*64+'  /data/app/~~build/com.example-ID/base.apk'
        with self.assertRaisesRegex(fleet.Blocked,'해시가 다릅니다'): d.verify_installed_apk()
        self.assertEqual(d.apk_identity['installed'],'b'*64)

    def test_attack_family_rejects_swapped_actions(self):
        d = self.device([])
        self.assertTrue(d.attack_family_matches('attack_light','ja-hyun-air-light'))
        self.assertTrue(d.attack_family_matches('attack_heavy','ja-hyun-heavy-side'))
        self.assertTrue(d.attack_family_matches('attack_special','ja-hyun.base-special-side'))
        self.assertFalse(d.attack_family_matches('attack_light','ja-hyun-heavy-side'))
        self.assertFalse(d.attack_family_matches('attack_special','ja-hyun-light-01'))
    def test_missing_ultimate_touch_cannot_pass(self):
        d = self.device([{'touch_events':[],'touch':{'active':[]}}])
        with self.assertRaises(fleet.Failure): d.assert_touch_edges('ultimate',0)
    def test_result_rejects_empty_winner_bad_hash_and_zero_tick(self):
        d = self.device([])
        snapshot = {'fighters':[{'id':'player'}],'mode':3}
        good = {'winner_id':'player','final_tick':1,'snapshot_hash':'a'*64}
        d.validate_result(good,snapshot)
        for edit in ({'winner_id':''},{'winner_id':'unknown'},{'final_tick':0},{'snapshot_hash':'invalid'}):
            with self.assertRaises(fleet.Failure): d.validate_result({**good,**edit},snapshot)
        with self.assertRaises(fleet.Failure): d.validate_result({**good,'winner_slot':0,'reason':'room_closed'},snapshot,lan=True)
    def test_modes_reject_wrong_mode_and_solo_teams(self):
        d = self.device([])
        good = {'mode':1,'fighters':[{'team_id':''} for _ in range(8)]}
        d.validate_mode_snapshot(good,1,8)
        with self.assertRaises(fleet.Failure): d.validate_mode_snapshot({**good,'mode':2},1,8)
        with self.assertRaises(fleet.Failure): d.validate_mode_snapshot({'mode':1,'fighters':[{'team_id':'alpha'} for _ in range(8)]},1,8)

    def test_soak_no_complete_round_is_unexecuted_and_never_suite_pass(self):
        d = self.device([])
        d.prepare = lambda: None
        d.command = lambda *args,**kwargs: None
        d.start_match = lambda: None
        d.assert_config = lambda *_args: None
        def unfinished(**kwargs):
            self.clock.now = 1
            return None
        d.combat_result = unfinished
        d.soak(.5,[{'character':'ja-hyun','accessory':''}])
        self.assertEqual(d.results[-1]['status'],'미실행')
        self.assertEqual(d.combos,[])
        d.mark('DEV-01','pass','observed')
        summary = fleet.write_summary(self.output,'test',{'mode':'soak'},[d],[])
        self.assertEqual(summary['status'],'blocked')

    def test_suite_defaults(self):
        self.assertEqual(fleet.parser().parse_args(['--suite','extended']).mode,'extended')


class AuthFixtureTests(unittest.TestCase):
    def setUp(self): self.api = GuestFixture('127.0.0.1',0,'service')
    def tearDown(self): self.api.server.server_close()
    def request(self, method, path, data=None, token=None, service=None):
        headers = {}
        if token: headers['Authorization'] = 'Bearer '+token
        if service: headers['x-forest-arena-service-token'] = service
        return self.api.route(method,path,headers,data or {})
    def test_guest_nickname_internal_auth_not_bypassed(self):
        status, auth = self.request('POST','/v1/auth/guest')
        self.assertEqual(status,201)
        token = auth['access_token']
        self.assertEqual(self.request('POST','/internal/v1/lan/auth', {'access_token':token}, service='service')[0],409)
        self.assertEqual(self.request('PATCH','/v1/guest/profile', {'nickname':'QA_one'},token)[0],200)
        self.assertEqual(self.request('POST','/internal/v1/lan/auth', {'access_token':token}, service='wrong')[0],401)
        self.assertEqual(self.request('POST','/internal/v1/lan/auth', {'access_token':token}, service='service')[1]['nickname'],'QA_one')
    def test_two_guest_fixtures_do_not_share_credentials(self):
        other = GuestFixture('127.0.0.1',0,'another-service')
        try:
            _, auth = self.request('POST','/v1/auth/guest')
            status, _ = other.route('GET','/v1/guest/profile',{'Authorization':'Bearer '+auth['access_token']},{})
            self.assertEqual(status,401)
            self.assertEqual(other.players,{})
            self.assertNotEqual(self.api.server.server_address[1],other.server.server_address[1])
        finally:
            other.server.server_close()

    def test_rotation_idempotency_and_identity(self):
        _, auth = self.request('POST','/v1/auth/guest')
        data = {'refresh_token':auth['refresh_token'],'next_refresh_token':'next'}
        _, first = self.request('POST','/v1/auth/refresh',data)
        _, repeat = self.request('POST','/v1/auth/refresh',data)
        self.assertEqual(first,repeat)
        self.assertEqual(first['player_id'],auth['player_id'])
        self.assertEqual(self.request('POST','/v1/auth/refresh',{'refresh_token':auth['refresh_token'],'next_refresh_token':'other'})[0],401)
    def test_nickname_validation_and_uniqueness(self):
        _, one = self.request('POST','/v1/auth/guest')
        _, two = self.request('POST','/v1/auth/guest')
        self.assertEqual(self.request('PATCH','/v1/guest/profile', {'nickname':'QA_one'},one['access_token'])[0],200)
        self.assertEqual(self.request('PATCH','/v1/guest/profile', {'nickname':'qa_ONE'},two['access_token'])[0],409)
        self.assertEqual(self.request('PATCH','/v1/guest/profile', {'nickname':' bad'},one['access_token'])[0],400)


if __name__ == '__main__': unittest.main()
