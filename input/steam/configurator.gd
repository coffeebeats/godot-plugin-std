##
## std/input/steam/configurator.gd
##
## SteamConfigurator is a node which will open the Steam Configurator (i.e. bindings
## panel) whenever the configure `Button` node is pressed.
##

@tool
class_name StdInputSteamConfigurator
extends Node

# -- DEFINITIONS --------------------------------------------------------------------- #

const Signals := preload("../../event/signal.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

## button is a `Button` node which, when pressed, will trigger the Steam bindings panel
## to be shown.
@export var button: Button = null

## player_id is a player identifier which will be used to look up the action's input
## origin bindings. Specifically, this is used to find the corresponding `StdInputSlot`
## node, which must be present in the scene tree.
@export var player_id: int = 1

# -- INITIALIZATION ------------------------------------------------------------------ #

var _logger := StdLogger.create("std/input/steam/configurator")

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return

	Signals.disconnect_safe(button.pressed, _on_button_pressed)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if not button is Button:
		warnings.append("missing 'Button' node")

	return warnings


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	assert(button is Button, "invalid config; missing button node")

	Signals.connect_safe(button.pressed, _on_button_pressed)


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_button_pressed() -> void:
	var slot := StdInputSlot.for_player(player_id)
	if not slot:
		return

	var joypad := slot.get_last_active_joypad_device()
	if not joypad:
		return

	if Steam.showBindingPanel(joypad.device_id):
		(
			_logger
			. info(
				"Opened bindings panel for joypad.",
				{&"device": joypad.device_id},
			)
		)
