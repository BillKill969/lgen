# lgen

An ANSI colorscheme auditor, checker, and auto-tuner in pure Lua designed for **extreme correctness and yet simple**.

`lgen` audits terminal colorschemes defined in simple Markdown (`.md`) files. It combines modern colorimetry (**Oklab/Oklch**, **APCA 0.98G**, **sRGB gamma linearization**, and **CVD simulation**) with terminal-specific semantics (monotonicity, syntax collision, comment legibility, and Git diff accessibility).

---

## Key Capabilities

- **Contrast (APCA + WCAG 2.x)**: Reports polarity-sensitive APCA with black flare compensation alongside WCAG contrast, using shared audit and fix targets.
- **Constant-Hue Chroma Reduction**: Fits colors to sRGB along an Oklch ray. This is lgen’s gamut-boundary method; hex rounding can slightly change the realized hue.
- **Syntax Visual Weight & Lightness Balance**: Audits the inter-accent lightness spread ($\Delta L \le 0.20, \sigma_L \le 0.070$) across the 6 primary syntax tokens (ANSI 1..6) so no single color (e.g. glaring yellow) visually overpowers another (e.g. dim blue).
- **Background Color Anchoring & Camouflage Detection**: Analyzes background warmth index ($W = b^* + 0.4 a^*$) and chroma in Oklab space. Detects when cool accents blend into cool background glare (hue camouflage) and flags backgrounds that are too cold, too warm, or overly saturated ($C > 0.045$).
- **Comment Chroma Ceiling & Tint Alignment**: Enforces comment ergonomics ($C \le 0.045$) so comments never distract from active syntax, and aligns comment temperature with tinted canvases.
- **Color Vision Deficiency (CVD) Diff Checker**: Measures red/green separation under named Viénot 1999 sRGB adaptations; the tritanopia viewport uses a Brettel 1997 two-plane adaptation.
- **Perceptual Uniformity (Oklab / Oklch)**: Computes true perceived Euclidean color distance ($\Delta E_{\text{Ok}}$) to detect syntax token collisions (when types, keywords, or strings look identical).
- **ANSI Semantics & Monotonicity**: Verifies that "bright" colors are actually brighter than their normal counterparts, flags illegible comments (ANSI 8), and verifies hue sector fidelity.
- **Auto-Fixer (`--fix`)**: Coordinates slot edits, re-audits the resulting Markdown, and reports remaining findings. Unrelated slots and prose keep their original colors.
- **Zero Dependencies**: Pure Lua (compatible with Lua 5.1, 5.2, 5.3, 5.4, 5.5, LuaJIT, and Neovim `nvim -l`).

---

## Installation & Requirements

The CLI needs Lua and no external Lua packages or C modules. Run it from a source checkout:

```bash
lua bin/lgen --help
lua bin/lgen test_themes/catppuccin_mocha_fixed.md --json
```

Examples below use `lgen` as shorthand for `lua bin/lgen`. The test suites have been run on Lua 5.4, Lua 5.5, and LuaJIT.

---

## Quickstart & CLI Usage

### Audit a Markdown colorscheme:
```bash
lgen examples/flawed_theme.md
```

### Auto-fix failing colors and generate a corrected theme:
```bash
lgen examples/flawed_theme.md --fix > fixed_theme.md
```

Repairs prioritize audit failures, then readability and ANSI hierarchy warnings. Among similarly effective edits, the fixer prefers the smallest total perceptual change from the original palette. It keeps the background fixed by default and leaves style-only warnings visible for review. Use `--fix-background` to let the fixer adjust the background or `--vibrant` to request stronger accent colors.

If individual suggestions stall, the fixer tries a bounded search over the normal and bright colors or Git diff red and green. A paired repair counts as one iteration. The Lua equivalent of `--fix-background` is `fix_background = true` in the options table.

### Overwrite the theme in-place with fixed colors:
```bash
lgen examples/flawed_theme.md --fix --write
```

### Piping from stdin:
```bash
cat theme.md | lgen -
```

### Output formats, strictness, and live preview:
```bash
# Export as machine-readable JSON
lgen theme.md --json

# Export as Markdown report
lgen theme.md --md

# Apply strict project targets (APCA 75 / WCAG 7 for warning-free text)
lgen theme.md --strict

# Apply relaxed thresholds (for pastel/muted themes)
lgen theme.md --relaxed

# Enforce high-chroma, vibrant colors (avoid washed-out/muted pastels)
lgen theme.md --vibrant

# Disable the 8-line live syntax code preview box
lgen theme.md --no-preview
```

