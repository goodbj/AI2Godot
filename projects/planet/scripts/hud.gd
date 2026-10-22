extends CanvasLayer

var _stage_label: Label
var _mass_label: Label
var _hint_label: Label
var _flash: ColorRect
var _flash_tween: Tween

const STAGE_NAMES := [
	"Asteroid", "Meteor", "Planet", "Star", "White Dwarf", "Black Hole",
]


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_stage_label = _make_label(root, Vector2(28, 22), 34, Color(0.92, 0.96, 1.0))
	_mass_label = _make_label(root, Vector2(30, 66), 18, Color(0.65, 0.78, 0.95))
	_hint_label = _make_label(root, Vector2(30, 0), 15, Color(0.55, 0.60, 0.70))
	_hint_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_hint_label.position = Vector2(30, -46)

	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(1.0, 0.25, 0.2, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_flash)

	_hint_label.text = "WASD / Arrows to move  -  swallow what is smaller than you"


func _make_label(parent: Control, pos: Vector2, size: int, color: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
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
		3:
			_stage_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6))
		4:
			_stage_label.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
		_:
			_stage_label.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
	_flash.color = Color(0.5, 0.8, 1.0, 0.30)
	_fade_flash()


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
	_mass_label.text = "press R to restart"
