extends RefCounted
## The Insane difficulty: one brain per AI faction, created by botnet_proto.gd on the faction's first tick.
## The game calls tick(dt) every simulated frame; the brain keeps its own clocks.
## (Stub: until the full brain lands it plays exactly like the Normal AI, on the Normal cadence.)

var game                 # the botnet_proto.gd instance (all rules and helpers live there)
var fac := -1            # the faction this brain plays
var _think_t := 0.0


func _init(g, faction: int) -> void:
	game = g; fac = faction
	_think_t = float(game.AI_PROFILE[fac].cadence) * 0.5


func tick(dt: float) -> void:
	_think_t -= dt
	if _think_t > 0.0: return
	_think_t = float(game.AI_PROFILE[fac].cadence) * float(game.ai_speed)
	game._ai_think(fac)
