#!/usr/bin/env python3
"""검사 선택의 누락·과잉 선택과 실제 Git 변경 탐지를 확인한다."""
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from verify_runner import changed_files, select_checks, diagnostics, MANIFEST

CHECKS = json.loads(MANIFEST.read_text())['checks']

class SelectionTests(unittest.TestCase):
    def suites(self, paths):
        selected, _ = select_checks(paths, CHECKS)
        return {s for c in selected for s in c['suites']}

    def test_docs_only_avoids_runtime_and_network(self):
        self.assertEqual(self.suites(['docs/gameplay/combat.md', '_workspace/task/00_request.md']), {'docs'})

    def test_approved_icon_selects_branding(self):
        self.assertEqual(self.suites(['assets/branding/myo-ryung-v02/main-192.png']), {'branding'})

    def test_combat_consumers_and_smoke(self):
        suites = self.suites(['scripts/fighter_controller.gd'])
        self.assertTrue({'combat','characters','presentation','smoke'} <= suites)
        self.assertNotIn('network', suites)

    def test_unknown_code_and_global_config_use_full(self):
        for path in ['scripts/new_mechanic.gd', 'project.godot', 'export_presets.cfg']:
            selected, _ = select_checks([path], CHECKS)
            self.assertEqual(selected, CHECKS, path)

    def test_existing_test_selects_own_suite(self):
        selected,_=select_checks(['tests/phase1_combat_behavior.gd'],CHECKS)
        ids={c['id'] for c in selected}
        self.assertIn('phase1_combat_behavior',ids)
        self.assertNotIn('docs',ids)
        self.assertNotIn('online-server',ids)

    def test_new_test_cannot_silently_skip(self):
        self.assertEqual(len(select_checks(['tests/new_behavior.gd'], CHECKS)[0]),len(CHECKS))

    def test_no_changes_is_not_full(self):
        self.assertEqual(select_checks([],CHECKS)[0],[])

    def test_manifest_has_unique_ids_and_all_commands_exist(self):
        root=MANIFEST.parents[2]
        self.assertEqual(len({c['id'] for c in CHECKS}),len(CHECKS))
        for c in CHECKS:
            self.assertTrue(c['suites'],c['id'])
            for item in c['command']:
                if item.startswith(('res://tests/','res://tools/','./scripts/','tools/forest_arena/')):
                    self.assertTrue((root/item.removeprefix('res://').removeprefix('./')).is_file(),item)

    def test_real_git_committed_staged_untracked_renamed_and_deleted(self):
        with tempfile.TemporaryDirectory() as folder:
            p=Path(folder)
            def git(*args):return subprocess.check_output(['git','-C',str(p),*args],stderr=subprocess.DEVNULL)
            git('init','-b','develop');git('config','user.email','fixture@example.invalid');git('config','user.name','Fixture')
            for name in ['deleted.txt','renamed.txt']:(p/name).write_text('original')
            git('add','.');git('commit','-m','base');git('branch','baseline')
            (p/'committed.txt').write_text('committed');git('add','.');git('commit','-m','committed')
            git('mv','renamed.txt','new-name.txt');(p/'deleted.txt').unlink()
            (p/'untracked.txt').write_text('new')
            self.assertEqual(changed_files(p,'baseline'),['committed.txt','deleted.txt','new-name.txt','renamed.txt','untracked.txt'])

    def test_partial_staging_cannot_hide_changes(self):
        with tempfile.TemporaryDirectory() as folder:
            p=Path(folder)
            def git(*args):return subprocess.check_output(['git','-C',str(p),*args],stderr=subprocess.DEVNULL)
            git('init','-b','develop');git('config','user.email','fixture@example.invalid');git('config','user.name','Fixture')
            (p/'file.gd').write_text('baseline');git('add','.');git('commit','-m','base')
            (p/'file.gd').write_text('staged');git('add','file.gd')
            (p/'file.gd').write_text('baseline')
            self.assertEqual(changed_files(p,'HEAD'),['file.gd'])

    def test_ui_consumer_keeps_resource_validation(self):
        for path in ['scripts/local_ai_app.gd','scripts/ui/new_panel.gd','scripts/touch_command_source.gd','scripts/local_fighter_presentation.gd']:
            selected,_=select_checks([path],CHECKS)
            self.assertIn('resources',{c['id'] for c in selected},path)

    def test_workspace_approval_inputs_are_not_skipped(self):
        for suffix in ['approval.json','normalized-candidates.json','installation.json','07_before_install/manifest.json']:
            selected,_=select_checks(['_workspace/character-personality-concepts/'+suffix],CHECKS)
            self.assertIn('install_personality_concepts',{c['id'] for c in selected})

    def test_timeout_kills_grandchild_before_unlock(self):
        import sys,time
        from workflow import run_process
        with tempfile.TemporaryDirectory() as folder:
            marker=Path(folder)/'orphan'
            child="import time;from pathlib import Path;time.sleep(.7);Path(%r).write_text('orphan')" % str(marker)
            parent="import subprocess,sys,time;subprocess.Popen([sys.executable,'-c',%r]);time.sleep(10)" % child
            with self.assertRaises(subprocess.TimeoutExpired):
                run_process([sys.executable,'-c',parent],timeout=.15,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
            time.sleep(.8)
            self.assertFalse(marker.exists())

    def test_overall_result_pass_only_after_last_command(self):
        import sys,contextlib,io
        from verify_runner import execute
        with tempfile.TemporaryDirectory() as folder:
            p=Path(folder)
            def git(*args):return subprocess.check_output(['git','-C',str(p),*args],stderr=subprocess.DEVNULL)
            git('init','-b','develop');git('config','user.email','fixture@example.invalid');git('config','user.name','Fixture')
            (p/'base').write_text('base');git('add','.');git('commit','-m','base')
            probe="import json,os;from pathlib import Path;r=json.loads((Path(os.environ['FOREST_ARENA_VERIFY_OUTPUT'])/'result.json').read_text());assert r['status']=='running' and r['completed_checks']==1 and r['total_checks']==2,r"
            with contextlib.redirect_stdout(io.StringIO()):
                code=execute([{'id':'first','command':[sys.executable,'-c','pass']},{'id':'last','command':[sys.executable,'-c',probe]}],p)
            self.assertEqual(code,0)
            report=json.loads(next((p/'build/verification').glob('*/result.json')).read_text())
            self.assertEqual(report['status'],'pass');self.assertEqual(report['completed_checks'],2)

    def test_engine_errors_fail_even_with_zero_exit(self):
        for text in ['SCRIPT ERROR: bad','Parse Error: bad','ERROR: missing texture','CONTRACT: FAIL (1)']:
            self.assertTrue(diagnostics(text)[0],text)
        failed,warnings=diagnostics('PASS\nERROR: 2 resources still in use at exit (run with --verbose for details).\n')
        self.assertFalse(failed);self.assertEqual(len(warnings),1)

if __name__=='__main__':unittest.main()
