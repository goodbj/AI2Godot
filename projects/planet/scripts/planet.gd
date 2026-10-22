extends RigidBody3D

## The player planet. Grows by absorbing smaller debris, shrinks when hit by
## larger bodies, and evolves through the stellar ladder:
## Asteroid -> Meteor -> Planet -> Star -> White Dwarf -> Black Hole

signal mass_changed(mass_value: float, stage: int)
signal stage_changed(stage: int)
signal died

const STAGE_ASTEROID := 0
const STAGE_METEOR := 1
const STAGE_PLANET := 2
const STAGE_STAR := 3
const STAGE_WHITE_DWARF := 4
const STAGE_BLACK_HOLE := 5

const STAGE_NAMES := [
	"Asteroid",
	"Meteor",
	"Planet",
	"Star",
	"White Dwarf",
	"Black Hole",
]

## Mass needed to reach each stage.
const STAGE_THRESHOLDS := [0.0, 8.0, 45.0, 160.0, 420.0, 900.0]

@export var thrust_force := 26.0
@export var max_speed := 34.0
@export var gravity_pull := 9.0
@export var gravity_radius := 26.0

@export var base_radius := 0.9
@export var radius_per_mass := 0.42

var mass_value := 1.0
var stage := STAGE_ASTEROID
var alive := true

## Optional touch joystick, assigned by the game root.
var touch_controls: CanvasLayer = null

var _camera: Camera3D
var _cam_offset := Vector3(0.0, 4.5, 11.0)
var _spin := 0.0
var _shader_mat: ShaderMaterial
var _is_black_hole := false

@onready var mesh_root: Node3D = $MeshRoot


func _ready() -> void:
	add_to_group("planet")
	_camera = get_viewport().get_camera_3d()
	_shader_mat = mesh_root.get_child(0).material_override as ShaderMaterial
	_update_size()


func _physics_process(delta: float) -> void:
	if not alive:
		return

	# --- Steering (screen-relative) ---
	var input := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down")
	)
	# Touch joystick overrides keyboard when active.
	if touch_controls:
		var tv: Vector2 = touch_controls.get_move_vector()
		if tv.length() > 0.05:
			input = tv
	if input.length() > 1.0:
		input = input.normalized()

	if _camera and input != Vector2.ZERO:
		var cam_basis := _camera.global_transform.basis
		var dir := (cam_basis.x * input.x - cam_basis.z * input.y).normalized()
		apply_central_force(dir * thrust_force * mass_value)

	# Speed cap
	if linear_velocity.length() > max_speed:
		linear_velocity = linear_velocity.normalized() * max_speed

	# Gentle drag so it feels like space, not ice
	linear_velocity *= 1.0 - 0.55 * delta

	_spin += delta * (0.35 + 0.02 * mass_value)
	mesh_root.rotation.y = _spin


func _process(delta: float) -> void:
	if not alive:
		return

	if _camera:
		# Pull the camera back as the body grows so it always stays in frame.
		var dist := get_radius() * 6.5 + 9.0
		var want := Vector3(0.0, dist * 0.42, dist)
		var target := global_position + want
		_camera.global_position = _camera.global_position.lerp(target, 8.0 * delta)
		_camera.look_at(global_position, Vector3.UP)

	if _shader_mat:
		_shader_mat.set_shader_parameter("stage", stage)
		_shader_mat.set_shader_parameter("black_hole_amount", _black_hole_blend())
		_shader_mat.set_shader_parameter("spin", _spin * 1.5)


## 0..1 ramp over the last stretch before the black hole threshold.
func _black_hole_blend() -> float:
	var next := STAGE_THRESHOLDS[STAGE_BLACK_HOLE]
	var prev := STAGE_THRESHOLDS[STAGE_BLACK_HOLE - 1]
	return clampf((mass_value - prev * 0.85) / (next - prev * 0.85), 0.0, 1.0)


func get_radius() -> float:
	return base_radius + sqrt(mass_value) * radius_per_mass


func get_stage_name() -> String:
	return STAGE_NAMES[stage]


func absorb(other_mass: float) -> void:
	mass_value += other_mass
	_after_mass_change()
	_update_size()


func take_hit(other_mass: float) -> void:
	# Losing mass is proportional to the *gap* in size, not a flat fraction,
	# so a barely-bigger rock chips you instead of one-shotting you.
	var gap: float = maxf(other_mass - mass_value, 0.0)
	var loss: float = minf(other_mass * 0.35, gap * 0.25 + mass_value * 0.18)
	mass_value = maxf(0.35, mass_value - loss)
	_after_mass_change()
	_update_size()
	if mass_value <= 0.4 and stage == STAGE_ASTEROID:
		die()


func _after_mass_change() -> void:
	var new_stage := STAGE_ASTEROID
	for i in range(STAGE_THRESHOLDS.size() - 1, -1, -1):
		if mass_value >= STAGE_THRESHOLDS[i]:
			new_stage = i
			break

	if new_stage != stage:
		stage = new_stage
		stage_changed.emit(stage)
		if stage == STAGE_BLACK_HOLE and not _is_black_hole:
			_become_black_hole()

	mass_changed.emit(mass_value, stage)


func _update_size() -> void:
	var s := get_radius()
	mesh_root.scale = Vector3.ONE * s
	var shape := $CollisionShape3D.shape as SphereShape3D
	if shape:
		shape.radius = s * 0.92


func _become_black_hole() -> void:
	_is_black_hole = true
	gravity_pull *= 2.5
	gravity_radius *= 3.0


## Endgame: everything on the field is dragged in and consumed.
func is_black_hole() -> bool:
	return _is_black_hole


func die() -> void:
	if not alive:
		return
	alive = false
	died.emit()
	set_physics_process(false)
