-- tests/test_vibrancy.lua
local runner = require("tests.run")
local test = runner.test
local assert_near = runner.assert_near
local assert_eq = runner.assert_eq
local assert_true = runner.assert_true

package.path = package.path .. ";./?.lua;./?/init.lua"
local cm = require("lgen.color_math")
local auditor = require("lgen.auditor")
local fixer = require("lgen.fixer")

test("auditor flags muted low-chroma syntax colors", function()
  -- Muted pastel palette (Chroma ~ 0.08 - 0.11)
  local muted_palette = {
    bg = "#1e1e2e",
    fg = "#cdd6f4",
    [1] = "#d8a8b8", -- very muted red/pink (C ~ 0.07)
    [2] = "#a6c8a1", -- muted green (C ~ 0.08)
    [3] = "#d8c8a0",
    [4] = "#9ab0d0", -- muted blue
    [5] = "#c8a8d0",
    [6] = "#a0c8c0",
    [7] = "#cdd6f4",
    [8] = "#686b80",
  }

  local res = auditor.audit(muted_palette)
  local found_muted = false
  for _, w in ipairs(res.warns) do
    if w.code == "MUTED_COLOR" and w.context.slot == 1 then
      found_muted = true
    end
  end
  assert_true(found_muted, "Should flag ANSI 1 as muted low-chroma color")
end)

test("fixer boosts vibrancy to make colors rich and punchy instead of washed out", function()
  local muted_blue = cm.hex_to_rgb("#89b4fa") -- C ~ 0.11
  local bg = cm.hex_to_rgb("#1e1e2e")

  local vibrant_hex = fixer.boost_vibrancy(muted_blue, bg, 0.16)
  assert_true(vibrant_hex ~= nil)

  local vibrant_rgb = cm.hex_to_rgb(vibrant_hex)
  local lab = cm.rgb_to_oklab(vibrant_rgb)
  local lch = cm.oklab_to_oklch(lab)
  assert_true(lch.C >= 0.15, "Vibrant chroma should be >= 0.15, got " .. lch.C)
  -- Make sure contrast against bg is still strong
  local apca = math.abs(cm.apca(vibrant_rgb, bg))
  assert_true(apca >= 45.0, "Vibrant color should still maintain APCA >= 45, got " .. apca)
end)
