extends Node

## Dev-only headless smoke test.
##
##   -- --selftest          steer toward edible debris for N seconds, report growth
##   -- --selftest-long     same but 60s, reports survival and peak mass
##
## Lets the AI verify gameplay balance without watching the screen.

var _elapsed := 0.0
var _start_mass := 0.0
var _peak_mass := 0.0
var _stages_seen: Array = []
var _planet: RigidBody3D
var _world: Node3D
var _duration := 18.0
var _running := false
var _rivals_seen := 0
var _rivals_eaten := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--selftest-long"):
		_duration = 60.0
		_running = true
	elif args.has("--selftest"):
		_running = true
	if not _running:
		set_process(false)


func _process(delta: float) -> void:
	_elapsed += delta

	if _planet == null:
		var nodes := get_tree().get_nodes_in_group("planet")
		if nodes.is_empty():
			return
		_planet = nodes[0]
		_start_mass = _planet.mass_value
		_peak_mass = _start_mass
		_planet.stage_changed.connect(func(s): _stages_seen.append(s))
		_world = get_parent().get_node_or_null("World")
		print("[selftest] start mass=%.2f duration=%.0fs" % [_start_mass, _duration])
		return

	if not _planet.alive:
		_report(false, "eaten at t=%.1fs" % _elapsed)
		return

	_peak_mass = maxf(_peak_mass, _planet.mass_value)

	# Track rivals actually present in the world.
	if _world:
		var rivals_now = _world.get("_rivals")
		if rivals_now:
			_rivals_seen = maxi(_rivals_seen, rivals_now.size())

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

	if _elapsed >= _duration:
		_report(_planet.mass_value > _start_mass, "survived")


func _report(grew: bool, note: String) -> void:
	var debris = _world.get("_debris") if _world else []
	var rivals = _world.get("_rivals") if _world else []
	var alive_rivals := 0
	for r in rivals:
		if r != null and is_instance_valid(r) and not r.consumed:
			alive_rivals += 1
	print("[selftest] end mass=%.2f peak=%.2f grew=%s stages=%s" % [
		_planet.mass_value, _peak_mass, str(grew), str(_stages_seen)
	])
	print("[selftest] debris=%d rivals=%d rivals_seen=%d note=%s" % [
		debris.size(), alive_rivals, _rivals_seen, note
	])
	print("[selftest] RESULT: %s" % ("PASS" if grew else "FAIL"))
	get_tree().quit()
