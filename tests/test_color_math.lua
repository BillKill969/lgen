-- tests/test_color_math.lua
local runner = require("tests.run")
local test = runner.test
local assert_near = runner.assert_near
local assert_eq = runner.assert_eq
local assert_true = runner.assert_true

package.path = package.path .. ";./?.lua;./?/init.lua"
local cm = require("lgen.color_math")

test("hex_to_rgb and rgb_to_hex conversions", function()
  local rgb = cm.hex_to_rgb("#ff0000")
  assert_near(rgb.r, 1.0, 1e-4)
  assert_near(rgb.g, 0.0, 1e-4)
  assert_near(rgb.b, 0.0, 1e-4)
  assert_eq(cm.rgb_to_hex(rgb), "#ff0000")

  -- 3-digit shorthand
  local short = cm.hex_to_rgb("#0f0")
  assert_near(short.r, 0.0, 1e-4)
  assert_near(short.g, 1.0, 1e-4)
  assert_near(short.b, 0.0, 1e-4)
  assert_eq(cm.rgb_to_hex(short), "#00ff00")

  -- Case insensitivity and whitespace
  local messy = cm.hex_to_rgb("  #aAbBcC  ")
  assert_eq(messy.hex, "#aabbcc")
end)

test("sRGB linearization and inverse roundtrip", function()
  local test_vals = { 0.0, 0.04045, 0.1, 0.5, 0.8, 1.0 }
  for _, c in ipairs(test_vals) do
    local lin = cm.srgb_to_linear(c)
    local inv = cm.linear_to_srgb(lin)
    assert_near(inv, c, 1e-4, "roundtrip for " .. c)
  end
end)

test("Oklab conversion matches Ottosson 2020 reference fixtures", function()
  -- Reference values from Björn Ottosson's specification
  local white = cm.rgb_to_oklab({ r = 1, g = 1, b = 1 })
  assert_near(white.L, 1.0, 1e-4, "White L")
  assert_near(white.a, 0.0, 1e-4, "White a")
  assert_near(white.b, 0.0, 1e-4, "White b")

  local black = cm.rgb_to_oklab({ r = 0, g = 0, b = 0 })
  assert_near(black.L, 0.0, 1e-4, "Black L")
  assert_near(black.a, 0.0, 1e-4, "Black a")
  assert_near(black.b, 0.0, 1e-4, "Black b")

  local red = cm.rgb_to_oklab({ r = 1, g = 0, b = 0 })
  assert_near(red.L, 0.627955, 1e-3, "Red L")
  assert_near(red.a, 0.224863, 1e-3, "Red a")
  assert_near(red.b, 0.125846, 1e-3, "Red b")

  local green = cm.rgb_to_oklab({ r = 0, g = 1, b = 0 })
  assert_near(green.L, 0.866440, 1e-3, "Green L")
  assert_near(green.a, -0.233888, 1e-3, "Green a")
  assert_near(green.b, 0.179498, 1e-3, "Green b")

  local blue = cm.rgb_to_oklab({ r = 0, g = 0, b = 1 })
  assert_near(blue.L, 0.452014, 1e-3, "Blue L")
  assert_near(blue.a, -0.032457, 1e-3, "Blue a")
  assert_near(blue.b, -0.311528, 1e-3, "Blue b")
end)

test("Oklab to RGB inverse roundtrip", function()
  local colors = {
    { r = 1, g = 0, b = 0 },
    { r = 0.2, g = 0.7, b = 0.4 },
    { r = 0.8, g = 0.5, b = 0.9 },
    { r = 0.12, g = 0.12, b = 0.12 },
  }
  for _, rgb in ipairs(colors) do
    local lab = cm.rgb_to_oklab(rgb)
    local inv = cm.oklab_to_rgb(lab)
    assert_near(inv.r, rgb.r, 1e-3)
    assert_near(inv.g, rgb.g, 1e-3)
    assert_near(inv.b, rgb.b, 1e-3)
  end
end)

test("Oklch cylindrical conversion and hue calculations", function()
  local red = cm.rgb_to_oklab({ r = 1, g = 0, b = 0 })
  local lch_red = cm.oklab_to_oklch(red)
  assert_true(lch_red.C > 0.2, "Red should have substantial chroma")
  assert_true(lch_red.h >= 20 and lch_red.h <= 40, "Red hue should be ~29 degrees")

  local green = cm.rgb_to_oklab({ r = 0, g = 1, b = 0 })
  local lch_green = cm.oklab_to_oklch(green)
  assert_true(lch_green.h >= 135 and lch_green.h <= 150, "Green hue should be ~142 degrees")

  local blue = cm.rgb_to_oklab({ r = 0, g = 0, b = 1 })
  local lch_blue = cm.oklab_to_oklch(blue)
  assert_true(lch_blue.h >= 250 and lch_blue.h <= 275, "Blue hue should be ~264 degrees")
end)

test("APCA 0.98G standard reference values", function()
  local black = { r = 0, g = 0, b = 0 }
  local white = { r = 1, g = 1, b = 1 }

  -- Black on White (normal polarity) should be approx +106.0
  local boW = cm.apca(black, white)
  assert_near(boW, 106.04, 0.5, "Black text on White bg APCA")

  -- White on Black (reverse polarity) should be approx -107.9
  local woB = cm.apca(white, black)
  assert_near(woB, -107.88, 0.5, "White text on Black bg APCA")

  -- Identical colors should return 0.0
  assert_near(cm.apca(black, black), 0.0, 1e-4)
  assert_near(cm.apca(white, white), 0.0, 1e-4)
end)

test("WCAG 2.1 contrast calculations", function()
  local black = { r = 0, g = 0, b = 0 }
  local white = { r = 1, g = 1, b = 1 }
  assert_near(cm.wcag_contrast(white, black), 21.0, 0.01)
  assert_near(cm.wcag_contrast(black, black), 1.0, 0.01)
end)

test("Color Vision Deficiency (CVD) simulation preserves luminance bounds", function()
  local red = { r = 1, g = 0, b = 0 }
  for _, cvd in ipairs({ "protan", "deutan", "tritan" }) do
    local sim = cm.sim_cvd(red, cvd)
    assert_true(sim.r >= 0 and sim.r <= 1, "r in bounds for " .. cvd)
    assert_true(sim.g >= 0 and sim.g <= 1, "g in bounds for " .. cvd)
    assert_true(sim.b >= 0 and sim.b <= 1, "b in bounds for " .. cvd)
  end
end)
