-- tests/test_fuzz_and_edges.lua
-- Precautionary edge-case & property-based stress tests for lgen

local runner = require("tests.run")
local test = runner.test
local assert_near = runner.assert_near
local assert_eq = runner.assert_eq
local assert_true = runner.assert_true

package.path = package.path .. ";./?.lua;./?/init.lua"
local cm = require("lgen.color_math")
local parser = require("lgen.markdown_parser")
local auditor = require("lgen.auditor")
local fixer = require("lgen.fixer")
local reporter = require("lgen.reporter")

test("edge case: mathematical singularities and boundaries", function()
  -- Black on Black
  local black = { r = 0, g = 0, b = 0 }
  local wcag_bb = cm.wcag_contrast(black, black)
  assert_eq(wcag_bb, 1.0, "Black on black WCAG should be 1.0")
  local apca_bb = cm.apca(black, black)
  assert_eq(apca_bb, 0.0, "Black on black APCA should be 0.0")

  -- White on White
  local white = { r = 1, g = 1, b = 1 }
  local wcag_ww = cm.wcag_contrast(white, white)
  assert_eq(wcag_ww, 1.0, "White on white WCAG should be 1.0")
  local apca_ww = cm.apca(white, white)
  assert_eq(apca_ww, 0.0, "White on white APCA should be 0.0")

  -- Neutral Gray Oklab hue singularity (a=0, b=0 -> hue should be 0 or in [0, 360))
  local gray = cm.rgb_to_oklab({ r = 0.5, g = 0.5, b = 0.5 })
  local lch_gray = cm.oklab_to_oklch(gray)
  assert_true(lch_gray.C < 1e-4, "Gray chroma should be near 0")
  assert_true(lch_gray.h >= 0 and lch_gray.h <= 360, "Gray hue should be in valid range")
end)

test("edge case: malformed, empty, and adversarial Markdown inputs", function()
  -- Completely empty string
  local empty_doc = parser.parse("")
  assert_true(empty_doc.palette ~= nil)
  local diag_empty = auditor.audit(empty_doc.palette)
  assert_true(diag_empty ~= nil)

  -- Windows CRLF line endings
  local crlf_md = "- bg: #121212\r\n- fg: #ffffff\r\n- red: #ff0000\r\n"
  local crlf_doc = parser.parse(crlf_md)
  assert_eq(crlf_doc.palette.bg.hex, "#121212")
  assert_eq(crlf_doc.palette.fg.hex, "#ffffff")
  assert_eq(crlf_doc.palette[1].hex, "#ff0000")

  -- Adversarial garbage and broken hexes
  local garbage = [[
# Random Notes
- broken: #1234
- not_a_hex: #zzzzzz
- empty_hex: #
- just_text: red
- invalid_slot: #abcdef
| broken | table |||
  ]]
  local garbage_doc = parser.parse(garbage)
  local diag_garbage = auditor.audit(garbage_doc.palette)
  assert_true(diag_garbage ~= nil, "Auditor should handle garbage doc without throwing")
end)

test("property test: fixer never produces NaN or crashes on 200 random colors", function()
  math.randomseed(42)
  for _ = 1, 200 do
    local r = math.random()
    local g = math.random()
    local b = math.random()
    local bg_r = math.random()
    local bg_g = math.random()
    local bg_b = math.random()

    local fg = { r = r, g = g, b = b, hex = cm.rgb_to_hex({ r = r, g = g, b = b }) }
    local bg = { r = bg_r, g = bg_g, b = bg_b, hex = cm.rgb_to_hex({ r = bg_r, g = bg_g, b = bg_b }) }

    -- Adjust contrast
    local fixed_hex = fixer.adjust_contrast(fg, bg, 50.0)
    assert_true(type(fixed_hex) == "string", "Fixed hex should be string")
    assert_true(#fixed_hex == 7, "Fixed hex should be #rrggbb, got: " .. tostring(fixed_hex))
    assert_true(fixed_hex:match("^#%x%x%x%x%x%x") ~= nil, "Fixed hex should be valid hex format")

    -- Adjust CVD
    local fixed_cvd = fixer.adjust_cvd_pair(fg, bg, bg, "protan")
    assert_true(type(fixed_cvd) == "string")
    assert_true(#fixed_cvd == 7)
    assert_true(fixed_cvd:match("^#%x%x%x%x%x%x") ~= nil)
  end
end)

test("edge case: reporter handles incomplete palettes without throwing", function()
  -- Palette with only 2 colors defined
  local minimal_doc = parser.parse("- bg: #101010\n- fg: #f0f0f0\n")
  local diag = auditor.audit(minimal_doc.palette)

  local term = reporter.format_terminal(diag, minimal_doc)
  assert_true(type(term) == "string" and #term > 0)

  local json = reporter.format_json(diag)
  assert_true(type(json) == "string" and #json > 0)

  local md = reporter.format_markdown(diag, minimal_doc)
  assert_true(type(md) == "string" and #md > 0)
end)
