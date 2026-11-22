# lgen handoff

`lgen` audits, adjusts, compares, and exports ANSI terminal palettes from Markdown using dependency-free Lua.

## Start here

- [README](README.md): commands, input format, Lua interface, agent JSON, and exit codes.
- [Color science](docs/COLOR_SCIENCE.md): numerical models, source attribution, policy, and search limitations.
- [Glossary](GLOSSARY.md): domain terminology.
- [Historical material](docs/archive/README.md): original research, prototype, and superseded handoff notes.

## Modules

| Path | Responsibility |
| --- | --- |
| `bin/lgen` | CLI arguments, input/output, viewport, watch, and atomic writes |
| `lgen/init.lua` | Document workflows, option precedence, structured errors |
| `lgen/markdown_parser.lua` | Content/file ingestion, aliases, source positions, precise slot edits |
| `lgen/color_math.lua` | sRGB, Oklab/Oklch, gamut reduction, APCA/WCAG, named CVD simulations |
| `lgen/policy.lua` | Shared project thresholds and acceptance predicates. Current policy version 4 |
| `lgen/auditor.lua` | Palette measurements and categorized diagnostics |
| `lgen/fixer.lua` | Quantized contrast, CVD, bright-tier, and style adjustments |
| `lgen/fix_plan.lua` | Whole-palette ranking of single-slot suggestions and bounded pair repairs |
| `lgen/reporter.lua` | Terminal/Markdown reports, deterministic JSON, comparisons |
| `lgen/exporter.lua` | Eight terminal configuration output formats |

## Contracts to preserve

- `markdown_parser.parse` accepts content only; `parse_file` reads files explicitly. Document workflows require `bg` or ANSI slot 0.
- Option precedence: explicit options, `opts.meta`, frontmatter, defaults. Input errors return `nil, {code, message}` from the document workflows.
- Slot edits preserve unrelated source bytes. The first declaration of a slot wins.
- Fix plans do not write files. They assess quantized colors, reject new failures, and re-audit the exact resulting Markdown. Unresolved findings stay explicit.
- Bright slots 9–15 need at least 0.06 Oklab lightness separation from slots 1–7. Dark-theme bright slots must be lighter; the adjustment target is 0.065.
- CVD simulation changes the viewport only. Numerical models and policy versions are identified in JSON; project heuristics are not standards-conformance certifications.
- CLI exits: 0 accepted, 1 audit findings rejected, 2 input/usage/output error. Fix uses the resulting audit; diff uses the second theme. `--fail-on-warn` rejects warnings.
- Atomic writes check source bytes but do not lock concurrent writers or preserve filesystem metadata. See the README before changing this behavior.

## Validation

```bash
lua tests/all.lua
python3 tests/test_cli.py
```

Set `LGEN_LUA` to run the CLI suite with a specific interpreter, such as `luajit`.

`test_themes/catppuccin_mocha.md` is the upstream reference. The fixed Mocha theme has a distinct bright tier and audits with zero failures and warnings under policy 4. The vibrant theme is a separate fixture. Preserve these distinctions when refreshing fixtures.

## Follow-up work

Open work includes direct terminal-config ingestion, packaging, and CI integration.
