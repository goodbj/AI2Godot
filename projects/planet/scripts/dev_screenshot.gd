extends Node

## Dev-only screenshot helper: captures the viewport a few seconds in and saves
## it to disk so the AI can inspect what the game actually looks like.
## Disabled unless the "screenshot" feature is requested on the command line.

@export var capture_at := 3.0
@export var path := "user://shot.png"

var _t := 0.0
var _done := false


func _ready() -> void:
	if not OS.get_cmdline_user_args().has("--shot"):
		set_process(false)
		return
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-path="):
			path = a.split("=", true, 1)[1]


func _process(delta: float) -> void:
	_t += delta
	if _done or _t < capture_at:
		return
	_done = true

	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(path)
	print("[shot] saved to ", ProjectSettings.globalize_path(path), " err=", err)
	get_tree().quit()
