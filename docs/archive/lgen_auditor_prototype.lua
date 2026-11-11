-- lgen_auditor_prototype.lua
-- Self-contained reference implementation of an ANSI colorscheme auditor
-- Extreme correctness (Oklab, APCA, WCAG 2.1, CVD) yet simple (pure Lua, zero dependencies)

local M = {}

--------------------------------------------------------------------------------
-- 1. Color Math & Conversions
--------------------------------------------------------------------------------

local math_sqrt = math.sqrt
local math_abs = math.abs
local math_atan2 = math.atan2 or math.atan -- compatibility across Lua 5.1/5.4
local math_pi = math.pi
local math_floor = math.floor

function M.hex_to_rgb(hex)
  if type(hex) ~= "string" then return nil end
  hex = hex:gsub("^#", ""):gsub("%s+", "")
  if #hex == 3 then
    hex = hex:sub(1,1):rep(2) .. hex:sub(2,2):rep(2) .. hex:sub(3,3):rep(2)
  end
  if #hex ~= 6 then return nil end
  local num = tonumber(hex, 16)
  if not num then return nil end
  return {
    r = math_floor(num / 65536) / 255,
    g = math_floor((num % 65536) / 256) / 255,
    b = (num % 256) / 255,
    hex = "#" .. hex:lower()
  }
end

function M.srgb_to_linear(c)
  if c <= 0.04045 then
    return c / 12.92
  else
    return ((c + 0.055) / 1.055) ^ 2.4
  end
end

-- Converts normalized sRGB {r, g, b} in [0, 1] to Oklab {L, a, b}
function M.rgb_to_oklab(rgb)
  local r = M.srgb_to_linear(rgb.r)
  local g = M.srgb_to_linear(rgb.g)
  local b = M.srgb_to_linear(rgb.b)

  -- Linear sRGB to LMS
  local l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
  local m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
  local s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b

  -- Non-linear compression
  local l_ = l ^ (1 / 3)
  local m_ = m ^ (1 / 3)
  local s_ = s ^ (1 / 3)

  -- LMS to Oklab
  local L = 0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_
  local a = 1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_
  local b_val = 0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_

  return { L = L, a = a, b = b_val }
end

-- Converts Oklab {L, a, b} to Oklch {L, C, h} (h in degrees 0..360)
function M.oklab_to_oklch(oklab)
  local C = math_sqrt(oklab.a * oklab.a + oklab.b * oklab.b)
  local h = math_atan2(oklab.b, oklab.a) * (180 / math_pi)
  if h < 0 then h = h + 360 end
  return { L = oklab.L, C = C, h = h }
end

-- Perceptual Euclidean distance in Oklab space
function M.delta_e_ok(lab1, lab2)
  local dL = lab1.L - lab2.L
  local da = lab1.a - lab2.a
  local db = lab1.b - lab2.b
  return math_sqrt(dL * dL + da * da + db * db)
end

-- Relative luminance Y (BT.709 / sRGB)
function M.relative_luminance(rgb)
  local r = M.srgb_to_linear(rgb.r)
  local g = M.srgb_to_linear(rgb.g)
  local b = M.srgb_to_linear(rgb.b)
  return 0.2126729 * r + 0.7151522 * g + 0.0721750 * b
end

-- Standard WCAG 2.1 Contrast Ratio
function M.wcag_contrast(rgb1, rgb2)
  local y1 = M.relative_luminance(rgb1)
  local y2 = M.relative_luminance(rgb2)
  local lighter = y1 > y2 and y1 or y2
  local darker = y1 > y2 and y2 or y1
  return (lighter + 0.05) / (darker + 0.05)
end

-- APCA (Accessible Perceptual Contrast Algorithm - 0.98G standard)
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

-- Color Vision Deficiency (CVD) Simulation (Viénot et al. 1999)
-- Applies projection to linear sRGB
function M.sim_cvd(rgb, cvd_type)
  local r = M.srgb_to_linear(rgb.r)
  local g = M.srgb_to_linear(rgb.g)
  local b = M.srgb_to_linear(rgb.b)

  local r_sim, g_sim, b_sim
  if cvd_type == "protan" then
    r_sim = 0.56667 * r + 0.43333 * g
    g_sim = 0.55833 * r + 0.44167 * g
    b_sim = 0.24167 * g + 0.75833 * b
  elseif cvd_type == "deutan" then
    r_sim = 0.62500 * r + 0.37500 * g
    g_sim = 0.70000 * r + 0.30000 * g
    b_sim = 0.30000 * g + 0.70000 * b
  elseif cvd_type == "tritan" then
    r_sim = 0.95000 * r + 0.05000 * g
    g_sim = 0.43333 * g + 0.56667 * b
    b_sim = 0.47500 * g + 0.52500 * b
  else
    r_sim, g_sim, b_sim = r, g, b
  end

  -- Clamp to [0, 1]
  local function clamp(v) return v < 0 and 0 or (v > 1 and 1 or v) end
  r_sim, g_sim, b_sim = clamp(r_sim), clamp(g_sim), clamp(b_sim)

  -- De-linearize back to sRGB representation
  local function linear_to_srgb(c)
    if c <= 0.0031308 then
      return c * 12.92
    else
      return 1.055 * (c ^ (1 / 2.4)) - 0.055
    end
  end

  return {
    r = linear_to_srgb(r_sim),
    g = linear_to_srgb(g_sim),
    b = linear_to_srgb(b_sim),
  }