### Side-by-side theme comparison diff:
```bash
# Compare an original theme against a fixed rework side-by-side
lgen original.md --diff fixed.md
```

### Export to terminal emulator configs:
```bash
# Export directly to Alacritty, Kitty, Ghostty, WezTerm, Neovim, Foot, Xresources, or Windows Terminal
lgen theme.md --export alacritty
lgen theme.md --export kitty
lgen theme.md --export ghostty
lgen theme.md --export wezterm
lgen theme.md --export nvim
lgen theme.md --export foot
lgen theme.md --export xresources
lgen theme.md --export wt
```

### Colorblind simulation viewport:
```bash
# Inspect your theme as perceived by colorblind users
lgen theme.md --cvd protan   # Protanopia (Red-Blind)
lgen theme.md --cvd deutan   # Deuteranopia (Green-Blind)
lgen theme.md --cvd tritan   # Tritanopia (Blue-Blind)
```

### Interactive live watch mode:
```bash
# Re-audits and redraws terminal preview instantly on every file save
lgen theme.md --watch
```

---

## Agentic usage

Use JSON and check the process exit code:

```bash
lgen theme.md --json
lgen theme.md --fix --json
lgen theme.md --fix --write --json --max-iterations 12
lgen before.md --diff after.md --json --fail-on-warn
cat theme.md | lgen - --fix --json
```

`--json` writes exactly one JSON value to stdout, without ANSI colors or progress messages. JSON errors have the form `{"schema_version":1,"error":{"code":"READ_ERROR","message":"..."}}`. Codes include `INVALID_ARGUMENT`, `INVALID_INPUT`, `INVALID_OPTIONS`, `INVALID_THEME`, `READ_ERROR`, `EXPORT_ERROR`, `WRITE_ERROR`, and `WRITE_CONFLICT`. Error messages provide context; branch on codes rather than matching messages.

| Exit | Meaning |
| --- | --- |
| `0` | No audit failures; warnings are allowed unless `--fail-on-warn` is set. |
| `1` | Audit failures remain, or warnings remain with `--fail-on-warn`. |
| `2` | Invalid arguments, unreadable input, invalid theme/options, or output failure. |

A fix command uses the **resulting** audit for its exit code. A diff command uses the **second** theme. Export succeeds with `0` when the configuration is generated; it does not enforce a passing audit. `--export` emits the requested format and cannot be combined with `--json` or `--md`. Watch mode requires terminal output and a file input.

Audit JSON identifies numerical models in `metrics.models` and the project profile/version in `metrics.policy` (currently version `4`). Normal-to-bright lightness measurements and required separation are exposed in `metrics.bright_pairs`. Diagnostics include `category` (`readability`, `semantics`, `style`) and `basis` (`project-policy`).

Audit JSON includes `schema_version`, `fails`, `warns`, `passes`, `summary`, and `metrics`. Diagnostics contain a `code`, `message`, `context`, and an optional `suggested_hex`. Palette metric maps use string keys such as `"8"` and `"bg"`. Object keys and diagnostic ordering are deterministic for the same input, options, and Lua runtime.

Fix JSON includes `content` (the exact resulting Markdown), ordered `edits` (`slot`, `old_hex`, `new_hex`), `before` and `after` audit objects, `iterations`, `status`, and `written`. Status is `resolved` when no findings remain, `stalled` when no accepted suggestion improves the current result, or `limit` when the accepted-step budget is exhausted. A stalled plan can contain useful edits and unresolved findings. `written` is true only when the file was actually replaced.

The planner evaluates one suggested slot adjustment at a time against the entire palette. It chooses the largest immediate improvement, comparing failure count first and warning count second, and rejects candidates that introduce a new failure. Stable diagnostic order breaks ties. It accepts at most 12 steps by default (`--max-iterations 1..100`). This is a bounded, conservative search: it can stop at a local optimum, does not guarantee all findings are fixable, and does not accept a temporary regression to reach a later improvement.

