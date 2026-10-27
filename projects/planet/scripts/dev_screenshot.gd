extends Node

## Dev-only screenshot helper: captures the viewport a few seconds in and saves
## it to disk so the AI can inspect what the game actually looks like.
## Disabled unless the "screenshot" feature is requested on the command line.
##
##   -- --shot --shot-path=E:/out.png
##   -- --shot --stage=3 --yaw=135 --pitch=55 --capture-at=4
##
## `--yaw` / `--pitch` aim the orbit camera before the shot, so the new camera
## frame can be checked visually without a human dragging the mouse.

@export var capture_at := 3.0
@export var path := "user://shot.png"

var _t := 0.0
var _done := false
var _aim := false
var _yaw := 0.0
var _pitch := 0.0


func _ready() -> void:
	if not OS.get_cmdline_user_args().has("--shot"):
		set_process(false)
		return
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-path="):
			path = a.split("=", true, 1)[1]
		elif a.begins_with("--yaw="):
			_yaw = float(a.split("=", true, 1)[1])
			_aim = true
		elif a.begins_with("--pitch="):
			_pitch = float(a.split("=", true, 1)[1])
			_aim = true
		elif a.begins_with("--capture-at="):
			capture_at = float(a.split("=", true, 1)[1])


func _process(delta: float) -> void:
	_t += delta
	if _done or _t < capture_at:
		return
	_done = true

	_aim_camera()

	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var target := _resolve_path(path)
	var err := img.save_png(target)
	print("[shot] saved to ", target, " err=", err)
	get_tree().quit()


## `--shot-path` may be a res:// or user:// path, or a plain filesystem path
## (absolute, or relative to the project folder). Plain paths get their folders
## created, otherwise save_png silently fails with err=7.
func _resolve_path(p: String) -> String:
	if p.begins_with("res://") or p.begins_with("user://"):
		return ProjectSettings.globalize_path(p)
	var abs := p
	if not p.substr(1, 1) == ":" and not p.begins_with("/"):
		# Not a Windows drive path and not a POSIX absolute path: treat it as
		# relative to the project folder so `build/shots/x.png` is predictable.
		abs = ProjectSettings.globalize_path("res://").path_join(p)
	var dir := abs.get_base_dir()
	if dir != "" and not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	return abs


## Applies the requested orbit angles to the camera rig and snaps the camera to
## its ideal pose, so the frame is deterministic instead of mid-lerp.
func _aim_camera() -> void:
	if not _aim:
		return
	var rig: Node3D = get_parent().get_node_or_null("CameraRig") as Node3D
	if rig == null:
		print("[shot] no CameraRig; ignoring --yaw/--pitch")
		return
	rig.pitch = clampf(_pitch, rig.min_pitch, rig.max_pitch)
	rig.yaw = fposmod(_yaw, 360.0)
	rig.snap()
	print("[shot] camera yaw=%.1f pitch=%.1f" % [rig.yaw, rig.pitch])

