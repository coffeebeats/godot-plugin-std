##
## std/input/steam/actions_manifest_writer.gd
##
## `InputSteamActionsManifestWriter` is a class which, given a list of available
## `StdInputActionSet`s and `StdInputActionSetLayer`s, can output a Steam Input actions
## manifest file.
##

extends RefCounted

# -- DEPENDENCIES -------------------------------------------------------------------- #

const FilePath := preload("../../file/path.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

## dir is a directory in which the actions manifest will be written.
@export_dir var dir: String

## app_id is the ID of the Steam application. This is used to determine the manifest
## file's name.
@export var app_id: int = 480

@export_group("Actions")

## action_sets is the complete set of available `StdInputActionSet`s within the game.
## This must not include `StdInputActionSetLayer` types.
@export var action_sets: Array[StdInputActionSet] = []

## action_set_layers is the complete set of available `StdInputActionSetLayers`s within the
## game. This must not include base `StdInputActionSet` types.
@export var action_set_layers: Array[StdInputActionSetLayer] = []

@export_group("Localization")

## locales is a mapping from Steam locale codes to Godot locale codes.
@export var locales: Dictionary = {
	"english": "en",
}

# -- INITIALIZATION ------------------------------------------------------------------ #

var _contents: String = ""
var _indent: int = 0

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## get_filename returns the basename of the actions manifest file.
func get_filename() -> String:
	return "res://game_actions_%d.vdf" % app_id


## get_filepath returns the absolute filepath to the directory in which the actions
## manifest will be written.
func get_filepath() -> String:
	return dir.path_join(get_filename())


## write_actions_manifest outputs a Steam actions manifest to the configured filepath
## using the configured action sets and action set layers.
func write_actions_manifest() -> Error:
	_write_string("In Game Actions")

	write_open_bracket()

	# action

	_write_string("actions")
	write_open_bracket()

	for action_set in action_sets:
		_write_string(action_set.name)
		write_open_bracket()

		_write_string("title", true, false)
		write_space()
		_write_string("#set_%s" % action_set.name, false)

		_write_actions_in_action_set(action_set)

		_write_close_bracket()

	_write_close_bracket()

	_write_string("action_layers")
	write_open_bracket()

	for action_set_layer in action_set_layers:
		_write_string(action_set_layer.name)
		write_open_bracket()

		_write_string("title", true, false)
		write_space()
		_write_string("#layer_%s" % action_set_layer.name, false)

		_write_string("legacy_set", true, false)
		write_space()
		_write_string("0", false)

		_write_string("set_layer", true, false)
		write_space()
		_write_string("1", false)

		_write_string("parent_set_name", true, false)
		write_space()
		_write_string(action_set_layer.parent.name, false)

		_write_actions_in_action_set(action_set_layer)

		_write_close_bracket()

	_write_close_bracket()

	_write_string("localization")
	write_open_bracket()

	for locale_steam in locales:
		# TODO: Map entity names to correct locale.
		@warning_ignore("UNUSED_VARIABLE")
		var locale_godot: String = locales[locale_steam]

		_write_string(locale_steam)
		write_open_bracket()

		for action_set in action_sets:
			_write_string("set_" + action_set.name, true, false)
			write_space()
			_write_string(action_set.name, false)

			for action in action_set.actions:
				_write_string("action_" + action.name, true, false)
				write_space()
				_write_string(action.name, false)

		for action_set_layer in action_set_layers:
			_write_string("layer_" + action_set_layer.name, true, false)
			write_space()
			_write_string(action_set_layer.name, false)

			for action in action_set_layer.actions:
				_write_string("action_" + action.name, true, false)
				write_space()
				_write_string(action.name, false)

		_write_close_bracket()

	_write_close_bracket()

	_write_close_bracket()

	assert(_indent == 0, "missing bracket!")

	var path := FilePath.make_project_path_absolute(get_filepath())

	if not DirAccess.dir_exists_absolute(path.get_base_dir()):
		var err := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		if err != OK:
			return err

	var file := FileAccess.open(path, FileAccess.ModeFlags.WRITE)
	if not file:
		return FileAccess.get_open_error()

	file.store_string(_contents)
	file.flush()
	file.close()

	return OK


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _write_indent() -> void:
	for _i in range(_indent):
		_contents += "\t"


func _write_string(value: String, indent: bool = true, newline: bool = true) -> void:
	if indent:
		_write_indent()

	_contents += '"%s"' % value
	if newline:
		_write_newline()


func _write_newline() -> void:
	_contents += "\n"


func write_space() -> void:
	for _i in range(8 - _indent):
		_contents += "\t"


func write_open_bracket(newline: bool = true) -> void:
	_write_indent()

	_contents += "{"

	if newline:
		_write_newline()
		_indent += 1


func _write_close_bracket(newline: bool = true) -> void:
	_indent -= 1
	assert(_indent >= 0, "invalid indent; outdented too far")

	_write_indent()

	_contents += "}"

	if newline:
		_write_newline()


func _write_actions_in_action_set(action_set: StdInputActionSet) -> void:
	for section in ["StickPadGyro", "AnalogTrigger", "Button"]:
		_write_string(section)
		write_open_bracket()

		match section:
			"StickPadGyro":
				for action in action_set.actions_analog_2d:
					_write_string(action)
					write_open_bracket()

					_write_string("title", true, false)
					write_space()
					_write_string("#Action_%s" % action, false, true)

					_write_string("input_mode", true, false)
					write_space()
					_write_string("joystick_move", false)

					_write_close_bracket()

				if action_set.action_absolute_mouse:
					_write_string(action_set.action_absolute_mouse)
					write_open_bracket()

					_write_string("title", true, false)
					write_space()
					_write_string(
						"#Action_%s" % action_set.action_absolute_mouse, false, true
					)

					_write_string("input_mode", true, false)
					write_space()
					_write_string("absolute_mouse", false)

					_write_close_bracket()

			"AnalogTrigger":
				for action in action_set.actions_analog_1d:
					_write_string(action, true, false)
					write_space()
					_write_string("#Action_%s" % action, false)
			"Button":
				for action in action_set.actions_digital:
					_write_string(action, true, false)
					write_space()
					_write_string("#Action_%s" % action, false)

		_write_close_bracket()
