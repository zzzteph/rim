## Town generation — grid size, gaps, streets.
## Edit the numbers here; scripts/botnet_proto.gd reads them through aliases and never defines them itself.
## A changed value needs the scene restarted (constants are read when the script loads).

# ── the town ──
const GRID_COLS := 6
const GRID_ROWS := 6
const EMPTY_CELL := 0.15           # chance a cell is a gap (park, void) — never the rigs or downtown
const LINK_REACH := 1.55           # × MAP_CELL: the hidden network links every two buildings this close; it is also
                                   # how far a building SEES and how far a connection can REACH (hidden: a link is drawn once used)
const LINK_INTEL := 0.02           # Intel/s every connection (wire) drains while it exists — cheap, but not free
const SHAPES := ["spiral", "elliptical", "ring", "grid"]   # New-game layouts, the default first (the hidden network adapts to any shape)
const GALAXIES := ["spiral", "elliptical", "ring"]          # the galaxy shapes; a multiplayer match takes one from its seed
# ── galaxy layouts (in MAP_CELL units) ──
const STAR_SPACING := 0.85         # no two computers closer than this
const STAR_AREA := 1.15            # room per computer: sets how big a galaxy grows for its computer count
const STAR_CANDIDATES := 10        # each computer is the best of this many random spots (the farthest from the others): even spacing
const SPIRAL_TWIST := 0.9          # × PI: how far a 2-arm galaxy's arms wind from the core to the tips (more arms wind a little more)
const SPIRAL_ARM := 1.0            # half-width of a 2-arm galaxy's arms (more arms are narrower, so gaps stay between them)
const ELLIPSE_X := 1.3             # the elliptical galaxy's axes (wide, like the screen)
const ELLIPSE_Y := 0.8
const RING_HOLE := 0.55            # the ring's empty middle, as a share of its outer radius
const TOWN_WORDS := ["Block", "Yard", "Row", "Plaza", "Depot", "Tower", "Mill", "Court", "Lane", "Pier", "Works", "Arcade"]
# JUNCTIONS are the best-connected crossroads of the mid town, whose links admit
# JUNCTION_CAP_MULT × LINK_CAP packets per second — holding one opens a second front
const JUNCTIONS := 2               # junction spots per town
const JUNCTION_CAP_MULT := 2       # traffic multiplier on a junction's streets
