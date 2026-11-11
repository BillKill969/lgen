-- lgen/markdown_parser.lua
-- Flexible Markdown color extractor & rich alias normalizer

local cm = require("lgen.color_math")

local M = {}

-- Canonical alias map
local ALIASES = {
  ["0"] = 0, ["ansi0"] = 0, ["color0"] = 0, ["black"] = 0,
  ["1"] = 1, ["ansi1"] = 1, ["color1"] = 1, ["red"] = 1,
  ["2"] = 2, ["ansi2"] = 2, ["color2"] = 2, ["green"] = 2,
  ["3"] = 3, ["ansi3"] = 3, ["color3"] = 3, ["yellow"] = 3,
  ["4"] = 4, ["ansi4"] = 4, ["color4"] = 4, ["blue"] = 4,
  ["5"] = 5, ["ansi5"] = 5, ["color5"] = 5, ["magenta"] = 5, ["purple"] = 5,
  ["6"] = 6, ["ansi6"] = 6, ["color6"] = 6, ["cyan"] = 6, ["teal"] = 6,
  ["7"] = 7, ["ansi7"] = 7, ["color7"] = 7, ["white"] = 7,

  ["8"] = 8, ["ansi8"] = 8, ["color8"] = 8, ["bright_black"] = 8, ["brightblack"] = 8,
  ["b_black"] = 8, ["b.black"] = 8, ["gray"] = 8, ["grey"] = 8, ["dark_gray"] = 8,
  ["dark_grey"] = 8, ["comment"] = 8, ["comments"] = 8,

  ["9"] = 9, ["ansi9"] = 9, ["color9"] = 9, ["bright_red"] = 9, ["brightred"] = 9,
  ["b_red"] = 9, ["b.red"] = 9,

  ["10"] = 10, ["ansi10"] = 10, ["color10"] = 10, ["bright_green"] = 10, ["brightgreen"] = 10,
  ["b_green"] = 10, ["b.green"] = 10,

  ["11"] = 11, ["ansi11"] = 11, ["color11"] = 11, ["bright_yellow"] = 11, ["brightyellow"] = 11,
  ["b_yellow"] = 11, ["b.yellow"] = 11,

  ["12"] = 12, ["ansi12"] = 12, ["color12"] = 12, ["bright_blue"] = 12, ["brightblue"] = 12,
  ["b_blue"] = 12, ["b.blue"] = 12,

  ["13"] = 13, ["ansi13"] = 13, ["color13"] = 13, ["bright_magenta"] = 13, ["brightmagenta"] = 13,
  ["b_magenta"] = 13, ["b.magenta"] = 13, ["bright_purple"] = 13, ["brightpurple"] = 13,

  ["14"] = 14, ["ansi14"] = 14, ["color14"] = 14, ["bright_cyan"] = 14, ["brightcyan"] = 14,
  ["b_cyan"] = 14, ["b.cyan"] = 14, ["bright_teal"] = 14,

  ["15"] = 15, ["ansi15"] = 15, ["color15"] = 15, ["bright_white"] = 15, ["brightwhite"] = 15,
  ["b_white"] = 15, ["b.white"] = 15,

  ["bg"] = "bg", ["background"] = "bg", ["terminal_bg"] = "bg",
  ["fg"] = "fg", ["foreground"] = "fg", ["terminal_fg"] = "fg",
  ["cursor"] = "cursor", ["cursor_color"] = "cursor",
  ["selection"] = "selection", ["selection_bg"] = "selection", ["select"] = "selection",
}

function M.normalize_key(raw_key)
  if type(raw_key) == "number" and raw_key >= 0 and raw_key <= 15 then
    return raw_key
  end
  if type(raw_key) ~= "string" then return nil end

  local cleaned = raw_key:lower()
    :gsub("^[%-%*%s%|%`]+", "")
    :gsub("[%:%=%s%|%`]+$", "")
    :gsub("[%s%_]+", "_")
    :gsub("%._", ".")
    :gsub("ansi_?", "")
    :gsub("color_?", "")

  if ALIASES[cleaned] ~= nil then
    return ALIASES[cleaned]
  end

  -- Check direct lookup of raw cleaned
  local pure = raw_key:lower():gsub("[^%w%.%_]", "")
  if ALIASES[pure] ~= nil then
    return ALIASES[pure]
  end

  return nil