end

--------------------------------------------------------------------------------
-- 2. Audit Engine & Diagnostic Rules
--------------------------------------------------------------------------------

local COLOR_NAMES = {
  [0] = "Black", [1] = "Red",     [2] = "Green", [3] = "Yellow",
  [4] = "Blue",  [5] = "Magenta", [6] = "Cyan",  [7] = "White",
  [8] = "Bright Black",   [9] = "Bright Red",     [10] = "Bright Green", [11] = "Bright Yellow",
  [12] = "Bright Blue",   [13] = "Bright Magenta", [14] = "Bright Cyan",  [15] = "Bright White",
}

function M.audit_palette(raw_palette)
  local palette = {}
  local oklab = {}
  local oklch = {}

  -- Parse all entries
  for k, v in pairs(raw_palette) do
    local rgb = type(v) == "string" and M.hex_to_rgb(v) or v
    if rgb then
      palette[k] = rgb
      oklab[k] = M.rgb_to_oklab(rgb)
      oklch[k] = M.oklab_to_oklch(oklab[k])
    end
  end

  local bg = palette.bg or palette[0]
  local fg = palette.fg or palette[7]
  local is_dark = oklab.bg and oklab.bg.L < 0.5 or (oklab[0] and oklab[0].L < 0.5)

  local diagnostics = {
    fails = {},
    warns = {},
    infos = {},
    metrics = {
      is_dark = is_dark,
      contrast_scores = {},
      pairwise_distances = {},
    }
  }

  local function add_diag(level, code, msg, ctx)
    local entry = { code = code, message = msg, context = ctx }
    if level == "FAIL" then
      table.insert(diagnostics.fails, entry)
    elseif level == "WARN" then
      table.insert(diagnostics.warns, entry)
    else
      table.insert(diagnostics.infos, entry)
    end
  end

  -- Rule A: Contrast of ANSI 1..7, 9..15, and fg against bg
  for idx = 1, 15 do
    if idx ~= 8 and palette[idx] and bg then
      local wcag = M.wcag_contrast(palette[idx], bg)
      local apca_val = M.apca(palette[idx], bg)
      local abs_apca = math_abs(apca_val)
      local name = COLOR_NAMES[idx]

      diagnostics.metrics.contrast_scores[idx] = { wcag = wcag, apca = apca_val }

      if wcag < 3.0 or abs_apca < 45 then
        add_diag("FAIL", "LOW_CONTRAST",
          string.format("ANSI %d (%s) has unreadable contrast against bg (WCAG: %.2f:1, APCA: %.1f)", idx, name, wcag, apca_val),
          { slot = idx, wcag = wcag, apca = apca_val })
      elseif wcag < 4.5 or abs_apca < 60 then
        add_diag("WARN", "SUBOPTIMAL_CONTRAST",
          string.format("ANSI %d (%s) has suboptimal contrast against bg (WCAG: %.2f:1, APCA: %.1f)", idx, name, wcag, apca_val),
          { slot = idx, wcag = wcag, apca = apca_val })
      end
    end
  end

  -- Rule B: Comment & Muted Contrast (ANSI 8)
  if palette[8] and bg then
    local wcag8 = M.wcag_contrast(palette[8], bg)
    local apca8 = M.apca(palette[8], bg)
    local abs_apca8 = math_abs(apca8)
    diagnostics.metrics.contrast_scores[8] = { wcag = wcag8, apca = apca8 }

    if abs_apca8 < 35 or wcag8 < 2.5 then
      add_diag("FAIL", "COMMENT_ILLEGIBLE",
        string.format("ANSI 8 (Bright Black/Comment) is illegible against bg (APCA: %.1f, WCAG: %.2f:1)", apca8, wcag8),
        { slot = 8, wcag = wcag8, apca = apca8 })
    elseif abs_apca8 < 45 then
      add_diag("WARN", "COMMENT_FAINT",
        string.format("ANSI 8 (Bright Black/Comment) is faint against bg (APCA: %.1f)", apca8),
        { slot = 8, apca = apca8 })
    end

    if palette[7] and oklab[8].L >= oklab[7].L then
      add_diag("WARN", "COMMENT_OVERBRIGHT",
        "ANSI 8 (Comment) is brighter than or equal to ANSI 7 (Default Foreground)",
        { slot = 8 })
    end
  end

  -- Rule C: Bright Pair Hierarchy / Monotonicity
  for i = 1, 6 do
    local norm_idx = i
    local bright_idx = i + 8
    if oklab[norm_idx] and oklab[bright_idx] then
      local L_norm = oklab[norm_idx].L
      local L_bright = oklab[bright_idx].L
      if is_dark and L_bright < L_norm - 0.02 then
        add_diag("WARN", "INVERTED_BRIGHT_PAIR",
          string.format("ANSI %d (%s) is darker than normal ANSI %d (L_bright=%.2f < L_norm=%.2f)",
            bright_idx, COLOR_NAMES[bright_idx], norm_idx, L_bright, L_norm),
          { norm = norm_idx, bright = bright_idx })
      end
    end
  end

  -- Rule D: Semantic Syntax Distinction (Pairwise Delta-E among normal tokens)
  local syntax_tokens = { 1, 2, 3, 4, 5, 6 }
  for i = 1, #syntax_tokens do
    for j = i + 1, #syntax_tokens do
      local a_idx = syntax_tokens[i]
      local b_idx = syntax_tokens[j]
      if oklab[a_idx] and oklab[b_idx] then
        local de = M.delta_e_ok(oklab[a_idx], oklab[b_idx])
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
  if palette[1] and palette[2] then
    for _, cvd in ipairs({ "protan", "deutan" }) do
      local sim_r = M.sim_cvd(palette[1], cvd)
      local sim_g = M.sim_cvd(palette[2], cvd)
      local lab_r = M.rgb_to_oklab(sim_r)
      local lab_g = M.rgb_to_oklab(sim_g)
      local de_cvd = M.delta_e_ok(lab_r, lab_g)
      local dL_cvd = math_abs(lab_r.L - lab_g.L)

      if de_cvd < 0.05 and dL_cvd < 0.06 then
        add_diag("FAIL", "CVD_DIFF_COLLISION",
          string.format("Git diff Red (ANSI 1) and Green (ANSI 2) are indistinguishable under %s simulation (ΔE=%.3f, |ΔL|=%.3f)",
            cvd:upper(), de_cvd, dL_cvd),
          { cvd = cvd, de = de_cvd, dL = dL_cvd })
      elseif de_cvd < 0.08 and dL_cvd < 0.08 then
        add_diag("WARN", "CVD_DIFF_DIFFICULT",
          string.format("Git diff Red and Green are difficult to distinguish under %s simulation (ΔE=%.3f, |ΔL|=%.3f)",
            cvd:upper(), de_cvd, dL_cvd),
          { cvd = cvd, de = de_cvd, dL = dL_cvd })
      end
    end
  end

  return diagnostics
