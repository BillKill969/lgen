-- Project audit policy. These cutoffs are not claims of standards conformance.
local M = { version = "3", hue_epsilon = 0.000004, bright_tolerance = 0.02 }
M.bright = {min_gap=0.06, target_gap=0.065}

function M.bright_gap(normal_L, bright_L, is_dark)
  if is_dark then return bright_L - normal_L end
  return math.abs(bright_L - normal_L)
end

local text = {
  relaxed = { fail = {apca=35, wcag=2.5}, warn = {apca=50, wcag=3.5} },
  normal = { fail = {apca=45, wcag=3}, warn = {apca=60, wcag=4.5} },
  strict = { fail = {apca=60, wcag=4.5}, warn = {apca=75, wcag=7} },
}

function M.text(strictness)
  return text[strictness or "normal"] or text.normal
end

M.comment = {fail={apca=35, wcag=2.5}, warn={apca=45, wcag=2.5}, target={apca=48, wcag=2.5}}
M.cvd = {fail=0.05, warn=0.08, target=0.085}
M.balance = {spread=0.20, std_dev=0.070}
M.camouflage = {hue=35, apca=68, chromatic_distance=0.090, target_apca=75}

function M.meets_contrast(apca, wcag, target)
  return math.abs(apca) >= target.apca and wcag >= target.wcag
end

function M.contrast_level(apca, wcag, thresholds)
  if not M.meets_contrast(apca, wcag, thresholds.fail) then return "FAIL" end
  if not M.meets_contrast(apca, wcag, thresholds.warn) then return "WARN" end
  return "PASS"
end

-- delta E already includes the lightness difference; a second dL bound is redundant.
function M.cvd_level(delta_e)
  if delta_e < M.cvd.fail then return "FAIL" end
  if delta_e < M.cvd.warn then return "WARN" end
  return "PASS"
end

local readability = {
  LOW_CONTRAST=true, SUBOPTIMAL_CONTRAST=true, CONTRAST_OK=true, FG_ILLEGIBLE=true,
  COMMENT_ILLEGIBLE=true, COMMENT_FAINT=true, SYNTAX_COLLISION=true, SYNTAX_AMBIGUITY=true,
  CVD_DIFF_COLLISION=true, CVD_DIFF_DIFFICULT=true, CURSOR_LOW_CONTRAST=true,
  SELECTION_LOW_CONTRAST=true,
}

function M.category(code)
  if readability[code] then return "readability" end
  if code == "INVERTED_BRIGHT_PAIR" or code == "INDISTINCT_BRIGHT_PAIR" then return "semantics" end
  return "style"
end

return M
