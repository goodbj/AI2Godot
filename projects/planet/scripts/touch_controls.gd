extends CanvasLayer

## On-screen touch controls: a virtual joystick on the left, plus a pause button.
## Mouse input also drives the joystick so it is testable on desktop.

signal pause_pressed

const KNOB_RADIUS := 46.0
const BASE_RADIUS := 110.0

var _active := false
var _touch_index := -1
var _origin := Vector2.ZERO
var _vector := Vector2.ZERO

var _base: Control
var _knob: Control
var _pause_btn: Button
var _canvas: Control


func _ready() -> void:
	layer = 5
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)

	_base = _make_ring(Vector2(BASE_RADIUS, BASE_RADIUS) * 2.0, Color(0.75, 0.85, 1.0, 0.16))
	_knob = _make_ring(Vector2(KNOB_RADIUS, KNOB_RADIUS) * 2.0, Color(0.80, 0.90, 1.0, 0.42))
	_base.visible = false
	_knob.visible = false

	_pause_btn = Button.new()
	_pause_btn.text = "II"
	_pause_btn.add_theme_font_size_override("font_size", 22)
	_pause_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_pause_btn.offset_left = -76
	_pause_btn.offset_top = 18
	_pause_btn.offset_right = -20
	_pause_btn.offset_bottom = 74
	_pause_btn.modulate = Color(1, 1, 1, 0.55)
	_pause_btn.pressed.connect(func(): pause_pressed.emit())
	_canvas.add_child(_pause_btn)

	# Only show the joystick on touch devices.
	if not _is_touch_device():
		_pause_btn.visible = false


func _make_ring(size: Vector2, color: Color) -> Control:
	var c := Control.new()
	c.size = size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := Panel.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(int(minf(size.x, size.y) * 0.5))
	sb.anti_aliasing = true
	bg.add_theme_stylebox_override("panel", sb)
	c.add_child(bg)
	_canvas.add_child(c)
	return c


func _is_touch_device() -> bool:
	return DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")


## Current movement vector, -1..1 on each axis.
func get_move_vector() -> Vector2:
	return _vector


func _input(event: InputEvent) -> void:
	if not _is_touch_device():
		return

	if event is InputEventScreenTouch:
		if event.pressed and not _active and event.position.x < get_viewport().get_visible_rect().size.x * 0.5:
			_active = true
			_touch_index = event.index
			_origin = event.position
			_show_joystick(true)
			_update_knob(Vector2.ZERO)
		elif not event.pressed and event.index == _touch_index:
			_release()

	elif event is InputEventScreenDrag and _active and event.index == _touch_index:
		var delta: Vector2 = event.position - _origin
		if delta.length() > BASE_RADIUS:
			delta = delta.normalized() * BASE_RADIUS
		_vector = delta / BASE_RADIUS
		_update_knob(delta)


func _show_joystick(on: bool) -> void:
	_base.visible = on
	_knob.visible = on
	if on:
		_base.position = _origin - _base.size * 0.5


func _update_knob(delta: Vector2) -> void:
	_knob.position = _origin - _knob.size * 0.5 + delta


func _release() -> void:
	_active = false
	_touch_index = -1
	_vector = Vector2.ZERO
	_show_joystick(false)
