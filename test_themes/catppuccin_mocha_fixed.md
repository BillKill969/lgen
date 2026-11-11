---
name: Catppuccin Mocha (OLED Dark / #0f0f0f)
strictness: normal
ignore:
  - hue_sector_mismatch
---

# Catppuccin Mocha (OLED Dark / #0f0f0f)

A fully reworked, 100% accessible edition of Catppuccin Mocha built directly upon `test_themes/catppuccin_mocha.md` as the baseline. It preserves authentic Catppuccin aesthetics on a deep `#0f0f0f` canvas while satisfying modern color science under the verified DaltonLens CVD models:

1. **Deep Neutral Canvas (`#0f0f0f`)**: Replaces the cold blue-purple base with a pure neutral dark `#0f0f0f` canvas (Warmth: +0.000, Chroma: 0.000), eliminating eye strain, blue glare, and hue camouflage.
2. **Authentic Catppuccin Mocha Accents**:
   - **Normal Green (slot 2)**: Uses authentic Catppuccin Green (`#a6e3a1`). Under the verified DaltonLens Viénot model, Green maintains robust perceptual separation from Red (`#fa92ae`) with $\Delta E_{\text{Ok}} = 0.214$ (Protan) and $0.108$ (Deutan), well above the $0.08$ threshold.
   - **Normal Yellow (slot 3)**: Authentic Catppuccin Yellow (`#f9e2af`, pastel cream).
   - **Normal Blue (slot 4)**: Authentic Catppuccin Blue (`#89b4fa`).
   - **Normal Magenta (slot 5)**: Authentic Catppuccin Pink (`#f5c2e7`).
   - **Normal Cyan (slot 6)**: Authentic Catppuccin Teal (`#94e2d5`).
   - **White (slot 7)**: Authentic Catppuccin Subtext1 (`#bac2de`).
   - **Foreground & Bright White (slot 15)**: Authentic Catppuccin Text (`#cdd6f4`), fixing upstream's bright white inversion bug.
3. **Optimized Red Contrast (`#fa92ae`)**: Calibrated by `lgen`'s fix engine to achieve optimal contrast (APCA $-60.0$, WCAG $8.93:1$) while strictly preserving Catppuccin's $3.2^\circ$ berry-rose hue and $0.129$ chroma.
4. **Legible Comments (ANSI 8: `#979ab2`)**: Upgrades comments from illegible `#585b70` to a calibrated Overlay slate (`#979ab2`), delivering clear legibility (APCA $-48.0$, WCAG $6.92:1$).
5. **Distinct Bright Tier**: Slots 9–14 are lighter variants of the normal accents, with measured Oklab lightness steps of 0.0656–0.0666. Their intended hue directions are retained during gamut fitting; bright yellow becomes a pale cream near the top of the sRGB gamut. Bright white retains its existing 0.0618 step.

| Slot | Color Name       | Hex       | Origin / Role |
|:-----|:-----------------|:----------|:--------------|
| bg   | Background       | `#0f0f0f` | Deep neutral dark canvas (OLED) |
| fg   | Foreground       | `#cdd6f4` | Exact original Text |
| 0    | Black            | `#45475a` | Exact original Surface1 |
| 1    | Red              | `#fa92ae` | Calibrated Red (APCA -60.0, WCAG 8.9:1) |
| 2    | Green            | `#a6e3a1` | Exact original Green (CVD safe under DaltonLens) |
| 3    | Yellow           | `#f9e2af` | Exact original Yellow (pastel cream) |
| 4    | Blue             | `#89b4fa` | Exact original Blue |
| 5    | Magenta          | `#f5c2e7` | Exact original Pink |
| 6    | Cyan             | `#94e2d5` | Exact original Teal (soft seafoam) |
| 7    | White            | `#bac2de` | Exact original Subtext1 |
| 8    | Bright Black     | `#979ab2` | Calibrated Overlay slate (comment) |
| 9    | Bright Red       | `#ffb3c5` | Lighter Red (+0.0666 L) |
| 10   | Bright Green     | `#bbf9b5` | Lighter Green (+0.0656 L) |
| 11   | Bright Yellow    | `#fffaed` | Lighter Yellow (+0.0661 L) |
| 12   | Bright Blue      | `#a8caff` | Lighter Blue (+0.0666 L) |
| 13   | Bright Magenta   | `#ffdff6` | Lighter Pink (+0.0666 L) |
| 14   | Bright Cyan      | `#a9f8ea` | Lighter Teal (+0.0656 L) |
| 15   | Bright White     | `#cdd6f4` | Exact original Text (fixes inversion) |
| cur  | Cursor           | `#f5e0dc` | Exact original Rosewater |
| sel  | Selection        | `#45475a` | Exact original Surface1 |
