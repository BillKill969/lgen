-- lgen/color_math.lua
-- Color science calculations: sRGB, Oklab/Oklch, APCA 0.98G, WCAG 2.1, CVD

local M = {}

local math_sqrt = math.sqrt
local math_abs = math.abs
local math_atan2 = math.atan2 or math.atan
local math_pi = math.pi
local math_floor = math.floor
local math_min = math.min
local math_max = math.max

local function clamp01(v)
  if v < 0 then return 0 elseif v > 1 then return 1 else return v end
end

-- Parse hex string to { r, g, b, hex } where r, g, b in [0, 1]
function M.hex_to_rgb(hex)
  if type(hex) ~= "string" then return nil end
  hex = hex:gsub("%s+", ""):gsub("^#", "")
  if #hex == 3 then
    hex = hex:sub(1,1):rep(2) .. hex:sub(2,2):rep(2) .. hex:sub(3,3):rep(2)
  elseif #hex == 8 then
    -- Strip alpha channel if provided (#rrggbbaa)
    hex = hex:sub(1, 6)
  end
  if #hex ~= 6 then return nil end
  local num = tonumber(hex, 16)
  if not num then return nil end

  local r = math_floor(num / 65536) / 255
  local g = math_floor((num % 65536) / 256) / 255
  local b = (num % 256) / 255

  return {
    r = r,
    g = g,
    b = b,
    hex = "#" .. hex:lower()
  }
end

-- Convert normalized RGB { r, g, b } in [0, 1] to #rrggbb
function M.rgb_to_hex(rgb)
  local r = math_floor(clamp01(rgb.r) * 255 + 0.5)
  local g = math_floor(clamp01(rgb.g) * 255 + 0.5)
  local b = math_floor(clamp01(rgb.b) * 255 + 0.5)
  return string.format("#%02x%02x%02x", r, g, b)
end

-- Exact IEC 61966-2-1 piecewise sRGB gamma expansion
function M.srgb_to_linear(c)
  if c <= 0.04045 then
    return c / 12.92
  else
    return ((c + 0.055) / 1.055) ^ 2.4
  end
end

-- Exact inverse sRGB transfer function
function M.linear_to_srgb(c)
  c = clamp01(c)
  if c <= 0.0031308 then
    return c * 12.92
  else
    return 1.055 * (c ^ (1 / 2.4)) - 0.055
  end
end

-- Convert {r, g, b} in [0, 1] to Oklab {L, a, b}
function M.rgb_to_oklab(rgb)
  local r = M.srgb_to_linear(rgb.r)
  local g = M.srgb_to_linear(rgb.g)
  local b = M.srgb_to_linear(rgb.b)

  -- Step 1: linear sRGB to LMS
  local l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
  local m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
  local s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b

  -- Step 2: non-linear response compression
  local l_ = l ^ (1 / 3)
  local m_ = m ^ (1 / 3)
  local s_ = s ^ (1 / 3)

  -- Step 3: LMS to Oklab
  local L = 0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_
  local a = 1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_
  local b_val = 0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_

  return { L = L, a = a, b = b_val }
end

-- Check if linear sRGB values fall within the [0, 1] cube (with small tolerance)
local function is_linear_srgb_in_gamut(r_lin, g_lin, b_lin, eps)
  eps = eps or 0.0001
  return r_lin >= -eps and r_lin <= 1.0 + eps
     and g_lin >= -eps and g_lin <= 1.0 + eps
     and b_lin >= -eps and b_lin <= 1.0 + eps
end

-- Convert Oklab {L, a, b} to linear sRGB {r_lin, g_lin, b_lin} without gamma or clamping
function M.oklab_to_linear_srgb(lab)
  local l_ = lab.L + 0.3963377774 * lab.a + 0.2158037573 * lab.b
  local m_ = lab.L - 0.1055613458 * lab.a - 0.0638541728 * lab.b
  local s_ = lab.L - 0.0894841775 * lab.a - 1.2914855480 * lab.b

  local l = l_ * l_ * l_
  local m = m_ * m_ * m_
  local s = s_ * s_ * s_

  local r_lin = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
  local g_lin = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
  local b_lin = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s

  return r_lin, g_lin, b_lin
end

-- Check if an Oklch color is inside the sRGB gamut
function M.is_oklch_in_srgb(lch)
  local lab = M.oklch_to_oklab(lch)
  local r_lin, g_lin, b_lin = M.oklab_to_linear_srgb(lab)
  return is_linear_srgb_in_gamut(r_lin, g_lin, b_lin)
end

-- Constant-lightness/hue chroma reduction to the sRGB gamut boundary.
-- This is not the CSS Color 4 binary-search algorithm with local MINDE.
-- Hex quantization can slightly change the resulting lightness and hue.
function M.fit_oklch_to_gamut(lch)
  local L = lch.L
  if L <= 0 then
    return { r = 0, g = 0, b = 0, L = 0, C = 0, h = lch.h, hex = "#000000" }
  elseif L >= 1 then
    return { r = 1, g = 1, b = 1, L = 1, C = 0, h = lch.h, hex = "#ffffff" }
  end

  local C = math_max(0, lch.C)
  local h = lch.h

  -- Test if original color is already in gamut
  local lab_orig = M.oklch_to_oklab({ L = L, C = C, h = h })
  local r0, g0, b0 = M.oklab_to_linear_srgb(lab_orig)
  if is_linear_srgb_in_gamut(r0, g0, b0) then
    local rgb = {
      r = clamp01(M.linear_to_srgb(r0)),
      g = clamp01(M.linear_to_srgb(g0)),
      b = clamp01(M.linear_to_srgb(b0)),
    }
    rgb.hex = M.rgb_to_hex(rgb)
    rgb.L, rgb.C, rgb.h = L, C, h
    return rgb
  end

  -- Binary search Chroma down to gamut boundary (20 iterations ~ 10^-6 precision)
  local low = 0
  local high = C

  for _ = 1, 20 do
    local mid = (low + high) * 0.5
    local lab_mid = M.oklch_to_oklab({ L = L, C = mid, h = h })
    local r_lin, g_lin, b_lin = M.oklab_to_linear_srgb(lab_mid)
    if is_linear_srgb_in_gamut(r_lin, g_lin, b_lin) then
      low = mid
    else
      high = mid
    end
  end

  local final_lab = M.oklch_to_oklab({ L = L, C = low, h = h })
  local r_lin, g_lin, b_lin = M.oklab_to_linear_srgb(final_lab)
  local rgb = {
    r = clamp01(M.linear_to_srgb(r_lin)),
    g = clamp01(M.linear_to_srgb(g_lin)),
    b = clamp01(M.linear_to_srgb(b_lin)),
  }
  rgb.hex = M.rgb_to_hex(rgb)
  rgb.L, rgb.C, rgb.h = L, low, h
  return rgb
end

-- Convert Oklch to sRGB with constant-hue gamut mapping
function M.oklch_to_rgb_gamut_mapped(lch)
  return M.fit_oklch_to_gamut(lch)
end

-- Project hue-dependent chroma preferences; these are not computed gamut cusps.
-- Returns { min, target, max } for comfortable terminal syntax readability
function M.get_hue_chroma_limits(h)
  h = ((h % 360) + 360) % 360

  if (h >= 345 or h < 60) then
    -- Red / Warm Coral
    return { min = 0.095, target = 0.125, max = 0.180 }
  elseif h >= 60 and h < 115 then
    -- Yellow (supports both pastel cream and saturated amber)
    return { min = 0.072, target = 0.115, max = 0.170 }
  elseif h >= 115 and h < 170 then
    -- Green
    return { min = 0.090, target = 0.120, max = 0.160 }
  elseif h >= 170 and h < 225 then
    -- Cyan / Teal (gamut is naturally narrower at high lightness)
    return { min = 0.070, target = 0.095, max = 0.130 }
  elseif h >= 225 and h < 290 then
    -- Blue (reaches high chroma only at low lightness; pastel at high L)
    return { min = 0.080, target = 0.110, max = 0.145 }
  else
    -- Magenta / Pink (290 to 345)
    return { min = 0.065, target = 0.090, max = 0.130 }
  end
end

-- Shortest angular distance between two hue angles in degrees [0, 180]
function M.hue_difference(h1, h2)
  local d = math_abs(h1 - h2) % 360
  if d > 180 then d = 360 - d end
  return d
end

-- Chromatic distance in Oklab space (ignoring Lightness L)
function M.chromatic_distance(lab1, lab2)
  local da = lab1.a - lab2.a
  local db = lab1.b - lab2.b
  return math_sqrt(da * da + db * db)
end

-- Inverse: Oklab {L, a, b} to {r, g, b} in [0, 1]
function M.oklab_to_rgb(lab)
  local r_lin, g_lin, b_lin = M.oklab_to_linear_srgb(lab)

  return {
    r = clamp01(M.linear_to_srgb(r_lin)),
    g = clamp01(M.linear_to_srgb(g_lin)),
    b = clamp01(M.linear_to_srgb(b_lin)),
  }
end

-- Convert Oklab {L, a, b} to cylindrical Oklch {L, C, h}
-- h in degrees [0, 360)
function M.oklab_to_oklch(lab)
  local C = math_sqrt(lab.a * lab.a + lab.b * lab.b)
  local h = math_atan2(lab.b, lab.a) * (180 / math_pi)
  if h < 0 then h = h + 360 end
  return { L = lab.L, C = C, h = h }
end

-- Convert Oklch {L, C, h} to Oklab {L, a, b}
function M.oklch_to_oklab(lch)
  local rad = lch.h * (math_pi / 180)
  return {
    L = lch.L,
    a = lch.C * math.cos(rad),
    b = lch.C * math.sin(rad),
  }
end

-- Perceptual Euclidean distance in Oklab
function M.delta_e_ok(lab1, lab2)
  local dL = lab1.L - lab2.L
  local da = lab1.a - lab2.a
  local db = lab1.b - lab2.b
  return math_sqrt(dL * dL + da * da + db * db)
end

-- WCAG 2.x relative luminance (distinct from APCA luminance coefficients).
function M.relative_luminance(rgb)
  local r = M.srgb_to_linear(rgb.r)
  local g = M.srgb_to_linear(rgb.g)
  local b = M.srgb_to_linear(rgb.b)
  return 0.2126 * r + 0.7152 * g + 0.0722 * b
end

-- WCAG 2.1 Contrast Ratio
function M.wcag_contrast(rgb1, rgb2)
  local y1 = M.relative_luminance(rgb1)
  local y2 = M.relative_luminance(rgb2)
  local l1 = math_max(y1, y2)
  local l2 = math_min(y1, y2)
  return (l1 + 0.05) / (l2 + 0.05)
end

-- APCA (Accessible Perceptual Contrast Algorithm 0.98G standard)
function M.apca(rgb_fg, rgb_bg)
  local function to_y(rgb)
    local r = rgb.r ^ 2.4
    local g = rgb.g ^ 2.4
    local b = rgb.b ^ 2.4
    local y = 0.2126729 * r + 0.7151522 * g + 0.0721750 * b
    if y < 0.022 then
      y = y + (0.022 - y) ^ 1.414
    end
    return y
  end

  local y_fg = to_y(rgb_fg)
  local y_bg = to_y(rgb_bg)

  local c
  if y_bg > y_fg then
    -- Normal polarity (dark text on light bg)
    c = 1.14 * (y_bg ^ 0.56 - y_fg ^ 0.57)
    if math_abs(c) < 0.1 then return 0.0 end
    c = c - 0.027
  else
    -- Reverse polarity (light text on dark bg)
    c = 1.14 * (y_bg ^ 0.65 - y_fg ^ 0.62)
    if math_abs(c) < 0.1 then return 0.0 end
    c = c + 0.027
  end
  return c * 100.0
end

-- Linear-sRGB projections from DaltonLens (public domain / Unlicense).
-- https://github.com/DaltonLens/libDaltonLens/blob/master/svg/cvd_svg_filters.html
-- Protan/deutan: Viénot 1999 adaptation; tritan: Brettel 1997 two-plane adaptation.
M.cvd_models = {
  protan = "vienot1999-srgb-daltonlens",
  deutan = "vienot1999-srgb-daltonlens",
  tritan = "brettel1997-srgb-daltonlens",
}

function M.sim_cvd(rgb, cvd_type)
  local r = M.srgb_to_linear(rgb.r)
  local g = M.srgb_to_linear(rgb.g)
  local b = M.srgb_to_linear(rgb.b)
  local r_sim, g_sim, b_sim
  if cvd_type == "protan" then
    r_sim = 0.10889 * r + 0.89111 * g
    g_sim = r_sim
    b_sim = 0.00447 * r - 0.00447 * g + b
  elseif cvd_type == "deutan" then
    r_sim = 0.29031 * r + 0.70969 * g
    g_sim = r_sim
    b_sim = -0.02197 * r + 0.02197 * g + b
  elseif cvd_type == "tritan" then
    if 7.92482 * r - 5.66475 * g - 2.26007 * b >= 0 then
      r_sim = 1.01354 * r + 0.14268 * g - 0.15622 * b
      g_sim = -0.01181 * r + 0.87561 * g + 0.13619 * b
      b_sim = 0.07707 * r + 0.81208 * g + 0.11085 * b
    else
      r_sim = 0.93337 * r + 0.19999 * g - 0.13336 * b
      g_sim = 0.05809 * r + 0.82565 * g + 0.11626 * b
      b_sim = -0.37923 * r + 1.13825 * g + 0.24098 * b
    end
  else
    error("Unknown CVD type: " .. tostring(cvd_type))
  end
  return {
    r = M.linear_to_srgb(r_sim),
    g = M.linear_to_srgb(g_sim),
    b = M.linear_to_srgb(b_sim),
  }
end

-- Warmth index in Oklab space: positive = warm (yellow/red), negative = cool (blue)
function M.warmth_index(lab)
  return lab.b + 0.4 * lab.a
end

-- Classifies the perceptual temperature of a color
function M.temperature_category(lab)
  local w = M.warmth_index(lab)
  local c = math_sqrt(lab.a * lab.a + lab.b * lab.b)
  if c < 0.012 then
    return "Neutral", w
  elseif w > 0.030 then
    return "Very Warm", w
  elseif w > 0.010 then
    return "Warm", w
  elseif w < -0.035 then
    return "Very Cold", w
  elseif w < -0.010 then
    return "Cool", w
  else
    return "Neutral", w
  end
end

return M