end

--------------------------------------------------------------------------------
-- 3. Human-Readable Terminal Reporter
--------------------------------------------------------------------------------

function M.format_cli_report(diag)
  local lines = {}
  local function out(fmt, ...) table.insert(lines, string.format(fmt, ...)) end

  out("\n\27[1m=== ANSI Colorscheme Audit Report ===\27[0m\n")

  if #diag.fails == 0 and #diag.warns == 0 then
    out("\27[32m✔ EXCELLENT: All correctness, accessibility, and colorimetry checks passed!\27[0m\n")
    return table.concat(lines, "\n")
  end

  if #diag.fails > 0 then
    out("\27[1;31m✖ FAILS (%d):\27[0m", #diag.fails)
    for _, f in ipairs(diag.fails) do
      out("  \27[31m[FAIL]\27[0m \27[1m%s\27[0m: %s", f.code, f.message)
    end
    out("")
  end

  if #diag.warns > 0 then
    out("\27[1;33m⚠ WARNINGS (%d):\27[0m", #diag.warns)
    for _, w in ipairs(diag.warns) do
      out("  \27[33m[WARN]\27[0m \27[1m%s\27[0m: %s", w.code, w.message)
    end
    out("")
  end

  local summary_color = #diag.fails > 0 and "\27[31m" or "\27[33m"
  out("%sSummary: %d failure(s), %d warning(s)\27[0m\n", summary_color, #diag.fails, #diag.warns)

  return table.concat(lines, "\n")
end

--------------------------------------------------------------------------------
-- Self-test CLI Entry Point
--------------------------------------------------------------------------------

if not ... or ... == "test" then
  print("Auditing sample 'Problematic Dark Theme'...")
  local test_theme = {
    bg = "#121212",
    fg = "#d0d0d0",
    [0]  = "#1c1c1c",
    [1]  = "#c0392b", -- Red (dark)
    [2]  = "#27ae60", -- Green (similar lightness to red!)
    [3]  = "#f39c12", -- Yellow
    [4]  = "#1a5276", -- Blue (very dark, contrast fail)
    [5]  = "#8e44ad", -- Magenta
    [6]  = "#16a085", -- Cyan
    [7]  = "#bdc3c7", -- White
    [8]  = "#2c3e50", -- Bright Black / Comment (very dark!)
    [9]  = "#962d22", -- Bright Red (DARKER than normal red: inversion bug!)
    [10] = "#2ecc71", -- Bright Green
    [11] = "#f1c40f", -- Bright Yellow
    [12] = "#2980b9", -- Bright Blue
    [13] = "#9b59b6", -- Bright Magenta
    [14] = "#1abc9c", -- Bright Cyan
    [15] = "#ecf0f1", -- Bright White
  }

  local results = M.audit_palette(test_theme)
  print(M.format_cli_report(results))
end

return M
