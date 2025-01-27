##
## std/input/steam/in_game_actions.gd
##
## StdInputSteamInGameActions is a resource which defines a Steam in-game actions (IGA)
## file. Changes to this resource will automatically write a new manifest file to the
## project's root directory.
##

@tool
class_name StdInputSteamInGameActions
extends Resource

# -- CONFIGURATION ------------------------------------------------------------------- #

## app_id is the ID of the Steam application. This is used to determine the manifest
## file's name.
@export var app_id: int = 480:
	set(value):
		app_id = value
		_write_file()

@export_group("Actions")

## action_sets is the complete set of available `StdInputActionSet`s within the game.
## This must not include `StdInputActionSetLayer` types.
@export var action_sets: Array[StdInputActionSet] = []:
	set(value):
		action_sets = value
		_write_file()

## action_set_layers is the complete set of available `StdInputActionSetLayers`s within the
## game. This must not include base `StdInputActionSet` types.
@export var action_set_layers: Array[StdInputActionSetLayer] = []:
	set(value):
		action_set_layers = value
		_write_file()

@export_group("Localization")

## locales is a mapping from Steam locale codes to Godot locale codes.
@export var locales: Dictionary = {
	"english": "en",
}:
	set(value):
		locales = value
		_write_file()

# -- INITIALIZATION ------------------------------------------------------------------ #

var _contents: String = ""
var _indent: int = 0

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## get_filename returns the basename of the actions manifest file.
func get_filename() -> String:
	return "res://game_actions_%d.vdf" % app_id


## get_in_game_actions_file_contents returns the contents of the Steam Input in-game
## actions file based on the configured settings.
func get_in_game_actions_file_contents() -> String:
	# Reset state before starting.
	_contents = ""
	_indent = 0

	_write_string("In Game Actions")

	write_open_bracket()

	# action

	_write_string("actions")
	write_open_bracket()

	for action_set in action_sets:
		if not action_set:
			continue

		_write_string(action_set.name)
		write_open_bracket()

		_write_string("title", true, false)
		write_space()
		_write_string("#set_%s" % action_set.name, false)

		_write_string("legacy_set", true, false)
		write_space()
		_write_string("0", false)

		_write_game_actions_in_action_set(action_set)

		_write_close_bracket()

	_write_close_bracket()

	_write_string("action_layers")
	write_open_bracket()

	for action_set_layer in action_set_layers:
		if not action_set_layer:
			continue

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

		_write_game_actions_in_action_set(action_set_layer)

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
			if not action_set:
				continue

			_write_locale_actions_in_action_set(action_set, locale_godot)

		for action_set_layer in action_set_layers:
			if not action_set_layer:
				continue

			_write_locale_actions_in_action_set(action_set_layer, locale_godot)

		_write_close_bracket()

	_write_close_bracket()

	_write_close_bracket()

	assert(_indent == 0, "missing bracket!")

	return _contents


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


func _write_indent() -> void:
	for _i in range(_indent):
		_contents += "\t"


func _write_file() -> void:
	if not Engine.is_editor_hint():
		return

	var contents := get_in_game_actions_file_contents()

	var file := FileAccess.open(get_filename(), FileAccess.ModeFlags.WRITE)
	if not file:
		push_error(
			"failed to write Steam Input IGA file: %d" % FileAccess.get_open_error()
		)
		return

	file.store_string(contents)
	file.flush()
	file.close()


func _write_newline() -> void:
	_contents += "\n"


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


func write_space() -> void:
	for _i in range(8 - _indent):
		_contents += "\t"


func _write_string(value: String, indent: bool = true, newline: bool = true) -> void:
	if indent:
		_write_indent()

	_contents += '"%s"' % value
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
				write_open_bracket()

				for action in action_set.actions_analog_2d:
					assert(
						action.ends_with("_x") or action.ends_with("_y"),
						"invalid action; 2D analog action must specify axis"
					)

					_write_string(action)
					write_open_bracket()

					_write_string("title", true, false)
					write_space()
					_write_string("#action_%s" % action, false, true)

					_write_string("input_mode", true, false)
					write_space()
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
					write_open_bracket()

					_write_string("title", true, false)
					write_space()
					_write_string(
						"#action_%s" % action_set.action_absolute_mouse, false, true
					)

					_write_string("input_mode", true, false)
					write_space()
					_write_string("absolute_mouse", false)

					_write_close_bracket()

				_write_close_bracket()

			"AnalogTrigger":
				if not action_set.actions_analog_1d:
					continue

				_write_string(section)
				write_open_bracket()

				for action in action_set.actions_analog_1d:
					_write_string(action, true, false)
					write_space()
					_write_string("#action_%s" % action, false)

				_write_close_bracket()
			"Button":
				if not action_set.actions_digital:
					continue

				_write_string(section)
				write_open_bracket()

				for action in action_set.actions_digital:
					_write_string(action, true, false)
					write_space()
					_write_string("#action_%s" % action, false)

				_write_close_bracket()


func _write_locale_actions_in_action_set(
	action_set: StdInputActionSet,
	locale: StringName,
) -> void:
	var prefix := "layer_" if action_set is StdInputActionSetLayer else "set_"
	_write_string(prefix + action_set.name, true, false)
	write_space()

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
		write_space()

		var action_display_name := _get_action_display_name(
			action_set.name,
			action,
			locale,
		)
		_write_string(action_display_name, false)
