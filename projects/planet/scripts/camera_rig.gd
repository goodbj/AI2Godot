extends Node3D

## Orbits around the player and defines the movement frame.
##
## Drag with the mouse (or with a second finger on the right half of a touch
## screen) to rotate the view. The player then moves relative to the ground
## plane of whatever direction the camera is facing.

@export var distance_base := 9.0
@export var distance_per_radius := 6.5
## Stays above the play plane: going below it puts the camera under the debris
## field and lets the sky horizon cut across the arena.
@export var min_pitch := 6.0
@export var max_pitch := 78.0
@export var mouse_sensitivity := 0.28
@export var touch_sensitivity := 0.30
@export var follow_speed := 9.0

var target: Node3D = null

## Horizontal rotation around the target, in degrees.
var yaw := 0.0
## Elevation above the ground plane, in degrees.
var pitch := 26.0

var _camera: Camera3D
var _dragging_mouse := false
var _touch_orbit_index := -1


func _ready() -> void:
	_camera = get_viewport().get_camera_3d()
	if _camera:
		# Keep the horizontal field constant so a portrait phone sees as much
		# of the play field as a landscape desktop.
		_camera.keep_aspect = Camera3D.KEEP_WIDTH


## Direction the camera looks along, flattened onto the ground plane.
func forward() -> Vector3:
	var y := deg_to_rad(yaw)
	return Vector3(-sin(y), 0.0, -cos(y))


## Camera-right, flattened onto the ground plane.
func right() -> Vector3:
	var y := deg_to_rad(yaw)
	return Vector3(cos(y), 0.0, -sin(y))


## Converts a screen-space input (-1..1, y positive is down) into a world
## direction on the ground plane.
func input_to_world(input: Vector2) -> Vector3:
	return (right() * input.x + forward() * -input.y).normalized()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging_mouse = event.pressed
	elif event is InputEventMouseMotion and _dragging_mouse:
		_apply_drag(event.relative, mouse_sensitivity)
	elif event is InputEventScreenTouch:
		# Right half of the screen orbits; the left half is the joystick.
		var half := get_viewport().get_visible_rect().size.x * 0.5
		if event.pressed and event.position.x >= half and _touch_orbit_index == -1:
			_touch_orbit_index = event.index
		elif not event.pressed and event.index == _touch_orbit_index:
			_touch_orbit_index = -1
	elif event is InputEventScreenDrag and event.index == _touch_orbit_index:
		_apply_drag(event.relative, touch_sensitivity)


func _apply_drag(relative: Vector2, sensitivity: float) -> void:
	yaw -= relative.x * sensitivity
	pitch = clampf(pitch - relative.y * sensitivity, min_pitch, max_pitch)
	yaw = fposmod(yaw, 360.0)


func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target) or _camera == null:
		return

	var radius: float = 1.0
	if target.has_method("get_radius"):
		radius = target.get_radius()

	var dist: float = radius * distance_per_radius + distance_base
	var p := deg_to_rad(pitch)
	var y := deg_to_rad(yaw)

	var offset := Vector3(
		sin(y) * cos(p) * dist,
		sin(p) * dist,
		cos(y) * cos(p) * dist
	)

	var want := target.global_position + offset
	_camera.global_position = _camera.global_position.lerp(want, follow_speed * delta)
	_camera.look_at(target.global_position, Vector3.UP)


## Snaps the camera straight to its ideal pose (used on spawn).
func snap() -> void:
	if target == null or not is_instance_valid(target) or _camera == null:
		return
	var radius: float = 1.0
	if target.has_method("get_radius"):
		radius = target.get_radius()
	var dist: float = radius * distance_per_radius + distance_base
	var p := deg_to_rad(pitch)
	var y := deg_to_rad(yaw)
	_camera.global_position = target.global_position + Vector3(
		sin(y) * cos(p) * dist,
		sin(p) * dist,
		cos(y) * cos(p) * dist
	)
	_camera.look_at(target.global_position, Vector3.UP)
