## Town generation — grid size, gaps, streets.
## Edit the numbers here; scripts/botnet_proto.gd reads them through aliases and never defines them itself.
## A changed value needs the scene restarted (constants are read when the script loads).

# ── the town ──
const GRID_COLS := 6
const GRID_ROWS := 6
const EMPTY_CELL := 0.15           # chance a cell is a gap (park, void) — never the rigs or downtown
const LINK_REACH := 1.55           # × MAP_CELL: the hidden network links every two buildings this close; it is also
                                   # how far a building SEES and how far a connection can REACH (routes are never drawn)
const LINK_INTEL := 0.02           # Intel/s every connection (wire) drains while it exists — cheap, but not free
const SHAPES := ["grid", "circle"] # map layouts (the hidden network adapts to any shape)
const TOWN_WORDS := ["Block", "Yard", "Row", "Plaza", "Depot", "Tower", "Mill", "Court", "Lane", "Pier", "Works", "Arcade"]
# JUNCTIONS are the best-connected crossroads of the mid town, whose links admit
# JUNCTION_CAP_MULT × LINK_CAP packets per second — holding one opens a second front
const JUNCTIONS := 2               # junction spots per town
const JUNCTION_CAP_MULT := 2       # traffic multiplier on a junction's streets
