##
## run.gd
##
## Launches `harness.gd` beside this script as the scene tree's only node, so the harness
## runs from any directory with `godot --path . -s <path to this file> [-- --appid=N]`
## and no scene file needs a path baked in.
##

extends SceneTree


func _initialize() -> void:
	var harness: Script = load(
		get_script().resource_path.get_base_dir().path_join("harness.gd")
	)
	root.add_child(harness.new())
