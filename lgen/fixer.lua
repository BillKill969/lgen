-- lgen/fixer.lua
-- Searches for quantized color adjustments; shared policy owns acceptance criteria.

local cm = require("lgen.color_math")
local policy = require("lgen.policy")

local M = {}

-- Search both lightness directions; evaluate the exact hex the caller receives.
-- Returns a hex color, or nil when the bounded search finds no feasible color.
local function search_lightness(rgb_fg, meets)
  local original = cm.hex_to_rgb(cm.rgb_to_hex(rgb_fg))
  if meets(original) then return original.hex end
  local lab = cm.rgb_to_oklab(original)
  local lch = cm.oklab_to_oklch(lab)
  local function candidate(L)
    local fit = cm.fit_oklch_to_gamut({L=L, C=lch.C, h=lch.h})
    return cm.hex_to_rgb(fit.hex)
  end
  local best, distance
  for _, endpoint in ipairs({0, 1}) do
    local previous = lch.L
    for step = 1, 64 do
      local L = lch.L + (endpoint - lch.L) * step / 64
      local rgb = candidate(L)
      if meets(rgb) then
        -- Refine this observed failing/passing interval without assuming global monotonicity.
        local bad, good = previous, L
        for _ = 1, 20 do
          local mid = (bad + good) / 2
          if meets(candidate(mid)) then good = mid else bad = mid end
        end
        rgb = candidate(good)
        local delta = cm.delta_e_ok(lab, cm.rgb_to_oklab(rgb))
        if not distance or delta < distance then best, distance = rgb.hex, delta end
        break
      end
      previous = L
    end
  end
  return best
end

function M.adjust_contrast(rgb_fg, rgb_bg, target_apca, target_wcag)
  local target = {apca=target_apca or 60, wcag=target_wcag or 0}
  local best = search_lightness(rgb_fg, function(rgb)
    return policy.meets_contrast(cm.apca(rgb, rgb_bg), cm.wcag_contrast(rgb, rgb_bg), target)
  end)
  if best then return best end
  return nil, {code="UNREACHABLE_CONTRAST", message="No feasible quantized color found for the requested contrast targets"}
end

-- Distinguish the bright slot without changing its normal partner.
function M.distinguish_bright(rgb_bright, rgb_normal, rgb_bg, minimum)
  minimum = minimum or policy.text().fail
  local normal_L = cm.rgb_to_oklab(rgb_normal).L
  local is_dark = cm.rgb_to_oklab(rgb_bg).L < 0.5
  local best = search_lightness(rgb_bright, function(rgb)
    local L = cm.rgb_to_oklab(rgb).L
    return policy.bright_gap(normal_L, L, is_dark) >= policy.bright.target_gap
      and policy.meets_contrast(cm.apca(rgb, rgb_bg), cm.wcag_contrast(rgb, rgb_bg), minimum)
  end)
  if best then return best end
  return nil, {code="UNREACHABLE_BRIGHT_PAIR", message="No feasible bright-slot separation found while preserving text contrast"}
end

-- Preserve text contrast while separating the actual serialized CVD projections.
function M.adjust_cvd_pair(rgb_target, rgb_ref, rgb_bg, cvd_type, minimum)
  cvd_type = cvd_type or "protan"
  minimum = minimum or policy.text().fail
  local ref_lab = cm.rgb_to_oklab(cm.sim_cvd(rgb_ref, cvd_type))
  local best = search_lightness(rgb_target, function(rgb)
    if not policy.meets_contrast(cm.apca(rgb, rgb_bg), cm.wcag_contrast(rgb, rgb_bg), minimum) then
      return false
    end
    local lab = cm.rgb_to_oklab(cm.sim_cvd(rgb, cvd_type))
    return cm.delta_e_ok(lab, ref_lab) >= policy.cvd.target
  end)
  if best then return best end
  return nil, {code="UNREACHABLE_CVD", message="No feasible quantized color found for CVD separation and text contrast"}
end