Without `--write`, fixes only return content. With `--write`, the CLI stages content beside the input, checks for changed source bytes, and renames it over the original. A write failure returns `2`; an audit exit of `1` may still accompany a successfully written improvement. Atomic replacement creates a new file using the current umask, replaces a symlink itself, and does not preserve permissions or other filesystem metadata. Source checks detect observed changes but do not lock out concurrent writers. Use returned content and your own write mechanism when those filesystem properties matter.

Document workflows require an explicit background (`bg` or ANSI `0`). Sparse palettes remain supported; only present slots are audited. Options resolve in this order: explicit options, explicit `opts.meta`, document frontmatter, defaults. Explicit `ignore={}` overrides frontmatter ignores. `--cvd` affects the terminal viewport only; audit metrics, JSON, fixes, and exit status always describe the original palette.

---

## Audit Rules Reference

These are project policy thresholds, rather than a standards-conformance certification. See [Color calculations and audit policy](docs/COLOR_SCIENCE.md) for model sources, numerical limits, and adjustment behavior.

| Rule Code | Category | Description | Fail Threshold | Warn Threshold |
|:---|:---|:---|:---|:---|
| `LOW_CONTRAST`, `FG_ILLEGIBLE`, `SUBOPTIMAL_CONTRAST` | Contrast | ANSI 1–7, 9–15 and explicit foreground against background | APCA \|$L_c$\| < 45 or WCAG < 3.0 | APCA \|$L_c$\| < 60 or WCAG < 4.5 |
| `COMMENT_ILLEGIBLE` | Comments | ANSI 8 (Bright Black) contrast | APCA \|$L_c$\| < 35 or WCAG < 2.5 | APCA \|$L_c$\| < 45 |
| `COMMENT_OVERLY_SATURATED` | Comments | ANSI 8 chroma distracts from code | — | Chroma $C_{\text{ok}} > 0.045$ |
| `COMMENT_TEMPERATURE_MISMATCH` | Comments | ANSI 8 tint clashes with bg tint | — | Mismatched warmth signs |
| `INVERTED_BRIGHT_PAIR` | Hierarchy | Bright color is darker than normal on a dark theme (includes white) | — | $L_{\text{bright}} < L_{\text{norm}} - 0.02$ |
| `INDISTINCT_BRIGHT_PAIR` | Hierarchy | Normal and bright slots are insufficiently separated | — | Lightness separation < 0.06; brighter required on dark themes |
| `SYNTAX_COLLISION` | Syntax | Distinction between syntax slots 1–6 | $\Delta E_{\text{Ok}} < 0.04$ | $\Delta E_{\text{Ok}} < 0.07$ |
| `ACCENT_LIGHTNESS_IMBALANCE` | Syntax | Excessive lightness spread among accents | — | $\Delta L > 0.20$ or $\sigma_L > 0.070$ |
| `ACCENT_BACKGROUND_CAMOUFLAGE` | Harmony | Accent shares hue with tinted background | — | $\Delta h < 35^\circ$ and (APCA < 68 or chromatic distance < 0.090) |
| `CVD_DIFF_COLLISION` | Accessibility | Git diff Red vs. Green under CVD | $\Delta E_{\text{Ok}} < 0.05$ | $\Delta E_{\text{Ok}} < 0.08$ |
| `HUE_SECTOR_MISMATCH`| Style | Color hue outside canonical arc | — | Non-neutral hue outside expected range |
| `MUTED_COLOR` | Vibrancy | Syntax color is desaturated/washed out | — | Chroma $C_{\text{ok}} < \text{Threshold}(h)_{\min} \times 0.95$ |
| `BACKGROUND_TOO_COLD`| Temperature | Background has harsh blue bias | — | Warmth Index $W < -0.022$ |
| `BACKGROUND_TOO_WARM`| Temperature | Background has muddy brown bias | — | Warmth Index $W > +0.025$ |
| `BACKGROUND_OVER_SATURATED` | Ergonomics | Background is too saturated | — | Chroma $C_{\text{ok}} > 0.045$ |
| `TEMPERATURE_CLASH` | Harmony | Tint mismatch between bg & text | — | Cool bg with warm text (or vice versa) |

---

## Theme Markdown Format

`lgen` parses simple Markdown files. You can write your theme as a bulleted list or a Markdown table:

