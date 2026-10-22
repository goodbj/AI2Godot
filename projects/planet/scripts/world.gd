extends Node3D

## Spawns debris and rivals, applies gravity toward the player, and resolves
## the "big fish eats little fish" rules.

const DebrisScript := preload("res://scripts/debris.gd")
const RivalScript := preload("res://scripts/rival.gd")

@export var debris_count := 70
@export var spawn_radius := 30.0
@export var field_radius := 60.0
@export var respawn_delay := 1.4

## A body must be this much bigger than the other to eat it.
@export var eat_margin := 1.12

## Rivals
@export var rival_count := 3
@export var rival_spawn_radius := 55.0
@export var rival_respawn_delay := 9.0
## Rivals are held back until the player has grown past this mass, so the
## opening seconds are a safe feeding phase.
@export var rival_grace_mass := 6.0

const RIVAL_TINTS := [
	Color(0.85, 0.28, 0.22),  # rust red
	Color(0.90, 0.62, 0.15),  # amber
	Color(0.55, 0.35, 0.85),  # violet
	Color(0.20, 0.75, 0.70),  # teal
	Color(0.90, 0.35, 0.60),  # magenta
]

var planet: RigidBody3D
var debris_root: Node3D
var rival_root: Node3D
var fx: Node3D

var _debris: Array = []
var _rivals: Array = []
var _respawn_timer := 0.0
var _rival_timer := 0.0


func _ready() -> void:
	debris_root = Node3D.new()
	debris_root.name = "Debris"
	add_child(debris_root)

	rival_root = Node3D.new()
	rival_root.name = "Rivals"
	add_child(rival_root)

	# Opening field: everything is safely edible so the player always gets a
	# running start. Threats are introduced only by later respawns.
	for i in debris_count:
		_spawn_debris(1.0, true)

	_rival_timer = 0.0


func register_planet(p: RigidBody3D) -> void:
	planet = p


func register_fx(f: Node3D) -> void:
	fx = f


func _spawn_debris(near_mass: float, safe: bool = false) -> void:
	var d = DebrisScript.new()
	var r := randf()
	var kind := 0
	if r < 0.25:
		kind = 1
	elif r < 0.40:
		kind = 2

	# Mostly smaller than the player, occasionally a genuine threat.
	var m := near_mass * randf_range(0.15, 0.85)
	if not safe and randf() < 0.10:
		m = near_mass * randf_range(1.4, 3.0)
	if safe:
		m = minf(m, near_mass * 0.85)

	d.setup(maxf(m, 0.12), kind)

	var angle := randf() * TAU
	var dist := randf_range(spawn_radius * 0.55, spawn_radius)
	var origin := planet.global_position if planet else Vector3.ZERO
	var pos := origin + Vector3(cos(angle) * dist, randf_range(-10.0, 10.0), sin(angle) * dist)

	d.position = pos
	debris_root.add_child(d)
	_debris.append(d)

	# Give it an inward drift so the field actually closes in on the player.
	if planet:
		var inward: Vector3 = (origin - pos).normalized()
		d.linear_velocity = inward * randf_range(1.5, 5.5)


func _spawn_rival() -> void:
	if planet == null:
		return

	var r = RivalScript.new()
	# Rivals should contest the field, not execute the player. Keep them
	# close to the player's size and never lethal at spawn.
	var base: float = maxf(planet.mass_value, 1.0)
	# A rival is never dramatically bigger than the player at spawn; it must
	# grow by feeding too. This keeps every encounter winnable.
	var m: float = clampf(base * randf_range(0.55, 0.95), 0.6, 340.0)
	r.setup(m, RIVAL_TINTS[randi() % RIVAL_TINTS.size()])

	var angle := randf() * TAU
	var pos: Vector3 = planet.global_position + Vector3(
		cos(angle) * rival_spawn_radius,
		randf_range(-14.0, 14.0),
		sin(angle) * rival_spawn_radius
	)
	r.position = pos

	r.eaten_by_player.connect(func(gained): _on_rival_eaten(gained))
	r.ate_player.connect(func(): _on_rival_ate_player())

	rival_root.add_child(r)
	_rivals.append(r)


func _physics_process(delta: float) -> void:
	if planet == null or not planet.alive:
		return

	_apply_gravity()
	_resolve_debris()
	_resolve_rivals()
	_resolve_rival_vs_debris()

	# Endgame: a black hole drags in and swallows everything.
	if planet.is_black_hole():
		_consume_everything(delta)
		return

	_respawn_timer += delta
	if _respawn_timer >= respawn_delay and _debris.size() < debris_count:
		_respawn_timer = 0.0
		_spawn_debris(planet.mass_value)

	_rival_timer += delta
	_rivals = _rivals.filter(func(r): return is_instance_valid(r) and not r.consumed)
	var past_grace: bool = planet.mass_value >= rival_grace_mass
	if past_grace and _rival_timer >= rival_respawn_delay and _rivals.size() < rival_count:
		_rival_timer = 0.0
		_spawn_rival()


func _apply_gravity() -> void:
	var target := planet.global_position
	var reach: float = planet.gravity_radius
	var pull: float = planet.gravity_pull

	for d in _debris:
		if d == null or d.consumed:
			continue
		var to_target: Vector3 = target - d.global_position
		var dist := to_target.length()
		if dist > reach or dist < 0.001:
			continue
		var strength := pull * clampf(1.0 - dist / reach, 0.0, 1.0)
		strength /= maxf(dist * 0.35, 1.0)
		d.apply_central_force(to_target.normalized() * strength * d.mass * 18.0)


