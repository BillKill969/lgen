-- tests/run.lua
-- Minimal, dependency-free test runner for lgen

local M = {
  passed = 0,
  failed = 0,
  tests = {},
}

function M.test(name, fn)
  table.insert(M.tests, { name = name, fn = fn })
end

function M.assert_eq(actual, expected, msg)
  if actual ~= expected then
    error(string.format("%s: expected %s, got %s", msg or "assertion failed", tostring(expected), tostring(actual)), 2)
  end
end

function M.assert_near(actual, expected, tolerance, msg)
  tolerance = tolerance or 1e-4
  if math.abs(actual - expected) > tolerance then
    error(string.format("%s: expected %s ± %s, got %s (diff %s)",
      msg or "assertion failed", tostring(expected), tostring(tolerance), tostring(actual), tostring(math.abs(actual - expected))), 2)
  end
end

function M.assert_true(cond, msg)
  if not cond then
    error(msg or "expected true, got false", 2)
  end
end

function M.run()
  local total = #M.tests
  print(string.format("Running %d test(s)...", total))
  for _, t in ipairs(M.tests) do
    local ok, err = pcall(t.fn)
    if ok then
      M.passed = M.passed + 1
      io.stdout:write("\27[32m.\27[0m")
    else
      M.failed = M.failed + 1
      io.stdout:write("\27[31mF\27[0m")
      print(string.format("\n\27[31mFAIL: %s\27[0m\n  %s", t.name, err))
    end
    io.stdout:flush()
  end
  print(string.format("\n\nTest results: \27[32m%d passed\27[0m, \27[%dm%d failed\27[0m (total %d)",
    M.passed, M.failed > 0 and 31 or 32, M.failed, total))
  if M.failed > 0 then
    os.exit(1)
  end
end

return M
