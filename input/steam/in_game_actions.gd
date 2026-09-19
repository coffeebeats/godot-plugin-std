##
## std/input/steam/in_game_actions.gd
##
## StdInputSteamInGameActions generates the Steam Input in-game actions (IGA) manifest.
## Every `StdInputActionSet` resource under `res://` is registered, layers told apart
## from sets by type, so a set cannot be left out. `write` writes the manifest beside
## `project.godot`; nothing else writes it, so it is generated for a build rather than
## committed. A subclass resolves display names by overriding the two `_get_*` hooks.
##
## NOTE: Discovery reads text resource headers, so it works in a project checkout and
## not in an exported game, and a subclass of `StdInputActionSet` is found only if it
## declares a `class_name`.
##

class_name StdInputSteamInGameActions
extends Resource

# -- CONFIGURATION ------------------------------------------------------------------- #

## app_id is the ID of the Steam application, which names the manifest file.
@export var app_id: int = 480

@export_group("Localization")

## locales maps Steam language names to Godot locales and is written as the manifest's
## localization sections.
@export var locales: Dictionary = {
	"english": "en",
}

# -- INITIALIZATION ------------------------------------------------------------------ #

var _contents: String = ""
var _indent: int = 0

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## find_resources returns every text resource under `root` whose script is `base` or a
## global class descending from it, sorted by path.
static func find_resources(
	base: StringName, root: String = "res://"
) -> Array[Resource]:
	var classes := _descendants(base, ProjectSettings.get_global_class_list())
	classes.append(base)

	var paths := PackedStringArray()
	_collect_resources(root, classes, paths)
	paths.sort()

	var resources: Array[Resource] = []
	for path in paths:
		var resource: Resource = ResourceLoader.load(path)
		if resource:
			resources.append(resource)

	return resources


## generate returns the manifest for the project: every action set under `res://` and
## the configured `locales`.
func generate() -> String:
	var action_sets: Array[StdInputActionSet] = []
	for resource in find_resources(&"StdInputActionSet"):
		action_sets.append(resource as StdInputActionSet)

	return render(action_sets, locales)


## get_filename returns the path of the manifest file.
func get_filename() -> String:
	return "res://game_actions_%d.vdf" % app_id


## render returns the manifest text for the provided action sets, layers included, and
## `languages`, a mapping from Steam language names to Godot locales.
func render(action_sets: Array[StdInputActionSet], languages: Dictionary) -> String:
	_contents = ""
	_indent = 0

	var sets: Array[StdInputActionSet] = []
	var layers: Array[StdInputActionSetLayer] = []
	for action_set in action_sets:
		if not action_set:
			continue

		if action_set is StdInputActionSetLayer:
			layers.append(action_set)
		else:
			sets.append(action_set)

	_write_string("In Game Actions")
	_write_open_bracket()

	_write_string("actions")
	_write_open_bracket()

	for action_set in sets:
		_write_string(action_set.name)
		_write_open_bracket()

		_write_string("title", true, false)
		_write_space()
		_write_string("#set_%s" % action_set.name, false)

		_write_string("legacy_set", true, false)
		_write_space()
		_write_string("0", false)

		_write_game_actions_in_action_set(action_set)

		_write_close_bracket()

	_write_close_bracket()

	_write_string("action_layers")
	_write_open_bracket()

	for layer in layers:
		assert(layer.parent, "invalid config; layer '%s' has no parent" % layer.name)

		_write_string(layer.name)
		_write_open_bracket()

		_write_string("title", true, false)
		_write_space()
		_write_string("#layer_%s" % layer.name, false)

		_write_string("legacy_set", true, false)
		_write_space()
		_write_string("0", false)

		_write_string("set_layer", true, false)
		_write_space()
		_write_string("1", false)

		_write_string("parent_set_name", true, false)
		_write_space()
		_write_string(layer.parent.name, false)

		_write_game_actions_in_action_set(layer)

		_write_close_bracket()

	_write_close_bracket()

	_write_string("localization")
	_write_open_bracket()

	for language in languages:
		var locale: String = languages[language]

		_write_string(language)
		_write_open_bracket()

		for action_set in sets:
			_write_locale_actions_in_action_set(action_set, locale)

		for layer in layers:
			_write_locale_actions_in_action_set(layer, locale)

		_write_close_bracket()

	_write_close_bracket()

	_write_close_bracket()

	assert(_indent == 0, "missing bracket!")

	return _contents


## write writes `generate` to `get_filename`.
func write() -> Error:
	var contents := generate()

	var file := FileAccess.open(get_filename(), FileAccess.ModeFlags.WRITE)
	if not file:
		return FileAccess.get_open_error()

	file.store_string(contents)
	file.close()

	return OK


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_action_set_display_name(
	action_set_name: StringName,
	_locale: StringName = &"",
) -> String:
	return action_set_name


