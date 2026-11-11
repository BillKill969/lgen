-- lgen/reporter.lua
-- Terminal visual renderer (truecolor ANSI), JSON, and Markdown formatters

local cm = require("lgen.color_math")

local M = {}

local COLOR_NAMES = {
  [0] = "Black", [1] = "Red",     [2] = "Green", [3] = "Yellow",
  [4] = "Blue",  [5] = "Magenta", [6] = "Cyan",  [7] = "White",
  [8] = "Bright Black",   [9] = "Bright Red",     [10] = "Bright Green", [11] = "Bright Yellow",
  [12] = "Bright Blue",   [13] = "Bright Magenta", [14] = "Bright Cyan",  [15] = "Bright White",
  ["bg"] = "Background", ["fg"] = "Foreground",
  ["cursor"] = "Cursor", ["selection"] = "Selection",
}

local function ansi_swatch(rgb)
  if not rgb then return "      " end
  if type(rgb) == "string" then rgb = cm.hex_to_rgb(rgb) end
  if not rgb then return "      " end
  local r = math.floor(rgb.r * 255 + 0.5)
  local g = math.floor(rgb.g * 255 + 0.5)
  local b = math.floor(rgb.b * 255 + 0.5)
  return string.format("\27[48;2;%d;%d;%dm    \27[0m", r, g, b)
end

local function ansi_fg(rgb)
  if not rgb then return "" end
  if type(rgb) == "string" then rgb = cm.hex_to_rgb(rgb) end
  if not rgb then return "" end
  local r = math.floor(rgb.r * 255 + 0.5)
  local g = math.floor(rgb.g * 255 + 0.5)
  local b = math.floor(rgb.b * 255 + 0.5)
  return string.format("\27[38;2;%d;%d;%dm", r, g, b)
end

-- Renders a live 8-line terminal syntax & Git diff preview using palette truecolors
function M.render_syntax_preview(palette, opts)
  opts = opts or {}
  local p = palette or {}
  local fg = p.fg or p[7]

  local col = function(slot, text)
    local rgb = p[slot] or fg
    return ansi_fg(rgb) .. text .. "\27[0m"
  end

  local lines = {}
  local function out(fmt, ...) table.insert(lines, string.format(fmt or "", ...)) end

  out("┌─ \27[1mSyntax & Git Diff Preview\27[0m ──────────────────────────────────┐")
  out("│ %s │", col(8,  "  -- Compute accessible color delta                   "))
  out("│ %s %s %s(theme, opts)                   │", col(5, "  local"), col(5, "function"), col(4, "audit_tokens"))
  out("│ %s delta = opts.strict %s %s %s %s       │", col(5, "    local"), col(5, "and"), col(3, "42"), col(5, "or"), col(3, "0.0"))
  out("│ %s label = %s        │", col(5, "    local"), col(2, "\"Oklab perceptual uniformity\""))
  out("│ %s │", col(1,  "  - local diff_removed = \"legacy contrast failure\"    "))
  out("│ %s │", col(2, "  + local diff_added   = \"accessible diff example\"       "))
  out("│ %s delta > %s %s label %s %s                  │", col(5, "    return"), col(3, "0"), col(5, "and"), col(5, "or"), col(5, "nil"))
  out("│ %s │", col(5,  "  end                                                 "))
  out("└─────────────────────────────────────────────────────────────┘")

  return table.concat(lines, "\n")
end

