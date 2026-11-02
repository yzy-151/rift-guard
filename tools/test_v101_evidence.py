"""Regression checks for stale evidence detection, without touching production files."""
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import v101_evidence as evidence


class EvidenceTests(unittest.TestCase):
    def test_both_runtime_and_authoring_workbooks_invalidate_evidence(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'game/data').mkdir(parents=True)
            (root / 'content').mkdir()
            with patch.object(evidence, 'ROOT', root):
                for relative in ['game/data/game_config.xlsx', 'content/game_config.xlsx']:
                    workbook = root / relative
                    workbook.write_bytes(b'workbook\r\n')
                    baseline = evidence.source_digest()
                    workbook.write_bytes(b'workbook\n')
                    self.assertNotEqual(baseline, evidence.source_digest())

    def test_source_changes_invalidate_evidence_but_line_endings_do_not(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            game = root / 'game'
            game.mkdir()
            script = game / 'main.gd'
            script.write_bytes(b'extends Node\n')
            with patch.object(evidence, 'ROOT', root):
                baseline = evidence.source_digest()
                script.write_bytes(b'extends Node\r\n')
                self.assertEqual(baseline, evidence.source_digest())
                script.write_bytes(b'extends Node2D\n')
                self.assertNotEqual(baseline, evidence.source_digest())

    def test_generated_import_cache_does_not_change_source_identity(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'game').mkdir()
            with patch.object(evidence, 'ROOT', root):
                baseline = evidence.source_digest()
                cache = root / 'game/.godot'
                cache.mkdir()
                (cache / 'editor.cfg').write_text('cache')
                self.assertEqual(baseline, evidence.source_digest())

    def test_replacing_pck_or_executable_invalidates_release_evidence(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'game').mkdir()
            executable = root / 'RiftGuard.exe'
            pack = executable.with_suffix('.pck')
            executable.write_bytes(b'engine')
            pack.write_bytes(b'game')
            with patch.object(evidence, 'ROOT', root):
                baseline = evidence.identity(executable, True)
                pack.write_bytes(b'changed game')
                self.assertNotEqual(baseline, evidence.identity(executable, True))
                pack.write_bytes(b'game')
                executable.write_bytes(b'changed engine')
                self.assertNotEqual(baseline, evidence.identity(executable, True))


if __name__ == '__main__':
    unittest.main()
