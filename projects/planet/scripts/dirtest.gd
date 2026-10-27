extends Node

## Dev-only directional test: simulates pressing each direction and checks the
## resulting world-space motion against what the camera sees.
##
##   -- --dirtest
##
## Prints PASS/FAIL per direction so control mapping bugs are caught without
## a human at the keyboard.

var _planet: RigidBody3D
var _rig: Node3D
var _step := 0
var _timer := 0.0
var _start := Vector3.ZERO
var _results: Array = []
var _pending_yaw := 0.0

const STEPS := [
	{"name": "ui_up", "expect": "away from camera"},
	{"name": "ui_down", "expect": "toward camera"},
	{"name": "ui_right", "expect": "screen right"},
	{"name": "ui_left", "expect": "screen left"},
]


func _ready() -> void:
	if not OS.get_cmdline_user_args().has("--dirtest"):
		set_process(false)
		return
	# If asked, rotate the view first so we prove movement follows the camera.
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--yaw="):
			_pending_yaw = float(a.split("=", true, 1)[1])


func _process(delta: float) -> void:
	_timer += delta

	if _planet == null:
		var nodes := get_tree().get_nodes_in_group("planet")
		if nodes.is_empty():
			return
		_planet = nodes[0]
		_rig = get_parent().get_node_or_null("CameraRig")
		if _rig == null:
			print("[dirtest] no CameraRig")
			get_tree().quit()
			return
		if _pending_yaw != 0.0:
			_rig.yaw = _pending_yaw
			_rig.snap()
			print("[dirtest] yaw=%.1f" % _rig.yaw)
		return

	# Settle between steps.
	if _timer < 0.6:
		if _timer < 0.05:
			_start = _planet.global_position
			_planet.linear_velocity = Vector3.ZERO
			_planet.angular_velocity = Vector3.ZERO
		return

	if _step >= STEPS.size():
		_finish()
		return

	var step: Dictionary = STEPS[_step]
	Input.action_press(step["name"])

	if _timer >= 1.1:
		Input.action_release(step["name"])
		var moved: Vector3 = _planet.global_position - _start
		_evaluate(step, moved)
		_step += 1
		_timer = 0.0


func _evaluate(step: Dictionary, moved: Vector3) -> void:
	var flat := Vector3(moved.x, 0.0, moved.z)
	if flat.length() < 0.05:
		_results.append("%s: NO MOVEMENT" % step["name"])
		return

	flat = flat.normalized()

	# Camera-relative basis on the ground plane.
	var fwd: Vector3 = _rig.forward()
	var right: Vector3 = _rig.right()

	var dot_fwd := flat.dot(fwd)
	var dot_right := flat.dot(right)

	var ok := false
	var label := ""

	match step["name"]:
		"ui_up":
			ok = dot_fwd > 0.7
			label = "forward=%.2f right=%.2f" % [dot_fwd, dot_right]
		"ui_down":
			ok = dot_fwd < -0.7
			label = "forward=%.2f right=%.2f" % [dot_fwd, dot_right]
		"ui_right":
			ok = dot_right > 0.7
			label = "forward=%.2f right=%.2f" % [dot_fwd, dot_right]
		"ui_left":
			ok = dot_right < -0.7
			label = "forward=%.2f right=%.2f" % [dot_fwd, dot_right]

	_results.append("%s: %s  %s" % [
		step["name"], "PASS" if ok else "FAIL", label
	])


func _finish() -> void:
	var all_ok := true
	for r in _results:
		print("[dirtest] ", r)
		if "FAIL" in r:
			all_ok = false
	print("[dirtest] RESULT: %s" % ("PASS" if all_ok else "FAIL"))
	get_tree().quit()
