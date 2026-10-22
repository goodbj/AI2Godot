extends RigidBody3D

## A rival consumer: another growing body competing for the same debris.
## It hunts smaller things, flees bigger things, and can be eaten by the player.

signal eaten_by_player(mass_gained: float)
signal ate_player
signal devoured

const STAGE_NAMES := [
	"Asteroid", "Meteor", "Planet", "Star", "White Dwarf", "Black Hole",
]
const STAGE_THRESHOLDS := [0.0, 8.0, 45.0, 160.0, 420.0, 900.0]

@export var tint_color := Color(0.85, 0.28, 0.22)
@export var speed := 16.0

var mass_value := 1.0
var radius := 0.8
var alive := true
var consumed := false
var stage := 0

var _mesh_root: Node3D
var _shader_mat: ShaderMaterial
var _spin := 0.0
var _target = null
var _retarget := 0.0
var _heat := 0.0
var _is_black_hole := false


func setup(p_mass: float, p_tint: Color) -> void:
	mass_value = p_mass
	tint_color = p_tint


func _ready() -> void:
	add_to_group("rival")
	_build_mesh()

	mass = maxf(mass_value, 0.5)
	gravity_scale = 0.0
	linear_damp = 0.0
	angular_damp = 0.0

	_apply_size()
	_after_mass_change(false)


func _build_mesh() -> void:
	_mesh_root = Node3D.new()
	_mesh_root.name = "MeshRoot"
	add_child(_mesh_root)

	var mi := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 64
	sphere.rings = 40
	mi.mesh = sphere

	var shader := load("res://shaders/planet.gdshader") as Shader
	_shader_mat = ShaderMaterial.new()
	_shader_mat.shader = shader
	_shader_mat.set_shader_parameter("tint", tint_color)
	_shader_mat.set_shader_parameter("seed_offset", Vector3(
		randf() * 40.0, randf() * 40.0, randf() * 40.0
	))
	mi.material_override = _shader_mat
	_mesh_root.add_child(mi)

	var cs := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.92
	cs.shape = shape
	add_child(cs)


func get_radius() -> float:
	return 0.9 + sqrt(mass_value) * 0.42


func _apply_size() -> void:
	var s := get_radius()
	if _mesh_root:
		_mesh_root.scale = Vector3.ONE * s
	var cs := get_node_or_null("CollisionShape3D")
	if cs and cs.shape is SphereShape3D:
		(cs.shape as SphereShape3D).radius = s * 0.92


func _physics_process(delta: float) -> void:
	if not alive:
		return

	_spin += delta * (0.3 + 0.02 * mass_value)
	if _mesh_root:
		_mesh_root.rotation.y = _spin

	_retarget -= delta
	if _retarget <= 0.0:
		_retarget = randf_range(0.35, 0.8)
		_choose_target()

	_steer(delta)

	_heat = lerpf(_heat, 1.0 if _target and _target_edible() else 0.15, 4.0 * delta)
	if _shader_mat:
		_shader_mat.set_shader_parameter("stage", stage)
		_shader_mat.set_shader_parameter("heat", _heat)
		_shader_mat.set_shader_parameter("spin", _spin * 1.5)
		_shader_mat.set_shader_parameter("black_hole_amount", _black_hole_blend())


func _target_edible() -> bool:
	return _target != null and is_instance_valid(_target) and mass_value >= _target.mass_value * 1.12


func _choose_target() -> void:
	_target = null
	var best_d := 1e9

	# Prefer the player if we can eat them.
	var player := _get_player()
	if player and player.alive and mass_value >= player.mass_value * 1.12:
		var d: float = player.global_position.distance_to(global_position)
		if d < 45.0:
			_target = player
			return

	# Otherwise hunt the biggest debris we can safely swallow.
	for d in get_tree().get_nodes_in_group("debris"):
		if d.consumed or mass_value < d.mass_value * 1.12:
			continue
		var dist: float = d.global_position.distance_to(global_position)
		if dist < best_d:
			best_d = dist
			_target = d


func _steer(delta: float) -> void:
	var desired := Vector3.ZERO

	var player := _get_player()
	# Flee a player that can eat us.
	if player and player.alive and player.mass_value >= mass_value * 1.12:
		var away: Vector3 = global_position - player.global_position
		if away.length() < 30.0:
			desired = away.normalized()
	elif _target and is_instance_valid(_target):
		desired = (_target.global_position - global_position).normalized()

	if desired != Vector3.ZERO:
		linear_velocity += desired * speed * delta * 3.0

	# Speed cap scaled to size (bigger bodies are slower).
	var cap := speed * clampf(1.4 - mass_value / 260.0, 0.45, 1.4)
	if linear_velocity.length() > cap:
		linear_velocity = linear_velocity.normalized() * cap

	linear_velocity *= 1.0 - 0.7 * delta


func _get_player() -> RigidBody3D:
	var nodes := get_tree().get_nodes_in_group("planet")
	return nodes[0] if not nodes.is_empty() else null


func absorb(other_mass: float) -> void:
	mass_value += other_mass
	_after_mass_change(true)
	_apply_size()


func _after_mass_change(announce: bool) -> void:
	var new_stage := 0
	for i in range(STAGE_THRESHOLDS.size() - 1, -1, -1):
		if mass_value >= STAGE_THRESHOLDS[i]:
			new_stage = i
			break
	if new_stage != stage:
		stage = new_stage
		if stage == 5 and not _is_black_hole:
			_is_black_hole = true
			tint_color = Color(1.0, 0.55, 0.15)


func _black_hole_blend() -> float:
	if not _is_black_hole:
		return 0.0
	var prev: float = STAGE_THRESHOLDS[4]
	return clampf((mass_value - prev) / (STAGE_THRESHOLDS[5] - prev), 0.0, 1.0)


func get_stage_name() -> String:
	return STAGE_NAMES[stage]


func devour() -> void:
	if consumed:
		return
	consumed = true
	alive = false
	devoured.emit()
	queue_free()
