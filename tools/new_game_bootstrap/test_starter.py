#!/usr/bin/env python3
"""배포 ZIP을 실제로 풀어 정상·실패·보존·재실행 상황을 검사한다."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import zipfile

from build_starter import build, REPO


class StarterTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.work = tempfile.TemporaryDirectory(prefix='new-game-starter-tests-')
        cls.archive = build(Path(cls.work.name)/'starter.zip')

    @classmethod
    def tearDownClass(cls):
        cls.work.cleanup()

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='starter-case-')
        self.addCleanup(self.tmp.cleanup)
        with zipfile.ZipFile(self.archive) as archive:
            self.assertIsNone(archive.testzip())
            archive.extractall(self.tmp.name)
        self.root = Path(self.tmp.name)/'game-starter'

    def command(self, tool, *args, ok=True):
        result = subprocess.run([sys.executable, str(self.root/'tools'/tool), *args],
                                cwd=self.tmp.name, capture_output=True, text=True)
        self.assertEqual(result.returncode == 0, ok, result.stdout+result.stderr)
        return result.stdout+result.stderr

    def input(self, **changes):
        data = dict(game_name='구름 정원', project_id='cloud-garden', core_play='씨앗을 심고 길을 연결한다.',
                    first_goal='씨앗 하나를 심어 자라는 모습을 확인한다.', platforms=[], engine=None,
                    screen_input=None, excluded_features=['온라인'], optional_tools=[], android=False, confirmed=True)
        data.update(changes)
        (self.root/'project-input.json').write_text(json.dumps(data, ensure_ascii=False, indent=2)+'\n')
        return data

    def configure(self, **changes):
        self.input(**changes)
        self.command('configure_project.py')
        self.command('verify_bootstrap.py', '--scope', 'all', '--require-configured')

    def snapshot(self):
        return {str(p.relative_to(self.root)): hashlib.sha256(p.read_bytes()).hexdigest()
                for p in self.root.rglob('*') if p.is_file()}

    def test_empty_project_and_engine_unknown_no_tools(self):
        self.command('verify_bootstrap.py', '--scope', 'all')
        self.command('verify_bootstrap.py', '--require-configured', ok=False)
        self.configure()
        self.assertFalse((self.root/'project.godot').exists())
        self.assertFalse((self.root/'docs/engineering/godot').exists())
        self.assertEqual(json.loads((self.root/'bootstrap-state.json').read_text())['engine'], None)
        self.assertIn('엔진: 미정', (self.root/'docs/engineering/architecture.md').read_text())

    def test_optional_godot_android_and_shell_wrappers(self):
        self.configure(engine='Godot', android=True, platforms=['Android'], screen_input='가로·터치')
        self.assertEqual(json.loads((self.root/'assets/resource-registry.json').read_text())['assets'], [])
        for script in ['verify-docs.sh', 'verify-harness.sh', 'verify.sh']:
            result = subprocess.run(['sh', str(self.root/'scripts'/script)], cwd=self.tmp.name, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
        (self.root/'docs/engineering/android.md').unlink()
        out = self.command('verify_bootstrap.py', ok=False)
        self.assertIn('docs/engineering/android.md', out)

    def test_android_without_godot(self):
        self.configure(engine='other', android=True)
        self.assertTrue((self.root/'docs/engineering/android.md').exists())
        self.assertFalse((self.root/'docs/engineering/godot').exists())

    def test_rerun_preserves_edits_and_decisions(self):
        self.configure()
        p = self.root/'docs/product/decisions.md'
        p.write_text(p.read_text()+'\n사용자가 승인한 후속 결정은 보존한다.\n')
        previous = self.snapshot()
        self.command('configure_project.py')
        self.assertEqual(previous, self.snapshot())
        self.command('verify_bootstrap.py', '--require-configured')
        self.input(first_goal='변경된 목표')
        previous = self.snapshot()
        self.command('configure_project.py', ok=False)
        self.assertEqual(previous, self.snapshot())
        self.command('verify_bootstrap.py', ok=False)

    def test_existing_modified_files_not_overwritten(self):
        self.input()
        p = self.root/'README.md'
        p.write_text(p.read_text()+'\n기존 사용자 내용\n')
        previous = self.snapshot()
        self.command('configure_project.py', ok=False)
        self.assertEqual(previous, self.snapshot())

    def test_existing_optional_file_not_overwritten(self):
        self.input(engine='godot')
        p = self.root/'docs/engineering/godot/setup.md'
        p.parent.mkdir(parents=True)
        p.write_text('기존 설정')
        previous = self.snapshot()
        self.command('configure_project.py', ok=False)
        self.assertEqual(previous, self.snapshot())

    def test_missing_file_link_and_heading(self):
        self.configure()
        p = self.root/'docs/product/vision.md'
        original = p.read_text()
        p.unlink()
        self.assertIn('vision.md', self.command('verify_bootstrap.py', ok=False))
        p.write_text(original+'\n[잘못된 링크](missing.md)\n')
        self.assertIn('끊어진 링크', self.command('verify_bootstrap.py', ok=False))
        p.write_text(original+'\n[잘못된 제목](#없는-제목)\n')
        self.assertIn('없는 제목', self.command('verify_bootstrap.py', ok=False))
        p.write_text(original+'\n```text\n[예시](missing.md)\n```\n')
        self.command('verify_bootstrap.py')

    def test_skill_and_roster_failures(self):
        self.configure()
        p = self.root/'.agents/skills/cloud-garden-workflow/SKILL.md'
        original = p.read_text()
        p.write_text(original.replace('name: cloud-garden-workflow', 'name: wrong-name'))
        self.assertIn('YAML', self.command('verify_bootstrap.py', ok=False))
        p.write_text(original.replace('description: "', 'description: "미완료', 1).replace('진행한다."', '진행한다.', 1))
        self.assertIn('따옴표', self.command('verify_bootstrap.py', ok=False))
        p.write_text(original)
        roster = self.root/'docs/operations/harness/team-spec.md'
        roster.write_text(roster.read_text().replace('품질 확인(qa)', '미정'))
        self.assertIn('담당 책임 누락', self.command('verify_bootstrap.py', ok=False))

    def test_name_with_quotes_colon_and_backslash(self):
        self.configure(game_name='구름: "정원" \\ 새싹')
        p = self.root/'.agents/skills/cloud-garden-workflow/SKILL.md'
        description = p.read_text().split('description: ', 1)[1].splitlines()[0]
        self.assertIn('구름: "정원" \\ 새싹', json.loads(description))

    def test_leftover_identifiers_and_tokens(self):
        self.configure()
        p = self.root/'docs/product/vision.md'
        original = p.read_text()
        for value in ['{{PROJECT_ID}}', 'starter-game', 'Forest'+'ArenaResources']:
            p.write_text(original+'\n'+value+'\n')
            self.command('verify_bootstrap.py', ok=False)
        p.write_text(original)
        self.command('verify_bootstrap.py')

    def test_input_validation_and_symlink_preservation(self):
        self.input(confirmed=False)
        self.command('configure_project.py', ok=False)
        self.input(project_id='../wrong')
        self.command('configure_project.py', ok=False)
        self.input()
        target = Path(self.tmp.name)/'outside.md'
        target.write_text('사용자 문서')
        readme = self.root/'README.md'
        readme.unlink()
        readme.symlink_to(target)
        self.command('configure_project.py', ok=False)
        self.assertEqual(target.read_text(), '사용자 문서')

    def test_archive_content_and_reproducible_bytes(self):
        with zipfile.ZipFile(self.archive) as archive:
            names = archive.namelist()
            self.assertTrue(all(name.startswith('game-starter/') and '..' not in Path(name).parts for name in names))
            self.assertTrue(any('/.agents/skills/' in name for name in names))
            self.assertFalse(any('/.git/' in name or '__pycache__' in name or name.endswith('.png') for name in names))
            self.assertEqual((archive.getinfo('game-starter/scripts/verify.sh').external_attr >> 16) & 0o777, 0o755)
        other = build(Path(self.work.name)/'second.zip')
        self.assertEqual(self.archive.read_bytes(), other.read_bytes())


if __name__ == '__main__':
    unittest.main(verbosity=2)