-- Re-anchors color temperature to stay within balanced, eye-friendly bounds
function M.anchor_temperature(rgb, target_mode)
  local lab = cm.rgb_to_oklab(rgb)
  local w = cm.warmth_index(lab)

  -- Balanced neutral bounds: warmth around [-0.010, +0.010]
  local test_lab = { L = lab.L, a = lab.a * 0.3, b = lab.b }

  if w < -0.020 then
    test_lab.b = -0.005
  elseif w > 0.022 then
    test_lab.b = 0.005
  end

  local test_rgb = cm.oklab_to_rgb(test_lab)
  return cm.rgb_to_hex(test_rgb)
end

-- Boosts saturation and chroma within the sRGB gamut to prevent washed-out/muted colors
-- Uses hue-adaptive chroma limits and constant-hue gamut mapping
function M.boost_vibrancy(rgb, bg, target_chroma, minimum)
  local lab = cm.rgb_to_oklab(rgb)
  local lch = cm.oklab_to_oklch(lab)
  if lch.C <= policy.hue_epsilon then return cm.rgb_to_hex(rgb) end
  local limits = cm.get_hue_chroma_limits(lch.h)
  target_chroma = target_chroma or limits.target
  minimum = minimum or policy.text().fail
  local is_dark = cm.rgb_to_oklab(bg).L < 0.5

  local best_hex = cm.rgb_to_hex(rgb)
  local best_c = lch.C

  -- Search across lightness levels where sRGB gamut allows high chroma
  local l_candidates = is_dark and { 0.76, 0.74, 0.72, 0.78, 0.70, 0.80, 0.82 } or { 0.45, 0.50, 0.40, 0.55 }

  for _, test_L in ipairs(l_candidates) do
    for c = target_chroma, lch.C, -0.005 do
      local fit = cm.fit_oklch_to_gamut({ L = test_L, C = c, h = lch.h })
      local test_fit = cm.hex_to_rgb(fit.hex)
      local actual_C = cm.oklab_to_oklch(cm.rgb_to_oklab(test_fit)).C
      local accepted = policy.meets_contrast(cm.apca(test_fit, bg), cm.wcag_contrast(test_fit, bg), minimum)

      if accepted and actual_C >= c - 0.010 and actual_C > best_c then
        best_hex = test_fit.hex
        best_c = actual_C
        if best_c >= target_chroma then
          return best_hex
        end
      end
    end
  end

  return best_hex
end

-- Desaturates ANSI 8 (Comment) and aligns its hue/temperature to the background
function M.desaturate_comment(rgb_comment, rgb_bg)
  local lab_bg = cm.rgb_to_oklab(rgb_bg)
  local lch_bg = cm.oklab_to_oklch(lab_bg)
  local lab_c = cm.rgb_to_oklab(rgb_comment)
  local lch_c = cm.oklab_to_oklch(lab_c)
  local is_dark = lab_bg.L < 0.5

  -- Lightness calibrated for comfortable comment contrast (APCA ~ -48 in dark mode)
  local target_L = is_dark and 0.63 or 0.42
  local target_C = 0.012
  local target_h = (lch_bg.C > 0.015) and lch_bg.h or lch_c.h

  local fixed = cm.fit_oklch_to_gamut({ L = target_L, C = target_C, h = target_h })
  return M.adjust_contrast(cm.hex_to_rgb(fixed.hex), rgb_bg,
    policy.comment.target.apca, policy.comment.target.wcag)
end

-- Balances an accent's lightness towards the target mean while preserving hue
function M.balance_accent_lightness(rgb_accent, target_L, rgb_bg, minimum)
  local lab = cm.rgb_to_oklab(rgb_accent)
  local lch = cm.oklab_to_oklch(lab)
  local target = math.max(0, math.min(1, target_L))

  local fixed = cm.fit_oklch_to_gamut({ L = target, C = lch.C, h = lch.h })
  if not rgb_bg then return fixed.hex end
  minimum = minimum or policy.text().fail
  return M.adjust_contrast(cm.hex_to_rgb(fixed.hex), rgb_bg, minimum.apca, minimum.wcag)
end

return M
