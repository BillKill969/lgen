-- tests/test_exporter.lua
local runner = require("tests.run")
local test = runner.test
local assert_true = runner.assert_true

package.path = package.path .. ";./?.lua;./?/init.lua"
local exporter = require("lgen.exporter")

test("exporter generates valid configurations for all supported formats", function()
  local pal = {
    bg = "#0f0f0f",
    fg = "#cdd6f4",
    cursor = "#f5e0dc",
    selection = "#45475a",
    [0]  = "#45475a",
    [1]  = "#f38ba8",
    [2]  = "#96c792",
    [3]  = "#f9e2af",
    [4]  = "#89b4fa",
    [5]  = "#f5c2e7",
    [6]  = "#94e2d5",
    [7]  = "#bac2de",
    [8]  = "#9399b2",
    [9]  = "#f7a4ba",
    [10] = "#a6e3a1",
    [11] = "#fdf0cf",
    [12] = "#9bc0fa",
    [13] = "#fad2f0",
    [14] = "#aae8dd",
    [15] = "#cdd6f4",
  }

  local formats = { "kitty", "alacritty", "ghostty", "wezterm", "nvim", "foot", "xresources", "windows_terminal" }
  for _, fmt in ipairs(formats) do
    local out, err = exporter.export(pal, fmt, { name = "Test Theme" })
    assert_true(out ~= nil, "Export should succeed for " .. fmt .. ": " .. tostring(err))
    assert_true(#out > 50, "Export output should have content for " .. fmt)
  end
end)

test("exporter rejects invalid formats with informative error", function()
  local pal = { bg = "#000000", fg = "#ffffff" }
  local out, err = exporter.export(pal, "invalid_format_xyz")
  assert_true(out == nil)
  assert_true(err:find("Unsupported export format") ~= nil)
end)