func _get_action_display_name(
	_action_set_name: StringName,
	action_name: StringName,
	_locale: StringName = &"",
) -> String:
	return action_name


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _collect_resources appends to `paths` every `.tres` under `dir` whose header names a
## script class in `classes`, skipping dot-directories.
static func _collect_resources(
	dir: String, classes: PackedStringArray, paths: PackedStringArray
) -> void:
	var access := DirAccess.open(dir)
	if not access:
		return

	access.list_dir_begin()

	var name := access.get_next()
	while name != "":
		var path := dir.path_join(name)

		if access.current_is_dir():
			if not name.begins_with("."):
				_collect_resources(path, classes, paths)
		elif name.ends_with(".tres"):
			var file := FileAccess.open(path, FileAccess.ModeFlags.READ)
			if file and _parse_script_class(file.get_line()) in classes:
				paths.append(path)

		name = access.get_next()

	access.list_dir_end()


## _descendants returns the names of every global class in `classes`, as reported by
## `ProjectSettings.get_global_class_list`, that descends from `base`.
static func _descendants(
	base: StringName, classes: Array[Dictionary]
) -> PackedStringArray:
	var found := PackedStringArray([base])

	var grew := true
	while grew:
		grew = false

		for info in classes:
			if info["class"] in found:
				continue

			if info["base"] in found:
				found.append(info["class"])
				grew = true

	found.remove_at(0)

	return found


## _parse_script_class returns the `script_class` a text resource header declares, or an
## empty name when it declares none.
static func _parse_script_class(header: String) -> StringName:
	var start := header.find('script_class="')
	if start == -1:
		return &""

	start += len('script_class="')

	var end := header.find('"', start)
	if end == -1:
		return &""

	return StringName(header.substr(start, end - start))


func _write_close_bracket(newline: bool = true) -> void:
	_indent -= 1
	assert(_indent >= 0, "invalid indent; outdented too far")

	_write_indent()

	_contents += "}"

	if newline:
		_write_newline()


func _write_game_actions_in_action_set(action_set: StdInputActionSet) -> void:
	for section in ["StickPadGyro", "AnalogTrigger", "Button"]:
		match section:
			"StickPadGyro":
				if not (
					action_set.actions_analog_2d or action_set.action_absolute_mouse
				):
					continue

				_write_string(section)
				_write_open_bracket()

				for action in action_set.actions_analog_2d:
					assert(
						action.ends_with("_x") or action.ends_with("_y"),
						"invalid action; 2D analog action must specify axis"
					)

					_write_string(action)
					_write_open_bracket()

					_write_string("title", true, false)
					_write_space()
					_write_string("#action_%s" % action, false, true)

					_write_string("input_mode", true, false)
					_write_space()
					_write_string("joystick_move", false)

					_write_close_bracket()

				if action_set.action_absolute_mouse:
					assert(
						not (
							action_set.action_absolute_mouse
							in action_set.actions_analog_2d
						),
						"invalid action; conflicting definition"
					)

					_write_string(action_set.action_absolute_mouse)
					_write_open_bracket()

					_write_string("title", true, false)
					_write_space()
					_write_string(
						"#action_%s" % action_set.action_absolute_mouse, false, true
					)

					_write_string("input_mode", true, false)
					_write_space()
					_write_string("absolute_mouse", false)

					_write_close_bracket()

				_write_close_bracket()

			"AnalogTrigger":
				if not action_set.actions_analog_1d:
					continue

				_write_string(section)
				_write_open_bracket()

				for action in action_set.actions_analog_1d:
					_write_string(action, true, false)
					_write_space()
					_write_string("#action_%s" % action, false)

				_write_close_bracket()
			"Button":
				if not action_set.actions_digital:
					continue

				_write_string(section)
				_write_open_bracket()

				for action in action_set.actions_digital:
					_write_string(action, true, false)
					_write_space()
					_write_string("#action_%s" % action, false)

				_write_close_bracket()


func _write_indent() -> void:
	for _i in range(_indent):
		_contents += "\t"


func _write_locale_actions_in_action_set(
	action_set: StdInputActionSet,
	locale: StringName,
) -> void:
	var prefix := "layer_" if action_set is StdInputActionSetLayer else "set_"
	_write_string(prefix + action_set.name, true, false)
	_write_space()

	var action_set_display_name := _get_action_set_display_name(action_set.name, locale)
	_write_string(action_set_display_name, false)

	for action in (
		action_set.actions_analog_1d
		+ action_set.actions_analog_2d
		+ action_set.actions_digital
		+ (
			[action_set.action_absolute_mouse]
			if action_set.action_absolute_mouse
			else []
		)
	):
		_write_string("action_" + action, true, false)
		_write_space()

		var action_display_name := _get_action_display_name(
			action_set.name,
			action,
			locale,
		)
		_write_string(action_display_name, false)


func _write_newline() -> void:
	_contents += "\n"


func _write_open_bracket(newline: bool = true) -> void:
	_write_indent()

	_contents += "{"

	if newline:
		_write_newline()
		_indent += 1


func _write_space() -> void:
	for _i in range(8 - _indent):
		_contents += "\t"


func _write_string(value: String, indent: bool = true, newline: bool = true) -> void:
	if indent:
		_write_indent()

	_contents += '"%s"' % value
	if newline:
		_write_newline()
