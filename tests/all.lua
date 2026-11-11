-- tests/all.lua
-- Runs all test suites for lgen

package.path = package.path .. ";./?.lua;./?/init.lua"
local runner = require("tests.run")

require("tests.test_color_math")
require("tests.test_parser")
require("tests.test_fixer")
require("tests.test_auditor")
require("tests.test_reporter")
require("tests.test_temperature")
require("tests.test_vibrancy")
require("tests.test_color_refinements")
require("tests.test_exporter")
require("tests.test_diff_and_preview")
require("tests.test_fuzz_and_edges")
require("tests.test_workflows")
require("tests.test_math_regressions")
require("tests.test_bright_pairs")

runner.run()
