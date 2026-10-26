"""Reject unapproved, partial or changed personality additions without weakening old checks."""
import copy
import unittest
from unittest.mock import patch
import install_personality_concepts as subject


class RegistrationTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.assets = subject.read(subject.ROOT/'assets/character/manifest.json')['assets']

    def test_exact_approved_addition_preserves_existing_order_and_values(self):
        existing = subject.without_personality_variants(self.assets)
        self.assertEqual(existing, [e for e in self.assets if e.get('type') != 'concept-variant'])
        self.assertEqual(len(self.assets)-len(existing), 4)

    def test_pre_addition_manifest_needs_no_approval(self):
        assets = [{'asset_id': 'old', 'type': 'concept'}]
        self.assertEqual(subject.without_personality_variants(assets), assets)

    def test_installed_check_rejects_removing_all_four_variants(self):
        original_read = subject.read
        def altered(path):
            result = original_read(path)
            if path == subject.ROOT/'assets/character/manifest.json':
                result['assets'] = [e for e in result['assets'] if e.get('type') != 'concept-variant']
            return result
        with patch.object(subject, 'read', side_effect=altered), self.assertRaises(AssertionError):
            subject.check()

    def test_duplicate_ids_rejected(self):
        with self.assertRaises(AssertionError):
            subject.without_personality_variants(self.assets+[self.assets[-1]])

    def test_unknown_or_partial_variant_rejected(self):
        variant_id = next(e['asset_id'] for e in self.assets if e.get('type') == 'concept-variant')
        for assets in ([e for e in self.assets if e['asset_id'] != variant_id], self.assets+[{'asset_id':'unknown', 'type':'concept-variant'}]):
            with self.subTest(count=len(assets)), self.assertRaises(AssertionError):
                subject.without_personality_variants(assets)

    def test_modified_metadata_reference_or_hash_rejected(self):
        for field, value in [('sha256','0'*64), ('variant','other'), ('reference_concept_asset_id','nabi-concept-v01'), ('consumer_path','other.md')]:
            assets = copy.deepcopy(self.assets)
            next(e for e in assets if e.get('type') == 'concept-variant')[field] = value
            with self.subTest(field=field), self.assertRaises(AssertionError):
                subject.without_personality_variants(assets)

    def test_missing_adoption_or_stale_report_or_substituted_images_rejected(self):
        original_read = subject.read
        for field, value in [('user_approved',False), ('report_sha256','0'*64), ('images',{})]:
            def altered(path):
                result = original_read(path)
                if path.name == 'approval.json':
                    result[field] = value
                return result
            with self.subTest(field=field), patch.object(subject, 'read', side_effect=altered), self.assertRaises(AssertionError):
                subject.expected_entries()

    def test_changed_installed_png_rejected(self):
        original_sha = subject.sha
        target = next(e['path'] for e in self.assets if e.get('type') == 'concept-variant')
        def altered(path):
            return '0'*64 if str(path).endswith(target) else original_sha(path)
        with patch.object(subject, 'sha', side_effect=altered), self.assertRaises(AssertionError):
            subject.without_personality_variants(self.assets)

    def test_changed_generation_source_rejected(self):
        original_sha = subject.sha
        def altered(path):
            return '0'*64 if path.parent.name == '03_drafts' else original_sha(path)
        with patch.object(subject, 'sha', side_effect=altered), self.assertRaises(AssertionError):
            subject.approved_report()

    def test_current_check_accepts_independently_registered_later_motions(self):
        # This checkout includes approved later animation registrations. A static
        # concept check must not freeze the rest of the game's development.
        subject.check()

    def test_future_non_concept_addition_is_outside_static_variant_scope(self):
        original_read = subject.read
        def altered(path):
            result = original_read(path)
            if path == subject.ROOT/'assets/character/manifest.json':
                result['assets'].append({'asset_id': 'later-motion', 'type': 'animation-runtime'})
            return result
        with patch.object(subject, 'read', side_effect=altered):
            subject.check()
            with self.assertRaisesRegex(AssertionError, 'during installation'):
                subject.check(preserve_install_snapshot=True)

    def test_current_check_still_rejects_changed_canonical_entry_and_png(self):
        original_read = subject.read
        def altered(path):
            result = original_read(path)
            if path == subject.ROOT/'assets/character/manifest.json':
                next(e for e in result['assets'] if e['type'] == 'concept')['sha256'] = '0'*64
            return result
        with patch.object(subject, 'read', side_effect=altered), self.assertRaises(AssertionError):
            subject.check()
        original_sha = subject.sha
        canonical = next(e for e in self.assets if e['type'] == 'concept')['path']
        def altered_sha(path):
            return '0'*64 if path == subject.ROOT/canonical else original_sha(path)
        with patch.object(subject, 'sha', side_effect=altered_sha), self.assertRaises(AssertionError):
            subject.check()

    def test_explicit_installation_audit_still_rejects_changed_gameplay_file(self):
        original_read, original_sha = subject.read, subject.sha
        baseline = original_read(subject.ROOT/subject.TOPIC/'07_before_install/manifest.json')
        receipt = original_read(subject.ROOT/subject.TOPIC/'installation.json')
        target = 'scripts/local_fighter_presentation.gd'
        self.assertIn(target, receipt['preserved_files'])
        def altered_read(path):
            result = original_read(path)
            if path == subject.ROOT/'assets/character/manifest.json':
                result['assets'] = baseline['assets'] + subject.expected_entries()
            return result
        def altered_sha(path):
            relative = str(path.relative_to(subject.ROOT))
            if relative == target:
                return '0'*64
            return receipt['preserved_files'].get(relative, original_sha(path))
        with patch.object(subject, 'read', side_effect=altered_read), patch.object(subject, 'sha', side_effect=altered_sha):
            with self.assertRaisesRegex(AssertionError, 'during installation: scripts/local_fighter_presentation.gd'):
                subject.check(preserve_install_snapshot=True)

    def test_non_combat_exception_is_limited_to_four_static_variants(self):
        contract = subject.read(subject.ROOT/'docs/contracts/character-appearance-v01.json')
        policy = contract['global_rules']['non_combat_pose_policy']
        self.assertEqual(policy['scope'], {'type':'concept-variant', 'variant':'personality'})
        self.assertEqual(policy['allowed_asset_ids'], [f'{cid}-concept-personality-v01' for cid in subject.ROSTER])
        self.assertEqual(set(policy['posture_exceptions']), set(subject.ROSTER))
        self.assertEqual(policy['posture_exceptions']['myo-ryung'], ['raised kick or aerial-entry stance','kick-led fighting posture','kick and aerial-entry posture'])
        self.assertIn('must_not_add', policy['preserved_rules'])
        before = subject.read(subject.ROOT/subject.TOPIC/'07_before_install/appearance.json')
        self.assertEqual(contract['characters'], before['characters'])


if __name__ == '__main__':
    unittest.main()