func _resolve_debris() -> void:
	var p_radius: float = planet.get_radius()
	var p_pos: Vector3 = planet.global_position
	var p_mass: float = planet.mass_value

	for i in range(_debris.size() - 1, -1, -1):
		var d = _debris[i]
		if d == null:
			_debris.remove_at(i)
			continue
		if d.consumed:
			_debris.erase(d)
			continue

		var dist: float = d.global_position.distance_to(p_pos)
		if dist > p_radius + d.radius:
			continue

		if p_mass >= d.mass_value * eat_margin:
			planet.absorb(d.mass_value)
			_burst(d.global_position, _debris_color(d), 10, 4.0, 0.45)
			_consume(d)
			_debris.erase(d)
		elif d.mass_value >= p_mass * eat_margin:
			planet.take_hit(d.mass_value)
			_burst(d.global_position, Color(1.0, 0.35, 0.2), 22, 7.0, 0.6)
			if fx: fx.shake(1.0)
			_consume(d)
			_debris.erase(d)
		else:
			var push: Vector3 = (d.global_position - p_pos).normalized()
			if push == Vector3.ZERO:
				push = Vector3.UP
			d.linear_velocity = push * 12.0
			planet.linear_velocity -= push * 3.0


func _resolve_rivals() -> void:
	if planet == null or not planet.alive:
		return

	var p_pos: Vector3 = planet.global_position
	var p_radius: float = planet.get_radius()
	var p_mass: float = planet.mass_value

	for i in range(_rivals.size() - 1, -1, -1):
		var r = _rivals[i]
		if r == null or not is_instance_valid(r) or r.consumed:
			_rivals.remove_at(i)
			continue

		var dist: float = r.global_position.distance_to(p_pos)
		if dist > p_radius + r.get_radius():
			continue

		if p_mass >= r.mass_value * eat_margin:
			# Player devours the rival.
			var gained: float = r.mass_value
			r.eaten_by_player.emit(gained)
			planet.absorb(gained)
			_burst(r.global_position, r.tint_color, 40, 9.0, 0.9)
			if fx: fx.shake(1.4)
			r.devour()
			_rivals.remove_at(i)

		elif r.mass_value >= p_mass * eat_margin:
			# Rival devours the player.
			r.ate_player.emit()
			planet.take_hit(r.mass_value * 0.85)
			_burst(p_pos, Color(1.0, 0.25, 0.15), 50, 11.0, 1.0)
			if fx: fx.shake(2.2)
			r.devour()
			_rivals.remove_at(i)
			if not planet.alive:
				return

		else:
			# Comparable size: bounce apart.
			var push: Vector3 = (r.global_position - p_pos).normalized()
			if push == Vector3.ZERO:
				push = Vector3.UP
			r.linear_velocity = push * 14.0
			planet.linear_velocity -= push * 4.0


func _resolve_rival_vs_debris() -> void:
	for r in _rivals:
		if r == null or not is_instance_valid(r) or r.consumed:
			continue
		var rr: float = r.get_radius()
		for i in range(_debris.size() - 1, -1, -1):
			var d = _debris[i]
			if d == null or d.consumed:
				continue
			if d.global_position.distance_to(r.global_position) > rr + d.radius:
				continue
			if r.mass_value >= d.mass_value * eat_margin:
				r.absorb(d.mass_value)
				_burst(d.global_position, _debris_color(d), 8, 3.0, 0.35)
				_consume(d)
				_debris.erase(d)


func _on_rival_eaten(gained: float) -> void:
	pass


func _on_rival_ate_player() -> void:
	pass


## Black-hole endgame: pull every remaining body in and consume it.
func _consume_everything(delta: float) -> void:
	var target: Vector3 = planet.global_position
	var p_radius: float = planet.get_radius()

	for i in range(_debris.size() - 1, -1, -1):
		var d = _debris[i]
		if d == null or d.consumed:
			_debris.remove_at(i)
			continue
		var to_target: Vector3 = target - d.global_position
		var dist := to_target.length()
		d.linear_velocity += to_target.normalized() * 120.0 * delta
		if dist < p_radius + d.radius:
			planet.absorb(d.mass_value)
			_burst(d.global_position, _debris_color(d), 6, 3.0, 0.3)
			_consume(d)
			_debris.erase(d)

	for i in range(_rivals.size() - 1, -1, -1):
		var r = _rivals[i]
		if r == null or not is_instance_valid(r) or r.consumed:
			_rivals.remove_at(i)
			continue
		var to_target: Vector3 = target - r.global_position
		var dist := to_target.length()
		r.linear_velocity += to_target.normalized() * 120.0 * delta
		if dist < p_radius + r.get_radius():
			planet.absorb(r.mass_value)
			_burst(r.global_position, r.tint_color, 30, 8.0, 0.8)
			if fx: fx.shake(1.0)
			r.devour()
			_rivals.remove_at(i)


func _debris_color(d) -> Color:
	match d.kind:
		1:
			return Color(0.75, 0.88, 1.0)
		2:
			return Color(0.70, 0.62, 0.55)
		_:
			return Color(0.55, 0.45, 0.38)


func _burst(pos: Vector3, color: Color, amount: int, spread: float, life: float) -> void:
	if fx and fx.has_method("burst"):
		fx.burst(pos, color, amount, spread, life)


func _consume(d) -> void:
	d.consumed = true
	d.queue_free()
