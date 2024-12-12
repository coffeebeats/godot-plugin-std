##
## std/file/path.gd
##
## A shared library for working with filepaths.
##
## NOTE: This 'Object' should *not* be instanced and/or added to the 'SceneTree'. It is a
## "static" library that can be imported at compile-time using 'preload'.
##

extends Object

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## make_project_path_absolute converts a project path into an absolute path, regardless
## of whether this script is running in the editor or an exported project.
static func make_project_path_absolute(path: String) -> String:
	assert(path.begins_with("res://") or path.begins_with("user://"), "invalid path")

	if OS.has_feature("editor"):
		return ProjectSettings.globalize_path(path)

	path = path.trim_prefix("res://")
	path = path.trim_prefix("user://")

	return OS.get_executable_path().get_base_dir().path_join(path)


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _init() -> void:
	assert(
		not OS.is_debug_build(),
		"Invalid config; this 'Object' should not be instantiated!"
	)
