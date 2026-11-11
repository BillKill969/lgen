-- lgen/auditor.lua
-- Core rule engine for colorimetry, contrast, CVD, and ANSI semantics

local cm = require("lgen.color_math")
local fixer = require("lgen.fixer")
local policy = require("lgen.policy")

local M = {}

local COLOR_NAMES = {
  [0] = "Black", [1] = "Red",     [2] = "Green", [3] = "Yellow",
  [4] = "Blue",  [5] = "Magenta", [6] = "Cyan",  [7] = "White",
  [8] = "Bright Black",   [9] = "Bright Red",     [10] = "Bright Green", [11] = "Bright Yellow",
  [12] = "Bright Blue",   [13] = "Bright Magenta", [14] = "Bright Cyan",  [15] = "Bright White",
  ["bg"] = "Background", ["fg"] = "Foreground",
  ["cursor"] = "Cursor", ["selection"] = "Selection",
}

-- Canonical Oklch hue ranges (degrees 0..360)
local HUE_RANGES = {
  [1] = { min = 15, max = 50, wrap = { 350, 360 } },   -- Red
  [2] = { min = 115, max = 165 },                       -- Green
  [3] = { min = 75, max = 110 },                        -- Yellow
  [4] = { min = 230, max = 280 },                       -- Blue
  [5] = { min = 305, max = 350 },                       -- Magenta
  [6] = { min = 175, max = 225 },                       -- Cyan
}

