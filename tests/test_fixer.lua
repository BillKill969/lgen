-- tests/test_fixer.lua
local runner = require("tests.run")
local test = runner.test
local assert_near = runner.assert_near
local assert_eq = runner.assert_eq
local assert_true = runner.assert_true

package.path = package.path .. ";./?.lua;./?/init.lua"
local cm = require("lgen.color_math")
local fixer = require("lgen.fixer")

test("fixer adjusts dark text to meet APCA contrast target", function()
  local bg = cm.hex_to_rgb("#121212")
  local failing_fg = cm.hex_to_rgb("#2c3e50") -- APCA contrast against #121212 is nearly zero

  local fixed_hex = fixer.adjust_contrast(failing_fg, bg, 45.0)
  assert_true(fixed_hex ~= nil, "fixed_hex should not be nil")

  local fixed_rgb = cm.hex_to_rgb(fixed_hex)
  local new_apca = math.abs(cm.apca(fixed_rgb, bg))
  assert_true(new_apca >= 44.5, "New APCA should be >= 45, got " .. new_apca)
end)

test("fixer resolves CVD diff collision between red and green", function()
  local red = cm.hex_to_rgb("#c0392b")
  local green = cm.hex_to_rgb("#27ae60")
  local bg = cm.hex_to_rgb("#121212")

  local fixed_green_hex = fixer.adjust_cvd_pair(green, red, bg, "protan")
  assert_true(fixed_green_hex ~= nil)

  local fixed_green = cm.hex_to_rgb(fixed_green_hex)
  local sim_r = cm.sim_cvd(red, "protan")
  local sim_g = cm.sim_cvd(fixed_green, "protan")
  local lab_r = cm.rgb_to_oklab(sim_r)
  local lab_g = cm.rgb_to_oklab(sim_g)
  local dL = math.abs(lab_r.L - lab_g.L)
  assert_true(dL >= 0.08, "CVD lightness difference should be >= 0.08, got " .. dL)
end)
