-- tests/test_auditor.lua
local runner = require("tests.run")
local test = runner.test
local assert_near = runner.assert_near
local assert_eq = runner.assert_eq
local assert_true = runner.assert_true

package.path = package.path .. ";./?.lua;./?/init.lua"
local auditor = require("lgen.auditor")

test("auditor catches low contrast and comment issues", function()
  local bad_palette = {
    bg = "#121212",
    fg = "#d0d0d0",
    [0]  = "#1c1c1c",
    [1]  = "#f38ba8",
    [2]  = "#a6e3a1",
    [3]  = "#f9e2af",
    [4]  = "#102040", -- very dark blue (contrast fail)
    [5]  = "#f5c2e7",
    [6]  = "#94e2d5",
    [7]  = "#bac2de",
    [8]  = "#1a1a1a", -- invisible comment (contrast fail)
    [9]  = "#f38ba8",
    [10] = "#a6e3a1",
    [11] = "#f9e2af",
    [12] = "#89b4fa",
    [13] = "#f5c2e7",
    [14] = "#94e2d5",
    [15] = "#a6adc8",
  }

  local res = auditor.audit(bad_palette)
  assert_true(#res.fails > 0, "Should have failures")

  local found_blue_fail = false
  local found_comment_fail = false
  for _, f in ipairs(res.fails) do
    if f.code == "LOW_CONTRAST" and f.context.slot == 4 then
      found_blue_fail = true
    end
    if f.code == "COMMENT_ILLEGIBLE" then
      found_comment_fail = true
    end
  end
  assert_true(found_blue_fail, "Should flag Blue (slot 4) as low contrast")
  assert_true(found_comment_fail, "Should flag Comment (slot 8) as illegible")
end)

test("auditor catches inverted bright pair", function()
  local inverted_palette = {
    bg = "#121212",
    fg = "#d0d0d0",
    [0] = "#1c1c1c",
    [1] = "#ff6b6b", -- light red
    [2] = "#51cf66",
    [3] = "#fcc419",
    [4] = "#339af0",
    [5] = "#cc5de8",
    [6] = "#20c997",
    [7] = "#f1f3f5",
    [8] = "#868e96",
    [9] = "#801010", -- DARK bright red! (inverted)
    [10] = "#51cf66",
    [11] = "#fcc419",
    [12] = "#339af0",
    [13] = "#cc5de8",
    [14] = "#20c997",
    [15] = "#ffffff",
  }

  local res = auditor.audit(inverted_palette)
  local found_inverted = false
  for _, w in ipairs(res.warns) do
    if w.code == "INVERTED_BRIGHT_PAIR" and w.context.bright == 9 then
      found_inverted = true
    end
  end
  assert_true(found_inverted, "Should warn about ANSI 9 being darker than ANSI 1")
end)

test("auditor catches syntax collision", function()
  local collision_palette = {
    bg = "#121212",
    fg = "#d0d0d0",
    [0] = "#1c1c1c",
    [1] = "#e06c75", -- red
    [2] = "#e06c76", -- almost identical to red!
    [3] = "#e5c07b",
    [4] = "#61afef",
    [5] = "#c678dd",
    [6] = "#56b6c2",
    [7] = "#abb2bf",
    [8] = "#5c6370",
    [9] = "#e06c75",
    [10] = "#98c379",
    [11] = "#e5c07b",
    [12] = "#61afef",
    [13] = "#c678dd",
    [14] = "#56b6c2",
    [15] = "#ffffff",
  }

  local res = auditor.audit(collision_palette)
  local found_collision = false
  for _, f in ipairs(res.fails) do
    if f.code == "SYNTAX_COLLISION" and f.context.a == 1 and f.context.b == 2 then
      found_collision = true
    end
  end
  assert_true(found_collision, "Should fail on identical syntax slots 1 and 2")
end)
