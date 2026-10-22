extends Node

## Dev-only headless smoke test: runs the game for N seconds with the player
## drifting toward the nearest debris, then reports whether mass grew and
## whether any stage transition fired. Invoked with `-- --selftest`.

var _elapsed := 0.0
var _start_mass := 0.0
var _stages_seen: Array = []
var _planet: RigidBody3D
var _world: Node3D


func _ready() -> void:
	if not OS.get_cmdline_user_args().has("--selftest"):
		set_process(false)
		return


func _process(delta: float) -> void:
	_elapsed += delta

	if _planet == null:
		var nodes := get_tree().get_nodes_in_group("planet")
		if nodes.is_empty():
			return
		_planet = nodes[0]
		_start_mass = _planet.mass_value
		_planet.stage_changed.connect(func(s): _stages_seen.append(s))
		_world = get_parent().get_node_or_null("World")
		print("[selftest] start mass=%.2f" % _start_mass)
		return

	# Steer toward the nearest edible debris to prove absorption works.
	if _world:
		var best = null
		var best_d := 1e9
		for d in _world.get("_debris"):
			if d == null or d.consumed:
				continue
			if d.mass_value * 1.12 > _planet.mass_value:
				continue
			var dist: float = d.global_position.distance_to(_planet.global_position)
			if dist < best_d:
				best_d = dist
				best = d
		if best:
			var dir: Vector3 = (best.global_position - _planet.global_position).normalized()
			_planet.linear_velocity += dir * 30.0 * delta

	if _elapsed >= 18.0:
		var grew: bool = _planet.mass_value > _start_mass
		print("[selftest] end mass=%.2f grew=%s stages=%s" % [
			_planet.mass_value, str(grew), str(_stages_seen)
		])
		var debris = _world.get("_debris") if _world else []
		print("[selftest] debris remaining=%d planet_radius=%.2f" % [
			debris.size(), _planet.get_radius()
		])
		var near := 0
		for d in debris:
			if d == null: continue
			if d.global_position.distance_to(_planet.global_position) < 8.0:
				near += 1
		print("[selftest] debris within 8 units=%d" % near)
		print("[selftest] RESULT: %s" % ("PASS" if grew else "FAIL"))
		get_tree().quit()
