extends CanvasLayer

var _stage_label: Label
var _mass_label: Label
var _hint_label: Label
var _threat_label: Label
var _banner: Label
var _banner_sub: Label
var _flash: ColorRect
var _flash_tween: Tween

const STAGE_NAMES := [
	"Asteroid", "Meteor", "Planet", "Star", "White Dwarf", "Black Hole",
]

## UI scale factor, derived from the shorter screen edge so the layout works
## on both a 1920x1080 desktop and a 390x844 phone.
var _ui := 1.0


func _ready() -> void:
	var vp := get_viewport().get_visible_rect().size
	_ui = clampf(minf(vp.x, vp.y) / 720.0, 0.62, 1.25)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var pad := int(28 * _ui)

	_stage_label = _make_label(root, Vector2(pad, int(22 * _ui)), int(34 * _ui), Color(0.92, 0.96, 1.0))
	_mass_label = _make_label(root, Vector2(pad + 2, int(66 * _ui)), int(18 * _ui), Color(0.65, 0.78, 0.95))
	_threat_label = _make_label(root, Vector2(pad + 2, int(94 * _ui)), int(16 * _ui), Color(0.95, 0.55, 0.45))

	_hint_label = _make_label(root, Vector2(pad, 0), int(15 * _ui), Color(0.55, 0.60, 0.70))
	_hint_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_hint_label.position = Vector2(pad, -int(46 * _ui))

	_banner = _make_label(root, Vector2(0, 0), int(56 * _ui), Color(1.0, 0.95, 0.85))
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.anchor_top = 0.32
	_banner.anchor_bottom = 0.32
	_banner.offset_left = -400
	_banner.offset_right = 400
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.visible = false

	_banner_sub = _make_label(root, Vector2(0, 0), int(20 * _ui), Color(0.8, 0.85, 0.95))
	_banner_sub.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner_sub.anchor_top = 0.32
	_banner_sub.anchor_bottom = 0.32
	_banner_sub.offset_left = -400
	_banner_sub.offset_right = 400
	_banner_sub.offset_top = int(74 * _ui)
	_banner_sub.offset_bottom = int(74 * _ui)
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_sub.visible = false

	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(1.0, 0.25, 0.2, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_flash)

	_hint_label.text = _hint_text()


func _hint_text() -> String:
	if DisplayServer.is_touchscreen_available() or OS.has_feature("mobile"):
		return "drag the left side to move  -  swallow what is smaller than you"
	return "WASD / Arrows to move  -  swallow what is smaller than you"


func _make_label(parent: Control, pos: Vector2, size: int, color: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func bind(planet) -> void:
	planet.mass_changed.connect(_on_mass_changed)
	planet.stage_changed.connect(_on_stage_changed)
	planet.died.connect(_on_died)
	_on_mass_changed(planet.mass_value, planet.stage)
	_on_stage_changed(planet.stage)


func _on_mass_changed(value: float, stage: int) -> void:
	_mass_label.text = "mass  %0.1f" % value


func _on_stage_changed(stage: int) -> void:
	_stage_label.text = STAGE_NAMES[stage].to_upper()
	match stage:
		5:
			_stage_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.2))
			show_banner("BLACK HOLE", "nothing escapes")
		3:
			_stage_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6))
			show_banner("STAR", "you are burning")
		4:
			_stage_label.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
			show_banner("WHITE DWARF", "the end is near")
		_:
			_stage_label.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
	_flash.color = Color(0.5, 0.8, 1.0, 0.30)
	_fade_flash()


## Rival proximity readout: how many things out there can eat you.
func update_threats(rivals: Array, player_mass: float) -> void:
	var threats := 0
	for r in rivals:
		if r == null or not is_instance_valid(r) or r.consumed:
			continue
		if r.mass_value >= player_mass * 1.12:
			threats += 1

	if threats > 0:
		_threat_label.text = "⚠  %d rival%s can devour you" % [threats, "" if threats == 1 else "s"]
	else:
		_threat_label.text = ""


func show_banner(title: String, sub: String) -> void:
	_banner.text = title
	_banner_sub.text = sub
	_banner.visible = true
	_banner_sub.visible = true
	_banner.modulate.a = 1.0
	_banner_sub.modulate.a = 1.0
	var t := create_tween()
	t.tween_interval(1.1)
	t.tween_property(_banner, "modulate:a", 0.0, 0.9)
	t.parallel().tween_property(_banner_sub, "modulate:a", 0.0, 0.9)
	t.tween_callback(func():
		_banner.visible = false
		_banner_sub.visible = false
	)


func flash_damage() -> void:
	_flash.color = Color(1.0, 0.2, 0.15, 0.42)
	_fade_flash()


func _fade_flash() -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash, "color:a", 0.0, 0.45)


func _on_died() -> void:
	_stage_label.text = "CONSUMED"
	_stage_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.25))
	_mass_label.text = ""
	_threat_label.text = ""
	show_banner("CONSUMED", "press R to try again")
