# Color calculations and audit policy

This is the current numerical contract. Earlier research and theme baselines predate the verified CVD corrections.

## Calculations

- Opaque colors use sRGB channels in `[0, 1]`. sRGB transfer functions are piecewise; Oklab transforms use the Ottosson matrices. Oklch differences use Euclidean Oklab distance.
- WCAG contrast uses relative luminance coefficients `0.2126`, `0.7152`, and `0.0722`, with `(lighter + 0.05) / (darker + 0.05)`.
- APCA uses the 0.0.98G-4g contrast core and its separate `0.2126729`, `0.7151522`, `0.0721750` coefficients. Signed results retain text/background polarity. A fixed APCA threshold alone does not establish readability for an unspecified font, size, or weight.
- Gamut fitting reduces chroma along a constant-lightness/hue Oklch ray using 20 binary-search steps and a `0.0001` linear-sRGB gamut tolerance. This is **lgen's gamut-boundary reduction**, not the CSS binary-search algorithm with local MINDE. Clipping tolerance and 8-bit hex rounding can slightly change the realized lightness and hue. Returned `L/C/h` fields describe the intended mapped coordinates; reparse `hex` to measure the written color.
- Hue-sector checks skip accents with chroma at or below `0.000004`, where hue is powerless. Vibrancy adjustment does not invent a hue for these neutral accents.

## CVD models

Protanopia and deuteranopia use the linear-sRGB Viénot 1999 adaptations published by DaltonLens. Tritanopia uses its Brettel 1997 adaptation with two projection planes. The coefficients are the published five-decimal filter coefficients, applied after sRGB decoding; the result is clipped to the display gamut and encoded back to sRGB. These are model simulations, not individual visual assessments.

The DaltonLens implementation is public domain under the Unlicense. Source attribution and independently evaluated primary/mixed-color fixtures are recorded in `lgen/color_math.lua` and `tests/test_math_regressions.lua`. Tests cover both tritanopia half-planes. They verify numerical implementation, not empirical accuracy for every observer.

Agent JSON identifies these choices under `metrics.models`:

| Field | Identifier |
| --- | --- |
| `apca` | `0.0.98G-4g` |
| `wcag` | `2.x` |
| `gamut` | `oklch-chroma-reduction-v1` |
| `cvd.protan`, `cvd.deutan` | `vienot1999-srgb-daltonlens` |
| `cvd.tritan` | `brettel1997-srgb-daltonlens` |

Changing the CVD model changes audit scores. Reference files named `catppuccin_mocha_fixed.md` and `catppuccin_mocha_vibrant.md` retain their names; names alone do not guarantee a passing audit. The current fixed Mocha theme has been updated with a distinct bright tier and passes policy 3.

## Shared project policy

`lgen/policy.lua` owns contrast acceptance, CVD separation cutoffs, bright-pair tolerance, and accent-balance/camouflage targets. Audit and adjustment use the same predicates. JSON exposes policy version `3`, profile `terminal`.

| Text profile | Failure below APCA / WCAG | Warning below APCA / WCAG |
| --- | --- | --- |
| relaxed | 35 / 2.5 | 50 / 3.5 |
| normal | 45 / 3 | 60 / 4.5 |
| strict | 60 / 4.5 | 75 / 7 |

Both contrast criteria must be met. Comments use failure thresholds 35 / 2.5, warning thresholds 45 / 2.5, and an adjustment target of 48 / 2.5. Explicit foregrounds retain failure-only diagnostics; their measured contrast is included in the result.

CVD diff auditing compares ANSI 1 and 2 under protanopia and deuteranopia. Failure is delta E below `0.05`; warning is below `0.08`. Earlier lightness conditions were redundant because delta E is at least the absolute lightness difference. CVD adjustment aims for `0.085` while retaining the selected text profile's failure thresholds. The preview uses slots 1 and 2 too.

Bright-pair auditing covers normal slots 1–7 against bright slots 9–15. On dark themes the bright slot must be at least `0.06` Oklab L lighter; on light themes it must have at least `0.06` absolute lightness separation while retaining text contrast. These are project preferences, not universal visibility guarantees. Inversions beyond `0.02` on dark themes retain `INVERTED_BRIGHT_PAIR`; otherwise insufficient separation emits `INDISTINCT_BRIGHT_PAIR`. Both carry suggested bright-slot edits when feasible. The fixer aims for `0.065` separation to provide a quantization margin, tries warning-free contrast first, and falls back to the failure thresholds if needed. It preserves the normal partner; other audit fixes can still change normal slots independently. Black/comment ordering retains its separate rules. JSON exposes each pair under `metrics.bright_pairs`, keyed by bright slot.

Warmth (`b + 0.4a`), chroma preferences, hue sectors, camouflage, and lightness-dispersion cutoffs are project heuristics. Chroma preferences are fixed hue-dependent values; they are not calculated gamut cusps. Diagnostics carry `basis: "project-policy"` and a `category` of `readability`, `semantics`, or `style`. These categories describe the concern, not a standards-conformance verdict. Existing style checks remain enabled and can be suppressed with `ignore`.

## Adjustment behavior

Contrast and CVD adjustment sample 64 intervals in each lightness direction, refine the first observed failing/passing interval with 20 binary-search steps, and choose the nearer passing candidate by Oklab distance. Every acceptance test uses the quantized hex color. The search preserves hue direction while reducing chroma as needed for gamut fitting; it is not a global optimizer over all colors.

Contrast adjustment accepts optional targets as `adjust_contrast(fg, bg, apca, wcag)`. It returns `hex`, or `nil, {code="UNREACHABLE_CONTRAST", message=...}` when no candidate is found. CVD adjustment can similarly return `UNREACHABLE_CVD`. `distinguish_bright(bright, normal, bg, minimum)` can return `UNREACHABLE_BRIGHT_PAIR` when separation and contrast cannot both be achieved in its search. These errors describe a bounded, hue-preserving search, not proof that no color anywhere can meet the goals. Audit diagnostics omit a suggestion when none is found. Failure-level contrast adjustment tries the warning targets first, then the failure targets if necessary.

Accent balancing follows the requested mean rather than forcing a dark-theme lightness range, then checks text contrast. Comment desaturation also preserves comment contrast. Vibrancy adjustment measures the serialized color's chroma and contrast. A fix plan still evaluates every proposed edit against the whole palette and re-audits the final returned source text; unresolved findings remain explicit.

## Primary references

- [Ottosson: Oklab](https://bottosson.github.io/posts/oklab/)
- [WCAG relative luminance](https://www.w3.org/TR/WCAG22/#dfn-relative-luminance)
- [APCA reference implementation](https://github.com/Myndex/apca-w3/blob/master/src/apca-w3.js)
- [Viénot, Brettel, Mollon 1999](https://vision.psychol.cam.ac.uk/jdmollon/papers/colourmaps.pdf)
- [Brettel, Viénot, Mollon 1997](https://vision.psychol.cam.ac.uk/jdmollon/papers/Dichromatsimulation.pdf)
- [DaltonLens linearRGB coefficients](https://github.com/DaltonLens/libDaltonLens/blob/master/svg/cvd_svg_filters.html) and [license](https://github.com/DaltonLens/libDaltonLens/blob/master/LICENSE)
- [CSS gamut mapping](https://www.w3.org/TR/css-color-4/#gamut-mapping) and [powerless Oklch hue](https://www.w3.org/TR/css-color-4/#ok-lab)
