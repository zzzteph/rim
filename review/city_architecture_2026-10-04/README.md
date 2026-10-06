# Architecture reference sheet

Prepared 4 October 2026 for [CITY_ARCHITECTURE.md](../../CITY_ARCHITECTURE.md) and [CLAUDE_CITY.md](../../CLAUDE_CITY.md).

- [PNG preview](architecture_reference.png): nine proposed architecture/site patterns.
- [SVG original](architecture_reference.svg): scalable, self-contained vector illustration with no external assets.
- [Generator](build_reference_sheet.py): Python standard-library script producing the SVG from simple isometric geometry.

The sheet is an original schematic study. It illustrates massing, roof rhythm, frontage, and grounds; it is not a game capture, measured reconstruction, or implementation/performance result. Regional source evidence and the distinction between observed references and proposed game rules are in the main architecture guide.

Regenerate the SVG with `python review/city_architecture_2026-10-04/build_reference_sheet.py` from the repository root. The PNG was rasterised at 1460 x 1270 using Chromium through Playwright, drawing the SVG onto a canvas. The Python SVG generator itself does not require Playwright.

Inspected the generated preview and corrected a garden-tree draw-order overlap. Documentation checks cover readable UTF-8, local link targets, SVG parsing, and the presence of all nine pattern panels. No game-code changes or game-runtime checks are part of this reference-sheet work.
