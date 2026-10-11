"""Deterministic host runner tests: no physical-device claims and no waiting."""
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock, patch

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
    def test_combat_negative_stocks_fails_immediately_preserves_actual_snapshot(self):
        state = {'screen':'match', 'snapshot':{'fighters':[{'id':'eliminated','stocks':-1,'state':'FALL','current_hp':0}]}}
        d = self.device([state])
        with self.assertRaisesRegex(fleet.Failure, 'eliminated=-1'):
            d.combat_result()
        self.assertEqual(self.clock.now, 0)
        self.assertEqual(d.case_observations['invalid_combat_state']['snapshot'], state['snapshot'])
        self.assertEqual(d.case_observations['invalid_combat_state']['reason'], 'negative_stocks')
        self.assertTrue(list(self.output.glob('*negative-stocks.json')))
    def test_zero_stocks_dead_is_valid_elimination_not_negative_invariant(self):
        d = self.device([{'screen':'match','snapshot':{'fighters':[{'id':'eliminated','stocks':0,'state':'DEAD','current_hp':0}]}},
                         {'screen':'result','snapshot':{'fighters':[{'id':'player','stocks':1}, {'id':'eliminated','stocks':0,'state':'DEAD'}]},
                          'latest_result':{'winner_id':'player','final_tick':42,'snapshot_hash':'a'*64}}])
        self.assertEqual(d.combat_result()['winner_id'], 'player')
        self.assertNotIn('invalid_combat_state', d.case_observations)

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
    def test_websocket_handshake_eof_fails_immediately(self):
        sock = Mock()
        sock.recv.return_value = b''
        with self.assertRaisesRegex(fleet.Failure,'응답 전 종료'):
            fleet._websocket_upgrade(sock,b'request',clock=lambda: 0)
        sock.recv.assert_called_once()
    def test_websocket_handshake_has_total_deadline(self):
        sock = Mock()
        sock.recv.return_value = b'partial'
        with self.assertRaisesRegex(fleet.Failure,'시간 초과'):
            fleet._websocket_upgrade(sock,b'request',clock=iter([0,0,11]).__next__)
        sock.recv.assert_called_once()
    def test_websocket_handshake_limits_header_bytes(self):
        sock = Mock()
        sock.recv.return_value = b'a'*4096
        with self.assertRaisesRegex(fleet.Failure,'크기 오류'):
            fleet._websocket_upgrade(sock,b'request',clock=lambda: 0)
        self.assertEqual(sock.recv.call_count,5)
    def test_websocket_handshake_checks_cancellation(self):
        sock = Mock()
        with patch.object(fleet.CANCELLED,'is_set',return_value=True):
            with self.assertRaises(fleet.Blocked): fleet._websocket_upgrade(sock,b'request')
        sock.recv.assert_not_called()
    def test_websocket_handshake_preserves_appended_frame(self):
        sock = Mock()
        sock.recv.return_value = b'HTTP/1.1 101 Switching Protocols\r\n\r\nframe'
        self.assertEqual(fleet._websocket_upgrade(sock,b'request'),'frame'.encode())
    def test_logcat_failure_records_unavailability_and_stderr(self):
        d = self.device([])
        self.adb.shell = lambda *_args,**_kwargs: 'package:com.example.game uid:123'
        process = Mock(returncode=1)
        process.poll.return_value = 1
        def failed_logcat(*_args,**kwargs):
            kwargs['stderr'].write(b'logcat: unsupported --uid argument')
            return process
        self.adb.run = Mock(return_value=b'--uid UID filter')
        with patch.object(fleet.subprocess,'Popen',side_effect=failed_logcat): d.start_logcat()
        d.close()
        evidence = json.loads((self.output/'game-log.json').read_text())
        self.assertEqual(evidence['status'],'unavailable')
        self.assertEqual(evidence['exit_status'],1)
        self.assertIn('unsupported --uid',evidence['stderr'])
        self.assertEqual(evidence['stdout_bytes'],0)
        self.assertFalse(evidence['running_until_cleanup'])
        self.assertFalse((self.output/'game-log-stderr.raw').exists())
    def test_android11_pid_log_filter_follows_cold_launches(self):
        d = self.device([])
        self.adb.run = Mock(return_value=b'--pid PID filter')
        self.adb.shell = Mock(side_effect=['package:com.example.game uid:123', '101', '202'])
        first, second = Mock(), Mock()
        first.poll.return_value = None
        second.poll.return_value = None
        with patch.object(fleet.subprocess, 'Popen', side_effect=[first, second]) as spawn:
            d.start_logcat()
            spawn.assert_not_called()
            d.state = {'boot_id': 'one'}
            d._start_pid_logcat()
            d.state = {'boot_id': 'two'}
            d._start_pid_logcat()
        first.terminate.assert_called_once()
        first.wait.assert_called_once()
        arguments = [call.args[0] for call in spawn.call_args_list]
        self.assertIn('--pid=101', arguments[0])
        self.assertIn('--pid=202', arguments[1])
        self.assertEqual([x['boot_id'] for x in d.game_log['segments']], ['one', 'two'])
        d.logfile.close()
        d.logstderr.close()
    def test_current_accessory_runtime_ratios_and_replacements(self):
        base = {'max_hp': 100, 'weight': 100, 'ground_speed': 200, 'air_speed': 150,
                'jump_velocity': -500, 'gravity': 1000, 'dash_speed': 300, 'air_jump_count': 1}
        policy = {'': {}, 'fixture-boxing-gloves': {},
                  'fixture-iron-armor': {'weight': 1.05, 'ground_speed': .95},
                  'fixture-thorns': {'air_speed': 1.05, 'ground_speed': .95},
                  'fixture-explosive-gloves': {'jump_velocity': 1.05, 'weight': .95},
                  'fixture-phoenix-revive': {'gravity': .95, 'air_speed': .95},
                  'fixture-ultimate-charm': {'ground_speed': .95}}
        for accessory, ratios in policy.items():
            profile = {'base_stats': base, 'stats': {k: v*ratios.get(k, 1) for k, v in base.items()},
                       'move_set_id': 'yu-ran.base', 'replacement_move_set': 'yu-ran.base',
                       'attack_ids': ['yu-ran-light-01'],
                       'combat_effects': [{'cause_id': accessory, 'kind': 3, 'trigger': 2, 'amount': 4}]}
            observed = fleet.DeviceRun.validate_current_profile({'runtime_profile': profile}, accessory)
            self.assertEqual(observed['actual_effect_trigger'], '미실행: 별도 전투 동작 검사')
            profile['stats'] = {**profile['stats'], 'max_hp': 105}
            with self.assertRaises(fleet.Failure):
                fleet.DeviceRun.validate_current_profile({'runtime_profile': profile}, accessory)
    def test_boxing_accepts_canonical_special_ids_rejects_other_characters(self):
        profile = {'base_stats': {'weight': 100}, 'stats': {'weight': 100},
                   'move_set_id': 'yu-ran.base', 'replacement_move_set': 'yu-ran.base',
                   'attack_ids': ['yu-ran-light-01', 'yu-ran.base-special-side', 'yu-ran.base-special-down', 'yu-ran.base-ultimate']}
        fleet.DeviceRun.validate_current_profile({'runtime_profile': profile}, 'fixture-boxing-gloves')
        for invalid in ('ja-hyun-light-01', 'nabi.base-special-down', 'yu-ranx-ultimate', 'yu-ran.baseX-ultimate'):
            profile['attack_ids'] = ['yu-ran-light-01', invalid]
            with self.assertRaises(fleet.Failure):
                fleet.DeviceRun.validate_current_profile({'runtime_profile': profile}, 'fixture-boxing-gloves')

    def test_current_boxing_and_ultimate_effect_reject_old_bonus_contract(self):
        profile = {'base_stats': {'weight': 100}, 'stats': {'weight': 100},
                   'move_set_id': 'ja-hyun.base', 'replacement_move_set': '', 'attack_ids': ['ja-hyun-light-01']}
        with self.assertRaises(fleet.Failure):
            fleet.DeviceRun.validate_current_profile({'runtime_profile': profile}, 'fixture-boxing-gloves')
        profile['combat_effects'] = [{'cause_id': 'fixture-ultimate-charm', 'kind': 3, 'trigger': 2, 'amount': 6}]
        with self.assertRaises(fleet.Failure):
            fleet.DeviceRun.validate_current_profile({'runtime_profile': profile}, 'fixture-ultimate-charm')

    def test_positive_evade_requires_both_actual_touch_edges_and_evasion(self):
        d = self.device([])
        d.touch_helper = self.output/'helper.jar'
        d.command = Mock()
        before = {'snapshot': {'fighters': [{'id': 'player', 'state': 'IDLE'}]}, 'touch_events': [], 'combat_events': []}
        after = {**before, 'touch': {'active': []}, 'combat_events': [{'id': 'fighter_state', 'fighter_id': 'player', 'seq': 1, 'state': 'EVADE'}]}
        def wait(predicate, **_args):
            state = before if not d.state else after
            self.assertTrue(predicate(state))
            d.state = state
            return state
        d.wait = wait
        d.node = Mock(side_effect=[{'x':.1,'y':.8}, {'x':.8,'y':.8}])
        d.center = Mock(side_effect=[(100,800), (800,800)])
        d.assert_touch_edges = Mock()
        with patch('android_touch.perform', return_value={'source': 'adb_touch_multi_pointer'}) as perform:
            observed = d.positive_evade()
        perform.assert_called_once_with(self.adb, d.touch_helper, (100,800), (800,800))
        self.assertEqual([call.args[0] for call in d.assert_touch_edges.call_args_list], ['move_right','evade'])
        self.assertEqual(observed['combat_state'], 'EVADE')
        self.assertIn('미실행', observed['human_multitouch_quality'])

    def test_manual_pending_preserves_measured_subchecks(self):
        d = self.device([])
        observed = {'actions': ['jump'], 'ultimate_after_ready': True, 'evade_positive': '미실행'}
        def measured():
            raise fleet.ManualPending('동시 터치 수동 검사 필요', observed)
        self.assertEqual(d.case('INPUT-01', measured), 'blocked')
        self.assertEqual(d.results[-1]['observed'], observed)
    def test_recoverable_case_failure_continues_independent_cases(self):
        d = Mock()
        d.output = self.output
        d.case.side_effect = ['pass', 'pass', 'pass', 'blocked', 'pass', 'pass', 'pass']
        self.assertTrue(fleet.offline(d, Path('game.apk'), 'soak', 600, []))
        self.assertEqual(d.prepare.call_count, 2)
        d.soak.assert_called_once_with(600, [])
        d.mark.assert_not_called()
        self.assertEqual([call.args[0] for call in d.case.call_args_list], ['DEV-01', 'UI-01', 'OFF-01', 'INPUT-01', 'LIFE-01', 'OFF-02', 'MODE-01'])
    def test_failed_soak_can_recover_to_home_for_independent_lan(self):
        d = Mock()
        d.output = self.output
        d.case.return_value = 'pass'
        # DeviceRun.soak writes its own failed case and returns normally.
        d.soak.return_value = None
        self.assertTrue(fleet.offline(d, Path('game.apk'), 'soak', 600, []))
        d.command.assert_called_once_with('autoplay', enabled=False)
        d.prepare.assert_called_once()
        d.tap.assert_called_once_with('로비')
        d.screen.assert_called_once_with('home')
        self.assertTrue(json.loads((self.output/'offline-cleanup.json').read_text())['lan_eligible'])
    def test_soak_cleanup_failure_prevents_lan_without_promoting_case(self):
        d = Mock()
        d.output = self.output
        d.case.return_value = 'pass'
        d.command.side_effect = fleet.Blocked('ADB 단절')
        self.assertFalse(fleet.offline(d, Path('game.apk'), 'soak', 600, []))
        evidence = json.loads((self.output/'offline-cleanup.json').read_text())
        self.assertFalse(evidence['lan_eligible'])
        d.mark.assert_not_called()
    def test_off_selection_only_recheck_has_fresh_prerequisites_and_unexecuted_other_cases(self):
        d = Mock()
        d.case.return_value = 'pass'
        self.assertTrue(fleet.offline(d, Path('game.apk'), 'smoke', 0, [], selected_case='OFF-01'))
        self.assertEqual([call.args[0] for call in d.case.call_args_list], ['DEV-01', 'UI-01', 'OFF-01'])
        d.soak.assert_not_called()
        marks = [(call.args[0], call.args[1]) for call in d.mark.call_args_list]
        self.assertEqual(marks, [(case, '미실행') for case in fleet.CASES if case not in ('DEV-01', 'UI-01', 'OFF-01')])
    def test_runner_source_archive_hashes_remain_immutable_after_tools_change(self):
        source = self.output/'tools'
        source.mkdir()
        known = ['android_fleet.py', 'android_touch.py', 'android_fleet_touch/FleetTouch.java', 'android_fleet_auth_fixture.py']
        for name in known:
            target = source/name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text('original '+name)
        (source/'debug.keystore').write_text('private key')
        (source/'auth.env').write_text('private token')
        archive = self.output/'attempt-one'
        metadata = fleet.archive_runner_sources(archive, include_auth=True, source_root=source)
        for name in known:
            original_hash = fleet.hash_file(archive/'runner-source'/name)
            self.assertEqual(metadata['runner_source_files'][name], original_hash)
            (source/name).write_text('changed after launch')
            self.assertEqual(fleet.hash_file(archive/'runner-source'/name), original_hash)
        self.assertTrue((archive/'runner-source/.gdignore').exists())
        self.assertFalse((archive/'runner-source/debug.keystore').exists())
        self.assertFalse((archive/'runner-source/auth.env').exists())
        self.assertEqual(metadata['runner_tool_sha256'], metadata['runner_source_files']['android_fleet.py'])
        second = fleet.archive_runner_sources(self.output/'attempt-two', include_auth=False, source_root=source)
        self.assertNotIn('android_fleet_auth_fixture.py', second['runner_source_files'])
        self.assertNotEqual(metadata['runner_source_sha256'], second['runner_source_sha256'])
        with self.assertRaises(FileExistsError): fleet.archive_runner_sources(archive, source_root=source)

    def setup_mode_device(self, combat_failure=None, recovery_failure=False):
        d = self.device([])
        d.selected_mode = None
        d.attempted = []
        def command(op, **args):
            if op == 'select_config':
                mode = args['mode']
                d.selected_mode = mode
                d.attempted.append(mode)
                teams = ['alpha']*4+['beta']*4 if mode == 2 else ['']*(8 if mode == 1 else 2)
                d.state = {'screen': 'match', 'touch': {'active': []},
                           'snapshot': {'mode': mode, 'fighters': [{'id': str(i), 'team_id': team} for i,team in enumerate(teams)]}}
        def prepare():
            if recovery_failure and d.selected_mode == 1:
                raise fleet.Blocked('복귀 중 ADB 단절')
            d.state['screen'] = 'prepare'
        def result():
            if d.selected_mode == combat_failure:
                raise fleet.Failure('전투가 300초 안에 끝나지 않았습니다.')
            return {'winner_id': '0', 'winner_team_id': 'alpha' if d.selected_mode == 2 else ''}
        d.command = command
        d.prepare = prepare
        d.start_match = Mock()
        d.combat_result = result
        d.evidence = Mock()
        d.read = lambda: d.state
        return d
    def test_mode_solo_failure_preserves_observation_and_still_checks_team_story(self):
        d = self.setup_mode_device(combat_failure=1)
        self.assertEqual(d.case('MODE-01', d.modes), 'fail')
        self.assertEqual(d.attempted, [4,1,2,0])
        subcases = d.results[-1]['observed']['modes']
        self.assertEqual([r['status'] for r in subcases], ['pass','fail','pass','pass'])
        self.assertEqual(subcases[1]['observed']['initial_snapshot']['mode'], 1)
        self.assertIn('last_snapshot', subcases[1]['observed'])
        self.assertTrue(subcases[2]['observed']['return_to_prepare'])
        self.assertTrue(subcases[3]['observed']['entry'])
        self.assertNotIn('result', subcases[3]['observed'])
        for record in subcases:
            for key in ('schema_version','run_id','case_id','mode_case_id','device','step','expected','observed'):
                self.assertIn(key, record)
        self.assertEqual(json.loads((self.output/'mode-results.json').read_text())['modes'][1]['status'], 'fail')
    def test_modes_block_later_cases_only_when_recovery_fails(self):
        d = self.setup_mode_device(combat_failure=1, recovery_failure=True)
        self.assertEqual(d.case('MODE-01', d.modes), 'fail')
        self.assertEqual(d.attempted, [4,1])
        subcases = d.results[-1]['observed']['modes']
        self.assertEqual([r['status'] for r in subcases], ['pass','fail','blocked','blocked'])
        self.assertIn('recovery', subcases[1]['observed'])
    def test_modes_pass_requires_all_subcases_and_return_input_release(self):
        d = self.setup_mode_device()
        self.assertEqual(d.case('MODE-01', d.modes), 'pass')
        self.assertEqual([r['status'] for r in d.results[-1]['observed']['modes']], ['pass']*4)
    def test_mode_only_recheck_has_prerequisites_and_no_lan_or_soak(self):
        d = Mock()
        d.case.return_value = 'pass'
        self.assertTrue(fleet.offline(d, Path('game.apk'), 'smoke', 0, [], selected_case='MODE-01'))
        self.assertEqual([call.args[0] for call in d.case.call_args_list], ['DEV-01','UI-01','MODE-01'])
        d.soak.assert_not_called()
        marks = {call.args[0]: call.args[1] for call in d.mark.call_args_list}
        self.assertEqual(marks['LAN-01'], '미실행')
        self.assertEqual(marks['SOAK-01'], '미실행')
        self.assertEqual(fleet.parser().parse_args(['--case','MODE-01']).case, 'MODE-01')

    def test_soak_only_scope_runs_preparation_positive_duration_and_input_cleanup(self):
        d = Mock()
        d.output = self.output
        d.case.return_value = 'pass'
        d.read.return_value = {'screen':'match'}
        jobs = [{'character':'ja-hyun','accessory':''}]
        self.assertTrue(fleet.offline(d, Path('game.apk'), 'soak', 600, jobs, selected_case='SOAK-01'))
        self.assertEqual([call.args[0] for call in d.case.call_args_list], ['DEV-01','UI-01'])
        d.soak.assert_called_once_with(600,jobs)
        d.command.assert_called_once_with('autoplay',enabled=False)
        d.prepare.assert_called_once()
        d.tap.assert_called_once_with('로비')
        d.screen.assert_called_once_with('home')
        marks = {call.args[0]:call.args[1] for call in d.mark.call_args_list}
        self.assertNotIn('SOAK-01',marks)
        self.assertEqual(marks['MODE-01'],'미실행')
        self.assertEqual(marks['LAN-01'],'미실행')
    def test_selected_soak_failed_prerequisites_always_record_soak_blocked(self):
        for statuses in (['blocked'],['pass','fail']):
            d = Mock()
            d.case.side_effect = statuses
            self.assertFalse(fleet.offline(d,Path('game.apk'),'soak',600,[],selected_case='SOAK-01'))
            d.soak.assert_not_called()
            d.command.assert_not_called()  # Failed UI prerequisites cannot be promoted by screen recovery.
            marks = {call.args[0]:call.args[1] for call in d.mark.call_args_list}
            self.assertEqual(marks['SOAK-01'],'blocked')
            self.assertEqual(marks['LAN-01'],'미실행')
            self.assertEqual(marks['MODE-01'],'미실행')
    def test_selected_soak_failed_cleanup_is_not_promoted_to_completion(self):
        d = Mock()
        d.output = self.output
        d.case.return_value = 'pass'
        d.command.side_effect = fleet.Blocked('ADB 단절')
        self.assertFalse(fleet.offline(d,Path('game.apk'),'soak',600,[],selected_case='SOAK-01'))
        d.soak.assert_called_once_with(600,[])
        self.assertFalse(json.loads((self.output/'offline-cleanup.json').read_text())['lan_eligible'])
        self.assertTrue(any(call.args[0]=='SOAK-01' and call.args[1]=='blocked' for call in d.mark.call_args_list))
    def test_selected_soak_duration_defaults_and_smoke_recheck_limits(self):
        parse = fleet.parser()
        for mode,seconds in (('soak',600),('extended',1800)):
            self.assertEqual(fleet.execution_duration(parse.parse_args(['--case','SOAK-01','--suite',mode])),seconds)
        self.assertEqual(fleet.execution_duration(parse.parse_args(['--case','SOAK-01','--suite','soak','--duration','30'])),30)
        for argv in (['--case','SOAK-01'], ['--case','SOAK-01','--duration','600'],
                     ['--case','SOAK-01','--suite','soak','--duration','0'],
                     ['--case','SOAK-01','--suite','extended','--duration','-1'],
                     ['--case','SOAK-01','--suite','soak','--duration','nan'],
                     ['--case','SOAK-01','--suite','soak','--duration','inf']):
            with self.assertRaises(ValueError): fleet.execution_duration(parse.parse_args(argv))
        for case in ('OFF-01','LIFE-01','MODE-01','LAN-01'):
            self.assertEqual(fleet.execution_duration(parse.parse_args(['--case',case,'--suite','smoke'])),0)
            for extra in (['--suite','soak'],['--duration','1']):
                with self.assertRaises(ValueError): fleet.execution_duration(parse.parse_args(['--case',case]+extra))
    def test_selected_soak_main_never_starts_lan_even_with_explicit_bind(self):
        d = Mock()
        d.output = self.output/'fake-device'
        d.output.mkdir()
        d.alias = 'device-1'
        d.results,d.combos = [],[]
        d.read.return_value = {'screen':'home'}
        def mark(case,status,message):
            d.results.append({'case_id':case,'status':status,'message':message})
        def case(case_id,*_args):
            mark(case_id,'pass','fake unit observation')
            return 'pass'
        d.mark.side_effect = mark
        d.case.side_effect = case
        d.soak.side_effect = lambda *_args: mark('SOAK-01','pass','fake unit round')
        with patch.object(fleet,'run_process') as process, patch.object(fleet,'inspect_apk',return_value={'package':'com.example','activity':'Game'}), \
             patch.object(fleet,'ADB') as adb, patch.object(fleet,'DeviceRun',return_value=d), patch.object(fleet,'LanServer') as server:
            process.return_value.stdout = b'head'
            adb.return_value.inspect.return_value = {'ro.serialno':'physical-one'}
            result = fleet.main(['--case','SOAK-01','--suite','soak','--serial','one',
                                 '--lan-bind','192.168.1.2','--output',str(self.output/'runs')])
        self.assertEqual(result,0)
        server.assert_not_called()
        d.soak.assert_called_once()
        self.assertEqual(d.soak.call_args.args[0],600)
        artifact = json.loads(next((self.output/'runs').glob('*/results.json')).read_text())
        self.assertFalse(artifact['summary']['full_suite_executed'])
        self.assertIn('SOAK-01',artifact['summary']['scope'])
        self.assertTrue(all(r['status']=='미실행' for r in artifact['cases'] if r['case_id'].startswith('LAN-')))
    def test_selected_soak_preflight_error_records_unstarted_soak_blocked(self):
        with patch.object(fleet,'run_process') as process, patch.object(fleet,'inspect_apk',side_effect=fleet.Blocked('APK 검사 불가')):
            process.return_value.stdout = b'head'
            result = fleet.main(['--case','SOAK-01','--suite','extended','--serial','one','--output',str(self.output)])
        self.assertEqual(result,2)
        artifact = json.loads(next(self.output.glob('*/results.json')).read_text())
        self.assertEqual(artifact['metadata']['duration_seconds'],1800)
        self.assertTrue(any(r['case_id']=='SOAK-01' and r['status']=='blocked' for r in artifact['cases']))
        self.assertFalse(artifact['summary']['full_suite_executed'])

    def test_lan_recheck_runs_only_dev_ui_and_verifies_home_entry(self):
        d = Mock()
        d.output = self.output
        d.case.return_value = 'pass'
        d.read.return_value = {'screen': 'home'}
        self.assertTrue(fleet.offline(d, Path('game.apk'), 'smoke', 0, [], selected_case='LAN-01'))
        self.assertEqual([call.args[0] for call in d.case.call_args_list], ['DEV-01', 'UI-01'])
        d.soak.assert_not_called()
        d.prepare.assert_not_called()
        d.screen.assert_called_once_with('home')
        marks = {call.args[0]: call.args[1] for call in d.mark.call_args_list}
        self.assertEqual(marks['OFF-01'], '미실행')
        self.assertEqual(marks['SOAK-01'], '미실행')
        self.assertNotIn('LAN-01', marks)
        self.assertNotIn('LAN-02', marks)
        self.assertNotIn('LAN-03', marks)
    def test_lan_recheck_summary_preserves_error_case_results(self):
        d = self.device([])
        for case in ('DEV-01', 'UI-01', 'LAN-01', 'LAN-03'):
            d.mark(case, 'pass', 'observed')
        d.mark('LAN-02', 'fail', 'actual error UI mismatch')
        summary = fleet.write_summary(self.output, 'test', {'selected_case': 'LAN-01'}, [d], [])
        self.assertEqual(summary['status'], 'fail')
        self.assertIn('LAN-01/02/03', summary['scope'])
        self.assertFalse(summary['full_suite_executed'])
        self.assertIn('actual error UI mismatch', (self.output/'summary.md').read_text())
    def test_lan_pair_does_not_enter_ui_before_both_apps_recovered_home(self):
        host, guest, server = Mock(), Mock(), Mock()
        host.read.return_value = {'screen': 'home'}
        guest.read.return_value = {'screen': 'match'}
        with patch.object(fleet, '_lan_login') as login, self.assertRaises(fleet.Blocked):
            fleet._pair_join(host, guest, server)
        login.assert_not_called()
        host.tap.assert_not_called()
        guest.tap.assert_not_called()

    def test_failed_selected_setup_keeps_unselected_cases_unexecuted(self):
        d = Mock()
        d.case.return_value = 'blocked'
        self.assertFalse(fleet.offline(d, Path('game.apk'), 'smoke', 0, [], selected_case='OFF-01'))
        marks = {call.args[0]: call.args[1] for call in d.mark.call_args_list}
        self.assertEqual(marks['OFF-01'], 'blocked')
        self.assertEqual(marks['SOAK-01'], '미실행')
        self.assertEqual(marks['LAN-01'], '미실행')
    def test_selected_case_summary_labels_limited_scope(self):
        d = self.device([])
        for case in ('DEV-01', 'UI-01', 'OFF-01'):
            d.mark(case, 'pass', 'observed')
        summary = fleet.write_summary(self.output, 'test', {'selected_case': 'OFF-01'}, [d], [])
        self.assertEqual(summary['status'], 'pass')
        self.assertFalse(summary['full_suite_executed'])
        self.assertIn('독립 재검사', summary['scope'])
        self.assertIn('다른 사례의 통과를 뜻하지 않습니다', (self.output/'summary.md').read_text())

    def test_recheck_rejects_soak_time_before_device_operations(self):
        with patch('sys.stderr'), self.assertRaises(SystemExit):
            fleet.main(['--case', 'OFF-01', '--suite', 'soak'])
        self.assertEqual(fleet.parser().parse_args(['--case', 'OFF-01']).case, 'OFF-01')

    def test_failed_recovery_blocks_later_observations(self):
        d = Mock()
        d.case.side_effect = ['pass', 'fail']
        d.command.side_effect = fleet.Blocked('연결 단절')
        self.assertFalse(fleet.offline(d, Path('game.apk'), 'soak', 600, []))
        d.soak.assert_not_called()
        self.assertIn('SOAK-01', [call.args[0] for call in d.mark.call_args_list])
    def test_v1_server_uses_snapshot_without_api_fixture_or_credentials(self):
        server = fleet.LanServer('192.168.1.2', '192.168.1.0/24', 7777, 8888, self.output, 'godot', 'run', '/tmp/snapshot', 1)
        process = Mock()
        process.poll.return_value = None
        def start(args, **kwargs):
            kwargs['stdout'].write(b'FOREST_ARENA_LAN_READY FAH1|ws://192.168.1.2:7777|1\n')
            kwargs['stdout'].flush()
            return process
        with patch.object(fleet.subprocess, 'Popen', side_effect=start) as spawn, \
             patch.dict(fleet.os.environ, {'FOREST_ARENA_SERVICE_TOKEN': 'external', 'FOREST_ARENA_API_BASE_URL': 'external'}), \
             patch('android_fleet_auth_fixture.GuestFixture') as fixture:
            server.start()
        fixture.assert_not_called()
        self.assertEqual(spawn.call_args.args[0][3], '/tmp/snapshot')
        self.assertNotIn('FOREST_ARENA_SERVICE_TOKEN', spawn.call_args.kwargs['env'])
        self.assertNotIn('FOREST_ARENA_API_BASE_URL', spawn.call_args.kwargs['env'])
        server.stream.close()
    def test_protocol_peer_handles_godot_id_ping_mask_and_cleanup(self):
        server = Mock(protocol=1,bind='127.0.0.1',port=1)
        sock = Mock()
        message = json.dumps({'type':'joined','slot':2}).encode()
        key = b'1234'
        masked = bytes(value^key[i%4] for i,value in enumerate(message))
        frames = b'\x82\x04ID42'+b'\x89\x01P'+bytes([0x82,0x80|len(masked)])+key+masked
        with patch.object(fleet.socket,'create_connection',return_value=sock), patch.object(fleet,'_websocket_upgrade',return_value=frames):
            peer = fleet.ProtocolPeer(server)
        self.assertEqual(peer.receive_until(lambda m:m.get('type')=='joined')['slot'],2)
        pong = sock.sendall.call_args.args[0]
        self.assertEqual(pong[0],0x8a)
        self.assertTrue(pong[1]&0x80)
        peer.close()
        peer.close()
        sock.close.assert_called_once()
    def test_protocol_peer_eof_oversize_and_cancel_are_bounded(self):
        server = Mock(protocol=1,bind='127.0.0.1',port=1)
        for frame in (b'\x82\x7e\x20\x01', b'\x88\x00'):
            sock = Mock()
            with patch.object(fleet.socket,'create_connection',return_value=sock), patch.object(fleet,'_websocket_upgrade',return_value=frame):
                peer = fleet.ProtocolPeer(server)
            with self.assertRaises(fleet.Failure): peer.receive_until(lambda _m:False)
            peer.close()
        sock = Mock()
        sock.recv.return_value = b''
        with patch.object(fleet.socket,'create_connection',return_value=sock), patch.object(fleet,'_websocket_upgrade',return_value=b''):
            peer = fleet.ProtocolPeer(server)
        with self.assertRaisesRegex(fleet.Failure,'socket 종료'): peer.receive_until(lambda _m:False)
        with patch.object(fleet.CANCELLED,'is_set',return_value=True), self.assertRaises(fleet.Blocked):
            peer.receive_until(lambda _m:False)
        peer.close()
    def test_capacity_guest_occupies_only_slot2_and_closes_after_error(self):
        server = Mock(protocol=2)
        peer = Mock()
        peer.receive_until.side_effect = [{'type':'joined','slot':2,'reconnect_token':'private'}, {'type':'match_start','slot':2}, {'type':'match_end'}]
        with patch.object(fleet,'_protocol_auth',return_value={'access_token':'private'}), patch.object(fleet,'ProtocolPeer',return_value=peer):
            guest = fleet.CapacityGuest(server,'FA2|http://127.0.0.1:1|ws://127.0.0.1:2|ABCDEFGH|2').start()
        self.assertEqual(guest.observed['slot'],2)
        self.assertEqual(peer.send.call_args_list[0].args[0]['selection']['schema_version'],1)
        self.assertFalse(guest.observed['actual_apk'])
        self.assertFalse(guest.observed['combat_input_sent'])
        self.assertNotIn('private',json.dumps(guest.observed))
        guest.close()
        self.assertEqual([call.args[0]['type'] for call in peer.send.call_args_list],['join_room','leave'])
        peer.close.assert_called_once()
        rejected = Mock()
        rejected.receive_until.return_value = {'type':'error','code':'room_full'}
        with patch.object(fleet,'_protocol_auth',return_value={}), patch.object(fleet,'ProtocolPeer',return_value=rejected):
            fixture = fleet.CapacityGuest(Mock(protocol=1),'FA1|ws://127.0.0.1:1|ABCDEFGH|1')
            with self.assertRaises(fleet.Failure): fixture.start()
        rejected.close.assert_called_once()
    def room_full_ui_devices(self, show_error=True):
        host,guest = Mock(),Mock()
        events = []
        for alias,device in (('host-apk',host),('guest-apk',guest)):
            device.alias = alias
            device.state = {'screen':'lan_menu','match_generation':4,'touch':{'active':[]},'boot_id':alias+'-boot','msec':100,'foreground':True}
            device.node.return_value = {'id':'lan-input'}
            device.read.side_effect = lambda d=device:d.state
            def screen(expected,d=device):
                self.assertEqual(d.state['screen'],expected)
                return d.state
            device.screen.side_effect = screen
            def wait(predicate,d=device,**_kwargs):
                self.assertTrue(predicate(d.state))
                return d.state
            device.wait.side_effect = wait
            def tap(text,d=device):
                events.append((d.alias,text))
                d.state = {**d.state,'msec':d.state['msec']+300}
                if text=='방 만들기': d.state['screen']='lan_host'
                elif text=='초대 코드로 참가': d.state['screen']='lan_join'
                elif text=='방 생성': d.state.update(screen='lan_waiting',lan_invite='FA1|ws://127.0.0.1:1|ABCDEFGH|1')
                elif text=='방 참가':
                    d.state.update(screen='lan_menu',last_lan_error='room_full',ui=[{'text':'LAN 연결 실패: 방이 가득 참' if show_error else 'unrelated text'}])
                elif text=='대전 나가기': d.state['screen']='lan_leave_confirm' if d.state['screen']=='lan_match' else 'lan_menu'
                elif text=='방 닫기': d.state['screen']='lan_menu'
                return d.state
            device.tap.side_effect = tap
            device.assert_released = Mock(side_effect=lambda state,*_args:fleet.DeviceRun.assert_released(state))
        host.wait_new_match.side_effect = lambda *_args,**_kwargs: host.state.update(screen='lan_match')
        return host,guest,events
    def test_full_room_case_uses_actual_other_apk_join_ui_and_menu_return(self):
        host,guest,events = self.room_full_ui_devices()
        server = Mock(protocol=1,code='FAH1|ws://127.0.0.1:1|1')
        fixture = Mock(observed={'source':'protocol_capacity_fixture','slot':2,'actual_apk':False,'combat_input_sent':False})
        with patch.object(fleet,'CapacityGuest',return_value=fixture):
            observed = fleet._room_full_apk_ui(host,guest,server)
        self.assertIn(('host-apk','방 생성'),events)
        self.assertIn(('guest-apk','방 참가'),events)
        self.assertEqual(guest.state['screen'],'lan_menu')
        self.assertEqual(host.state['screen'],'lan_menu')
        self.assertEqual(observed['actual_error_ui_device'],'guest-apk')
        self.assertEqual(observed['error'],'room_full')
        self.assertEqual(observed['error_event'],'room_full')
        self.assertEqual(observed['status'],'blocked')
        self.assertEqual(observed['error_event_status'],'pass')
        self.assertEqual(observed['menu_return_status'],'pass')
        self.assertEqual(observed['error_notice_visual']['reason'],'ManualPending')
        self.assertIn('미확인',observed['actual_error_text_visual'])
        self.assertFalse(observed['capacity_fixture']['actual_apk'])
        self.assertEqual(guest.command.call_args_list[-1].kwargs['value'],'FA1|ws://127.0.0.1:1|ABCDEFGH|1')
        fixture.close.assert_called_once()
    def test_full_room_frozen_label_omission_preserves_error_capture_before_menu(self):
        host,guest,_events = self.room_full_ui_devices(show_error=False)
        fixture = Mock()
        captures = []
        guest.evidence.side_effect = lambda label:captures.append((label,dict(guest.state)))
        with patch.object(fleet,'CapacityGuest',return_value=fixture):
            observed = fleet._room_full_apk_ui(host,guest,Mock(protocol=1,code='FAH1|ws://127.0.0.1:1|1'))
        self.assertIn('미확인',observed['actual_error_text_visual'])
        self.assertEqual(captures[0][0],'room-full-error-event')
        self.assertEqual(captures[0][1]['last_lan_error'],'room_full')
        self.assertEqual(captures[0][1]['ui'][0]['text'],'unrelated text')
        fixture.close.assert_called_once()
        self.assertEqual(host.state['screen'],'lan_menu')

    @staticmethod
    def lan_motion(msec,tick,state='RUN',x=20,vx=150,**changes):
        value = {'boot_id':'lan-boot','msec':msec,'foreground':True,'screen':'lan_match',
                 'connected':True,'peer_connected':True,'reconnecting':False,'lan_slot':1,
                 'match_generation':4,'autocontrol':True,'touch':{'active':[]},'snapshot':{'tick':tick,'fighters':[
                     {'id':'lan_host','state':state,'position':{'x':x,'y':100},'velocity':{'x':vx,'y':0},
                      'current_hp':100,'stocks':3,'input_direction':0}]}}
        value.update(changes)
        return value

    def motion_device(self,states):
        d = self.device(states)
        d.command = Mock(return_value=self.lan_motion(101,11,state='IDLE',x=0,vx=0,autocontrol=False))
        d.case_id = 'LAN-03'
        return d

    def test_lan_before_interrupt_requires_new_neutral_then_two_run_positions_not_renderer_input(self):
        d = self.motion_device([self.lan_motion(100,10,state='IDLE',x=0,vx=0,autocontrol=False),
                                self.lan_motion(101,11,state='IDLE',x=0,vx=0,autocontrol=False),
                                self.lan_motion(102,12,x=1),self.lan_motion(103,13,x=3)])
        result = fleet._lan_before_interrupt(d,10,timeout=1)
        self.assertEqual(result['movement'],'pass')
        self.assertEqual([s['tick'] for s in result['samples']],[12,13])
        self.assertFalse(result['renderer_input_direction_used'])
        self.assertIn('미확인',result['server_nonzero_input'])
        self.assertEqual(d.command.call_args_list[0].kwargs,{'enabled':False})
        self.assertEqual(d.command.call_args_list[1].kwargs,{'enabled':True})
        self.assertTrue(list(self.output.glob('*debug-movement.json')))

    def test_lan_before_interrupt_rejects_stale_background_new_boot_result_and_knockback(self):
        invalid = [self.lan_motion(102,12,state='HITSTUN'), self.lan_motion(101,12),
                   self.lan_motion(102,11), self.lan_motion(102,12,foreground=False),
                   self.lan_motion(102,12,boot_id='another-boot'), self.lan_motion(102,12,screen='lan_result'),
                   self.lan_motion(102,12,connected=False),self.lan_motion(102,12,match_generation=5)]
        for state in invalid:
            with self.subTest(state=state):
                d = self.motion_device([self.lan_motion(100,10,state='IDLE',x=0,vx=0,autocontrol=False),
                                        self.lan_motion(101,11,state='IDLE',x=0,vx=0,autocontrol=False),state])
                with self.assertRaisesRegex(fleet.Blocked,'이동 미확인'):
                    fleet._lan_before_interrupt(d,65,timeout=.3)
                self.assertEqual(d.command.call_args_list[-1].kwargs,{'enabled':False})
                self.assertEqual(d.case_observations['before_interrupt_65']['movement'],'미확인')

    def test_lan_movement_duplicate_sample_and_unchanged_position_do_not_pass(self):
        for last in (self.lan_motion(102,12,x=1),self.lan_motion(103,13,x=1),self.lan_motion(103,13,x=0,vx=-150)):
            with self.subTest(last=last):
                d = self.motion_device([self.lan_motion(100,10,state='IDLE',x=0,vx=0,autocontrol=False),
                                        self.lan_motion(101,11,state='IDLE',x=0,vx=0,autocontrol=False),
                                        self.lan_motion(102,12,x=1),last])
                with self.assertRaises(fleet.Blocked): fleet._lan_before_interrupt(d,10,timeout=.6)

    def test_lan_movement_rejects_damage_and_zero_stocks(self):
        for field,value in (('current_hp',90),('stocks',0)):
            last = self.lan_motion(103,13,x=3)
            last['snapshot']['fighters'][0][field] = value
            d = self.motion_device([self.lan_motion(100,10,state='IDLE',x=0,vx=0,autocontrol=False),
                                    self.lan_motion(101,11,state='IDLE',x=0,vx=0,autocontrol=False),
                                    self.lan_motion(102,12,x=1),last])
            with self.assertRaises(fleet.Blocked): fleet._lan_before_interrupt(d,10,timeout=.6)

    def test_lan_interrupt_orders_active_movement_interrupt_disable_and_new_server_reset(self):
        for seconds in (10,65):
            host,guest,server = Mock(),Mock(),Mock()
            host.assert_released = Mock()
            host.state = self.lan_motion(105,15,interrupt_active=True,connected=False,autocontrol=False)
            guest.state = {'boot_id':'guest-boot','msec':105,'screen':'lan_match','peer_connected':False}
            guest.read.return_value = {'boot_id':'guest-boot','msec':100}
            calls = []
            host.command.side_effect = lambda op,**args:calls.append((op,args))
            host.wait.side_effect = lambda predicate,**_kwargs: host.state if predicate(host.state) else self.fail('host predicate')
            guest.wait.side_effect = lambda predicate,**_kwargs: guest.state if predicate(guest.state) else self.fail('guest predicate')
            reset = {'slot':1,'tick':14,'input_direction':0,'buffered_action':''}
            server.input_resets.side_effect = [[],[reset],[reset]]
            movement = {'samples':[{'boot_id':'lan-boot','msec':103,'tick':13}]}
            with patch.object(fleet,'_lan_before_interrupt',return_value=movement) as before:
                observed = fleet._lan_interrupt_with_movement(host,guest,server,seconds)
            before.assert_called_once_with(host,seconds)
            self.assertEqual(calls,[('interrupt',{'seconds':seconds}),('autoplay',{'enabled':False})])
            self.assertEqual(observed['server_input_resets'],[reset])
            self.assertTrue(observed['peer_offline'])

    def test_lan_interrupt_rejects_old_or_non_neutral_server_reset(self):
        for record,message in (({'slot':1,'tick':12,'input_direction':0,'buffered_action':''},'시간 초과'),
                               ({'slot':1,'tick':14,'input_direction':1,'buffered_action':''},'불일치')):
            with self.subTest(record=record):
                host = self.device([self.lan_motion(105,15,interrupt_active=True,connected=False,autocontrol=False)])
                host.command = Mock()
                guest = Mock()
                guest.read.return_value = {'boot_id':'guest-boot','msec':100}
                guest.wait.side_effect = lambda predicate,**_kwargs: self.assertTrue(predicate({'boot_id':'guest-boot','msec':105,'screen':'lan_match','peer_connected':False}))
                server = Mock()
                old = {'slot':1,'tick':1,'input_direction':0,'buffered_action':''}
                server.input_resets.side_effect = lambda: [old] if server.input_resets.call_count==1 else [old,record]
                with patch.object(fleet,'_lan_before_interrupt',return_value={'samples':[{'boot_id':'lan-boot','msec':103,'tick':13}]}), self.assertRaisesRegex(fleet.Failure,message):
                    fleet._lan_interrupt_with_movement(host,guest,server,10)
                self.assertEqual(host.command.call_args_list[-1].kwargs,{'enabled':False})

    def test_lan_interrupt_rejects_stale_other_apk_offline_snapshot(self):
        host = self.device([self.lan_motion(105,15,interrupt_active=True,connected=False,autocontrol=False)])
        host.command = Mock()
        guest = fleet.DeviceRun(FakeADB([{'boot_id':'guest-boot','msec':100,'screen':'lan_match','peer_connected':False}]),'guest','run',self.output,'Game',clock=self.clock.time,sleep=self.clock.sleep)
        with patch.object(fleet,'_lan_before_interrupt',return_value={'samples':[{'boot_id':'lan-boot','msec':103,'tick':13}]}), self.assertRaisesRegex(fleet.Failure,'새 단절 표시'):
            fleet._lan_interrupt_with_movement(host,guest,Mock(input_resets=Mock(return_value=[])),65)

    def test_v1_full_room_probe_sends_v1_selection_without_auth(self):
        import struct
        server = fleet.LanServer('192.168.1.2', '192.168.1.0/24', 7777, 8888, self.output, 'godot', 'run', protocol=1)
        sock = Mock()
        error = json.dumps({'type': 'error', 'code': 'room_full'}).encode()
        with patch.object(fleet.socket, 'create_connection', return_value=sock), \
             patch.object(fleet, '_websocket_upgrade', return_value=bytes([0x82, len(error)]) + error), \
             patch('urllib.request.urlopen') as http:
            result = fleet._third_guest_rejection(server, 'FA1|ws://192.168.1.2:7777|ABCDEFGH|1')
        http.assert_not_called()
        frame = sock.sendall.call_args.args[0]
        length = frame[1] & 127
        offset = 2
        if length == 126:
            length = struct.unpack('!H', frame[2:4])[0]
            offset = 4
        mask = frame[offset:offset+4]
        message = json.loads(bytes(v ^ mask[i%4] for i,v in enumerate(frame[offset+4:])))
        self.assertEqual(message['protocol_version'], 1)
        self.assertEqual(message['room_code'], 'ABCDEFGH')
        self.assertNotIn('access_token', message)
        self.assertEqual(result['source'], 'protocol_v1_probe')
        sock.close.assert_called_once()

    def test_source_manifest_preserves_token_filename_hashes_but_redacts_private_metadata(self):
        manifest = {'files': {'server/api/tokens.ts': 'a'*64, 'server/game/token_verifier.gd': 'b'*64},
                    'access_token': 'actual-private-token', 'nested': {'reconnect_token': 'actual-reconnect-token'},
                    'log': 'Authorization Bearer actualsecret'}
        destination = self.output/'source-manifest.json'
        fleet.dump_source_manifest(destination, manifest)
        saved = json.loads(destination.read_text())
        self.assertEqual(saved['files'], manifest['files'])
        self.assertEqual(saved['access_token'], '[redacted]')
        self.assertEqual(saved['nested']['reconnect_token'], '[redacted]')
        self.assertNotIn('actualsecret', destination.read_text())
        self.assertEqual(manifest['access_token'], 'actual-private-token')
        self.assertEqual(fleet.redact(manifest)['files']['server/api/tokens.ts'], '[redacted]')
    def test_source_manifest_rejects_non_sha_values_and_unsafe_paths_before_writing(self):
        destination = self.output/'source-manifest.json'
        for invalid in ('real-token-content', 'a'*63, 'a'*65, 'A'*64, None, 123, {'hash':'a'*64}):
            with self.assertRaises(fleet.Failure):
                fleet.dump_source_manifest(destination, {'files': {'server/api/tokens.ts': invalid}})
            self.assertFalse(destination.exists())
        for invalid in ('../secret', '/absolute/path', 'path/../secret', 'path//source', 'path\\source', 'path\nsource', ''):
            with self.assertRaises(fleet.Failure):
                fleet.dump_source_manifest(destination, {'files': {invalid: 'a'*64}})
            self.assertFalse(destination.exists())
        with self.assertRaises(fleet.Failure):
            fleet.source_manifest_metadata({'snapshot_root':'/tmp/source','git_head':'a'*40,'files':{'file':'not-sha'}}, '/tmp/source')

    def test_source_manifest_identifies_original_dirty_source_not_parent_git(self):
        manifest = {'snapshot_root': '/tmp/snapshot', 'source_root': '/tmp/original', 'git_head': 'a'*40,
                    'git_status': ' M asset.png', 'files': {'asset.png': 'b'*64, 'app.gd': 'c'*64}}
        metadata = fleet.source_manifest_metadata(manifest, Path('/tmp/snapshot'))
        self.assertEqual(metadata['code_version'], 'a'*40)
        self.assertTrue(metadata['code_dirty'])
        self.assertEqual(metadata['source_file_count'], 2)
        reversed_manifest = {**manifest, 'files': dict(reversed(list(manifest['files'].items())))}
        self.assertEqual(metadata['source_files_sha256'], fleet.source_manifest_metadata(reversed_manifest, '/tmp/snapshot')['source_files_sha256'])
        with self.assertRaises(fleet.Failure): fleet.source_manifest_metadata(manifest, '/tmp/other')
        with self.assertRaises(fleet.Failure): fleet.source_manifest_metadata({**manifest, 'files': {}}, '/tmp/snapshot')

    def test_explicit_project_and_lan_protocol_preserve_default_v2(self):
        args = fleet.parser().parse_args(['--project-root', '/tmp/snapshot', '--lan-protocol', '1'])
        self.assertEqual(args.project_root, Path('/tmp/snapshot'))
        self.assertEqual(args.lan_protocol, 1)
        self.assertEqual(fleet.parser().parse_args([]).lan_protocol, 2)
        v1 = fleet.LanServer('192.168.1.2', '192.168.1.0/24', 7777, 8888, self.output, 'godot', 'run', '/tmp/snapshot', 1)
        self.assertEqual(v1.code, 'FAH1|ws://192.168.1.2:7777|1')
        self.assertEqual(v1.project_root, Path('/tmp/snapshot'))
    def test_v1_ui_join_skips_v2_auth_screens(self):
        d = Mock()
        d.node.return_value = {'id': 'native-input'}
        with patch.object(fleet, '_menu'):
            fleet._lan_login(d, 'join', 'FA1|ws://192.168.1.2:7777|ABCDEFGH|1', 1)
        d.screen.assert_called_once_with('lan_join')
        self.assertEqual([call.args[0] for call in d.tap.call_args_list], ['초대 코드로 참가', '방 참가'])

    def test_soak_summary_requires_completion_on_every_selected_device(self):
        first = self.device([])
        first.mark('SOAK-01','pass','one complete round')
        second = self.device([])
        second.alias = 'device-2'
        second.mark('DEV-01','pass','connected')
        second.mark('SOAK-01','미실행','legitimate duration cutoff')
        for mode in ('soak','extended'):
            summary = fleet.write_summary(self.output,'test',{'mode':mode},[first,second],[])
            self.assertEqual(summary['status'],'blocked')
        second.mark('SOAK-01','pass','round completed')
        self.assertEqual(fleet.write_summary(self.output,'test',{'mode':'soak'},[first,second],[])['status'],'pass')
        second.mark('SOAK-01','fail','stall')
        self.assertEqual(fleet.write_summary(self.output,'test',{'mode':'soak'},[first,second],[])['status'],'fail')
    def test_option_unfocused_popup_first_down_establishes_focus(self):
        node = {'id':'prepare/choice/장신구','x':.5,'y':.5,'selected':4,'options':[{'id':str(i)} for i in range(5)]}
        def state(visible,focus,selected=4):
            return {'screen':'prepare','ui':[{**node,'popup_visible':visible,'popup_focused':focus,'selected':selected}]}
        d = self.device([state(False,-1),state(True,-1),state(True,0),state(True,2),state(False,-1,2)])
        d.state = {'screen':'prepare'}
        d.node = lambda **_kwargs: node
        d.select_option('장신구','2')
        keys = [c[-1] for c in self.adb.commands if c[:2] == ['input','keyevent']]
        self.assertEqual(keys,['20','20','20','66'])
        self.assertEqual(d.state['ui'][0]['selected'],2)
    def test_option_uses_observed_popup_focus_instead_of_selected(self):
        node = {'id':'prepare/choice/장신구','x':.5,'y':.5,'selected':0,'options':[{'id':str(i)} for i in range(5)]}
        def state(visible,focus,selected=0):
            return {'screen':'prepare','ui':[{**node,'popup_visible':visible,'popup_focused':focus,'selected':selected}]}
        d = self.device([state(False,-1),state(True,3),state(True,1),state(False,-1,1)])
        d.state = {'screen':'prepare'}
        d.node = lambda **_kwargs: node
        d.select_option('장신구','1')
        keys = [c[-1] for c in self.adb.commands if c[:2] == ['input','keyevent']]
        self.assertEqual(keys,['19','19','66'])
    def test_option_unobserved_popup_never_sends_enter(self):
        node = {'id':'prepare/choice/장신구','x':.5,'y':.5,'selected':0,'options':[{'id':'0'}]}
        d = self.device([{'screen':'prepare','ui':[node]}])
        d.state = {'screen':'prepare'}
        d.node = lambda **_kwargs: node
        with self.assertRaisesRegex(fleet.Failure,'선택 목록 열기'): d.select_option('장신구','0')
        self.assertFalse(any(c[:2] == ['input','keyevent'] for c in self.adb.commands))
    def test_global_and_mark_case_records_have_complete_envelope(self):
        d = self.device([])
        d.mark('UI-01','blocked','unavailable')
        self.assertIn('step',d.results[0])
        fleet.write_summary(self.output,'test-run',{},[d],[{'case_id':'DEV-01','status':'blocked','message':'no devices'}])
        cases = json.loads((self.output/'results.json').read_text())['cases']
        for case in cases:
            for field in ('schema_version','run_id','device','case_id','step','expected','observed'):
                self.assertIn(field,case)
        self.assertEqual(cases[0]['device'],'전체')
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
    @staticmethod
    def resume_state(msec, foreground=True, screen='pause', x=.5, boot='same-boot'):
        return {'boot_id':boot,'msec':msec,'foreground':foreground,'screen':screen,'touch':{'active':[]},
                'ui':[{'id':'pause/button/계속하기','text':'계속하기','kind':'button','visible':True,'disabled':False,
                       'x':x,'y':.6,'width':.2,'height':.1}]}
    def test_resume_rejects_stale_pause_background_and_duplicate_publication(self):
        states = [self.resume_state(100), self.resume_state(150, foreground=False),
                  self.resume_state(200), self.resume_state(200), self.resume_state(510)]
        d = self.device(states)
        state = d.wait_resumed('same-boot', 100, 'pause', '계속하기')
        self.assertEqual(state['msec'], 510)
        self.assertGreater(self.clock.now, .45)
        self.assertFalse(self.adb.commands)
    def test_resume_never_accepts_only_old_or_background_state(self):
        for state in (self.resume_state(100), self.resume_state(500, foreground=False)):
            d = self.device([state])
            with self.assertRaisesRegex(fleet.Failure, 'foreground'):
                d.wait_resumed('same-boot', 100, 'pause', '계속하기')
        d = self.device([self.resume_state(500, boot='new-boot')])
        with self.assertRaisesRegex(fleet.Failure, '프로세스'):
            d.wait_resumed('same-boot', 100, 'pause', '계속하기')
    def test_resume_waits_for_two_fresh_stable_position_publications(self):
        d = self.device([self.resume_state(200,x=.2), self.resume_state(510,x=.7),
                         self.resume_state(700,x=.7), self.resume_state(900,x=.7)])
        state = d.wait_resumed('same-boot', 100, 'pause', '계속하기')
        self.assertEqual(state['msec'], 900)
        self.assertEqual(state['ui'][0]['x'], .7)
    def test_home_resume_rechecks_latest_position_before_actual_touch(self):
        states = [self.resume_state(100,screen='match'), self.resume_state(200,foreground=False),
                  self.resume_state(200), self.resume_state(300,x=.3), self.resume_state(610,x=.3),
                  self.resume_state(650,x=.7), self.resume_state(700,x=.7), self.resume_state(1010,x=.7),
                  self.resume_state(1020,x=.7), self.resume_state(1200,screen='match')]
        d = self.device(states)
        d.physical_size = (1000,1000)
        details = d.home_and_return('pause','계속하기')
        touches = [entry for entry in self.adb.commands if isinstance(entry,list) and entry and isinstance(entry[0],int)]
        self.assertEqual(touches, [[700,600,0]])
        self.assertEqual(details['before_home_msec'], 100)
        self.assertEqual(details['after_home_msec'], 200)
        self.assertEqual(details['resumed_msec'], 1010)
        self.assertEqual(details['resume_button']['msec'], 1020)
        self.assertEqual(d.state['screen'], 'match')
        lines = (self.output/'adb-touch.jsonl').read_text().splitlines()
        self.assertEqual(json.loads(lines[0])['x'],700)
    def test_lan_home_resume_requires_fresh_foreground_publications(self):
        states = [self.resume_state(100,screen='lan_match'), self.resume_state(200,foreground=False,screen='lan_match'),
                  self.resume_state(200,screen='lan_match'), self.resume_state(300,foreground=False,screen='lan_match'),
                  self.resume_state(400,screen='lan_match'), self.resume_state(710,screen='lan_match')]
        d = self.device(states)
        details = d.home_and_return('lan_match')
        self.assertEqual(details['resumed_msec'],710)
        self.assertTrue(details['foreground'])
        self.assertNotIn('resume_button',details)
        self.assertEqual(len(self.adb.commands),2)
    def test_life_only_recheck_has_fresh_dev_ui_prerequisites(self):
        d = Mock()
        d.case.return_value = 'pass'
        self.assertTrue(fleet.offline(d, Path('game.apk'), 'smoke', 0, [], selected_case='LIFE-01'))
        self.assertEqual([call.args[0] for call in d.case.call_args_list], ['DEV-01','UI-01','LIFE-01'])
        d.soak.assert_not_called()
        self.assertEqual(fleet.parser().parse_args(['--case','LIFE-01']).case,'LIFE-01')

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
