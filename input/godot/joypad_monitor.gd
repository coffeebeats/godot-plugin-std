##
## std/input/godot/joypad_monitor.gd
##
## An implemention of `StdInputSlot.JoypadMonitor` which uses Godot's built-in device
## input system to notify the `StdInputSlot` on joypad connection changes.
##

extends StdInputSlot.JoypadMonitor

# -- DEFINITIONS --------------------------------------------------------------------- #

# NOTE: Match the supported device types to regular expression patterns using Godot's
# version of the SDL controller database [1].
#
# [1] https://github.com/godotengine/godot/blob/master/core/input/gamecontrollerdb.txt
static var _regex_generic := RegEx.create_from_string(
	"(Adapter|Joystick|Fightstick|Arcade Stick|Fight Pad)"
)
static var _regex_ps4 := RegEx.create_from_string("(PS[2-4]|DualShock [2-4])")
static var _regex_ps5 := RegEx.create_from_string("(DualSense|PS5)")
static var _regex_steam_controller := RegEx.create_from_string(
	"(Steam Controller|Horipad Steam)"
)
static var _regex_steam_deck := RegEx.create_from_string(
	"(Steam Deck|Steam Virtual Gamepad)"
)
static var _regex_switch_joy_con_pair := RegEx.create_from_string(
	"(Joy-Con \\(L/R\\)|Joy-Cons)"
)
static var _regex_switch_joy_con_single := RegEx.create_from_string(
	"(Joy-Con \\([LR]\\)|Left Joy-Con|Right Joy-Con)"
)
static var _regex_switch_pro := RegEx.create_from_string(
	"((Switch (Controller|Pro)|Horipad Switch)|Pro Controller)"
)
static var _regex_xbox_360 := RegEx.create_from_string("Xbox 360")
static var _regex_xbox_one := RegEx.create_from_string("Xbox(?!( 360))")

var _logger := StdLogger.create("std/input/godot/joypad-monitor").with_process_frame()

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## get_device_type returns the type/category of joypad based on its name. This method is
## a best effort attempt and uses the SDL controller database.
##
## FIXME(https://github.com/godotengine/godot/issues/98008): This does not work on macOS
## at the moment.
func get_device_type(joypad_name: String) -> StdInputDevice.DeviceType:
	# NOTE: Exclude generic matches first so that they don't match with any of the other
	# device patterns.
	if _regex_generic.search(joypad_name):
		return StdInputDevice.DEVICE_TYPE_GENERIC

	if _regex_xbox_360.search(joypad_name):
		return StdInputDevice.DEVICE_TYPE_XBOX_360

	if _regex_xbox_one.search(joypad_name):
		return StdInputDevice.DEVICE_TYPE_XBOX_ONE

	if _regex_ps4.search(joypad_name):
		return StdInputDevice.DEVICE_TYPE_PS_4

	if _regex_ps5.search(joypad_name):
		return StdInputDevice.DEVICE_TYPE_PS_5

	if _regex_switch_joy_con_pair.search(joypad_name):
		return StdInputDevice.DEVICE_TYPE_SWITCH_JOY_CON_PAIR

	if _regex_switch_joy_con_single.search(joypad_name):
		return StdInputDevice.DEVICE_TYPE_SWITCH_JOY_CON_SINGLE

	if _regex_switch_pro.search(joypad_name):
		return StdInputDevice.DEVICE_TYPE_SWITCH_PRO

	if _regex_steam_deck.search(joypad_name):
		return StdInputDevice.DEVICE_TYPE_STEAM_DECK

	if _regex_steam_controller.search(joypad_name):
		return StdInputDevice.DEVICE_TYPE_STEAM_CONTROLLER

	return StdInputDevice.DEVICE_TYPE_GENERIC  # gdlint:ignore=max-returns


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _exit_tree() -> void:
	if Input.joy_connection_changed.is_connected(_on_Input_joy_connection_changed):
		Input.joy_connection_changed.disconnect(_on_Input_joy_connection_changed)


func _ready() -> void:
	var err := Input.joy_connection_changed.connect(_on_Input_joy_connection_changed)
	assert(err == OK, "failed to connect to signal")


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _broadcast_connected_joypads() -> void:
	for device in Input.get_connected_joypads():
		_broadcast_connected_joypad(device)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _broadcast_connected_joypad(device: int) -> void:
	var joypad_name := Input.get_joy_name(device)
	var device_type := get_device_type(joypad_name)

	(
		_logger
		. info(
			"Joypad connected.",
			{&"device": device, &"name": joypad_name, &"type": device_type},
		)
	)

	joy_connected.emit(device, device_type)


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_Input_joy_connection_changed(device: int, connected: bool) -> void:
	if not connected:
		_logger.info("Joypad disconnected.", {&"device": device})

		joy_disconnected.emit(device)
		return

	_broadcast_connected_joypad(device)
