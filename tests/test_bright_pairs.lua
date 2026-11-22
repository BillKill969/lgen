local t = require("tests.run")
local lgen = require("lgen")
local cm = lgen.color_math

local function find(diag, code)
  for _, item in ipairs(diag.warns) do
    if item.code == code then return item end
  end
end

t.test("identical bright accents get actionable separation diagnostics", function()
  local diag = assert(lgen.audit_string("- bg: #000000\n- red: #fa92ae\n- bright_red: #fa92ae\n"))
  local item = assert(find(diag, "INDISTINCT_BRIGHT_PAIR"))
  t.assert_eq(item.context.slot, 9)
  t.assert_eq(item.category, "semantics")
  local normal = cm.rgb_to_oklab(cm.hex_to_rgb("#fa92ae"))
  local bright = cm.rgb_to_oklab(assert(cm.hex_to_rgb(item.suggested_hex)))
  t.assert_true(bright.L - normal.L >= 0.06)
end)

t.test("fix plans separate bright slots without changing normal colors", function()
  local text = "---\nignore:\n  - HUE_SECTOR_MISMATCH\n---\n- bg: #0f0f0f\n- red: #fa92ae\n- bright_red: #fa92ae\n- blue: #89b4fa\n- bright_blue: #89b4fa\n"
  local result = assert(lgen.fix_string(text))
  t.assert_eq(#result.after.fails, 0)
  t.assert_eq(#result.after.warns, 0)
  t.assert_eq(#result.edits, 2)
  local doc = lgen.markdown_parser.parse(result.content)
  t.assert_eq(doc.palette[1].hex, "#fa92ae")
  t.assert_eq(doc.palette[4].hex, "#89b4fa")
  for _, slot in ipairs({1, 4}) do
    local normal = cm.oklab_to_oklch(cm.rgb_to_oklab(doc.palette[slot]))
    local bright = cm.oklab_to_oklch(cm.rgb_to_oklab(doc.palette[slot+8]))
    t.assert_true(bright.L - normal.L >= 0.06)
    t.assert_true(cm.hue_difference(normal.h, bright.h) < 3)
    t.assert_true(math.abs(cm.apca(doc.palette[slot+8], doc.palette.bg)) >= 60)
    t.assert_true(cm.wcag_contrast(doc.palette[slot+8], doc.palette.bg) >= 4.5)
  end
  t.assert_eq(#assert(lgen.fix_string(result.content)).edits, 0)
end)

t.test("bright separation respects light-theme contrast", function()
  local result = assert(lgen.fix_string("---\nignore:\n  - MUTED_COLOR\n---\n- bg: #ffffff\n- blue: #335577\n- bright_blue: #335577\n"))
  local doc = lgen.markdown_parser.parse(result.content)
  t.assert_eq(doc.palette[4].hex, "#335577")
  t.assert_true(math.abs(cm.rgb_to_oklab(doc.palette[12]).L - cm.rgb_to_oklab(doc.palette[4]).L) >= 0.06)
  t.assert_true(cm.wcag_contrast(doc.palette[12], doc.palette.bg) >= 3)
  t.assert_true(math.abs(cm.apca(doc.palette[12], doc.palette.bg)) >= 45)
  t.assert_true(not find(result.after, "INDISTINCT_BRIGHT_PAIR"))
end)

t.test("bright separation can move the normal slot when the bright slot is at the gamut limit", function()
  local result = assert(lgen.fix_string("- bg: #000000\n- white: #ffffff\n- bright_white: #ffffff\n"))
  local item = assert(find(result.before, "INDISTINCT_BRIGHT_PAIR"))
  t.assert_eq(item.suggested_hex, nil)
  t.assert_eq(#result.edits, 1)
  t.assert_eq(result.edits[1].slot, 7)
  t.assert_eq(result.status, "resolved")
end)

t.test("inverted whites can be repaired together in one step", function()
  local text = "- bg: #000000\n- white: #ffffff\n- bright_white: #bbbbbb\n"
  local result = assert(lgen.fix_string(text, {max_iterations=1}))
  t.assert_eq(result.iterations, 1)
  t.assert_eq(#result.edits, 2)
  t.assert_eq(result.edits[1].slot, 7)
  t.assert_eq(result.edits[2].slot, 15)
  t.assert_eq(#result.after.fails, 0)
  t.assert_eq(result.status, "resolved")
  t.assert_true(result.after.metrics.bright_pairs[15].separation >= 0.06)
end)
