# ANSI colorscheme auditing

## Language

**Palette**: Colors assigned to ANSI slots 0–15 and terminal roles such as background, foreground, cursor, and selection.

**Theme document**: A palette and its metadata together with the source text that declares them.

**Slot edit**: A replacement color assigned to one declared palette slot, independent of other slots that share its original color.

**Fix plan**: A set of slot edits assessed together against the original palette, with the remaining audit findings made explicit.

**CVD viewport**: A simulated view of a palette for a color vision deficiency; it does not change the theme being audited or edited.
