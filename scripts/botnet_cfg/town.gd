## Town generation — grid size, gaps, streets.
## Edit the numbers here; scripts/botnet_proto.gd reads them through aliases and never defines them itself.
## A changed value needs the scene restarted (constants are read when the script loads).

# ── the town ──
const GRID_COLS := 6
const GRID_ROWS := 6
const EMPTY_CELL := 0.15           # chance a cell is a gap (park, void) — never the rigs or downtown
const LINK_KEEP := 0.78            # chance a street between two neighbouring buildings exists
const DIAG_P := 0.18               # chance of a diagonal shortcut street
const TOWN_WORDS := ["Block", "Yard", "Row", "Plaza", "Depot", "Tower", "Mill", "Court", "Lane", "Pier", "Works", "Arcade"]
# several paths and fronts: HIGHWAYS bridge the gaps (a street from the building before a gap to the one after
# it, nothing to cross), and JUNCTIONS are the best-connected crossroads of the mid town, whose streets admit
# JUNCTION_CAP_MULT × LINK_CAP packets per second — holding one opens a second front
const HIGHWAY_P := 0.85            # chance a gap gets a highway across it (per direction)
const JUNCTIONS := 2               # junction spots per town
const JUNCTION_CAP_MULT := 2       # traffic multiplier on a junction's streets