### Bulleted List Format:
```markdown
# My Dark Theme

- bg: #121212
- fg: #d0d0d0
- black: #1c1c1c
- red: #ff6b6b
- green: #51cf66
- yellow: #fcc419
- blue: #4dabf7
- magenta: #da77f2
- cyan: #38d9a9
- white: #ced4da
- comment: #727d8d
- bright_red: #ffa8a8
- bright_green: #8ce99a
- bright_yellow: #ffe066
- bright_blue: #74c0fc
- bright_magenta: #e599f7
- bright_cyan: #63e6be
- bright_white: #f8f9fa
```

### Table Format:
```markdown
| Slot | Color Name   | Hex       |
|:-----|:-------------|:----------|
| bg   | Background   | `#121212` |
| fg   | Foreground   | `#d0d0d0` |
| 0    | Black        | `#1c1c1c` |
| 1    | Red          | `#ff6b6b` |
| 2    | Green        | `#51cf66` |
...
```

### Frontmatter Configuration (Optional):
You can configure theme options at the top of the file:
```yaml
---
name: My Custom Theme
strictness: relaxed # normal, relaxed, strict
ignore:
  - hue_sector_mismatch
---
```

### Supported Aliases:
- **Slots**: `0`..`15`, `ansi0`..`ansi15`, `color0`..`color15`
- **Colors**: `black`, `red`, `green`, `yellow`, `blue`, `magenta` (or `purple`), `cyan` (or `teal`), `white`
- **Brights**: `bright_black` (or `gray`, `comment`), `bright_red` (or `b_red`), `bright_green`, etc.
- **Roles**: `bg` / `background`, `fg` / `foreground`, `cursor`, `selection`

---

## Lua Programmatic API

You can use `lgen` inside your Neovim plugins or Lua projects:

```lua
local lgen = require("lgen")

-- Audit a Markdown file
local diag, doc = lgen.audit_file("theme.md", { strictness = "normal" })
if not diag then error(doc.code .. ": " .. doc.message) end

-- Audit a raw table separately
local palette_diag = lgen.audit_palette({
  bg = "#121212",
  fg = "#d0d0d0",
  [1] = "#ff6b6b",
  [2] = "#51cf66",
  -- ...
})

-- Format terminal output
print(lgen.reporter.format_terminal(diag, doc))
```

For an in-memory theme or a fix plan:

```lua
local diag, doc_or_error = lgen.audit_string(markdown, { strictness = "relaxed" })
local plan, err = lgen.fix_string(markdown, { max_iterations = 12 })
if not plan then
  error(err.code .. ": " .. err.message)
end
print(lgen.reporter.format_fix_json(plan))
-- plan.content contains precise source edits; plan.after contains residual findings.

local plan, err = lgen.fix_file("theme.md") -- computes a plan without writing
```

`audit_file`, `audit_string`, `fix_file`, `fix_string`, `export_file`, and `diff_files` return `nil, {code, message}` on input errors. Successful audits return diagnostics and the theme document. The low-level `audit_palette` interface remains available for direct palette calculations, including incomplete palettes.

`markdown_parser.parse(text)` now accepts content only; use `markdown_parser.parse_file(path)` for explicit file ingestion. `markdown_parser.apply_edits(doc, edits)` applies slot edits to original source positions, preserving other bytes, line endings, and duplicate declarations (the first declaration wins). Invalid edits are programmer errors. The older `reporter.apply_fixes_to_markdown(doc, diag)` delegates to the fix planner; prefer `fix_string` or `fix_file` to retain the full result and unresolved findings.

---

## Repository layout

- `bin/`: CLI entry point.
- `lgen/`: current Lua implementation.
- `tests/`: Lua behavior tests and Python CLI contract checks.
- `examples/` and `test_themes/`: input examples and reference palettes.
- [docs/COLOR_SCIENCE.md](docs/COLOR_SCIENCE.md): numerical contract and model sources.
- [GLOSSARY.md](GLOSSARY.md) and [lgen_handoff.md](lgen_handoff.md): domain terms and current project state.
- [docs/archive/](docs/archive/README.md): superseded research, handoff, and prototype; excluded from the active implementation.

---

## Running Tests

Run the full, self-contained test suite:
```bash
lua tests/all.lua
```

CLI contract tests use Python’s standard library as an independent JSON consumer (Python is not a runtime dependency):

```bash
python3 tests/test_cli.py
LGEN_LUA=lua5.4 python3 tests/test_cli.py
```

---

## License

MIT
