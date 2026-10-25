##
## std/input/steam/configurator.gd
##
## SteamConfigurator is a node which will open the Steam Configurator (i.e. bindings
## panel) whenever the configure `Button` node is pressed.
##

class_name StdInputSteamConfigurator
extends Node

# -- DEFINITIONS --------------------------------------------------------------------- #

const Signals := preload("../../event/signal.gd")
const SteamJoypadMonitor := preload("joypad_monitor.gd")

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


func _ready() -> void:
	assert(button is Button, "invalid config; missing button node")
	Signals.connect_safe(button.pressed, _on_button_pressed)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _get_controller_handle returns the Steam handle of the controller `slot` stands for:
## its last active joypad's, else its first connected joypad's, since a component swap
## clears the last active one. It's `0` while no Steam controller is connected.
static func _get_controller_handle(slot: StdInputSlot) -> int:
	var monitor := slot.joypad_monitor as SteamJoypadMonitor
	if not monitor:
		return 0

	var joypad := slot.get_last_active_joypad_device()
	if not joypad:
		var joypads := slot.get_connected_devices(false)
		if not joypads:
			return 0

		joypad = joypads[0]

	return maxi(monitor.get_device_id_for_slot(joypad.device_id), 0)


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_button_pressed() -> void:
	var slot := StdInputSlot.for_player(player_id)
	if not slot:
		return

	var handle := _get_controller_handle(slot)
	if not handle:
		_logger.warn("No Steam controller to open bindings panel for.")
		return

	if not Steam.showBindingPanel(handle):
		_logger.warn("Failed to open bindings panel for joypad.", {&"handle": handle})
		return

	_logger.info("Opened bindings panel for joypad.", {&"handle": handle})
