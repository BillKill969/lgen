---
name: Pastel Paper Dark
strictness: normal
---

# Pastel Paper Dark

A soothing, OLED-optimized dark companion to Pastel Paper, inspired by soft artist chalks, pastels, and gouache pigments on deep obsidian carbon paper.

Polished for rich pigment body, balanced luminance, and zero glare against true OLED black. Built upon perceptual uniformity in Oklab and strictly calibrated for contrast, CVD discriminability, and distinct normal/bright hierarchies.

## Design Highlights

1. **Obsidian Carbon Paper Canvas (`#0a0b0d`)**:
   A deep, near-black charcoal paper canvas (Oklab $L=0.149$, Warmth: $-0.005$, Chroma: $0.005$) that maximizes OLED power efficiency and contrast while preserving a hint of cool slate paper texture to eliminate pixel-wake purple smearing.

2. **Punchy Pastel Chalk Pigments (ANSI 1–6)**:
   Velvety, opaque gouache and chalk tones with enhanced pigment body ($C \approx 0.10 - 0.14$) that glow with authentic pastel presence on dark paper without looking washed-out or glaring:
   - **Red (`#ff9198`)**: Punchy ruby-rose chalk ($L=0.776$, APCA $-60.1$, WCAG $9.15:1$).
   - **Green (`#a4eda4`)**: Celadon pistachio chalk ($L=0.873$, APCA $-85.0$, WCAG $14.28:1$, CVD safe).
   - **Yellow (`#f2d17b`)**: Buttercream golden honey chalk ($L=0.871$, APCA $-80.5$, WCAG $13.30:1$).
   - **Blue (`#86b8fd`)**: Cornflower sky chalk ($L=0.774$, APCA $-62.5$, WCAG $9.65:1$).
   - **Magenta (`#eaa3e3`)**: Antique rose quartz chalk ($L=0.804$, APCA $-65.3$, WCAG $10.17:1$).
   - **Cyan (`#66d2ce`)**: Toned-down sea glass turquoise chalk ($L=0.803$, APCA $-69.3$, WCAG $10.95:1$).

3. **Crisp Neutral Alabaster Text (`#e2e6ec` & `#ccd1db`)**:
   Eliminates warm yellow haze with clean, neutral alabaster chalk text ($L=0.86 - 0.92$, Warmth $-0.010$, APCA $> -78$, WCAG $> 12.8:1$), aligning with the cool obsidian paper canvas.

4. **Luminous Highlight Bright Tier (ANSI 9–14)**:
   In dark terminal environments, "bright" text illuminates syntax keywords with radiant pastel tones. Each bright slot provides a verified step ($\Delta L \ge +0.063$, $\Delta E_{\text{Ok}} \ge 0.065$) reaching AAA contrast ($APCA \ge 74.3$, $WCAG \ge 11.9:1$).

5. **Legible Graphite Slate Comments (`#959ba7`)**:
   Comments evoke soft graphite annotations on dark paper ($L=0.690$, APCA $-47.9$, WCAG $7.05:1$), remaining legible without competing with active syntax.

6. **DaltonLens CVD Verified**:
   Git diff Red (`#ff9198`) and Green (`#a4eda4`) maintain robust perceptual separation under all dichromatic simulations ($\Delta E_{\text{Ok}} = 0.213$ Protan, $0.101$ Deutan, $0.213$ Tritan).

| Slot | Color Name       | Hex       | Origin / Role |
|:-----|:-----------------|:----------|:--------------|
| bg   | Background       | `#0a0b0d` | Deep obsidian carbon paper (OLED) |
| fg   | Foreground       | `#e2e6ec` | Crisp alabaster chalk (neutral) |
| 0    | Black            | `#20232a` | Dark slate surface shadow |
| 1    | Red              | `#ff9198` | Punchy ruby-rose chalk |
| 2    | Green            | `#a4eda4` | Celadon pistachio chalk (CVD safe) |
| 3    | Yellow           | `#f2d17b` | Buttercream golden honey chalk |
| 4    | Blue             | `#86b8fd` | Cornflower sky chalk |
| 5    | Magenta          | `#eaa3e3` | Antique rose quartz chalk |
| 6    | Cyan             | `#66d2ce` | Toned-down sea glass turquoise |
| 7    | White            | `#ccd1db` | Cool slate chalk text |
| 8    | Bright Black     | `#959ba7` | Graphite slate comment |
| 9    | Bright Red       | `#ffb7bf` | Luminous ruby-rose highlight |
| 10   | Bright Green     | `#c4fdc4` | Luminous mint highlight |
| 11   | Bright Yellow    | `#ffe8ad` | Luminous cream highlight |
| 12   | Bright Blue      | `#b2d1ff` | Luminous sky highlight |
| 13   | Bright Magenta   | `#f8bdf1` | Luminous orchid highlight |
| 14   | Bright Cyan      | `#80ebe7` | Luminous sea glass highlight |
| 15   | Bright White     | `#f2f5fa` | Pure titanium white chalk |
| cur  | Cursor           | `#ff9198` | Ruby-rose chalk tip |
| sel  | Selection        | `#282c36` | Deep slate paper selection |
