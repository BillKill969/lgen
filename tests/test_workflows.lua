local t = require("tests.run")
local lgen = require("lgen")

t.test("document edits target source slots and preserve unrelated bytes", function()
  local text = "---\r\nname: '#111'\r\n---\r\n- red: #111\r\n- green: #111\r\nProse: #111\r\n- red: #222222\r\n"
  local doc = lgen.markdown_parser.parse(text)
  local out = lgen.markdown_parser.apply_edits(doc, {{slot=1, new_hex="#abcdef"}})
  t.assert_eq(out, text:gsub("red: #111", "red: #abcdef", 1))
end)

t.test("JSON output uses JSON escapes and deterministic object ordering", function()
  t.assert_eq(lgen.reporter.encode_json({z="\0\1\n\t\"\\", a=1}),
    '{"a":1,"z":"\\u0000\\u0001\\n\\t\\\"\\\\"}')
end)

t.test("input errors are explicit and content never becomes a file path", function()
  local path = os.tmpname()
  os.remove(path)
  local diag, err = lgen.audit_file(path)
  t.assert_eq(diag, nil)
  t.assert_eq(err.code, "READ_ERROR")
  local f = assert(io.open(path, "wb"))
  f:write("- bg: #000000\n"); f:close()
  local from_file = lgen.audit_file(path)
  local from_string, string_err = lgen.audit_string(path)
  os.remove(path)
  t.assert_true(from_file ~= nil)
  t.assert_eq(from_string, nil)
  t.assert_eq(string_err.code, "INVALID_THEME")
  local invalid, option_err = lgen.audit_string("- bg: #000000", {strictness="typo"})
  t.assert_eq(invalid, nil)
  t.assert_eq(option_err.code, "INVALID_OPTIONS")
end)

t.test("fix plans assess combined edits and preserve source identity", function()
  local text = "- bg: #000000\n- comment: #111111\nProse: #111111\n"
  local result = lgen.fix_string(text)
  t.assert_eq(#result.before.fails, 1)
  t.assert_eq(#result.after.fails, 0)
  t.assert_eq(#result.edits, 1)
  t.assert_eq(result.edits[1].slot, 8)
  t.assert_true(result.content:find("Prose: #111111", 1, true) ~= nil)
  local verified = lgen.audit_string(result.content)
  t.assert_eq(#verified.fails, #result.after.fails)
  t.assert_eq(#verified.warns, #result.after.warns)
  t.assert_eq(result.content, lgen.fix_string(text).content)
  t.assert_eq(#lgen.fix_string(result.content).edits, 0)
end)

t.test("audit workflows honor metadata and explicit overrides without mutating options", function()
  local text = "---\nstrictness: relaxed\nignore:\n  - COMMENT_ILLEGIBLE\n---\n- bg: #ffffff\n- comment: #eeeeee\n"
  local opts = {}
  local diag = lgen.audit_string(text, opts)
  t.assert_eq(diag.metrics.strictness, "relaxed")
  t.assert_eq(diag.metrics.is_dark, false)
  t.assert_eq(#diag.fails, 0)
  t.assert_eq(opts.meta, nil)
  local strict = lgen.audit_string(text, {strictness="strict", ignore={}})
  t.assert_eq(strict.metrics.strictness, "strict")
  t.assert_eq(#strict.fails, 1)
end)

t.test("fix planning is bounded and reports unresolved collisions", function()
  local result = assert(lgen.fix_file("examples/flawed_theme.md", {max_iterations=1}))
  t.assert_eq(result.iterations, 1)
  t.assert_eq(result.status, "limit")
  t.assert_true(#result.after.fails < #result.before.fails or
    (#result.after.fails == #result.before.fails and #result.after.warns < #result.before.warns))
  local full = assert(lgen.fix_file("examples/flawed_theme.md"))
  t.assert_eq(#full.after.fails, 0)
  local unresolved = assert(lgen.fix_string("---\nignore:\n  - MUTED_COLOR\n---\n- bg: #000000\n- yellow: #ffffff\n- blue: #ffffff\n"))
  t.assert_eq(unresolved.status, "stalled")
  t.assert_true(#unresolved.after.fails > 0)
  t.assert_eq(#unresolved.edits, 0)
  local invalid, err = lgen.fix_string("- bg: #000000", {max_iterations=0})
  t.assert_eq(invalid, nil)
  t.assert_eq(err.code, "INVALID_OPTIONS")
end)

t.test("repair preserves tinted backgrounds and muted accents by default", function()
  for _, slot in ipairs({"bg", "0"}) do
    local text = "- " .. slot .. ": #19194f\n- fg: #555566\n"
    local fixed = assert(lgen.fix_string(text))
    t.assert_eq(#fixed.after.fails, 0)
    t.assert_eq(#fixed.edits, 1)
    t.assert_eq(fixed.edits[1].slot, "fg")
    local opted_in = assert(lgen.fix_string("- " .. slot .. ": #19194f\n- fg: #ffffff\n", {fix_background=true}))
    t.assert_true(not opted_in.content:find("#19194f", 1, true))
  end
  local muted = "- bg: #ffffff\n- blue: #666677\n"
  t.assert_eq(assert(lgen.fix_string(muted)).content, muted)
  t.assert_eq(#assert(lgen.fix_string(muted, {vibrant=true})).edits, 1)
end)

t.test("equally effective contrast repairs prefer the color closer to its target", function()
  local text = "- bg: #000000\n- white: #111111\n- fg: #888888\n"
  local fixed = assert(lgen.fix_string(text, {max_iterations=1}))
  t.assert_eq(#fixed.edits, 1)
  t.assert_eq(fixed.edits[1].slot, "fg")
end)

t.test("red and green collision repair verifies both color vision simulations", function()
  local text = "- bg: #000000\n- red: #8c7150\n- green: #8c7150\n"
  local fixed = assert(lgen.fix_string(text))
  t.assert_true(#fixed.before.fails > 0)
  t.assert_eq(#fixed.after.fails, 0)
  t.assert_eq(assert(lgen.fix_string(fixed.content)).content, fixed.content)
end)

t.test("document edits do not cascade and support table entries", function()
  local text = "| bg | #ABCDEF |\n| 1 | #abc |\n| 2 | #123456 |\n"
  local doc = lgen.markdown_parser.parse(text)
  local out = lgen.markdown_parser.apply_edits(doc, {
    {slot=1, new_hex="#123456"}, {slot=2, new_hex="#aabbcc"},
  })
  t.assert_eq(out, "| bg | #ABCDEF |\n| 1 | #123456 |\n| 2 | #aabbcc |\n")
end)

t.test("metadata comments are honored and malformed colors are not truncated", function()
  local diag = assert(lgen.audit_string("---\nstrictness: relaxed # preset\n---\n- bg: #000000\n"))
  t.assert_eq(diag.metrics.strictness, "relaxed")
  local invalid, err = lgen.audit_string("- bg: #1234\n")
  t.assert_eq(invalid, nil)
  t.assert_eq(err.code, "INVALID_THEME")
end)

t.test("malformed workflow arguments return structured errors", function()
  for _, opts in ipairs({"strict", {meta="strict"}, {ignore={typo="LOW_CONTRAST"}}}) do
    local diag, err = lgen.audit_string("- bg: #000000", opts)
    t.assert_eq(diag, nil)
    t.assert_eq(err.code, "INVALID_OPTIONS")
  end
  local diag, err = lgen.audit_file(false)
  t.assert_eq(diag, nil)
  t.assert_eq(err.code, "INVALID_INPUT")
end)
