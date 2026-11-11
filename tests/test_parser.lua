-- tests/test_parser.lua
local runner = require("tests.run")
local test = runner.test
local assert_near = runner.assert_near
local assert_eq = runner.assert_eq
local assert_true = runner.assert_true

package.path = package.path .. ";./?.lua;./?/init.lua"
local parser = require("lgen.markdown_parser")

test("parse key-value list format with aliases", function()
  local md = [[
# My Theme

Some description here.

- bg: #1e1e2e
- fg: #cdd6f4
- black: #45475a
- red: #f38ba8
- green: #a6e3a1
- yellow: #f9e2af
- blue: #89b4fa
- purple: #f5c2e7
- teal: #94e2d5
- white: #bac2de
- comment: #585b70
- bright_red: #f38ba8
- bright_green: #a6e3a1
- bright_yellow: #f9e2af
- bright_blue: #89b4fa
- bright_magenta: #f5c2e7
- bright_cyan: #94e2d5
- bright_white: #a6adc8
  ]]

  local result = parser.parse(md)
  assert_true(result ~= nil, "result should not be nil")
  local pal = result.palette
  assert_eq(pal.bg.hex, "#1e1e2e")
  assert_eq(pal.fg.hex, "#cdd6f4")
  assert_eq(pal[0].hex, "#45475a")
  assert_eq(pal[1].hex, "#f38ba8")
  assert_eq(pal[2].hex, "#a6e3a1")
  assert_eq(pal[3].hex, "#f9e2af")
  assert_eq(pal[4].hex, "#89b4fa")
  assert_eq(pal[5].hex, "#f5c2e7") -- purple mapped to magenta (5)
  assert_eq(pal[6].hex, "#94e2d5") -- teal mapped to cyan (6)
  assert_eq(pal[7].hex, "#bac2de")
  assert_eq(pal[8].hex, "#585b70") -- comment mapped to bright_black (8)
  assert_eq(pal[9].hex, "#f38ba8")
  assert_eq(pal[15].hex, "#a6adc8")
end)

test("parse markdown table format", function()
  local md = [[
| Slot | Name | Hex |
|---|---|---|
| bg | Background | #181825 |
| fg | Foreground | #cdd6f4 |
| 0  | Black      | #313244 |
| 1  | Red        | #f38ba8 |
| 2  | Green      | #a6e3a1 |
| 3  | Yellow     | #f9e2af |
| 4  | Blue       | #89b4fa |
| 5  | Magenta    | #f5c2e7 |
| 6  | Cyan       | #94e2d5 |
| 7  | White      | #bac2de |
| 8  | Gray       | #45475a |
| 9  | B.Red      | #eba0ac |
| 10 | B.Green    | #a6e3a1 |
| 11 | B.Yellow   | #f9e2af |
| 12 | B.Blue     | #89b4fa |
| 13 | B.Magenta  | #f5c2e7 |
| 14 | B.Cyan     | #94e2d5 |
| 15 | B.White    | #a6adc8 |
  ]]

  local result = parser.parse(md)
  local pal = result.palette
  assert_eq(pal.bg.hex, "#181825")
  assert_eq(pal[0].hex, "#313244")
  assert_eq(pal[8].hex, "#45475a")
  assert_eq(pal[9].hex, "#eba0ac")
end)

test("parse YAML frontmatter metadata and overrides", function()
  local md = [[---
name: Solarized Minimal
strictness: relaxed
ignore:
  - hue_fidelity
---
- bg: #002b36
- fg: #839496
- 0: #073642
- 1: #dc322f
]]

  local result = parser.parse(md)
  assert_eq(result.meta.name, "Solarized Minimal")
  assert_eq(result.meta.strictness, "relaxed")
  assert_true(result.meta.ignore ~= nil)
  assert_eq(result.meta.ignore[1], "hue_fidelity")
  assert_eq(result.palette.bg.hex, "#002b36")
  assert_eq(result.palette[1].hex, "#dc322f")
end)
