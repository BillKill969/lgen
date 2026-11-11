-- tests/test_diff_and_preview.lua
local runner = require("tests.run")
local test = runner.test
local assert_true = runner.assert_true

package.path = package.path .. ";./?.lua;./?/init.lua"
local lgen = require("lgen")

test("format_diff generates side-by-side comparison between two themes", function()
  local diff_out = lgen.diff_files("test_themes/catppuccin_mocha.md", "test_themes/catppuccin_mocha_fixed.md")
  assert_true(diff_out ~= nil)
  assert_true(diff_out:find("Comparison Diff") ~= nil)
  assert_true(diff_out:find("Fixed Legible") ~= nil, "Should identify fixed comment legibility")
  assert_true(diff_out:find("Summary:") ~= nil)
end)

test("render_syntax_preview generates truecolor terminal code window", function()
  local diag, doc = lgen.audit_file("test_themes/catppuccin_mocha_fixed.md")
  local preview = lgen.reporter.render_syntax_preview(doc.palette)
  assert_true(preview ~= nil)
  assert_true(preview:find("Syntax & Git Diff Preview") ~= nil)
  assert_true(preview:find("audit_tokens") ~= nil)
  assert_true(preview:find("diff_removed") ~= nil)
  assert_true(preview:find("diff_added") ~= nil)
end)
