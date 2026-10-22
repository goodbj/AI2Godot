extends Node3D

## Visual feedback: absorption bursts, death explosion, and camera shake.

var _camera: Camera3D
var _shake := 0.0


func _ready() -> void:
	add_to_group("fx")


func bind_camera(cam: Camera3D) -> void:
	_camera = cam


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _process(delta: float) -> void:
	if _shake <= 0.0:
		return
	_shake = maxf(0.0, _shake - delta * 3.5)
	if _camera:
		var s := _shake * 0.35
		_camera.h_offset = randf_range(-s, s)
		_camera.v_offset = randf_range(-s, s)


func burst(pos: Vector3, color: Color, amount: int = 18, spread: float = 5.0, life: float = 0.7) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 0.95
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.3
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = spread * 0.5
	p.initial_velocity_max = spread
	p.gravity = Vector3.ZERO
	p.scale_amount_min = 0.12
	p.scale_amount_max = 0.3
	p.color = color
	p.position = pos

	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 6
	mesh.rings = 3
	p.mesh = mesh

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 3.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	p.material_override = mat

	add_child(p)
	p.emitting = true

	await get_tree().create_timer(life + 0.3).timeout
	if is_instance_valid(p):
		p.queue_free()
