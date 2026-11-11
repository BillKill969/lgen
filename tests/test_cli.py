"""Agent-facing CLI contract checks; run with python3 tests/test_cli.py."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
LUA = os.environ.get("LGEN_LUA", "lua")


def run(*args, content=None):
    return subprocess.run([LUA, "bin/lgen", *args], cwd=ROOT, input=content,
                          text=True, capture_output=True, timeout=20)


class AgentCLI(unittest.TestCase):
    def test_bright_tier_fixes_are_reported_in_agent_json(self):
        text = "- bg: #000000\n- blue: #89b4fa\n- bright_blue: #89b4fa\n"
        p = run("-", "--fix", "--json", content=text)
        self.assertEqual(p.returncode, 0, p.stderr)
        result = json.loads(p.stdout)
        self.assertEqual(result["after"]["summary"]["warns"], 0)
        self.assertEqual([edit["slot"] for edit in result["edits"]], [12])
        pair = result["after"]["metrics"]["bright_pairs"]["12"]
        self.assertGreaterEqual(pair["lightness_gap"], 0.06)
        self.assertEqual(pair["required_gap"], 0.06)
        self.assertEqual(result["after"]["metrics"]["policy"]["version"], "3")

    def test_math_fixes_and_model_metadata_reach_agent_json(self):
        p = run("-", "--fix", "--json", content="- bg: #666666\n- fg: #666666\n")
        self.assertEqual(p.returncode, 0, p.stderr)
        result = json.loads(p.stdout)
        self.assertEqual(result["after"]["summary"]["fails"], 0)
        self.assertGreaterEqual(abs(result["after"]["metrics"]["contrast_scores"]["fg"]["apca"]), 60)
        text = "---\nignore:\n  - MUTED_COLOR\n---\n- bg: #ffffff\n- blue: #666666\n"
        p = run("-", "--strict", "--fix", "--json", content=text)
        self.assertEqual(p.returncode, 0, p.stderr)
        result = json.loads(p.stdout)
        self.assertEqual(result["after"]["summary"]["warns"], 0)
        metrics = result["after"]["metrics"]
        self.assertGreaterEqual(metrics["contrast_scores"]["4"]["wcag"], 7)
        self.assertGreaterEqual(abs(metrics["contrast_scores"]["4"]["apca"]), 75)
        self.assertEqual(metrics["models"]["cvd"]["protan"], "vienot1999-srgb-daltonlens")
        self.assertEqual(metrics["policy"]["version"], "3")

    def test_argument_and_input_errors_are_json(self):
        for args in [("--cvd",), ("--export",), ("--diff",),
                     ("--unknown",), ("--write",), ("--watch",),
                     ("-", "--write"), ("-", "--watch"),
                     ("-", "--fix", "--export", "kitty"),
                     ("-", "--fix", "--max-iterations", "0"),
                     ("--cvd", "typo"), ()]:
            p = run("--json", *args)
            self.assertEqual(p.returncode, 2, p.stderr)
            self.assertEqual(json.loads(p.stdout)["error"]["code"], "INVALID_ARGUMENT")
            self.assertNotIn("stack traceback", p.stderr)
        p = run("/tmp/no-such-lgen-input-348184.md", "--json")
        self.assertEqual(p.returncode, 2)
        self.assertEqual(json.loads(p.stdout)["error"]["code"], "READ_ERROR")
        p = run("-", "--json", content="garbage")
        self.assertEqual(p.returncode, 2)
        self.assertEqual(json.loads(p.stdout)["error"]["code"], "INVALID_THEME")

    def test_fix_reports_reaudit_and_preserves_shared_values(self):
        text = "- bg: #000000\n- comment: #111111\nProse: #111111\n"
        p = run("-", "--fix", "--json", content=text)
        self.assertEqual(p.returncode, 0, p.stderr)
        result = json.loads(p.stdout)
        self.assertEqual(result["before"]["summary"]["fails"], 1)
        self.assertEqual(result["after"]["summary"]["fails"], 0)
        self.assertEqual(result["edits"][0]["slot"], 8)
        self.assertIn("Prose: #111111", result["content"])
        self.assertFalse(result["written"])
        audit = run("-", "--json", content=result["content"])
        self.assertEqual(json.loads(audit.stdout), result["after"])

    def test_unresolved_failures_use_exit_one(self):
        text = "---\nignore:\n  - MUTED_COLOR\n---\n- bg: #000000\n- yellow: #ffffff\n- blue: #ffffff\n"
        p = run("-", "--fix", "--json", content=text)
        self.assertEqual(p.returncode, 1, p.stderr)
        self.assertGreater(json.loads(p.stdout)["after"]["summary"]["fails"], 0)

    def test_warning_policy_and_fix_budget(self):
        text = "- bg: #000000\n- yellow: #ffffff\n"
        p = run("-", "--json", content=text)
        self.assertEqual(p.returncode, 0)
        self.assertGreater(json.loads(p.stdout)["summary"]["warns"], 0)
        p = run("-", "--json", "--fail-on-warn", content=text)
        self.assertEqual(p.returncode, 1)
        p = run("examples/flawed_theme.md", "--fix", "--json", "--max-iterations=1")
        result = json.loads(p.stdout)
        self.assertEqual(result["status"], "limit")
        self.assertEqual(result["iterations"], 1)

    def test_viewport_does_not_change_audit_and_json_is_repeatable(self):
        args = ("test_themes/catppuccin_mocha.md", "--json")
        base = run(*args)
        self.assertEqual(run(*args).stdout, base.stdout)
        cvd = run(*args, "--cvd", "protan")
        self.assertEqual(json.loads(cvd.stdout), json.loads(base.stdout))
        self.assertEqual(cvd.returncode, base.returncode)

    def test_write_and_diff_use_shared_workflows(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "theme.md"
            text = "---\r\nstrictness: relaxed\r\n---\r\n- bg: #000000\r\n- comment: #111111\r\n"
            path.write_bytes(text.encode())
            p = run(str(path), "--fix", "--write", "--json")
            self.assertEqual(p.returncode, 0, p.stderr)
            result = json.loads(p.stdout)
            self.assertTrue(result["written"])
            self.assertEqual(path.read_bytes(), result["content"].encode())
            self.assertIn("\r\n", result["content"])
            diff = run(str(path), "--diff", str(path), "--json")
            self.assertEqual(diff.returncode, 0, diff.stderr)
            result = json.loads(diff.stdout)
            self.assertEqual(result["before"], result["after"])
            self.assertEqual(result["after"]["metrics"]["strictness"], "relaxed")
            again = run(str(path), "--fix", "--write", "--json")
            self.assertEqual(again.returncode, 0, again.stderr)
            self.assertFalse(json.loads(again.stdout)["written"])
            self.assertEqual(json.loads(again.stdout)["edits"], [])


if __name__ == "__main__":
    unittest.main()
