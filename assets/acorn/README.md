# Imported Acorn

The designer imported `Workspace.acorn`. Its three uploaded meshes (Nut,
Cap and Stem) share one texture. `acorn.json` records Studio measurements;
`acorn.rbxmx` preserves a portable Roblox assembly using those uploaded IDs.
The original source GLB was not supplied with this import.

Overall bounds: 0.594 × 0.827 × 0.594 studs. Runtime uses a white tint and
positions each piece relative to the Nut centre. `Config.ACORN_MESH` is the
runtime source of IDs, dimensions and offsets. `AcornModel` prewarms a
replicated template; tree/ground Acorns, storage fill and carried baskets clone it.
The shake panel keeps the existing legible 2D `Theme.acorn` glyph.
