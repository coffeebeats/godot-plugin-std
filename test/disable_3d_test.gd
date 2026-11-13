##
## test/disable_3d_test.gd
##
## Tests that no script std ships names a 3D class, since an engine built with
## `disable_3d` registers none and fails to parse a script naming one, along with every
## script depending on it.
##

extends GutTest

# -- DEFINITIONS --------------------------------------------------------------------- #

## _ALLOWED_3D are the classes named with `3D` that an engine built with `disable_3d`
## still registers as of 4.7.2-stable, in the core, the `noise` and `visual_shader`
## modules, or outside the `_3D_DISABLED` blocks of `scene/register_scene_types.cpp`.
const _ALLOWED_3D: Array[StringName] = [
	&"AStar3D",
	&"CompressedTexture3D",
	&"Geometry3D",
	&"ImageTexture3D",
	&"NoiseTexture3D",
	&"PlaceholderTexture3D",
	&"Texture3D",
	&"Texture3DRD",
	&"VisualShaderNodeSample3D",
	&"VisualShaderNodeTexture3D",
	&"VisualShaderNodeTexture3DParameter",
]

## _PREFIXES_3D begin the names of classes whose modules `disable_3d` leaves out; `gltf`
## and `fbx` build only without it, and XR, `openxr` included, goes with the
## `disable_xr` it implies (see the engine's `SConstruct` and `modules/*/config.py`).
const _PREFIXES_3D: Array[String] = ["FBX", "GLTF", "OpenXR", "XR"]

## _ROOTS_3D are the classes `disable_3d` leaves out, each along with every class
## inheriting from it, whose families the name match misses in part; see the 4.7.2
## `_3D_DISABLED` blocks of the engine's `scene/register_scene_types.cpp`.
const _ROOTS_3D: Array[StringName] = [
	&"FogMaterial",
	&"ImporterMesh",
	&"LightmapGIData",
	&"Lightmapper",
	&"MeshLibrary",
	&"Node3D",
	&"PanoramaSkyMaterial",
	&"PhysicalSkyMaterial",
	&"PrimitiveMesh",
	&"ProceduralSkyMaterial",
	&"Skin",
	&"SkinReference",
	&"VoxelGIData",
	&"WorldEnvironment",
]

## _SKIPPED_DIRS are the directories holding no script std ships; `dist` leaves out
## `example` and `examples` (see `.github/workflows/release-please.yml`), and `addons`
## holds vendored plugins.
const _SKIPPED_DIRS: Array[String] = ["addons", "example", "examples"]

# -- INITIALIZATION ------------------------------------------------------------------ #

var _classes_3d := {}

# NOTE: A name right after `$`, `%` or `/` names a node in a node path, not a class, so
# it is skipped; gdformat spaces the `%` and `/` operators, so no class name sits there.
# A path spaced as `$ Name` or `$A / Name` is left out, since gdformat never writes it.
var _identifier := RegEx.create_from_string("(?<![$%/\\w])[A-Za-z_][A-Za-z0-9_]*")

# NOTE: Each alternative starts where its literal or comment starts, so the leftmost
# match is always the outermost one, and a `#` inside a string is never a comment.
var _literal_or_comment := RegEx.create_from_string(
	(
		'"""[\\s\\S]*?"""|\'\'\'[\\s\\S]*?\'\'\'|"(?:\\\\.|[^"\\\\\\n])*"'
		+ "|'(?:\\\\.|[^'\\\\\\n])*'|#[^\\n]*"
	)
)

# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_all() -> void:
	for candidate in ClassDB.get_class_list():
		if _is_3d_class(candidate):
			_classes_3d[StringName(candidate)] = true


# -- TEST METHODS -------------------------------------------------------------------- #


func test_class_lists_on_full_build_name_existing_classes() -> void:
	# Given: The classes the lists above name.
	var named: Array[StringName] = []
	named.append_array(_ALLOWED_3D)
	named.append_array(_ROOTS_3D)

	# Then: Each exists in the running engine, so a misspelled entry can't match nothing.
	for entry in named:
		assert_true(ClassDB.class_exists(entry), "missing class: %s" % entry)


