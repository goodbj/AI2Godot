extends Node3D

## Game root: builds the world, wires the HUD, handles restart.

const PlanetScene := preload("res://scenes/planet.tscn")
const WorldScript := preload("res://scripts/world.gd")
const HUDScript := preload("res://scripts/hud.gd")

var world: Node3D
var planet: RigidBody3D
var hud: CanvasLayer


func _ready() -> void:
	_setup_environment()
	_spawn_world()
	_apply_dev_args()


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

	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.6
	sun.light_color = Color(1.0, 0.95, 0.88)
	sun.rotation_degrees = Vector3(-42, -55, 0)
	sun.shadow_enabled = true
	add_child(sun)


func _spawn_world() -> void:
	if world:
		world.queue_free()
	if planet:
		planet.queue_free()

	world = WorldScript.new()
	world.name = "World"
	add_child(world)

	planet = PlanetScene.instantiate()
	add_child(planet)

	world.register_planet(planet)

	hud = HUDScript.new()
	add_child(hud)
	hud.bind(planet)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
	if planet and not planet.alive and event is InputEventKey and event.pressed and event.keycode == KEY_R:
		_spawn_world()
