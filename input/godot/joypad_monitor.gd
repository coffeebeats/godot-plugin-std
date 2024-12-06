##
## std/input/godot/joypad_monitor.gd
##
## An implemention of `InputSlot.JoypadMonitor` which uses Godot's built-in device
## input system to notify the `InputSlot` on joypad connection changes.
##

extends InputSlot.JoypadMonitor

# -- DEFINITIONS --------------------------------------------------------------------- #

# NOTE: Match the supported device types to regular expression patterns using the SDL
# controller database [1].
#
# [1] https://github.com/libsdl-org/SDL/blob/main/src/joystick/SDL_gamepad_db.h
static var _regex_nintendo_switch := RegEx.create_from_string("Switch")
static var _regex_sony := RegEx.create_from_string("(Sony|PS[0-9]+)")
static var _regex_steam_controller := RegEx.create_from_string("Steam Controller")
static var _regex_steam_deck := RegEx.create_from_string(
	"(Steam Deck|Steam Virtual Gamepad)"
)
static var _regex_xbox := RegEx.create_from_string("(Xbox|X-Box|XBOX)")

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## get_device_type returns the type/category of joypad based on its name. This method is
## a best effort attempt and uses the SDL controller database.
func get_device_type(joypad_name: String) -> InputDevice.InputDeviceType:
	var device_type := InputDevice.DEVICE_TYPE_UNKNOWN

	if _regex_xbox.search(joypad_name):
		device_type = InputDevice.DEVICE_TYPE_XBOX
	elif _regex_sony.search(joypad_name):
		device_type = InputDevice.DEVICE_TYPE_PLAYSTATION
	elif _regex_nintendo_switch.search(joypad_name):
		device_type = InputDevice.DEVICE_TYPE_NINTENDO_SWITCH
	elif _regex_steam_deck.search(joypad_name):
		device_type = InputDevice.DEVICE_TYPE_STEAM_DECK
	elif _regex_steam_controller.search(joypad_name):
		device_type = InputDevice.DEVICE_TYPE_STEAM_CONTROLLER

	return device_type


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _exit_tree() -> void:
	if Input.joy_connection_changed.is_connected(_on_Input_joy_connection_changed):
		Input.joy_connection_changed.disconnect(_on_Input_joy_connection_changed)


func _ready() -> void:
	var err := Input.joy_connection_changed.connect(_on_Input_joy_connection_changed)
	assert(err == OK, "failed to connect to signal")


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_Input_joy_connection_changed(device: int, connected: bool) -> void:
	if not connected:
		print(
			"std/input/godot/joypad_monitor.gd[",
			get_instance_id(),
			"]: joypad connection changed: %d (connected=%s)" % [device, connected],
		)

		joy_disconnected.emit(device)
		return

	var joypad_name := Input.get_joy_name(device)

	print(
		"std/input/godot/joypad_monitor.gd[",
		get_instance_id(),
		(
			"]: joypad connection changed: %d (name=%s,connected=%s)"
			% [device, joypad_name, connected]
		),
	)

	var device_type := get_device_type(joypad_name)

	joy_connected.emit(device, device_type)