func test_classes_3d_on_full_build_cover_3d_classes_and_spare_kept_ones() -> void:
	# Given: The 3D classes `before_all` found in the running engine's class list.

	# Then: Each kind of 3D class is present, and classes 2D builds keep are absent.
	assert_has(_classes_3d, &"Node3D")
	assert_has(_classes_3d, &"Camera3D")
	assert_has(_classes_3d, &"BoxShape3D")
	assert_has(_classes_3d, &"NavigationAgent3D")
	assert_has(_classes_3d, &"PhysicsServer3D")
	assert_has(_classes_3d, &"WorldEnvironment")
	assert_has(_classes_3d, &"GridMap")
	assert_has(_classes_3d, &"XRServer")
	assert_has(_classes_3d, &"GLTFDocument")
	assert_does_not_have(_classes_3d, &"Node2D")
	assert_does_not_have(_classes_3d, &"Texture3D")
	assert_does_not_have(_classes_3d, &"AStar3D")


func test_find_3d_names_in_source_ignores_comments_and_strings() -> void:
	# Given: A source naming 3D classes only in comments, strings and node paths.
	var lines := [
		"## Node3D in a doc comment.",
		'var a := node.is_class(&"Node3D")  # Node3D in a comment',
		'var b := \'Camera3D\' + "# not a comment" + """',
		"Node3D in a multiline string",
		'"""',
		"var c := $Camera3D",
		"var d := %Camera3D",
		"var e := $A/Camera3D",
		"var f := $/root/Camera3D",
		'var g := $"A"/Camera3D',
		"var h := $A/%Camera3D",
	]
	var source := "\n".join(lines)

	# When: The source is searched for 3D class names.
	var found := _find_3d_names(source)

	# Then: Nothing is found.
	assert_eq(found, PackedStringArray())


func test_find_3d_names_in_source_finds_type_uses() -> void:
	# Given: A source naming 3D classes as types, past a string holding a `#`.
	var lines := ['var s := "#"', "if child is Node3D:", "var camera: Camera3D = null"]
	var source := "\n".join(lines)

	# When: The source is searched for 3D class names.
	var found := _find_3d_names(source)

	# Then: Both names are found.
	assert_eq(found, PackedStringArray(["Node3D", "Camera3D"]))


func test_shipped_scripts_on_3d_disabled_build_name_no_3d_class() -> void:
	# Given: Every script std ships.
	var paths := _list_shipped_scripts("res://")
	assert_gt(paths.size(), 0)

	# When: Each is searched for 3D class names outside comments and strings.
	var offenders := PackedStringArray()
	for path in paths:
		for found in _find_3d_names(FileAccess.get_file_as_string(path)):
			offenders.append("%s: %s" % [path, found])

	# Then: None names one.
	assert_eq(offenders, PackedStringArray(), "\n".join(offenders))


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _find_3d_names(source: String) -> PackedStringArray:
	var found := PackedStringArray()

	var code := _literal_or_comment.sub(source, " ", true)
	for result in _identifier.search_all(code):
		var identifier := result.get_string()
		if _classes_3d.has(StringName(identifier)):
			found.append(identifier)

	return found


# NOTE: The match errs broad, since a kept class it matches fails the sweep at once and
# goes in `_ALLOWED_3D`, while a dropped class it misses passes until an export breaks.
func _is_3d_class(candidate: String) -> bool:
	if StringName(candidate) in _ALLOWED_3D:
		return false

	if candidate.contains("3D"):
		return true

	for prefix in _PREFIXES_3D:
		if candidate.begins_with(prefix):
			return true

	for root in _ROOTS_3D:
		if ClassDB.is_parent_class(candidate, root):
			return true

	return false


func _list_shipped_scripts(path_dir: String) -> PackedStringArray:
	var paths := PackedStringArray()

	var dir := DirAccess.open(path_dir)
	assert_not_null(dir)

	for file in dir.get_files():
		if file.ends_with(".gd") and not file.ends_with("_test.gd"):
			paths.append(path_dir.path_join(file))

	for child in dir.get_directories():
		if child.begins_with(".") or child in _SKIPPED_DIRS:
			continue

		paths.append_array(_list_shipped_scripts(path_dir.path_join(child)))

	return paths
