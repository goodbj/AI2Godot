extends Node3D

## Spawns debris, applies gravity toward the player, and resolves the
## "big fish eats little fish" rules.

const DebrisScript := preload("res://scripts/debris.gd")

@export var debris_count := 70
@export var spawn_radius := 30.0
@export var field_radius := 60.0
@export var respawn_delay := 1.4

## A body must be this much bigger than the other to eat it.
@export var eat_margin := 1.12

var planet: RigidBody3D
var debris_root: Node3D
var _debris: Array = []
var _respawn_timer := 0.0


func _ready() -> void:
	debris_root = Node3D.new()
	debris_root.name = "Debris"
	add_child(debris_root)

	for i in debris_count:
		_spawn_debris(_initial_mass())


func register_planet(p: RigidBody3D) -> void:
	planet = p


func _initial_mass() -> float:
	# Early game should be mostly edible, with a few threats to avoid.
	var r := randf()
	if r < 0.55:
		return randf_range(0.15, 0.75)
	elif r < 0.85:
		return randf_range(0.75, 2.0)
	return randf_range(2.0, 5.0)


func _spawn_debris(near_mass: float) -> void:
	var d = DebrisScript.new()
	var r := randf()
	var kind := 0
	if r < 0.25:
		kind = 1
	elif r < 0.40:
		kind = 2

	# Mostly smaller than the player, occasionally a genuine threat.
	var m := near_mass * randf_range(0.15, 0.85)
	if randf() < 0.10:
		m = near_mass * randf_range(1.4, 3.0)

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


func _physics_process(delta: float) -> void:
	if planet == null or not planet.alive:
		return

	_apply_gravity()
	_resolve_collisions()

	_respawn_timer += delta
	if _respawn_timer >= respawn_delay and _debris.size() < debris_count:
		_respawn_timer = 0.0
		_spawn_debris(planet.mass_value)


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


func _resolve_collisions() -> void:
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
			_consume(d)
			_debris.erase(d)
		elif d.mass_value >= p_mass * eat_margin:
			planet.take_hit(d.mass_value)
			_consume(d)
			_debris.erase(d)
		else:
			var push: Vector3 = (d.global_position - p_pos).normalized()
			if push == Vector3.ZERO:
				push = Vector3.UP
			d.linear_velocity = push * 12.0
			planet.linear_velocity -= push * 3.0


func _consume(d) -> void:
	d.consumed = true
	d.queue_free()