end

local function parse_frontmatter(text)
  local meta = {}
  local body = text

  if text:sub(1, 3) == "---" then
    local end_pos = text:find("\n%-%-%-", 4)
    if end_pos then
      local fm_text = text:sub(4, end_pos)
      body = text:sub(end_pos + 4)

      local current_list = nil
      for line in fm_text:gmatch("[^\r\n]+") do
        local list_item = line:match("^%s*%-%s+(.+)$")
        if list_item and current_list then
          local item_clean = list_item:gsub('^["\']', ''):gsub('["\']$', '')
          table.insert(meta[current_list], item_clean)
        else
          local k, v = line:match("^%s*([%w_%-]+)%s*:%s*(.*)$")
          if k then
            k = k:lower()
            if v == "" then
              meta[k] = {}
              current_list = k
            else
              current_list = nil
              if not v:match("^[\"\']") then v = v:gsub("%s+#.*$", "") end
              v = v:gsub("%s+$", ""):gsub('^["\']', ''):gsub('["\']$', '')
              meta[k] = v
            end
          end
        end
      end
    end
  end

  return meta, body
end

function M.parse(content)
  local meta, body = parse_frontmatter(content)
  local palette = {}
  local raw_entries = {}

  for line_pos, line in body:gmatch("()([^\r\n]+)") do
    local hex = line:match("#[%w]+")
    if hex and #hex ~= 4 and #hex ~= 7 then hex = nil end
    if hex then
      local rgb = cm.hex_to_rgb(hex)
      if rgb then
        -- Check if it is a table row: | col1 | col2 | col3 | ...
        if line:find("|") then
          local cols = {}
          for col in line:gmatch("[^|]+") do
            table.insert(cols, col:match("^%s*(.-)%s*$"))
          end
          -- Search columns for a key
          for _, col in ipairs(cols) do
            local key = M.normalize_key(col)
            if key ~= nil and palette[key] == nil then
              palette[key] = rgb
              raw_entries[key] = { hex = hex, line = line, start = #content - #body + line_pos + line:find(hex, 1, true) - 1, length = #hex }
              break
            end
          end
        else
          -- Key-value line: "- red: #hex", "red = #hex", "1: #hex", etc.
          local key_part = line:match("^[%s%-%*]*([^:=|]+)[=:]")
          if key_part then
            local key = M.normalize_key(key_part)
            if key ~= nil and palette[key] == nil then
              palette[key] = rgb
              raw_entries[key] = { hex = hex, line = line, start = #content - #body + line_pos + line:find(hex, 1, true) - 1, length = #hex }
            end
          end
        end
      end
    end
  end

  return {
    meta = meta,
    palette = palette,
    raw_entries = raw_entries,
    raw = content,
  }
end

-- File reading is explicit: content parsing never probes the filesystem.
function M.parse_file(path)
  if type(path) ~= "string" or path == "" then
    return nil, {code="INVALID_INPUT", message="Theme path must be a nonempty string"}
  end
  local f, err = io.open(path, "rb")
  if not f then return nil, { code = "READ_ERROR", message = tostring(err) } end
  local content, read_err = f:read("*a")
  f:close()
  if not content then return nil, { code = "READ_ERROR", message = tostring(read_err) } end
  return M.parse(content)
end

-- All edits refer to original source positions, applied from right to left.
function M.apply_edits(doc, edits)
  local patches, seen = {}, {}
  for _, edit in ipairs(edits) do
    local entry = doc.raw_entries[edit.slot]
    if not entry then error("Cannot edit an undeclared palette slot: " .. tostring(edit.slot)) end
    if seen[edit.slot] then error("Duplicate slot edit: " .. tostring(edit.slot)) end
    if not cm.hex_to_rgb(edit.new_hex) then error("Invalid replacement color") end
    seen[edit.slot] = true
    patches[#patches + 1] = { start = entry.start, length = entry.length, hex = edit.new_hex }
  end
  table.sort(patches, function(a, b) return a.start > b.start end)
  local text = doc.raw
  for _, patch in ipairs(patches) do
    text = text:sub(1, patch.start - 1) .. patch.hex .. text:sub(patch.start + patch.length)
  end
  return text
end

return M
