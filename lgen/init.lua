-- lgen/init.lua
-- Top-level module interface for lgen

local cm = require("lgen.color_math")
local parser = require("lgen.markdown_parser")
local auditor = require("lgen.auditor")
local fixer = require("lgen.fixer")
local reporter = require("lgen.reporter")
local exporter = require("lgen.exporter")

local M = {
  _VERSION = "0.1.0",
  color_math = cm,
  markdown_parser = parser,
  auditor = auditor,
  fixer = fixer,
  reporter = reporter,
  exporter = exporter,
}

local function options(doc, opts)
  if opts ~= nil and type(opts) ~= "table" then
    return nil, {code="INVALID_OPTIONS", message="Options must be a table"}
  end
  if opts and opts.meta ~= nil and type(opts.meta) ~= "table" then
    return nil, {code="INVALID_OPTIONS", message="meta must be a table"}
  end
  local effective = {}
  for k, v in pairs(doc.meta) do effective[k] = v end
  for k, v in pairs((opts and opts.meta) or {}) do effective[k] = v end
  for k, v in pairs(opts or {}) do effective[k] = v end
  effective.strictness = effective.strictness or "normal"
  if effective.strictness ~= "normal" and effective.strictness ~= "strict" and effective.strictness ~= "relaxed" then
    return nil, {code="INVALID_OPTIONS", message="strictness must be normal, strict, or relaxed"}
  end
  if effective.ignore ~= nil and type(effective.ignore) ~= "table" then
    return nil, {code="INVALID_OPTIONS", message="ignore must be a list of diagnostic codes"}
  end
  for _, code in ipairs(effective.ignore or {}) do
    if type(code) ~= "string" then
      return nil, {code="INVALID_OPTIONS", message="ignore must contain diagnostic code strings"}
    end
  end
  local count = 0
  for key in pairs(effective.ignore or {}) do
    count = count + 1
    if type(key) ~= "number" or key < 1 or key ~= math.floor(key) then
      return nil, {code="INVALID_OPTIONS", message="ignore must be a dense list"}
    end
  end
  if count ~= #(effective.ignore or {}) then
    return nil, {code="INVALID_OPTIONS", message="ignore must be a dense list"}
  end
  return effective
end

local function audit_document(doc, opts)
  if not (doc.palette.bg or doc.palette[0]) then
    return nil, {code="INVALID_THEME", message="Theme must declare a background (bg or ANSI 0)"}
  end
  local effective, err = options(doc, opts)
  if not effective then return nil, err end
  return auditor.audit(doc.palette, effective), doc, effective
end

-- Success: diagnostics, document. Failure: nil, structured error.
function M.audit_file(path, opts)
  local doc, err = parser.parse_file(path)
  if not doc then return nil, err end
  return audit_document(doc, opts)
end

function M.audit_string(str, opts)
  if type(str) ~= "string" then
    return nil, {code="INVALID_INPUT", message="Theme content must be a string"}
  end
  return audit_document(parser.parse(str), opts)
end

function M.audit_palette(pal, opts)
  return auditor.audit(pal, opts)
end

local function fix_document(doc, opts)
  local diag, err, effective = audit_document(doc, opts)
  if not diag then return nil, err end
  local result, plan_err = require("lgen.fix_plan").plan(doc, effective)
  if not result then return nil, plan_err end
  result.content = parser.apply_edits(doc, result.edits)
  -- Reparse the exact bytes returned to the caller, not just the proposed palette.
  result.after = M.audit_string(result.content, effective)
  return result
end

function M.fix_string(str, opts)
  if type(str) ~= "string" then
    return nil, {code="INVALID_INPUT", message="Theme content must be a string"}
  end
  return fix_document(parser.parse(str), opts)
end

-- Computes a plan; disk writes belong to the caller.
function M.fix_file(path, opts)
  local doc, err = parser.parse_file(path)
  if not doc then return nil, err end
  return fix_document(doc, opts)
end

function M.export_file(path, format_name)
  local doc, err = parser.parse_file(path)
  if not doc then return nil, err end
  if not (doc.palette.bg or doc.palette[0]) then
    return nil, {code="INVALID_THEME", message="Theme must declare a background (bg or ANSI 0)"}
  end
  local out, export_err = exporter.export(doc.palette, format_name, doc.meta)
  if not out then return nil, {code="EXPORT_ERROR", message=export_err} end
  return out
end

function M.diff_files(path1, path2, opts)
  local diag1, doc1 = M.audit_file(path1, opts)
  if not diag1 then return nil, doc1 end
  local diag2, doc2 = M.audit_file(path2, opts)
  if not diag2 then return nil, doc2 end
  return reporter.format_diff(doc1, doc2, diag1, diag2, opts)
end

return M
