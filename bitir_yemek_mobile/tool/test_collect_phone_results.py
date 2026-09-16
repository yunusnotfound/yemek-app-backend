import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from collect_phone_results import collect


def log(*, complete=True, profile=True, success=True):
    lines = [
        'Runner[1] flutter: PHONE_PERFORMANCE_RESULT ' + json.dumps({"complete": complete}),
        'Runner[1] flutter: PHONE_PERFORMANCE_RESULT ' + json.dumps({"environment": {"profileMode": profile, "os": "ios"}}),
        'Runner[1] flutter: PHONE_PERFORMANCE_RESULT ' + json.dumps({"home_first_render": {"frames": 12}}),
    ]
    if success:
        lines.append('Runner[1] flutter: 00:10 +3: All tests passed!')
    return '\n'.join(lines)


class CollectorTests(unittest.TestCase):
    def test_merges_json_fragments_with_native_prefixes(self):
        result = collect(log())
        self.assertTrue(result["complete"])
        self.assertTrue(result["environment"]["profileMode"])
        self.assertEqual(result["home_first_render"]["frames"], 12)

    def test_requires_all_completion_gates(self):
        for text in [log(complete=False), log(profile=False), log(success=False)]:
            with self.subTest(text=text), self.assertRaises(ValueError):
                collect(text)

    def test_failure_is_rejected_even_with_success_marker(self):
        with self.assertRaisesRegex(ValueError, "test failure"):
            collect(log() + '\n00:10 +3 -1: Some tests failed.')

    def test_multiple_runs_cannot_be_silently_merged(self):
        with self.assertRaisesRegex(ValueError, "Repeated result keys"):
            collect(log() + '\n' + log())

    def test_truncated_json_is_not_used_as_partial_success(self):
        with self.assertRaisesRegex(ValueError, "Truncated or invalid"):
            collect(log() + '\nPHONE_PERFORMANCE_RESULT {"coupons_scroll":')

    def test_cli_failure_leaves_no_result_file(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            source = path / 'failed.log'
            destination = path / 'result.json'
            source.write_text(log(complete=False))
            result = subprocess.run(
                [sys.executable, str(Path(__file__).with_name('collect_phone_results.py')),
                 str(source), '--output', str(destination)],
                text=True, capture_output=True, check=False,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse(destination.exists())
            self.assertNotIn('Validated profile result', result.stdout)


if __name__ == '__main__':
    unittest.main(verbosity=2)