function M.audit(raw_palette, opts)
  opts = opts or {}
  local strictness = opts.strictness or (opts.meta and opts.meta.strictness) or "normal"
  local ignore_list = opts.ignore or (opts.meta and opts.meta.ignore) or {}
  local ignore_map = {}
  for _, ig in ipairs(ignore_list) do
    ignore_map[ig:lower()] = true
  end

  local text_thresholds = policy.text(strictness)

  local palette = {}
  local oklab = {}
  local oklch = {}

  for k, v in pairs(raw_palette) do
    local rgb = type(v) == "string" and cm.hex_to_rgb(v) or v
    if rgb then
      palette[k] = rgb
      oklab[k] = cm.rgb_to_oklab(rgb)
      oklch[k] = cm.oklab_to_oklch(oklab[k])
    end
  end

  local bg = palette.bg or palette[0]
  local fg = palette.fg or palette[7]
  local bg_lab = oklab.bg or oklab[0]
  local is_dark = not bg_lab or bg_lab.L < 0.5

  local function contrast_fix(rgb, thresholds, level)
    local hex = fixer.adjust_contrast(rgb, bg, thresholds.warn.apca, thresholds.warn.wcag)
    if not hex and level == "FAIL" then
      hex = fixer.adjust_contrast(rgb, bg, thresholds.fail.apca, thresholds.fail.wcag)
    end
    return hex
  end

  local diagnostics = {
    fails = {},
    warns = {},
    passes = {},
    metrics = {
      is_dark = is_dark,
      strictness = strictness,
      ignore = ignore_list,
      vibrant = opts.vibrant or false,
      models = {
        apca="0.0.98G-4g", wcag="2.x",
        gamut="oklch-chroma-reduction-v1",
        cvd={protan=cm.cvd_models.protan, deutan=cm.cvd_models.deutan, tritan=cm.cvd_models.tritan},
      },
      policy = {version=policy.version, profile="terminal"},
      contrast_scores = {},
      bright_pairs = {},
      oklab = oklab,
      oklch = oklch,
    }
  }

  local function add_diag(level, code, msg, ctx, fix_hex)
    if ignore_map[code:lower()] then return end
    local entry = {code=code, message=msg, context=ctx, suggested_hex=fix_hex,
      category=policy.category(code), basis="project-policy"}
    if level == "FAIL" then
      table.insert(diagnostics.fails, entry)
    elseif level == "WARN" then
      table.insert(diagnostics.warns, entry)
    else
      table.insert(diagnostics.passes, entry)
    end
  end

  -- Rule A: Contrast of ANSI 1..7, 9..15, and fg against bg
  if bg then
    for idx = 1, 15 do
      if idx ~= 8 and palette[idx] then
        local wcag = cm.wcag_contrast(palette[idx], bg)
        local apca_val = cm.apca(palette[idx], bg)
        local name = COLOR_NAMES[idx]

        diagnostics.metrics.contrast_scores[idx] = { wcag = wcag, apca = apca_val }

        local contrast_level = policy.contrast_level(apca_val, wcag, text_thresholds)
        if contrast_level == "FAIL" then
          local fix = contrast_fix(palette[idx], text_thresholds, "FAIL")
          add_diag("FAIL", "LOW_CONTRAST",
            string.format("ANSI %d (%s) has unreadable contrast against bg (APCA: %.1f, WCAG: %.2f:1)", idx, name, apca_val, wcag),
            { slot = idx, wcag = wcag, apca = apca_val, current_hex = palette[idx].hex }, fix)
        elseif contrast_level == "WARN" then
          local fix = contrast_fix(palette[idx], text_thresholds, "WARN")
          add_diag("WARN", "SUBOPTIMAL_CONTRAST",
            string.format("ANSI %d (%s) has suboptimal contrast against bg (APCA: %.1f, WCAG: %.2f:1)", idx, name, apca_val, wcag),
            { slot = idx, wcag = wcag, apca = apca_val, current_hex = palette[idx].hex }, fix)
        else
          add_diag("PASS", "CONTRAST_OK", string.format("ANSI %d (%s) contrast OK", idx, name), { slot = idx })
        end
      end
    end

    if palette.fg then
      local wcag_fg = cm.wcag_contrast(palette.fg, bg)
      local apca_fg = cm.apca(palette.fg, bg)
      diagnostics.metrics.contrast_scores.fg = {wcag=wcag_fg, apca=apca_fg}
      if policy.contrast_level(apca_fg, wcag_fg, text_thresholds) == "FAIL" then
        local fix = contrast_fix(palette.fg, text_thresholds, "FAIL")
        add_diag("FAIL", "FG_ILLEGIBLE",
          string.format("Foreground (fg) has unreadable contrast against bg (APCA: %.1f, WCAG: %.2f:1)", apca_fg, wcag_fg),
          { slot = "fg", wcag = wcag_fg, apca = apca_fg }, fix)
      end
    end
  end

  -- Rule B: Comment & Muted Contrast (ANSI 8)
  if palette[8] and bg then
    local wcag8 = cm.wcag_contrast(palette[8], bg)
    local apca8 = cm.apca(palette[8], bg)
    diagnostics.metrics.contrast_scores[8] = { wcag = wcag8, apca = apca8 }

    local comment_level = policy.contrast_level(apca8, wcag8, policy.comment)
    if comment_level == "FAIL" then
      local fix = fixer.adjust_contrast(palette[8], bg, policy.comment.target.apca, policy.comment.target.wcag)
      add_diag("FAIL", "COMMENT_ILLEGIBLE",
        string.format("ANSI 8 (Bright Black/Comment) is illegible against bg (APCA: %.1f, WCAG: %.2f:1)", apca8, wcag8),
        { slot = 8, wcag = wcag8, apca = apca8, current_hex = palette[8].hex }, fix)
    elseif comment_level == "WARN" then
      local fix = fixer.adjust_contrast(palette[8], bg, policy.comment.target.apca, policy.comment.target.wcag)
      add_diag("WARN", "COMMENT_FAINT",
        string.format("ANSI 8 (Bright Black/Comment) is faint against bg (APCA: %.1f)", apca8),
        { slot = 8, apca = apca8, current_hex = palette[8].hex }, fix)
    end

    if palette[7] and oklab[8].L >= oklab[7].L then
      add_diag("WARN", "COMMENT_OVERBRIGHT",
        "ANSI 8 (Comment) is brighter than or equal to ANSI 7 (Default Foreground)",
        { slot = 8 })
    end

    -- Comment Chroma Ceiling (Comments should be subtle annotations, not active syntax)
    if oklch[8] and oklch[8].C > 0.045 then
      local fix = fixer.desaturate_comment(palette[8], bg)
      add_diag("WARN", "COMMENT_OVERLY_SATURATED",
        string.format("ANSI 8 (Bright Black/Comment) has excessive chroma (C=%.3f > 0.045), making comments compete with code", oklch[8].C),
        { slot = 8, chroma = oklch[8].C, current_hex = palette[8].hex }, fix)
    end

    -- Comment Tint & Temperature Alignment against tinted background
    local lab_bg = oklab.bg or (palette[0] and oklab[0])
    local lch_bg = oklch.bg or (palette[0] and oklch[0])
    if lab_bg and lch_bg and lch_bg.C > 0.015 and oklch[8] and oklch[8].C > 0.012 then
      local w_bg = cm.warmth_index(lab_bg)
      local w_8 = cm.warmth_index(oklab[8])
      if (w_bg < -0.012 and w_8 > 0.015) or (w_bg > 0.012 and w_8 < -0.015) then
        local fix = fixer.desaturate_comment(palette[8], bg)
        add_diag("WARN", "COMMENT_TEMPERATURE_MISMATCH",
          string.format("ANSI 8 comment temperature (%s, W=%+.3f) clashes with tinted background (%s, W=%+.3f)",
            cm.temperature_category(oklab[8]), w_8, cm.temperature_category(lab_bg), w_bg),
          { slot = 8, comment_warmth = w_8, bg_warmth = w_bg, current_hex = palette[8].hex }, fix)
      end
    end
  end

  -- Rule C: Bright slots must be distinguishable, including white (7 -> 15).
  for i = 1, 7 do
    local bright_idx = i + 8
    if oklab[i] and oklab[bright_idx] then
      local L_norm, L_bright = oklab[i].L, oklab[bright_idx].L
      local signed_gap = L_bright - L_norm
      local separation = policy.bright_gap(L_norm, L_bright, is_dark)
      diagnostics.metrics.bright_pairs[bright_idx] = {
        norm=i, bright=bright_idx, lightness_gap=signed_gap,
        separation=separation, required_gap=policy.bright.min_gap,
      }
      local inverted = is_dark and signed_gap < -policy.bright_tolerance
      if inverted or separation < policy.bright.min_gap then
        local fix
        if bg then
          fix = fixer.distinguish_bright(palette[bright_idx], palette[i], bg, text_thresholds.warn)
          if not fix then fix = fixer.distinguish_bright(palette[bright_idx], palette[i], bg, text_thresholds.fail) end
        end
        local code = inverted and "INVERTED_BRIGHT_PAIR" or "INDISTINCT_BRIGHT_PAIR"
        local message = inverted
          and string.format("ANSI %d (%s) is darker than normal ANSI %d (delta L=%.3f)", bright_idx, COLOR_NAMES[bright_idx], i, signed_gap)
          or string.format("ANSI %d (%s) is too similar to normal ANSI %d (lightness separation %.3f < %.3f)", bright_idx, COLOR_NAMES[bright_idx], i, separation, policy.bright.min_gap)
        add_diag("WARN", code, message, {
          slot=bright_idx, norm=i, bright=bright_idx, current_hex=palette[bright_idx].hex,
          lightness_gap=signed_gap, separation=separation, required_gap=policy.bright.min_gap,
        }, fix)
      end
    end
  end

  -- Rule D: Syntax Token Collision
  local syntax_tokens = { 1, 2, 3, 4, 5, 6 }
  for i = 1, #syntax_tokens do
    for j = i + 1, #syntax_tokens do
      local a_idx = syntax_tokens[i]
      local b_idx = syntax_tokens[j]
      if oklab[a_idx] and oklab[b_idx] then
        local de = cm.delta_e_ok(oklab[a_idx], oklab[b_idx])
        if de < 0.04 then
          add_diag("FAIL", "SYNTAX_COLLISION",
            string.format("Severe collision between ANSI %d (%s) and ANSI %d (%s): ΔE_Ok = %.3f",
              a_idx, COLOR_NAMES[a_idx], b_idx, COLOR_NAMES[b_idx], de),
            { a = a_idx, b = b_idx, de = de })
        elseif de < 0.07 then
          add_diag("WARN", "SYNTAX_AMBIGUITY",
            string.format("Low distinction between ANSI %d (%s) and ANSI %d (%s): ΔE_Ok = %.3f",
              a_idx, COLOR_NAMES[a_idx], b_idx, COLOR_NAMES[b_idx], de),
            { a = a_idx, b = b_idx, de = de })
        end
      end
    end
  end

  -- Rule E: Git Diff Red vs Green Discriminability under CVD
  if palette[1] and palette[2] and bg then
    for _, cvd in ipairs({ "protan", "deutan" }) do
      local sim_r = cm.sim_cvd(palette[1], cvd)
      local sim_g = cm.sim_cvd(palette[2], cvd)
      local lab_r = cm.rgb_to_oklab(sim_r)
      local lab_g = cm.rgb_to_oklab(sim_g)
      local de_cvd = cm.delta_e_ok(lab_r, lab_g)
      local dL_cvd = math.abs(lab_r.L - lab_g.L)

      local cvd_level = policy.cvd_level(de_cvd)
      if cvd_level == "FAIL" then
        local fix = fixer.adjust_cvd_pair(palette[2], palette[1], bg, cvd, text_thresholds.fail)
        add_diag("FAIL", "CVD_DIFF_COLLISION",
          string.format("Git diff Red (ANSI 1) and Green (ANSI 2) collide under %s simulation (ΔE=%.3f, |ΔL|=%.3f)",
            cvd:upper(), de_cvd, dL_cvd),
          { cvd = cvd, de = de_cvd, dL = dL_cvd, slot = 2, current_hex = palette[2].hex }, fix)
      elseif cvd_level == "WARN" then
        local fix = fixer.adjust_cvd_pair(palette[2], palette[1], bg, cvd, text_thresholds.fail)
        add_diag("WARN", "CVD_DIFF_DIFFICULT",
          string.format("Git diff Red and Green are difficult to distinguish under %s simulation (ΔE=%.3f, |ΔL|=%.3f)",
            cvd:upper(), de_cvd, dL_cvd),
          { cvd = cvd, de = de_cvd, dL = dL_cvd, slot = 2, current_hex = palette[2].hex }, fix)
      end
    end
  end

  -- Rule F: Hue Sector Fidelity (hue is powerless near the neutral axis)
  for idx = 1, 6 do
    if oklch[idx] and oklch[idx].C > policy.hue_epsilon then
      local range = HUE_RANGES[idx]
      local h = oklch[idx].h
      local in_range = false
      if range then
        if h >= range.min and h <= range.max then
          in_range = true
        elseif range.wrap and (h >= range.wrap[1] and h <= range.wrap[2]) then
          in_range = true
        end
        if not in_range then
          add_diag("WARN", "HUE_SECTOR_MISMATCH",
            string.format("ANSI %d (%s) hue angle %.1f° is outside canonical range [%d°, %d°]",
              idx, COLOR_NAMES[idx], h, range.min, range.max),
            { slot = idx, hue = h })
        end
      end
    end
  end

  -- Rule G: Cursor & Selection
  if palette.cursor and bg then
    local apca_cur = cm.apca(palette.cursor, bg)
    if math.abs(apca_cur) < 40 then
      add_diag("WARN", "CURSOR_LOW_CONTRAST",
        string.format("Cursor has low contrast against background (APCA: %.1f)", apca_cur),
        { slot = "cursor", apca = apca_cur })
    end
  end
  if palette.selection and fg then
    local apca_sel = cm.apca(fg, palette.selection)
    if math.abs(apca_sel) < 30 then
      add_diag("WARN", "SELECTION_LOW_CONTRAST",
        string.format("Foreground text in selection has low contrast (APCA: %.1f)", apca_sel),
        { slot = "selection", apca = apca_sel })
    end
  end

  -- Rule H: Background Anchoring & Temperature
  if bg then
    local lab_bg = oklab.bg or (palette[0] and oklab[0])
    local lch_bg = oklch.bg or (palette[0] and oklch[0])
    if lab_bg and lch_bg then
      local w_bg = cm.warmth_index(lab_bg)
      local category_bg = cm.temperature_category(lab_bg)
      diagnostics.metrics.bg_temperature = {
        category = category_bg,
        warmth = w_bg,
        chroma = lch_bg.C,
        hue = lch_bg.h,
      }

      -- Check 1: Excessive saturation in background
      if lch_bg.C > 0.045 then
        local fix = fixer.anchor_temperature(bg, "balanced")
        add_diag("WARN", "BACKGROUND_OVER_SATURATED",
          string.format("Background is overly saturated (Chroma: %.3f > 0.045), causing visual fatigue", lch_bg.C),
          { slot = "bg", chroma = lch_bg.C, current_hex = bg.hex }, fix)
      end

      -- Check 2: Too cold (harsh blue/indigo bias)
      if w_bg < -0.022 then
        local fix = fixer.anchor_temperature(bg, "balanced")
        add_diag("WARN", "BACKGROUND_TOO_COLD",
          string.format("Background has a cold blue/purple bias (Warmth Index: %.3f < -0.022)", w_bg),
          { slot = "bg", warmth = w_bg, current_hex = bg.hex }, fix)
      -- Check 3: Too warm (muddy yellow/brown bias)
      elseif w_bg > 0.025 then
        local fix = fixer.anchor_temperature(bg, "balanced")
        add_diag("WARN", "BACKGROUND_TOO_WARM",
          string.format("Background has a warm yellow/brown bias (Warmth Index: %.3f > 0.025)", w_bg),
          { slot = "bg", warmth = w_bg, current_hex = bg.hex }, fix)
      end

      -- Check 4: Temperature clash with comments (ANSI 8) or foreground
      local check_clash = { [8] = palette[8], fg = palette.fg }
      for _, slot_k in ipairs({8, "fg"}) do
        local elem_rgb = check_clash[slot_k]
        local lab_elem = oklab[slot_k]
        if lab_elem then
          local w_elem = cm.warmth_index(lab_elem)
          if w_bg < -0.012 and w_elem > 0.030 then
            add_diag("WARN", "TEMPERATURE_CLASH",
              string.format("%s temperature clashes with background: background is cool (W=%.3f) but %s is warm (W=%.3f)",
                COLOR_NAMES[slot_k] or tostring(slot_k), w_bg, COLOR_NAMES[slot_k] or tostring(slot_k), w_elem),
              { slot = slot_k, bg_warmth = w_bg, elem_warmth = w_elem, current_hex = elem_rgb.hex })
          elseif w_bg > 0.012 and w_elem < -0.030 then
            add_diag("WARN", "TEMPERATURE_CLASH",
              string.format("%s temperature clashes with background: background is warm (W=%.3f) but %s is cold (W=%.3f)",
                COLOR_NAMES[slot_k] or tostring(slot_k), w_bg, COLOR_NAMES[slot_k] or tostring(slot_k), w_elem),
              { slot = slot_k, bg_warmth = w_bg, elem_warmth = w_elem, current_hex = elem_rgb.hex })
          end
        end
      end
    end
  end

  -- Rule I: Vibrancy & Low Chroma Check (MUTED_COLOR)
  -- Uses project hue-dependent chroma preferences with a 5% tolerance buffer
  if bg then
    for idx = 1, 6 do
      if oklch[idx] then
        local limits = cm.get_hue_chroma_limits(oklch[idx].h)
        local min_chroma = (strictness == "strict" or opts.vibrant) and limits.target or limits.min
        local warn_threshold = min_chroma * 0.95 -- 5% hysteresis zone
        local c = oklch[idx].C
        if c < warn_threshold then
          local fix = fixer.boost_vibrancy(palette[idx], bg, limits.target, text_thresholds.fail)
          add_diag("WARN", "MUTED_COLOR",
            string.format("ANSI %d (%s) is muted / low chroma (C=%.3f < %.3f), reducing syntax scanability",
              idx, COLOR_NAMES[idx], c, min_chroma),
            { slot = idx, chroma = c, current_hex = palette[idx].hex }, fix)
        end
      end
    end
  end

  -- Rule J: Accent Visual Weight & Lightness Balance (Uniform Syntax Hierarchy)
  local accent_slots = { 1, 2, 3, 4, 5, 6 }
  local present_accents = {}
  local sum_L = 0
  for _, slot in ipairs(accent_slots) do
    if oklab[slot] then
      table.insert(present_accents, { slot = slot, L = oklab[slot].L })
      sum_L = sum_L + oklab[slot].L
    end
  end

  if #present_accents >= 4 then
    local count = #present_accents
    local mean_L = sum_L / count
    local var_sum = 0
    local min_entry = present_accents[1]
    local max_entry = present_accents[1]

    for _, a in ipairs(present_accents) do
      var_sum = var_sum + (a.L - mean_L) ^ 2
      if a.L < min_entry.L then min_entry = a end
      if a.L > max_entry.L then max_entry = a end
    end

    local std_dev = math.sqrt(var_sum / count)
    local spread = max_entry.L - min_entry.L

    diagnostics.metrics.accent_lightness = {
      mean = mean_L,
      spread = spread,
      std_dev = std_dev,
    }

    if spread > policy.balance.spread or std_dev > policy.balance.std_dev then
      local outlier = (math.abs(max_entry.L - mean_L) >= math.abs(min_entry.L - mean_L)) and max_entry or min_entry
      local fix = fixer.balance_accent_lightness(palette[outlier.slot], mean_L, bg, text_thresholds.fail)
      add_diag("WARN", "ACCENT_LIGHTNESS_IMBALANCE",
        string.format("Lightness spread across syntax accents is excessive (ΔL=%.2f > 0.20, σ=%.3f). ANSI %d (%s, L=%.2f) dominates while ANSI %d (%s, L=%.2f) recedes",
          spread, std_dev, max_entry.slot, COLOR_NAMES[max_entry.slot], max_entry.L, min_entry.slot, COLOR_NAMES[min_entry.slot], min_entry.L),
        { spread = spread, std_dev = std_dev, outlier = outlier.slot, current_hex = palette[outlier.slot].hex }, fix)
    end
  end

  -- Rule K: Background Camouflage on Tinted Backgrounds
  local lch_bg_k = bg and (oklch.bg or (palette[0] and oklch[0]))
  local lab_bg_k = bg and (oklab.bg or (palette[0] and oklab[0]))
  if bg and lch_bg_k and lab_bg_k and lch_bg_k.C > 0.015 then
    for idx = 1, 6 do
      if oklch[idx] and oklab[idx] then
        local hue_diff = cm.hue_difference(oklch[idx].h, lch_bg_k.h)
        if hue_diff < policy.camouflage.hue then
          local c_dist = cm.chromatic_distance(oklab[idx], lab_bg_k)
          local apca_val = math.abs(cm.apca(palette[idx], bg))
          if apca_val < policy.camouflage.apca or c_dist < policy.camouflage.chromatic_distance then
            local fix = fixer.adjust_contrast(palette[idx], bg, policy.camouflage.target_apca, text_thresholds.fail.wcag)
            add_diag("WARN", "ACCENT_BACKGROUND_CAMOUFLAGE",
              string.format("ANSI %d (%s) shares hue direction with tinted background (Δh=%.1f°, chromatic dist=%.3f), reducing visual pop",
                idx, COLOR_NAMES[idx], hue_diff, c_dist),
              { slot = idx, hue_diff = hue_diff, chromatic_distance = c_dist, current_hex = palette[idx].hex }, fix)
          end
        end
      end
    end
  end

  return diagnostics
end

return M
