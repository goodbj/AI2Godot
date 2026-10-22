extends Node3D

## Game root: builds the world, wires the HUD and FX, handles restart.

const PlanetScene := preload("res://scenes/planet.tscn")
const WorldScript := preload("res://scripts/world.gd")
const HUDScript := preload("res://scripts/hud.gd")
const FXScript := preload("res://scripts/fx.gd")
const TouchScript := preload("res://scripts/touch_controls.gd")

var world: Node3D
var planet: RigidBody3D
var hud: CanvasLayer
var fx: Node3D
var camera: Camera3D
var touch: CanvasLayer

var _threat_timer := 0.0
var _paused := false


func _ready() -> void:
	_setup_environment()
	_spawn_world()
	_apply_dev_args()
	_setup_touch()


func _setup_touch() -> void:
	touch = TouchScript.new()
	touch.name = "TouchControls"
	add_child(touch)
	touch.pause_pressed.connect(_toggle_pause)
	if planet:
		planet.touch_controls = touch


func _toggle_pause() -> void:
	_paused = not _paused
	get_tree().paused = _paused


## Dev-only: `-- --stage=N` jumps the player to a given evolution stage so the
## ladder can be inspected without grinding for mass.
func _apply_dev_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--stage="):
			var idx := int(a.split("=", true, 1)[1])
			var thresholds: Array = planet.STAGE_THRESHOLDS
			if idx >= 0 and idx < thresholds.size():
				var target: float = thresholds[idx] + 0.5
				planet.mass_value = target
				planet._after_mass_change()
				planet._update_size()
		elif a == "--show-rival":
			# Dev: force a rival into view for visual checks.
			world.rival_grace_mass = 0.0
			world.rival_respawn_delay = 0.01
			world._rival_timer = 999.0


func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY

	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.02, 0.03, 0.08)
	sky_mat.sky_horizon_color = Color(0.06, 0.08, 0.16)
	sky_mat.ground_bottom_color = Color(0.01, 0.01, 0.03)
	sky_mat.ground_horizon_color = Color(0.04, 0.05, 0.10)
	sky.sky_material = sky_mat
	env.sky = sky

	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.20, 0.26, 0.40)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_bloom = 0.15
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE

	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.6
	sun.light_color = Color(1.0, 0.95, 0.88)
	sun.rotation_degrees = Vector3(-42, -55, 0)
	sun.shadow_enabled = true
	add_child(sun)

	camera = get_node_or_null("Camera3D") as Camera3D
	if camera:
		# Keep the horizontal field constant so a portrait phone sees as much
		# of the play field as a landscape desktop.
		camera.keep_aspect = Camera3D.KEEP_WIDTH


func _spawn_world() -> void:
	if world:
		world.queue_free()
	if planet:
		planet.queue_free()
	if hud:
		hud.queue_free()

	world = WorldScript.new()
	world.name = "World"
	add_child(world)

	planet = PlanetScene.instantiate()
	add_child(planet)

	world.register_planet(planet)

	fx = FXScript.new()
	fx.name = "FX"
	add_child(fx)
	if camera:
		fx.bind_camera(camera)
	world.register_fx(fx)

	hud = HUDScript.new()
	add_child(hud)
	hud.bind(planet)

	_threat_timer = 0.0


func _process(delta: float) -> void:
	if world == null or planet == null or hud == null:
		return
	if not planet.alive:
		return

	_threat_timer += delta
	if _threat_timer >= 0.25:
		_threat_timer = 0.0
		hud.update_threats(world.get("_rivals"), planet.mass_value)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
	if planet and not planet.alive and event is InputEventKey and event.pressed and event.keycode == KEY_R:
		_spawn_world()
