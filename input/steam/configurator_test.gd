##
## std/input/steam/configurator_test.gd
##
## Tests pertaining to `StdInputSteamConfigurator`.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const SlotTest := preload("../slot_test.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

## _CONFIGURATOR_PATH is the configurator script, loaded in `before_all` rather than
## preloaded, since it can't be parsed without the `Steam` singleton the GodotSteam
## extension registers and `should_skip_script` skips this script without it.
const _CONFIGURATOR_PATH := "configurator.gd"

## _JOYPAD_MONITOR_PATH is the joypad monitor script, loaded as `_CONFIGURATOR_PATH`.
const _JOYPAD_MONITOR_PATH := "joypad_monitor.gd"

## _STEAM_ERROR is the condition GodotSteam reports when it rejects a call because
## Steam Input isn't running, as under test.
const _STEAM_ERROR := "SteamAPI_SteamInput() == nullptr"

## _TEST_HANDLE is the Steam handle of the controller connected in slot 0.
const _TEST_HANDLE := 7

# -- INITIALIZATION ------------------------------------------------------------------ #

var _configurator: Variant = null
var _joypad_monitor: Variant = null
var _monitor: StdInputSlot.JoypadMonitor = null
var _slot: StdInputSlot = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_configurator_uses_the_last_active_joypads_steam_handle() -> void:
	# Given: A slot whose controller connected before any player input, so it's active.
	_slot.prefer_activate_joypad_on_ready = true
	_add_slot()
	_connect_joypad()

	# When/Then: The handle is the controller's, not its slot index.
	assert_eq(_configurator._get_controller_handle(_slot), _TEST_HANDLE)


func test_configurator_uses_a_connected_joypad_once_none_was_active() -> void:
	# Given: A slot whose controller connected but never became active, as after a
	# component swap clears the last active joypad.
	_slot.prefer_activate_joypad_on_ready = false
	_add_slot()
	_connect_joypad()
	assert_null(_slot.get_last_active_joypad_device(), "precondition: none active")

	# When/Then: The handle is the connected controller's.
	assert_eq(_configurator._get_controller_handle(_slot), _TEST_HANDLE)


func test_configurator_has_no_handle_without_a_steam_controller() -> void:
	# Given: A slot with no controller connected.
	_add_slot()

	# When/Then: There's no handle.
	assert_eq(_configurator._get_controller_handle(_slot), 0)


func test_configurator_button_opens_the_panel_for_the_controller() -> void:
	# Given: A slot with a controller connected, and a configurator for its player.
	_add_slot()
	_connect_joypad()

	var configurator: Node = autofree(_configurator.new())
	configurator.player_id = _slot.player_id

	# When: The button is pressed.
	configurator._on_button_pressed()

	# Then: Steam is asked to open the panel, which it rejects since Steam Input isn't
	# running, and the rejection is logged rather than reported as opened.
	assert_engine_error(_STEAM_ERROR)


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_all() -> void:
	var path: String = get_script().resource_path.get_base_dir().path_join(
		_CONFIGURATOR_PATH
	)
	_configurator = load(path)
	_joypad_monitor = load(path.get_base_dir().path_join(_JOYPAD_MONITOR_PATH))


func before_each() -> void:
	# NOTE: The Steam monitor stays out of the scene, since entering it needs Steam
	# Input; the slot only needs its signals and slot-to-handle map.
	_monitor = _joypad_monitor.new()

	_slot = SlotTest.make_slot()
	_slot.claim_kbm_input = true
	_slot.joypad_monitor = _monitor


func should_skip_script():
	if not ClassDB.class_exists(&"Steam"):
		return "the GodotSteam extension isn't available on this platform"

	return false


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _add_slot adds the slot to the scene, freeing the Steam monitor after it, since the
## slot disconnects from its monitor as it leaves, and its keyboard device, which it
## only queues for freeing.
func _add_slot() -> void:
	add_child_autofree(_slot)
	autofree(_monitor)
	autofree(_slot.get_connected_devices()[0])


## _connect_joypad connects the controller `_TEST_HANDLE` in slot 0, as the Steam
## monitor reports one.
func _connect_joypad() -> void:
	_monitor._connected = PackedInt64Array([_TEST_HANDLE])
	_monitor.joy_connected.emit(0, StdInputDevice.DEVICE_TYPE_GENERIC)
	autofree(_slot.get_connected_devices(false)[0])
