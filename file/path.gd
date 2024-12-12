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
	if (
		path.begins_with("user://")
		or (path.begins_with("res://") and OS.has_feature("editor"))
	):
		return ProjectSettings.globalize_path(path)

	path = path.trim_prefix("res://")

	if path.is_absolute_path():
		return path

	return OS.get_executable_path().get_base_dir().path_join(path)


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _init() -> void:
	assert(
		not OS.is_debug_build(),
		"Invalid config; this 'Object' should not be instantiated!"
	)
