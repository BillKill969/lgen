-- tests/test_color_refinements.lua
-- Unit tests for all color science improvements: gamut mapping, hue limits,
-- comment saturation ceiling, syntax lightness balance, and camouflage.

local runner = require("tests.run")
local test = runner.test
local assert_near = runner.assert_near
local assert_eq = runner.assert_eq
local assert_true = runner.assert_true

package.path = package.path .. ";./?.lua;./?/init.lua"
local cm = require("lgen.color_math")
local auditor = require("lgen.auditor")
local fixer = require("lgen.fixer")

test("constant-hue chroma reduction approximately preserves realized hue", function()
  -- High-chroma cyan (C=0.30 at L=0.85, h=195°) is far outside the sRGB gamut
  local out_lch = { L = 0.85, C = 0.30, h = 195.0 }
  local fitted = cm.fit_oklch_to_gamut(out_lch)

  assert_true(fitted.r >= 0 and fitted.r <= 1.0)
  assert_true(fitted.g >= 0 and fitted.g <= 1.0)
  assert_true(fitted.b >= 0 and fitted.b <= 1.0)

  -- Re-convert to Oklch and verify hue angle did NOT rotate
  local re_lab = cm.rgb_to_oklab(fitted)
  local re_lch = cm.oklab_to_oklch(re_lab)
  local hue_diff = cm.hue_difference(re_lch.h, out_lch.h)
  assert_true(hue_diff < 1.0, "Hue difference after gamut mapping should be < 1.0°, got " .. hue_diff)
end)

test("project chroma preferences vary by hue", function()
  local yellow_lim = cm.get_hue_chroma_limits(90.0)
  local cyan_lim = cm.get_hue_chroma_limits(190.0)
  local magenta_lim = cm.get_hue_chroma_limits(320.0)

  -- The project prefers higher minimum chroma for yellow than cyan or magenta.
  assert_true(yellow_lim.min > cyan_lim.min, "Yellow min chroma should exceed Cyan min chroma")
  assert_true(cyan_lim.min >= magenta_lim.min, "Cyan min chroma should be >= Magenta min chroma")
end)

test("auditor flags overly saturated comments (COMMENT_OVERLY_SATURATED)", function()
  local saturated_comment_palette = {
    bg = "#121212",
    fg = "#d0d0d0",
    [0] = "#121212",
    [1] = "#e06c75",
    [2] = "#98c379",
    [3] = "#e5c07b",
    [4] = "#61afef",
    [5] = "#c678dd",
    [6] = "#56b6c2",
    [7] = "#abb2bf",
    [8] = "#9d7cd8", -- vivid purple comment! (C ~ 0.12 > 0.045)
  }

  local res = auditor.audit(saturated_comment_palette)
  local found_sat_comment = false
  for _, w in ipairs(res.warns) do
    if w.code == "COMMENT_OVERLY_SATURATED" then
      found_sat_comment = true
    end
  end
  assert_true(found_sat_comment, "Should flag vivid purple comment as overly saturated")

  -- Desaturating comment
  local fixed_hex = fixer.desaturate_comment(cm.hex_to_rgb("#9d7cd8"), cm.hex_to_rgb("#121212"))
  local fixed_rgb = cm.hex_to_rgb(fixed_hex)
  local fixed_lch = cm.oklab_to_oklch(cm.rgb_to_oklab(fixed_rgb))
  assert_true(fixed_lch.C <= 0.035, "Fixed comment chroma should be <= 0.035, got " .. fixed_lch.C)
end)

test("auditor detects comment temperature mismatch on tinted background", function()
  local mismatch_palette = {
    bg = "#161b22", -- cool dark blue background (w ~ -0.015)
    fg = "#e6edf3",
    [0] = "#161b22",
    [8] = "#8c7e5a", -- distinctly warm yellowish-brown comment (w ~ +0.03)
  }

  local res = auditor.audit(mismatch_palette)
  local found_mismatch = false
  for _, w in ipairs(res.warns) do
    if w.code == "COMMENT_TEMPERATURE_MISMATCH" then
      found_mismatch = true
    end
  end
  assert_true(found_mismatch, "Should flag warm comment on cool background as temperature mismatch")
end)

test("auditor detects accent lightness imbalance (ACCENT_LIGHTNESS_IMBALANCE)", function()
  -- Severely imbalanced palette: Yellow is glaring (L=0.95), Blue is dim (L=0.58)
  local imbalanced_palette = {
    bg = "#101010",
    fg = "#e0e0e0",
    [0] = "#101010",
    [1] = "#e06c75", -- L ~ 0.65
    [2] = "#98c379", -- L ~ 0.76
    [3] = "#ffff55", -- L ~ 0.96 (glaringly bright!)
    [4] = "#336699", -- L ~ 0.52 (very dark blue!)
    [5] = "#c678dd", -- L ~ 0.68
    [6] = "#56b6c2", -- L ~ 0.74
    [7] = "#abb2bf",
    [8] = "#707070",
  }

  local res = auditor.audit(imbalanced_palette)
  local found_imbalance = false
  for _, w in ipairs(res.warns) do
    if w.code == "ACCENT_LIGHTNESS_IMBALANCE" then
      found_imbalance = true
    end
  end
  assert_true(found_imbalance, "Should warn about excessive accent lightness spread")

  -- Check fixer balances accent lightness
  local fixed_hex = fixer.balance_accent_lightness(cm.hex_to_rgb("#ffff55"), 0.78, cm.hex_to_rgb("#101010"))
  local fixed_rgb = cm.hex_to_rgb(fixed_hex)
  local fixed_lab = cm.rgb_to_oklab(fixed_rgb)
  assert_true(fixed_lab.L <= 0.85, "Fixed accent lightness should be <= 0.85, got " .. fixed_lab.L)
end)

test("auditor detects background camouflage on tinted background (ACCENT_BACKGROUND_CAMOUFLAGE)", function()
  -- Tinted deep-blue background (#0a1628, h ~ 250°) with dim blue accent (#3a6ea5, h ~ 250°)
  local camo_palette = {
    bg = "#0a1628",
    fg = "#e0e0e0",
    [0] = "#0a1628",
    [1] = "#e06c75",
    [2] = "#98c379",
    [3] = "#e5c07b",
    [4] = "#3a6ea5", -- shares background hue, low pop
    [5] = "#c678dd",
    [6] = "#56b6c2",
    [7] = "#abb2bf",
    [8] = "#5c6d88",
  }

  local res = auditor.audit(camo_palette)
  local found_camo = false
  for _, w in ipairs(res.warns) do
    if w.code == "ACCENT_BACKGROUND_CAMOUFLAGE" and w.context.slot == 4 then
      found_camo = true
    end
  end
  assert_true(found_camo, "Should flag ANSI 4 for background camouflage on blue-tinted background")
end)
