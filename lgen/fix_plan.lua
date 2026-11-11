-- Coordinate suggestions against the whole palette, without editing source text.
local cm = require("lgen.color_math")
local auditor = require("lgen.auditor")
local M = {}

local function better(a, b)
  return #a.fails < #b.fails or (#a.fails == #b.fails and #a.warns < #b.warns)
end

local function failure_counts(diag)
  local counts = {}
  for _, item in ipairs(diag.fails) do
    local ctx = item.context or {}
    local key = item.code .. ":" .. tostring(ctx.slot or ctx.outlier or ctx.a) .. ":" .. tostring(ctx.b or ctx.cvd)
    counts[key] = (counts[key] or 0) + 1
  end
  return counts
end

local function preserves_failures(candidate, current)
  local counts = failure_counts(current)
  for key, count in pairs(failure_counts(candidate)) do
    if count > (counts[key] or 0) then return false end
  end
  return true
end

function M.plan(doc, opts)
  opts = opts or {}
  local limit = opts.max_iterations or 12
  if type(limit) ~= "number" or limit ~= math.floor(limit) or limit < 1 or limit > 100 then
    return nil, {code="INVALID_OPTIONS", message="max_iterations must be an integer from 1 to 100"}
  end
  local palette = {}
  for slot, rgb in pairs(doc.palette) do palette[slot] = rgb end
  local before = auditor.audit(palette, opts)
  local current, iterations = before, 0
  while iterations < limit do
    local best_diag, best_palette = current, nil
    local seen = {}
    -- Stable diagnostic order breaks ties: failures, then warnings.
    for _, items in ipairs({current.fails, current.warns}) do
      for _, item in ipairs(items) do
        local ctx = item.context or {}
        local slot = ctx.slot or ctx.outlier
        if slot == "bg" and not palette.bg then slot = 0 end
        local hex = item.suggested_hex
        local key = tostring(slot) .. ":" .. tostring(hex)
        if slot ~= nil and doc.raw_entries[slot] and hex and not seen[key] then
          seen[key] = true
          local rgb = cm.hex_to_rgb(hex)
          if rgb and rgb.hex ~= cm.rgb_to_hex(palette[slot]) then
            local candidate = {}
            for k, v in pairs(palette) do candidate[k] = v end
            candidate[slot] = rgb
            local diag = auditor.audit(candidate, opts)
            if better(diag, best_diag) and preserves_failures(diag, current) then
              best_diag, best_palette = diag, candidate
            end
          end
        end
      end
    end
    if not best_palette then break end
    current, palette = best_diag, best_palette
    iterations = iterations + 1
  end
  local edits = {}
  local slots = {"bg", "fg", "cursor", "selection", 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15}
  for _, slot in ipairs(slots) do
    if doc.palette[slot] then
      local old_hex, new_hex = cm.rgb_to_hex(doc.palette[slot]), cm.rgb_to_hex(palette[slot])
      if old_hex ~= new_hex then
        edits[#edits + 1] = {slot=slot, old_hex=old_hex, new_hex=new_hex}
      end
    end
  end
  local status = "stalled"
  if #current.fails == 0 and #current.warns == 0 then status = "resolved"
  elseif iterations == limit then status = "limit" end
  return {schema_version=1, before=before, after=current, edits=edits, iterations=iterations, status=status}
end

return M
