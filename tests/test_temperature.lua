-- tests/test_temperature.lua
local runner = require("tests.run")
local test = runner.test
local assert_near = runner.assert_near
local assert_eq = runner.assert_eq
local assert_true = runner.assert_true

package.path = package.path .. ";./?.lua;./?/init.lua"
local cm = require("lgen.color_math")
local auditor = require("lgen.auditor")
local fixer = require("lgen.fixer")

test("color_math calculates warmth index and classifies temperature", function()
  -- Pure Blue is cold
  local cold_blue = cm.rgb_to_oklab({ r = 0.1, g = 0.15, b = 0.35 })
  local w_cold = cm.warmth_index(cold_blue)
  assert_true(w_cold < -0.02, "Cool blue should have negative warmth index")

  -- Warm amber/brown is warm
  local warm_amber = cm.rgb_to_oklab({ r = 0.35, g = 0.25, b = 0.1 })
  local w_warm = cm.warmth_index(warm_amber)
  assert_true(w_warm > 0.02, "Warm amber should have positive warmth index")

  -- Neutral gray
  local neutral_gray = cm.rgb_to_oklab({ r = 0.2, g = 0.2, b = 0.2 })
  local w_neutral = cm.warmth_index(neutral_gray)
  assert_near(w_neutral, 0.0, 0.005, "Neutral gray warmth should be ~0")
end)

test("auditor detects background that is too cold or too warm", function()
  -- Excessive cold blue background (#051040: b* < -0.06)
  local too_cold_palette = {
    bg = "#051040",
    fg = "#ffffff",
    [0] = "#051040",
    [8] = "#6070a0",
  }
  local res_cold = auditor.audit(too_cold_palette)
  local found_cold_warn = false
  for _, w in ipairs(res_cold.warns) do
    if w.code == "BACKGROUND_TOO_COLD" then
      found_cold_warn = true
    end
  end
  assert_true(found_cold_warn, "Should warn about background being too cold")

  -- Excessive warm muddy background (#402805: b* > +0.05)
  local too_warm_palette = {
    bg = "#402805",
    fg = "#ffffff",
    [0] = "#402805",
    [8] = "#a08060",
  }
  local res_warm = auditor.audit(too_warm_palette)
  local found_warm_warn = false
  for _, w in ipairs(res_warm.warns) do
    if w.code == "BACKGROUND_TOO_WARM" then
      found_warm_warn = true
    end
  end
  assert_true(found_warm_warn, "Should warn about background being too warm")
end)

test("auditor detects temperature clash between background and foreground/comment", function()
  -- Cool slate background (#161b22, w ~ -0.015) paired with glaringly warm yellow comment (#a08030, w ~ +0.06)
  local clash_palette = {
    bg = "#161b22",
    fg = "#e6edf3",
    [0] = "#0d1117",
    [8] = "#a08030", -- strongly warm comment on cool bg!
  }
  local res = auditor.audit(clash_palette)
  local found_clash = false
  for _, w in ipairs(res.warns) do
    if w.code == "TEMPERATURE_CLASH" and w.context.slot == 8 then
      found_clash = true
    end
  end
  assert_true(found_clash, "Should warn about temperature clash between cool bg and warm comment")
end)

test("fixer re-anchors background temperature into balanced zone", function()
  local too_cold_bg = cm.hex_to_rgb("#051040")
  local balanced_hex = fixer.anchor_temperature(too_cold_bg, "balanced")
  assert_true(balanced_hex ~= nil)

  local balanced_rgb = cm.hex_to_rgb(balanced_hex)
  local lab = cm.rgb_to_oklab(balanced_rgb)
  local w = cm.warmth_index(lab)
  assert_true(w >= -0.035 and w <= 0.025, "Balanced warmth should be in [-0.035, 0.025], got " .. w)
end)
