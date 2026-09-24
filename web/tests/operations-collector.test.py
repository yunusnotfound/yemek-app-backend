"""Run with python3 web/tests/operations-collector.test.py."""
import importlib.util
import json
from pathlib import Path
import subprocess
import unittest
from contextlib import ExitStack
from unittest.mock import patch

source = Path(__file__).parents[1] / "src/lib/operations/collect-operations.py"
spec = importlib.util.spec_from_file_location("operations_collector", source)
collector = importlib.util.module_from_spec(spec)
spec.loader.exec_module(collector)


class CollectorTests(unittest.TestCase):
    def test_log_projection_does_not_emit_personal_or_secret_values(self):
        lines = [
            '2026-09-24T10:00:00.000Z ' + json.dumps({"level": "error", "message": "Redis failure password=private-secret user=person@example.com", "token": "private-token"}),
            '2026-09-24T10:01:00.000Z ' + json.dumps({"level": "warn", "message": "payment unknown order private-order-id"}),
            '2026-09-24T10:02:00.000Z ' + json.dumps({"level": "info", "message": "not an error"}),
            "unstructured private-secret",
        ]
        result = collector.summarize_logs(lines)
        self.assertEqual((result["errors"], result["warnings"]), (1, 1))
        self.assertEqual([item["label"] for item in result["categories"]], ["Redis / önbellek", "Ödeme / iade"])
        output = json.dumps(result)
        for sensitive in ("private-secret", "person@example.com", "private-token", "private-order-id"):
            self.assertNotIn(sensitive, output)

    def test_malformed_payloads_and_non_timestamp_prefixes_are_safe(self):
        result = collector.summarize_logs([
            'SECRET {"level":"warn", "message":"misc"}',
            '2026-09-24T10:00:00Z []',
            '2026-09-24T10:00:00Z null',
            '2026-09-24T10:00:00Z malformed',
        ], limit=4)
        self.assertTrue(result["limited"])
        self.assertEqual(result["categories"], [{"label": "Uygulama", "count": 1, "lastAt": None}])

    def test_docker_units_preserve_decimal_binary_distinction(self):
        self.assertEqual(collector.bytes_value("1.5MiB"), 1572864)
        self.assertEqual(collector.bytes_value("1.5MB"), 1500000)
        self.assertEqual(collector.bytes_value("0B"), 0)
        self.assertIsNone(collector.bytes_value("--"))
        self.assertIsNone(collector.percent_value("--"))

    def test_failed_command_never_reemits_stderr(self):
        failed = subprocess.CompletedProcess(["client"], 1, stdout="", stderr="password=secret")
        with patch.object(collector.subprocess, "run", return_value=failed):
            with self.assertRaisesRegex(RuntimeError, "^command failed$"):
                collector.command(["client"])

    def test_database_queries_cannot_write_and_exclude_the_collector(self):
        self.assertIn("BEGIN READ ONLY", collector.DATABASE_SQL)
        self.assertIn("statement_timeout = '3000ms'", collector.DATABASE_SQL)
        self.assertIn("pid<>pg_backend_pid()", collector.DATABASE_SQL)
        self.assertNotIn("ROLLBACK", collector.DATABASE_SQL)

    def test_unavailable_sources_are_unknown_with_fixed_errors(self):
        names = ("collect_host", "collect_containers", "collect_database", "collect_redis",
                 "collect_alloy", "http_probe", "collect_tls", "collect_logs",
                 "collect_backups", "collect_release")
        with ExitStack() as stack:
            for name in names:
                stack.enter_context(patch.object(collector, name, side_effect=RuntimeError("private failure")))
            snapshot = collector.collect()
        for key in ("host", "database", "redis", "logs", "backups", "release", "integrations", "queues"):
            self.assertIsNone(snapshot[key])
        self.assertEqual(snapshot["containers"], [])
        self.assertEqual(snapshot["http"], {"api": None, "web": None, "tls": None})
        self.assertEqual(len(snapshot["partialErrors"]), 11)
        self.assertNotIn("private failure", json.dumps(snapshot))


if __name__ == "__main__":
    unittest.main()
