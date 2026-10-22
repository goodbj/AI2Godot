extends RigidBody3D

## A chunk of matter drifting through space. Small ones get eaten by the player,
## big ones eat the player.

enum Kind { ROCK, ICY, METALLIC }

var mass_value := 1.0
var radius := 0.5
var kind: Kind = Kind.ROCK
var consumed := false

var _spin := Vector3.ZERO
var _mesh: MeshInstance3D
var _mat: StandardMaterial3D


func setup(p_mass: float, p_kind: Kind) -> void:
	mass_value = p_mass
	kind = p_kind
	radius = clampf(0.28 + sqrt(p_mass) * 0.30, 0.28, 3.2)


func _ready() -> void:
	add_to_group("debris")

	_mesh = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 12
	sphere.rings = 7
	_mesh.mesh = sphere
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	_mat = StandardMaterial3D.new()
	_mat.albedo_color = _kind_color()
	_mat.roughness = 0.95
	_mat.metallic = 0.35 if kind == Kind.METALLIC else 0.0
	_mat.emission_enabled = kind == Kind.ICY
	_mat.emission = _kind_color() * 0.35
	_mesh.material_override = _mat
	add_child(_mesh)

	var shape := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = radius
	shape.shape = sphere_shape
	add_child(shape)

	mass = maxf(mass_value, 0.2)
	gravity_scale = 0.0
	linear_damp = 0.05
	angular_damp = 0.0

	_spin = Vector3(
		randf_range(-1.2, 1.2),
		randf_range(-1.2, 1.2),
		randf_range(-1.2, 1.2)
	)

	var dir := Vector3(randf_range(-1, 1), randf_range(-0.4, 0.4), randf_range(-1, 1)).normalized()
	linear_velocity = dir * randf_range(1.0, 5.0)


func _physics_process(delta: float) -> void:
	_mesh.rotate_x(_spin.x * delta)
	_mesh.rotate_y(_spin.y * delta)
	_mesh.rotate_z(_spin.z * delta)


func _kind_color() -> Color:
	match kind:
		Kind.ICY:
			return Color(0.72, 0.86, 0.98)
		Kind.METALLIC:
			return Color(0.55, 0.50, 0.46)
		_:
			return Color(0.36, 0.31, 0.27)