function M.format_terminal(diag, parsed_doc, opts)
  opts = opts or {}
  local lines = {}
  local function out(fmt, ...) table.insert(lines, string.format(fmt or "", ...)) end

  local theme_name = (parsed_doc and parsed_doc.meta and parsed_doc.meta.name) or "Colorscheme"
  out("")
  out("\27[1;36m━━━ ANSI Colorscheme Audit Report: %s ━━━\27[0m", theme_name)
  local bg_temp = diag.metrics.bg_temperature
  local temp_str = bg_temp and string.format(" | Anchoring: \27[1m%s\27[0m (Warmth: %+.3f, Chroma: %.3f)",
    bg_temp.category, bg_temp.warmth, bg_temp.chroma) or ""
  out("Strictness: \27[1m%s\27[0m | Polarized: \27[1m%s\27[0m%s",
    diag.metrics.strictness, diag.metrics.is_dark and "Dark Theme" or "Light Theme", temp_str)
  local al = diag.metrics.accent_lightness
  if al then
    local balance_label = al.spread <= 0.20 and "\27[32mBalanced\27[0m" or "\27[33mImbalanced\27[0m"
    out("Syntax Balance: Mean L_ok: \27[1m%.2f\27[0m | Spread ΔL: \27[1m%.2f\27[0m | Dispersion σ: \27[1m%.3f\27[0m (%s)",
      al.mean, al.spread, al.std_dev, balance_label)
  end
  out("")

  -- Palette Swatch Overview Table
  out("\27[1mSlot  Name            Hex      Swatch  APCA(bg)  WCAG     L_ok\27[0m")
  out("─────────────────────────────────────────────────────────────────")

  local ordered_keys = { "bg", "fg", 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 }
  local palette = parsed_doc and parsed_doc.palette or {}

  for _, key in ipairs(ordered_keys) do
    local rgb = palette[key]
    if type(rgb) == "string" then rgb = cm.hex_to_rgb(rgb) end
    if rgb then
      local name = COLOR_NAMES[key] or tostring(key)
      local hex = rgb.hex or cm.rgb_to_hex(rgb)
      local swatch = ansi_swatch(rgb)
      local scores = diag.metrics.contrast_scores[key]
      local apca_str = scores and string.format("%+6.1f", scores.apca) or "   -  "
      local wcag_str = scores and string.format("%5.2f:1", scores.wcag) or "   -   "
      local lab = diag.metrics.oklab[key]
      local L_str = lab and string.format("%.2f", lab.L) or " -  "

      local slot_str = string.format("%-4s", tostring(key))
      out("%s  %-14s  %-7s  %s  %s  %s  %s",
        slot_str, name:sub(1, 14), hex, swatch, apca_str, wcag_str, L_str)
    end
  end
  out("─────────────────────────────────────────────────────────────────\n")

  -- Live Terminal Code & Git Diff Preview
  if opts.preview ~= false then
    out("%s\n", M.render_syntax_preview(palette, opts))
  end

  -- List Failures
  if #diag.fails > 0 then
    out("\27[41;1;37m FAILURES (%d) \27[0m", #diag.fails)
    for _, f in ipairs(diag.fails) do
      out("  \27[31m✖\27[0m \27[1m[%s]\27[0m %s", f.code, f.message)
      if f.suggested_hex then
        local fix_rgb = cm.hex_to_rgb(f.suggested_hex)
        local cur_rgb = f.context and f.context.slot and palette[f.context.slot]
        out("    \27[32m↳ Suggested Fix:\27[0m %s %s \27[90m→\27[0m %s \27[1;32m%s\27[0m",
          cur_rgb and ansi_swatch(cur_rgb) or "",
          f.context and f.context.current_hex or "",
          ansi_swatch(fix_rgb),
          f.suggested_hex)
      end
    end
    out("")
  end

  -- List Warnings
  if #diag.warns > 0 then
    out("\27[43;1;30m WARNINGS (%d) \27[0m", #diag.warns)
    for _, w in ipairs(diag.warns) do
      out("  \27[33m⚠\27[0m \27[1m[%s]\27[0m %s", w.code, w.message)
      if w.suggested_hex then
        local fix_rgb = cm.hex_to_rgb(w.suggested_hex)
        local cur_rgb = w.context and w.context.slot and palette[w.context.slot]
        out("    \27[32m↳ Suggested Fix:\27[0m %s %s \27[90m→\27[0m %s \27[1;32m%s\27[0m",
          cur_rgb and ansi_swatch(cur_rgb) or "",
          w.context and w.context.current_hex or "",
          ansi_swatch(fix_rgb),
          w.suggested_hex)
      end
    end
    out("")
  end

  -- Final summary badge
  if #diag.fails == 0 and #diag.warns == 0 then
    out("\27[42;1;30m PASS \27[0m \27[32mAll correctness, contrast, and color vision deficiency checks passed!\27[0m\n")
  elseif #diag.fails == 0 then
    out("\27[43;1;30m PASS WITH WARNINGS \27[0m \27[33mNo breaking failures, %d warning(s) found.\27[0m\n", #diag.warns)
  else
    out("\27[41;1;37m AUDIT FAILED \27[0m \27[31m%d failure(s), %d warning(s) detected.\27[0m\n", #diag.fails, #diag.warns)
  end

  return table.concat(lines, "\n")
end

-- JSON strings use JSON escapes rather than Lua's version-dependent %q.
local function quote_json(value)
  local escapes = { ['"']='\\"', ['\\']='\\\\', ['\b']='\\b', ['\f']='\\f', ['\n']='\\n', ['\r']='\\r', ['\t']='\\t' }
  return '"' .. value:gsub('[%z\1-\31\\"]', function(ch)
    return escapes[ch] or string.format('\\u%04x', ch:byte())
  end) .. '"'
end

local function to_json_val(val)
  local kind = type(val)
  if kind == "number" then
    if val ~= val or val == math.huge or val == -math.huge then return "null" end
    return tostring(val)
  elseif kind == "boolean" then return tostring(val)
  elseif kind == "string" then return quote_json(val)
  elseif kind == "table" then
    local n, max_idx, array = 0, 0, not (getmetatable(val) or {}).__json_object
    for k in pairs(val) do
      n = n + 1
      if type(k) == "number" and k > 0 and k == math.floor(k) then
        max_idx = math.max(max_idx, k)
      else array = false end
    end
    local parts = {}
    if array and n == max_idx then
      for i = 1, n do parts[#parts + 1] = to_json_val(val[i]) end
      return "[" .. table.concat(parts, ",") .. "]"
    end
    local keys = {}
    for k in pairs(val) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for _, k in ipairs(keys) do
      parts[#parts + 1] = quote_json(tostring(k)) .. ":" .. to_json_val(val[k])
    end
    return "{" .. table.concat(parts, ",") .. "}"
  end
  return "null"
end

M.encode_json = to_json_val

local function audit_result(diag)
  local metrics = {}
  for k, v in pairs(diag.metrics) do
    if k == "contrast_scores" or k == "oklab" or k == "oklch" or k == "bright_pairs" then
      local slots = {}
      for slot, score in pairs(v) do slots[tostring(slot)] = score end
      metrics[k] = setmetatable(slots, {__json_object=true})
    else metrics[k] = v end
  end
  return {
    schema_version=1, fails=diag.fails, warns=diag.warns, passes=diag.passes,
    summary={fails=#diag.fails, warns=#diag.warns, passes=#diag.passes}, metrics=metrics,
  }
end

function M.format_json(diag)
  return to_json_val(audit_result(diag))
end

function M.format_fix_json(result)
  return to_json_val({schema_version=1, content=result.content, edits=result.edits,
    before=audit_result(result.before), after=audit_result(result.after),
    iterations=result.iterations, status=result.status, written=result.written or false})
end

function M.format_markdown(diag, parsed_doc)
  local lines = {}
  local function out(fmt, ...) table.insert(lines, string.format(fmt or "", ...)) end

  local name = (parsed_doc and parsed_doc.meta and parsed_doc.meta.name) or "Colorscheme"
  out("# Audit Report: %s\n", name)
  out("- **Status**: %s", #diag.fails > 0 and "FAIL" or (#diag.warns > 0 and "WARN" or "PASS"))
  out("- **Failures**: %d", #diag.fails)
  out("- **Warnings**: %d\n", #diag.warns)

  if #diag.fails > 0 then
    out("## Failures\n")
    for _, f in ipairs(diag.fails) do
      out("- **[%s]**: %s", f.code, f.message)
      if f.suggested_hex then
        out("  - *Suggested Fix*: `%s`", f.suggested_hex)
      end
    end
    out("")
  end

  if #diag.warns > 0 then
    out("## Warnings\n")
    for _, w in ipairs(diag.warns) do
      out("- **[%s]**: %s", w.code, w.message)
      if w.suggested_hex then
        out("  - *Suggested Fix*: `%s`", w.suggested_hex)
      end
    end
    out("")
  end

  return table.concat(lines, "\n")
end

-- Compatibility entry point: fix selection belongs to the palette fix module.
-- Prefer lgen.fix_string/fix_file to receive the plan and remaining diagnostics.
function M.apply_fixes_to_markdown(parsed_doc, diag)
  local metrics = diag.metrics or {}
  local opts = {}
  for k, v in pairs(parsed_doc.meta or {}) do opts[k] = v end
  opts.strictness = metrics.strictness or opts.strictness
  opts.ignore = metrics.ignore or opts.ignore
  opts.vibrant = metrics.vibrant
  local result, err = require("lgen.fix_plan").plan(parsed_doc, opts)
  if not result then error(err.message) end
  return require("lgen.markdown_parser").apply_edits(parsed_doc, result.edits)
end

-- Renders a side-by-side terminal comparison diff between two themes
function M.format_diff(doc1, doc2, diag1, diag2, opts)
  opts = opts or {}
  local lines = {}
  local function out(fmt, ...) table.insert(lines, string.format(fmt or "", ...)) end

  local name1 = (doc1 and doc1.meta and doc1.meta.name) or "Base Theme"
  local name2 = (doc2 and doc2.meta and doc2.meta.name) or "Fixed Theme"

  out("")
  out("\27[1;36m━━━ Colorscheme Comparison Diff: %s → %s ━━━\27[0m", name1, name2)
  out("")
  out("\27[1mSlot  Name            Before        After         ΔL_ok   ΔAPCA   Status\27[0m")
  out("─────────────────────────────────────────────────────────────────────────────")

  local ordered_keys = { "bg", "fg", 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 }
  local pal1 = doc1 and doc1.palette or {}
  local pal2 = doc2 and doc2.palette or {}

  for _, key in ipairs(ordered_keys) do
    local rgb1 = pal1[key]
    local rgb2 = pal2[key]
    if rgb1 or rgb2 then
      local name = COLOR_NAMES[key] or tostring(key)
      local hex1 = rgb1 and (rgb1.hex or cm.rgb_to_hex(rgb1)) or "  -    "
      local hex2 = rgb2 and (rgb2.hex or cm.rgb_to_hex(rgb2)) or "  -    "
      local swatch1 = ansi_swatch(rgb1)
      local swatch2 = ansi_swatch(rgb2)

      local L1 = (diag1 and diag1.metrics and diag1.metrics.oklab[key] and diag1.metrics.oklab[key].L) or 0
      local L2 = (diag2 and diag2.metrics and diag2.metrics.oklab[key] and diag2.metrics.oklab[key].L) or 0
      local dL = L2 - L1

      local apca1 = (diag1 and diag1.metrics and diag1.metrics.contrast_scores[key] and diag1.metrics.contrast_scores[key].apca) or 0
      local apca2 = (diag2 and diag2.metrics and diag2.metrics.contrast_scores[key] and diag2.metrics.contrast_scores[key].apca) or 0
      local dAPCA = math.abs(apca2) - math.abs(apca1)

      local status = "\27[90mIdentical\27[0m"
      if hex1:lower() ~= hex2:lower() then
        if key == 8 and math.abs(apca2) >= 45 and math.abs(apca1) < 45 then
          status = "\27[32mFixed Legible\27[0m"
        elseif key == 2 and #diag1.fails > #diag2.fails then
          status = "\27[32mFixed CVD Diff\27[0m"
        elseif key == 15 and L2 >= ((diag2.metrics.oklab[7] and diag2.metrics.oklab[7].L) or 0) then
          status = "\27[32mFixed Inversion\27[0m"
        elseif dAPCA > 5 then
          status = string.format("\27[36m+%.1f APCA\27[0m", dAPCA)
        else
          status = "\27[33mModified\27[0m"
        end
      end

      local slot_str = string.format("%-4s", tostring(key))
      out("%s  %-14s  %-7s %s  %-7s %s  %+5.2f   %+6.1f   %s",
        slot_str, name:sub(1, 14), hex1, swatch1, hex2, swatch2, dL, dAPCA, status)
    end
  end
  out("─────────────────────────────────────────────────────────────────────────────\n")

  local f1, f2 = #diag1.fails, #diag2.fails
  local w1, w2 = #diag1.warns, #diag2.warns
  out("\27[1mSummary:\27[0m Failures: \27[1m%d → %d\27[0m (\27[%sm%+d\27[0m) | Warnings: \27[1m%d → %d\27[0m (\27[%sm%+d\27[0m)\n",
    f1, f2, (f2 <= f1 and "32" or "31"), f2 - f1,
    w1, w2, (w2 <= w1 and "32" or "31"), w2 - w1)

  return table.concat(lines, "\n")
end

return M
