-- tests/test_reporter.lua
local runner = require("tests.run")
local test = runner.test
local assert_near = runner.assert_near
local assert_eq = runner.assert_eq
local assert_true = runner.assert_true

package.path = package.path .. ";./?.lua;./?/init.lua"
local parser = require("lgen.markdown_parser")
local auditor = require("lgen.auditor")
local reporter = require("lgen.reporter")

test("reporter formats terminal output with badges and swatches", function()
  local md = [[
- bg: #121212
- fg: #d0d0d0
- black: #1c1c1c
- red: #c0392b
- green: #27ae60
- yellow: #f39c12
- blue: #1a5276
- magenta: #8e44ad
- cyan: #16a085
- white: #bdc3c7
- comment: #1a1a1a
  ]]
  local doc = parser.parse(md)
  local diag = auditor.audit(doc.palette)

  local term_out = reporter.format_terminal(diag, doc)
  assert_true(term_out:find("FAIL") ~= nil, "Should contain FAIL badge")
  assert_true(term_out:find("ANSI Colorscheme Audit Report") ~= nil)
  -- Should contain truecolor escape code
  assert_true(term_out:find("\27%[48;2;") ~= nil, "Should render truecolor ANSI escape sequences")
end)

test("reporter generates valid JSON string", function()
  local md = "- bg: #000000\n- fg: #ffffff\n- 1: #ff0000"
  local doc = parser.parse(md)
  local diag = auditor.audit(doc.palette)

  local json_str = reporter.format_json(diag)
  assert_true(json_str:find('"fails":') ~= nil)
  assert_true(json_str:find('"warns":') ~= nil)
  assert_true(json_str:find('"metrics":') ~= nil)
end)

test("apply_fixes_to_markdown replaces failing hex with suggested fix", function()
  local md = [[
# My Theme
- bg: #121212
- fg: #d0d0d0
- comment: #141414
  ]]
  local doc = parser.parse(md)
  local diag = auditor.audit(doc.palette)

  local patched_md = reporter.apply_fixes_to_markdown(doc, diag)
  assert_true(not patched_md:find("#141414"), "Old illegible comment hex should be replaced")
  assert_true(patched_md:find("#121212"), "Background should remain unchanged")
end)
