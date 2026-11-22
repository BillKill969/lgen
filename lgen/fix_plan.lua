-- Coordinate suggestions against the whole palette, without editing source text.
local cm = require("lgen.color_math")
local auditor = require("lgen.auditor")
local policy = require("lgen.policy")
local M = {}

local slots = {"bg", "fg", "cursor", "selection", 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15}

local function score(diag, opts)
  local functional, requested, style = 0, 0, 0
  for _, item in ipairs(diag.warns) do
    if item.category ~= "style" then functional = functional + 1
    elseif (opts.vibrant and item.code == "MUTED_COLOR")
      or (opts.fix_background and item.context.slot == "bg") then requested = requested + 1
    else style = style + 1 end
  end
  return {#diag.fails, functional, requested}, style
end

local function compare_scores(a, b)
  for i = 1, #a do
    if a[i] ~= b[i] then return a[i] - b[i] end
  end
  return 0
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

-- Keep the search local in Oklch and audit only quantized, usable candidates.
local function pair_colors(rgb, bg, minimum)
  local lch = cm.oklab_to_oklch(cm.rgb_to_oklab(rgb))
  local colors, seen = {}, {}
  for _, offset in ipairs({0, -0.02, 0.02, -0.04, 0.04, -0.065, 0.065, -0.10, 0.10, -0.16, 0.16}) do
    local lightness = math.max(0, math.min(1, lch.L + offset))
    local color = rgb
    if offset ~= 0 then
      local fit = cm.fit_oklch_to_gamut({L=lightness, C=lch.C, h=lch.h})
      color = cm.hex_to_rgb(fit.hex)
    end
    if not seen[color.hex] and policy.meets_contrast(cm.apca(color, bg), cm.wcag_contrast(color, bg), minimum) then
      seen[color.hex] = true
      colors[#colors + 1] = {rgb=color, lab=cm.rgb_to_oklab(color)}
    end
  end
  return colors
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
    local best_diag, best_palette
    local best_score, best_style = score(current, opts)
    local best_distance
    local seen = {}
    local bg_slot = palette.bg and "bg" or 0
    local function consider(slot, rgb, other, other_rgb)
      if not rgb then return end
      if rgb.hex == palette[slot].hex and (not other or other_rgb.hex == palette[other].hex) then return end
      if other and rgb.hex == palette[slot].hex then
        slot, rgb, other = other, other_rgb, nil
      elseif other and other_rgb.hex == palette[other].hex then
        other = nil
      end
      local key = tostring(slot) .. ":" .. rgb.hex
      if other then key = key .. ":" .. other .. ":" .. other_rgb.hex end
      if seen[key] then return end
      seen[key] = true
      local candidate = {}
      for k, v in pairs(palette) do candidate[k] = v end
      candidate[slot] = rgb
      if other then candidate[other] = other_rgb end
      local diag = auditor.audit(candidate, opts)
      local candidate_score, style = score(diag, opts)
      local order = compare_scores(candidate_score, best_score)
      if order > 0 or (order == 0 and not best_distance) then return end
      if not preserves_failures(diag, current) then return end

      -- Compare total perceptual movement from the input, including prior steps.
      local distance = 0
      local labs = diag.metrics.oklab
      for _, k in ipairs(slots) do
        if labs[k] then distance = distance + cm.delta_e_ok(before.metrics.oklab[k], labs[k]) end
      end
      if order < 0 or distance < best_distance or (distance == best_distance and style < best_style) then
        best_diag, best_palette = diag, candidate
        best_score, best_style, best_distance = candidate_score, style, distance
      end
    end

    for _, items in ipairs({current.fails, current.warns}) do
      for _, item in ipairs(items) do
        local ctx = item.context or {}
        local slot = ctx.slot or ctx.outlier
        if slot == "bg" then slot = bg_slot end
        if slot and doc.raw_entries[slot] and item.suggested_hex
          and (slot ~= bg_slot or opts.fix_background) then
          consider(slot, cm.hex_to_rgb(item.suggested_hex))
        end
      end
    end
    if not best_palette then
      local bg = palette[bg_slot]
      local minimum = policy.text(opts.strictness).fail
      local function try_pair(a, b, separates)
        if not doc.raw_entries[a] or not doc.raw_entries[b] then return end
        local left = pair_colors(palette[a], bg, minimum)
        local right = pair_colors(palette[b], bg, minimum)
        for _, x in ipairs(left) do
          for _, y in ipairs(right) do
            if separates(x, y) then consider(a, x.rgb, b, y.rgb) end
          end
        end
      end
      for _, items in ipairs({current.fails, current.warns}) do
        for _, item in ipairs(items) do
          local ctx = item.context
          if item.code == "CVD_DIFF_COLLISION" or item.code == "CVD_DIFF_DIFFICULT" then
            local minimum_gap = item.code == "CVD_DIFF_COLLISION" and policy.cvd.fail or policy.cvd.warn
            try_pair(1, 2, function(x, y)
              local left = cm.rgb_to_oklab(cm.sim_cvd(x.rgb, ctx.cvd))
              local right = cm.rgb_to_oklab(cm.sim_cvd(y.rgb, ctx.cvd))
              return cm.delta_e_ok(left, right) >= minimum_gap
            end)
          elseif ctx.a == 1 and ctx.b == 2 then
            local minimum_gap = item.code == "SYNTAX_COLLISION" and policy.syntax.fail or policy.syntax.warn
            try_pair(1, 2, function(x, y)
              return cm.delta_e_ok(x.lab, y.lab) >= minimum_gap
            end)
          elseif ctx.norm and ctx.bright then
            try_pair(ctx.norm, ctx.bright, function(x, y)
              return policy.bright_gap(x.lab.L, y.lab.L, current.metrics.is_dark) >= policy.bright.min_gap
            end)
          end
        end
      end
    end
    if not best_palette then break end
    current, palette = best_diag, best_palette
    iterations = iterations + 1
  end
  local edits = {}
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
