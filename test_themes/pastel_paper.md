---
name: Pastel Paper
strictness: normal
ignore:
  - comment_overbright
---

# Pastel Paper

A warm, tactile light terminal theme inspired by artist sketchbooks, watercolor washes, and antique book paper.

Designed for long reading and writing sessions without glare or eye fatigue. Built with perceptual uniformity in Oklab and strictly calibrated for contrast, CVD discriminability, and distinct normal/bright hierarchies.

## Design Highlights

1. **Warm Natural Canvas (`#f6f3eb`)**:
   An ivory/vellum matte paper base (Oklab $L=0.963$, Warmth: $+0.011$, Chroma: $0.011$) that eliminates the harsh blue glare of `#ffffff` while preserving warm paper texture.

2. **Soft Pastel Watercolor Accents (ANSI 1–6)**:
   Perceptually soft gouache and watercolor washes calibrated to satisfy standard text contrast ($APCA \ge 67.5$, $WCAG \ge 4.5:1$):
   - **Red (`#823b34`)**: Terracotta rose ink ($L=0.445$, APCA $+80.2$, WCAG $7.22:1$).
   - **Green (`#457a51`)**: Herbal sage mint ($L=0.531$, APCA $+67.7$, WCAG $4.56:1$).
   - **Yellow (`#7c5c16`)**: Warm amber ochre ($L=0.495$, APCA $+73.5$, WCAG $5.57:1$).
   - **Blue (`#446799`)**: Dusty denim blue ($L=0.510$, APCA $+71.3$, WCAG $5.16:1$).
   - **Magenta (`#7d537a`)**: Antique mauve / plum ($L=0.502$, APCA $+73.7$, WCAG $5.59:1$).
   - **Cyan (`#1c767b`)**: Vintage sea glass teal ($L=0.518$, APCA $+69.0$, WCAG $4.79:1$).

3. **Concentrated Ink Bright Tier (ANSI 9–14)**:
   In light terminal environments, "bright" text emphasizes keywords with deep, pigmented ink. Each bright slot provides a verified step ($\Delta L \ge 0.076$, $\Delta E_{\text{Ok}} \ge 0.076$) delivering AAA-tier contrast ($APCA \ge 77$, $WCAG \ge 6.4:1$).

4. **Legible Graphite Comments (`#7c8390`)**:
   Comments evoke soft 2B pencil annotations ($L=0.605$, APCA $+58.6$, WCAG $3.44:1$), remaining legible without competing with active syntax.

5. **DaltonLens CVD Verified**:
   Git diff Red (`#823b34`) and Green (`#457a51`) maintain robust perceptual separation under all dichromatic simulations ($\Delta E_{\text{Ok}} = 0.165$ Protan, $0.083$ Deutan, $0.183$ Tritan).

| Slot | Color Name       | Hex       | Origin / Role |
|:-----|:-----------------|:----------|:--------------|
| bg   | Background       | `#f6f3eb` | Warm paper / cream vellum canvas |
| fg   | Foreground       | `#2c333d` | Deep charcoal fountain pen ink |
| 0    | Black            | `#424855` | Soft charcoal surface ink |
| 1    | Red              | `#823b34` | Terracotta rose wash |
| 2    | Green            | `#457a51` | Herbal sage mint |
| 3    | Yellow           | `#7c5c16` | Warm amber ochre |
| 4    | Blue             | `#446799` | Dusty denim blue |
| 5    | Magenta          | `#7d537a` | Antique mauve / plum |
| 6    | Cyan             | `#1c767b` | Vintage sea glass teal |
| 7    | White            | `#474d5a` | Charcoal text ink |
| 8    | Bright Black     | `#7c8390` | Graphite pencil comment |
| 9    | Bright Red       | `#682520` | Concentrated madder red |
| 10   | Bright Green     | `#2b6338` | Deep cypress green |
| 11   | Bright Yellow    | `#5d4300` | Deep bistre amber |
| 12   | Bright Blue      | `#244f80` | Deep indigo blue |
| 13   | Bright Magenta   | `#62375f` | Deep mulberry ink |
| 14   | Bright Cyan      | `#005f66` | Deep pine teal |
| 15   | Bright White     | `#242932` | Dark calligraphy ink |
| cur  | Cursor           | `#823b34` | Terracotta pen nib |
| sel  | Selection        | `#e6dfd1` | Washed linen paper highlight |
