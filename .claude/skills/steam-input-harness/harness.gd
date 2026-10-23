##
## harness.gd
##
## A Steam Input harness: starts Steam, mounts std's Steam joypad monitor, actions and
## glyph components under a real `StdInputSlot`, and walks a person through scripted
## steps on screen while logging what the hardware reports to `results.log` beside this
## script. It is launched through `run.gd` beside it; the `steam-input-harness` skill
## explains how to run it and which arguments it takes.
##

@tool
extends Node

const DEFAULT_APP_ID := 480

## REVEAL_RAMP_START and REVEAL_RAMP_STEP shape the pointer ramp of the frame-rate reveal
## steps, in px/s: the starting speed and the rise every half second.
const REVEAL_RAMP_START := 10.0
const REVEAL_RAMP_STEP := 5.0

## REVEAL_RAMP_X is the window x coordinate the pointer ramp starts from.
const REVEAL_RAMP_X := 100.0

## REVEAL_RETRIES is how many spurious reveals a frame-rate step re-arms after.
const REVEAL_RETRIES := 3

## CONFIRMED lists the steps whose behaviour the hardware pass of 2026-10-19 confirmed
## (DualShock 4, Windows, app 480, the #495 stack through #523). A run skips them unless
## `--all` is given, so a default run covers only what is still open.
const CONFIRMED := [
	"stick_up",
	"stick_release_1",
	"stick_left",
	"stick_release_2",
	"hold_counts",
	"hold_release",
	"jump_presses",
	"switch_kbm_while_held",
	"reactivate_joypad",
	"stick_held_while_typing",
	"pointer",
	"pointer_slow",
	"reveal_60",
	"reveal_240",
	"captured",
	"origins",
	"rebind",
	"disconnect",
]
const DEADZONE := 0.5
const MOVE: Array[StringName] = [&"move_left", &"move_right", &"move_up", &"move_down"]

## STEPS lists each step's name and on-screen instruction; hooks are methods named
## `_s_<name>_enter`, `_s_<name>_tick`, `_s_<name>_check` and `_s_<name>_exit`.
const STEPS := [
	[
		"connect",
		"Waiting for the controller. Press any button on the pad. If nothing happens, check Steam > Settings > Controller for the pad's family."
	],
	[
		"bindings",
		"Steam knows the Harness set but nothing is bound to it yet. Press F1 to open the binding panel (or Big Picture > the app > Controller settings), bind: Left stick as Joystick -> move, Cross/A -> jump, Circle/B -> cancel, Right trigger -> fire, Right stick or trackpad as Mouse -> pointer. Save the layout privately. This step ends by itself once 'jump' has an origin."
	],
	[
		"rest",
		"Hands off the controller for 5 seconds. The harness presses SPACE itself to activate the keyboard, then watches the resting pad."
	],
	["stick_up", "Push the LEFT STICK fully UP and hold."],
	["stick_release_1", "Release the stick."],
	["stick_left", "Push the LEFT STICK fully LEFT and hold."],
	["stick_release_2", "Release the stick."],
	["hold_counts", "Push the LEFT STICK fully RIGHT and hold it still for 3 seconds."],
	["hold_release", "Release the stick and wait."],
	["jump_presses", "Press JUMP (Cross / A) three times."],
	[
		"switch_kbm_while_held",
		"HOLD JUMP. While holding it, press SPACE on the keyboard once. Keep holding the button for 2 more seconds, then release it."
	],
	["reactivate_joypad", "Now press JUMP again once."],
	[
		"stick_held_while_typing",
		"Push the LEFT STICK fully UP and hold. While holding, press SPACE once, keep holding the stick 2 more seconds, then release."
	],
	[
		"trigger",
		"Squeeze the RIGHT TRIGGER (fire) SLOWLY all the way in, then release it slowly."
	],
	[
		"pointer",
		"Press SPACE first so the keyboard is active, then move the pointer with the controller (right stick, trackpad or gyro, bound to 'pointer' as mouse). Move it at least 200 px; keep the real mouse still."
	],
	[
		"pointer_slow",
		"Move the pointer VERY slowly with the controller for 3 seconds (sub-pixel motion should still creep)."
	],
	[
		"reveal_60",
		"Frame rate capped at 60 fps. Hands off the mouse and the stick: once the pointer has rested for a second, the harness hides the cursor and moves the pointer itself, faster and faster, until the cursor reveals."
	],
	[
		"reveal_240",
		"Frame rate capped at 240 fps. Same again, hands off: the harness ramps the pointer until the cursor reveals."
	],
	[
		"captured",
		"Cursor is now CAPTURED. Move the pointer with the controller again, for about 6 seconds (the step ends after 60 motion events)."
	],
	[
		"origins",
		"Origins and glyphs are being read (logged after 2 s). Optionally bind a SECOND button to Jump via F1 so cycling can be checked, then press ENTER."
	],
	[
		"rebind",
		"Press F1, change Jump's binding in the Steam panel, close the panel. The step ends once a configuration change is seen (or ENTER)."
	],
	[
		"disconnect",
		"HOLD JUMP and, while holding, unplug the controller. Then plug it back in and press JUMP once."
	],
	[
		"generic_override",
		"Hands off: the harness presses SPACE itself. UNPLUG the controller, wait a second, then plug it back in WITHOUT pressing anything on it. The step ends 2 s after it reconnects."
	],
]


## NoGlyphs is a keyboard glyph component which reports nothing, since the base class
## asserts and the harness only cares about the joypad side.
class NoGlyphs:
	extends StdInputDeviceGlyphs

	func _get_action_glyph(
		_slot: int,
		_device_type: StdInputDevice.DeviceType,
		_action_set: StdInputActionSet,
		_action: StringName,
		_index: int,
		_target_size: Vector2
	) -> Texture2D:
		return null

	func _get_action_origin_count(
		_slot: int,
		_device_type: StdInputDevice.DeviceType,
		_action_set: StdInputActionSet,
		_action: StringName
	) -> int:
		return 0

	func _get_action_origin_label(
		_slot: int,
		_device_type: StdInputDevice.DeviceType,
		_action_set: StdInputActionSet,
		_action: StringName,
		_index: int
	) -> String:
		return ""


## CycleGlyph records every binding index the glyph is asked to draw.
class CycleGlyph:
	extends StdInputGlyph
	var seen: Array[int] = []

	func _update_glyph(_device_type: DeviceType, index: int) -> bool:
		seen.append(index)
		return true


## GenericGlyph records the family and the Steam texture size of each redraw, for a glyph
## locked to controller prompts by a `DEVICE_TYPE_GENERIC` override.
class GenericGlyph:
	extends StdInputGlyph
	var drawn: Array[String] = []

	func _update_glyph(device_type: DeviceType, index: int) -> bool:
		var texture := _slot.get_action_glyph(
			action_set, action, index, Vector2(64, 64), device_type
		)
		var values: Array = StdInputDevice.DeviceType.values()
		var family := str(StdInputDevice.DeviceType.keys()[values.find(device_type)])
		drawn.append("%s:%s" % [family, str(texture.get_size()) if texture else "null"])
		return texture != null


var _app_id: int = DEFAULT_APP_ID
var _std_input: String = ""
var _scripts: Dictionary = {}

var _set: StdInputActionSet
var _scope := StdSettingsScope.new()
var _steam_enabled: StdSettingsPropertyBool
var _slot: StdInputSlot
var _cursor: StdInputCursor
var _monitor: StdInputSlot.JoypadMonitor
var _steam_actions: StdInputDeviceActions
var _steam_glyphs: StdInputDeviceGlyphs
var _glyph: CycleGlyph
var _generic_glyph: GenericGlyph
var _origin_button: Button

var _instruction: Label
var _status: Label
var _log_view: RichTextLabel
var _file: FileAccess

var _step: int = -1
var _step_time: float = 0.0
var _state: Dictionary = {}

var _activations: Array[String] = []
var _config_changes: int = 0
var _native_joy_events: int = 0
var _motion_events: Array[String] = []
var _record_motion: bool = false
var _late_slot: bool = false
var _from_step: String = ""
var _run_all: bool = false
var _cursor_visibility: Array[bool] = []

# -- ENGINE METHODS ------------------------------------------------------------------ #


func _ready() -> void:
	var here: String = get_script().resource_path.get_base_dir()
	_file = FileAccess.open(here.path_join("results.log"), FileAccess.WRITE)

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--appid="):
			_app_id = int(arg.trim_prefix("--appid="))
		if arg == "--late-slot":
			_late_slot = true
		if arg.begins_with("--from="):
			_from_step = arg.trim_prefix("--from=")
		if arg == "--all":
			_run_all = true

	# NOTE: std may live at `res://` (its own repository) or `res://addons/std`.
	var slot_script: Script = StdInputSlot
	_std_input = slot_script.resource_path.get_base_dir()
	for key in [
		"steam/joypad_monitor.gd",
		"steam/device_actions.gd",
		"steam/device_glyphs.gd",
		"godot/device_actions.gd"
	]:
		_scripts[key] = load(_std_input.path_join(key))

	_build_ui()

	# NOTE: An unknown `--from` step would skip every step, so the run stops instead.
	var step_names := STEPS.map(func(s): return s[0])
	if _from_step and _from_step not in step_names:
		_instruction.text = "Unknown --from step '%s'; see results.log." % _from_step
		_log("unknown --from step %s; steps: %s" % [_from_step, step_names])
		return

	_register_actions()
	_build_action_set()

	var response: Dictionary = Steam.steamInitEx(_app_id)
	_log("steamInitEx(%d): %s" % [_app_id, response])
	if response.get("status", 1) != OK:
		_instruction.text = "Steam failed to start; see results.log."
		return

	_log(
		(
			"steam running=%s loggedOn=%s appid=%d"
			% [Steam.isSteamRunning(), Steam.loggedOn(), Steam.getAppID()]
		)
	)

	# NOTE: The manifest is written before the monitor calls inputInit. Steam prefers a
	# `game_actions_<appid>.vdf` in its own `controller_config` folder, and the override
	# call returns false while one exists; the skill covers copying it there.
	var manifest := StdInputSteamInGameActions.new()
	manifest.app_id = _app_id
	var vdf := manifest.render([_set], {"english": "en"})
	var vdf_path := ProjectSettings.globalize_path(
		here.path_join("game_actions_%d.vdf" % _app_id)
	)
	var f := FileAccess.open(vdf_path, FileAccess.WRITE)
	f.store_string(vdf)
	f.close()
	var set_ok := Steam.setInputActionManifestFilePath(vdf_path)
	_log(
		(
			"manifest written: %s (%d bytes); setInputActionManifestFilePath=%s"
			% [vdf_path, vdf.length(), set_ok]
		)
	)

	_build_input()
	_next_step()


func _process(delta: float) -> void:
	Steam.run_callbacks()

	if _step < 0 or _step >= STEPS.size():
		return

	_step_time += delta
	_status.text = (
		"step %d/%d  t=%.1fs  active=%s  cursor=%s  mouse_mode=%d  vec=%s"
		% [
			_step + 1,
			STEPS.size(),
			_step_time,
			_active_name(),
			_cursor.get_is_visible(),
			DisplayServer.mouse_get_mode(),
			Input.get_vector(MOVE[0], MOVE[1], MOVE[2], MOVE[3]),
		]
	)

	_call_hook("tick", [delta])

	var done: Variant = _call_hook("check", [])
	if done == true:
		_finish_step()


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		_native_joy_events += 1

	if event is InputEventMouseMotion and _record_motion:
		_motion_events.append(
			(
				"rel=%s screen_rel=%s pos=%s dev=%d"
				% [event.relative, event.screen_relative, event.position, event.device]
			)
		)

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ENTER, KEY_KP_ENTER:
				_log("  (skipped by user)")
				_finish_step()
			KEY_F1:
				var device: int = _monitor.get_device_id_for_slot(0)
				var shown := (
					str(Steam.showBindingPanel(device)) if device != -1 else "no device"
				)
				_log("F1: showBindingPanel(%d) -> %s" % [device, shown])
			KEY_F2:
				_set.cursor_captured = not _set.cursor_captured
				_cursor.update_configuration([_set])
				_log(
					(
						"F2: cursor_captured=%s -> mouse_mode=%d"
						% [_set.cursor_captured, DisplayServer.mouse_get_mode()]
					)
				)


# -- SETUP --------------------------------------------------------------------------- #


func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_instruction = Label.new()
	_instruction.autowrap_mode = TextServer.AUTOWRAP_WORD
	_instruction.add_theme_font_size_override("font_size", 26)
	root.add_child(_instruction)

	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 14)
	root.add_child(_status)

	var help := Label.new()
	help.text = "ENTER: skip step   F1: Steam binding panel   F2: toggle captured cursor"
	root.add_child(help)

	_log_view = RichTextLabel.new()
	_log_view.scroll_following = true
	_log_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_log_view)

	# NOTE: A button at the window origin, to detect hover while captured.
	_origin_button = Button.new()
	_origin_button.text = "origin"
	_origin_button.position = Vector2.ZERO
	_origin_button.size = Vector2(80, 30)
	add_child(_origin_button)


func _register_actions() -> void:
	var all: Array[StringName] = [&"jump", &"cancel", &"fire", &"pointer"]
	all.append_array(MOVE)
	for action in all:
		if not InputMap.has_action(action):
			InputMap.add_action(action, DEADZONE)

	# NOTE: Keyboard defaults for the Godot-backed keyboard component; the joypad side is
	# Steam's.
	var binds := {
		&"jump": KEY_SPACE,
		&"cancel": KEY_ESCAPE,
		MOVE[0]: KEY_A,
		MOVE[1]: KEY_D,
		MOVE[2]: KEY_W,
		MOVE[3]: KEY_S
	}
	# NOTE: Every action gets a project setting, since the Godot binding component reads
	# `input/<action>` for each action in the set and warns when one is missing.
	for action in all:
		var events: Array = []
		if action in binds:
			var key := InputEventKey.new()
			key.keycode = binds[action]
			events.append(key)
		ProjectSettings.set_setting(
			"input/" + action, {"deadzone": DEADZONE, "events": events}
		)


func _build_action_set() -> void:
	_set = StdInputActionSet.new()
	_set.name = &"Harness"
	_set.actions_digital = [&"jump", &"cancel", MOVE[0], MOVE[1], MOVE[2], MOVE[3]]
	_set.actions_analog_1d = [&"fire"]
	_set.actions_analog_2d = [&"move"]
	_set.action_absolute_mouse = &"pointer"
	_set.cursor_reveal_distance_minimum = Vector2(4, 4)
	_set.cursor_reveal_window = 0.1
	_set.cursor_click_activates_kbm = StdInputActionSet.PROPERTY_STATUS_ON
	_set.version_major = 1


func _build_input() -> void:
	_scope.is_loaded = true

	_steam_enabled = StdSettingsPropertyBool.new()
	_steam_enabled.category = &"harness"
	_steam_enabled.name = &"steam_input"
	_steam_enabled.scope = _scope
	_steam_enabled.value_changed.connect(_on_steam_enabled_changed)

	_monitor = _scripts["steam/joypad_monitor.gd"].new()
	_monitor.name = "SteamJoypadMonitor"
	_monitor.steam_input_enabled_property = _steam_enabled

	_steam_actions = _scripts["steam/device_actions.gd"].new()
	_steam_actions.name = "SteamActions"
	_steam_actions.joypad_monitor = _monitor
	_steam_actions.steam_input_enabled_property = _steam_enabled
	_steam_actions.bindings_changed.connect(_on_steam_bindings_changed)

	_steam_glyphs = _scripts["steam/device_glyphs.gd"].new()
	_steam_glyphs.name = "SteamGlyphs"
	_steam_glyphs.joypad_monitor = _monitor

	var kbm_actions: StdInputDeviceActions = _scripts["godot/device_actions.gd"].new()
	kbm_actions.name = "GodotActions"
	kbm_actions.scope = _scope
	kbm_actions.claim_joy_input = false

	_cursor = StdInputCursor.new()
	_cursor.name = "Cursor"
	_cursor.cursor_visibility_changed.connect(_on_cursor_visibility_changed)

	_slot = StdInputSlot.new()
	_slot.name = "Slot"
	_slot.player_id = 1
	_slot.haptics_disabled_property = StdSettingsPropertyBool.new()
	_slot.haptics_strength_property = StdSettingsPropertyFloatRange.new()
	_slot.cursor = _cursor
	_slot.joypad_monitor = _monitor
	_slot.actions_kbm = kbm_actions
	_slot.glyphs_kbm = NoGlyphs.new()
	_slot.haptics_kbm = StdInputDeviceHaptics.new()
	_slot.actions_joy = _steam_actions
	_slot.glyphs_joy = _steam_glyphs
	_slot.haptics_joy = StdInputDeviceHaptics.new()

	_slot.device_connected.connect(_on_device_connected)
	_slot.device_disconnected.connect(_on_device_disconnected)
	_slot.device_activated.connect(_on_device_activated)
	_slot.action_configuration_changed.connect(_on_action_configuration_changed)

	for n in [
		_cursor,
		_monitor,
		_steam_actions,
		_steam_glyphs,
		kbm_actions,
		_slot.glyphs_kbm,
		_slot.haptics_kbm,
		_slot.haptics_joy
	]:
		add_child(n)

	# NOTE: With `--late-slot` the slot enters the tree only after Steam connected a
	# pad, so the monitor must report it through `broadcast_connected_joypads`.
	if not _late_slot:
		_mount_slot()


func _mount_slot() -> void:
	add_child(_slot)

	_log("slot ready; loading set -> %s" % _slot.load_action_set(_set))

	_glyph = CycleGlyph.new()
	_glyph.action_set = _set
	_glyph.action = &"jump"
	_glyph.player_id = 1
	_glyph.cycle_interval = 0.5
	add_child(_glyph)


# -- STEP ENGINE --------------------------------------------------------------------- #


func _call_hook(kind: String, args: Array) -> Variant:
	var method := "_s_%s_%s" % [STEPS[_step][0], kind]
	if has_method(method):
		return callv(method, args)
	return null


func _next_step() -> void:
	_step += 1
	_step_time = 0.0
	if _step >= STEPS.size():
		_instruction.text = "DONE. Results written; you can close the window."
		_log("DONE")
		return

	# NOTE: `--from=<step>` skips every step before the named one, except the two which
	# establish the pad and its bindings. The named step runs even when confirmed, while
	# the confirmed steps after it are still skipped without `--all`.
	var step_name: String = STEPS[_step][0]
	var is_from_target := _from_step != "" and step_name == _from_step
	if _from_step and not is_from_target and step_name not in ["connect", "bindings"]:
		_log("--- step %s (skipped by --from)" % step_name)
		_next_step.call_deferred()
		return

	if is_from_target:
		_from_step = ""
	elif step_name in CONFIRMED and not _run_all:
		_log("--- step %s (skipped: confirmed on hardware; run with --all)" % step_name)
		_next_step.call_deferred()
		return

	_instruction.text = "[%d/%d] %s" % [_step + 1, STEPS.size(), STEPS[_step][1]]
	_log("--- step %s" % step_name)
	_call_hook("enter", [])


func _finish_step() -> void:
	if _step < 0 or _step >= STEPS.size():
		return
	_call_hook("exit", [])
	_next_step()


# -- STEP HOOKS ---------------------------------------------------------------------- #


func _s_connect_check() -> bool:
	return _slot.get_connected_devices(false).size() > 0


func _s_connect_exit() -> void:
	var d := _slot.get_connected_devices(false)
	var described := d.map(func(x): return [x.device_id, _type_name(x.device_type)])
	_log(
		(
			"connected joypads: %s; steam handles=%s; godot joypads=%s"
			% [
				described,
				Steam.getConnectedControllers(),
				Input.get_connected_joypads()
			]
		)
	)
	var device: int = _monitor.get_device_id_for_slot(0)
	if device != -1:
		var harness_handle: int = (
			_scripts["steam/device_actions.gd"].get_action_set_handle(&"Harness")
		)
		_log(
			(
				"current steam set handle=%d (Harness=%d) input type=%d"
				% [
					Steam.getCurrentActionSet(device),
					harness_handle,
					Steam.getInputTypeForHandle(device)
				]
			)
		)
		if harness_handle == 0:
			_log(
				(
					"!! Steam has no Harness set: copy game_actions_%d.vdf into Steam's controller_config folder and relaunch"
					% _app_id
				)
			)


func _s_bindings_enter() -> void:
	_state = {"t": 0.0}


func _s_bindings_tick(delta: float) -> void:
	_state["t"] += delta
	if _state["t"] >= 5.0:
		_state["t"] = 0.0
		_log("waiting for bindings: jump origins=%d" % _jump_origin_count())


func _s_bindings_check() -> bool:
	return _jump_origin_count() > 0


func _s_bindings_exit() -> void:
	_log("bindings present: jump origins=%d" % _jump_origin_count())


func _s_rest_enter() -> void:
	_activations.clear()
	_state = {"max": 0.0, "pressed_frames": 0}

	# NOTE: The harness types SPACE itself, so the step runs with no hands on anything.
	for pressed in [true, false]:
		var key := InputEventKey.new()
		key.keycode = KEY_SPACE
		key.pressed = pressed
		Input.parse_input_event(key)


func _s_rest_tick(_delta: float) -> void:
	for action in MOVE + [&"fire"]:
		_state["max"] = maxf(_state["max"], Input.get_action_raw_strength(action))
		if Input.is_action_pressed(action):
			_state["pressed_frames"] += 1


func _s_rest_check() -> bool:
	return _step_time >= 5.0


func _s_rest_exit() -> void:
	var deadzones := MOVE.map(func(a): return InputMap.action_get_deadzone(a))
	_log(
		(
			"rest: max strength=%.5f pressed frames=%d activations=%s move deadzones=%s (expect 0, 0, no joypad, all near 0)"
			% [_state["max"], _state["pressed_frames"], _activations, deadzones]
		)
	)


func _s_stick_up_enter() -> void:
	_log_action_origins(&"move_left")


func _s_stick_up_check() -> bool:
	return _max_move_strength() > 0.8


func _s_stick_up_exit() -> void:
	_log_move("stick UP")


func _s_stick_release_1_check() -> bool:
	return _max_move_strength() < 0.05


func _s_stick_left_check() -> bool:
	return _max_move_strength() > 0.8


func _s_stick_left_exit() -> void:
	_log_move("stick LEFT")


func _s_stick_release_2_check() -> bool:
	return _max_move_strength() < 0.05


func _s_hold_counts_enter() -> void:
	_state = {"pressed": 0, "released": 0, "held": 0.0}


func _s_hold_counts_tick(delta: float) -> void:
	for a in MOVE:
		if Input.is_action_just_pressed(a):
			_state["pressed"] += 1
		if Input.is_action_just_released(a):
			_state["released"] += 1
	if Input.get_action_strength(MOVE[1]) > 0.8:
		_state["held"] += delta


func _s_hold_counts_check() -> bool:
	return _state["held"] >= 3.0


func _s_hold_counts_exit() -> void:
	_log(
		(
			"hold 3s: just_pressed=%d just_released=%d (expect 1 / 0; stick flutter adds pairs)"
			% [_state["pressed"], _state["released"]]
		)
	)


func _s_hold_release_enter() -> void:
	_state = {"released": 0, "idle": 0.0}


func _s_hold_release_tick(delta: float) -> void:
	for a in MOVE:
		if Input.is_action_just_released(a):
			_state["released"] += 1
	if _max_move_strength() < 0.05:
		_state["idle"] += delta


func _s_hold_release_check() -> bool:
	return _state["idle"] >= 1.5


func _s_hold_release_exit() -> void:
	_log(
		"after release: just_released=%d over 1.5s idle (expect 1)" % _state["released"]
	)


func _s_jump_presses_enter() -> void:
	_state = {"pressed": 0, "released": 0}
	_native_joy_events = 0


func _s_jump_presses_tick(_delta: float) -> void:
	if Input.is_action_just_pressed(&"jump"):
		_state["pressed"] += 1
	if Input.is_action_just_released(&"jump"):
		_state["released"] += 1


func _s_jump_presses_check() -> bool:
	return _state["pressed"] >= 3 and _state["released"] >= 3


func _s_jump_presses_exit() -> void:
	_log(
		(
			"jump: just_pressed=%d just_released=%d native joypad events seen=%d"
			% [_state["pressed"], _state["released"], _native_joy_events]
		)
	)


func _s_switch_kbm_while_held_enter() -> void:
	_activations.clear()
	_state = {"space": false, "after": 0.0, "released": false}


func _s_switch_kbm_while_held_tick(delta: float) -> void:
	if Input.is_key_pressed(KEY_SPACE) and Input.is_action_pressed(&"jump"):
		_state["space"] = true
	if _state["space"] and Input.is_action_pressed(&"jump"):
		_state["after"] += delta
	if (
		_state["space"]
		and _state["after"] > 1.0
		and not Input.is_action_pressed(&"jump")
	):
		_state["released"] = true


func _s_switch_kbm_while_held_check() -> bool:
	return _state["released"]


func _s_switch_kbm_while_held_exit() -> void:
	_log(
		(
			"held jump + space: activations=%s (expect KEYBOARD once, no later joypad while held)"
			% [_activations]
		)
	)


func _s_reactivate_joypad_enter() -> void:
	_activations.clear()


func _s_reactivate_joypad_check() -> bool:
	return Input.is_action_just_pressed(&"jump")


func _s_reactivate_joypad_exit() -> void:
	_log("fresh jump press: activations=%s (expect the joypad)" % [_activations])


func _s_stick_held_while_typing_enter() -> void:
	_activations.clear()
	_state = {"space": false, "after": 0.0, "done": false}


func _s_stick_held_while_typing_tick(delta: float) -> void:
	if Input.is_key_pressed(KEY_SPACE) and _max_move_strength() > 0.8:
		_state["space"] = true
	if _state["space"] and _max_move_strength() > 0.8:
		_state["after"] += delta
	if _state["space"] and _state["after"] > 1.5 and _max_move_strength() < 0.05:
		_state["done"] = true


func _s_stick_held_while_typing_check() -> bool:
	return _state["done"]


func _s_stick_held_while_typing_exit() -> void:
	_log(
		(
			"stick held + space: activations=%s (expect joypad then KEYBOARD, no joypad after SPACE)"
			% [_activations]
		)
	)


func _s_trigger_enter() -> void:
	_log_action_origins(&"fire")
	_state = {
		"press_strength": -1.0, "release_strength": -1.0, "max": 0.0, "samples": []
	}


func _s_trigger_tick(_delta: float) -> void:
	var s := Input.get_action_strength(&"fire")
	_state["max"] = maxf(_state["max"], s)
	if Input.is_action_just_pressed(&"fire"):
		_state["press_strength"] = s
	if Input.is_action_just_released(&"fire"):
		_state["release_strength"] = s
	if Engine.get_process_frames() % 10 == 0 and s > 0.0:
		_state["samples"].append(snappedf(s, 0.01))


func _s_trigger_check() -> bool:
	return (
		_state["press_strength"] >= 0.0
		and _state["release_strength"] >= 0.0
		and Input.get_action_strength(&"fire") == 0.0
	)


func _s_trigger_exit() -> void:
	_log(
		(
			"trigger: pressed at strength=%.2f released at %.2f max=%.2f (expect a press at the first strength above 0) samples=%s"
			% [
				_state["press_strength"],
				_state["release_strength"],
				_state["max"],
				_state["samples"]
			]
		)
	)


func _s_pointer_enter() -> void:
	_log_action_origins(&"pointer")
	_set.cursor_captured = false
	_cursor.update_configuration([_set])
	_log(
		(
			"pointer: mouse_mode=%d active=%s (expect the keyboard before moving)"
			% [DisplayServer.mouse_get_mode(), _active_name()]
		)
	)
	_activations.clear()
	_cursor_visibility.clear()
	_state = {"start": DisplayServer.mouse_get_position(), "far": 0.0}


func _s_pointer_tick(_delta: float) -> void:
	var moved := (
		(Vector2(DisplayServer.mouse_get_position()) - Vector2(_state["start"]))
		. length()
	)
	_state["far"] = maxf(_state["far"], moved)


func _s_pointer_check() -> bool:
	return _state["far"] >= 200.0


func _s_pointer_exit() -> void:
	_log(
		(
			"pointer moved %.0f px; activations=%s cursor visibility=%s remainder=%s (expect joypad activation, cursor visible)"
			% [
				_state["far"],
				_activations,
				_cursor_visibility,
				_steam_actions._warp_remainder
			]
		)
	)


func _s_pointer_slow_enter() -> void:
	_state = {"start": DisplayServer.mouse_get_position(), "t": 0.0}


func _s_pointer_slow_tick(delta: float) -> void:
	_state["t"] += delta


func _s_pointer_slow_check() -> bool:
	return _state["t"] >= 3.0


func _s_pointer_slow_exit() -> void:
	_log(
		(
			"slow pointer: moved %s px over 3s; remainder=%s"
			% [
				Vector2(DisplayServer.mouse_get_position()) - Vector2(_state["start"]),
				_steam_actions._warp_remainder
			]
		)
	)


func _s_reveal_60_enter() -> void:
	_begin_reveal_at(60)


func _s_reveal_60_tick(delta: float) -> void:
	_arm_reveal_at(delta)


func _s_reveal_60_check() -> bool:
	return _check_reveal_at()


func _s_reveal_60_exit() -> void:
	_end_reveal_at()


func _s_reveal_240_enter() -> void:
	_begin_reveal_at(240)


func _s_reveal_240_tick(delta: float) -> void:
	_arm_reveal_at(delta)


func _s_reveal_240_check() -> bool:
	return _check_reveal_at()


func _s_reveal_240_exit() -> void:
	_end_reveal_at()
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)


func _s_captured_enter() -> void:
	_set.cursor_captured = true
	_cursor.update_configuration([_set])
	_motion_events.clear()
	_record_motion = true
	_state = {"t": 0.0, "hovered": false}
	_log(
		(
			"captured: mouse_mode=%d (expect %d)"
			% [DisplayServer.mouse_get_mode(), DisplayServer.MOUSE_MODE_CAPTURED]
		)
	)


func _s_captured_tick(delta: float) -> void:
	if _motion_events.size() > 0:
		_state["t"] += delta
	if _origin_button.is_hovered():
		_state["hovered"] = true


func _s_captured_check() -> bool:
	return _state["t"] >= 6.0 or _motion_events.size() >= 60


func _s_captured_exit() -> void:
	_record_motion = false
	_log(
		(
			"captured motion events=%d origin button hovered=%s first=%s last=%s"
			% [
				_motion_events.size(),
				_state["hovered"],
				_motion_events.slice(0, 2),
				_motion_events.slice(-2)
			]
		)
	)
	_set.cursor_captured = false
	_cursor.update_configuration([_set])
	_log("uncaptured: mouse_mode=%d" % DisplayServer.mouse_get_mode())


func _s_origins_enter() -> void:
	_state = {"t": 0.0, "logged": false}
	_glyph.seen.clear()
	_glyph.update()


func _s_origins_tick(delta: float) -> void:
	_state["t"] += delta
	if _state["t"] > 2.0 and not _state["logged"]:
		_state["logged"] = true
		_log_origins()


func _s_origins_check() -> bool:
	return false


func _s_origins_exit() -> void:
	_log_origins()


func _s_rebind_enter() -> void:
	_config_changes = 0


func _s_rebind_check() -> bool:
	return _config_changes > 0


func _s_rebind_exit() -> void:
	_log("rebind: action_configuration_changed count=%d" % _config_changes)
	_log_origins()


func _s_disconnect_enter() -> void:
	_activations.clear()
	_state = {"disconnected": false, "pressed_after": false, "jump_after_disc": null}


func _s_disconnect_tick(_delta: float) -> void:
	var joypads := _slot.get_connected_devices(false)
	if joypads.is_empty() and not _state["disconnected"]:
		_state["disconnected"] = true
		_state["jump_after_disc"] = Input.is_action_pressed(&"jump")
	if (
		_state["disconnected"]
		and joypads.size() > 0
		and Input.is_action_just_pressed(&"jump")
	):
		_state["pressed_after"] = true


func _s_disconnect_check() -> bool:
	return _state["pressed_after"]


func _s_disconnect_exit() -> void:
	_log(
		(
			"disconnect: jump still pressed right after disconnect=%s (expect false); activations=%s"
			% [_state["jump_after_disc"], _activations]
		)
	)


func _s_generic_override_enter() -> void:
	_activations.clear()
	_state = {"unplugged": false, "replugged_at": -1.0, "last_active": "unchecked"}

	if not _generic_glyph:
		var override := StdSettingsPropertyInt.new()
		override.category = &"harness"
		override.name = &"glyph_override"
		override.scope = _scope
		override.default = StdInputDevice.DEVICE_TYPE_GENERIC

		_generic_glyph = GenericGlyph.new()
		_generic_glyph.action_set = _set
		_generic_glyph.action = &"jump"
		_generic_glyph.player_id = 1
		_generic_glyph.device_type_override = override
		add_child(_generic_glyph)

	# NOTE: The harness types SPACE itself, so the keyboard is active when the pad
	# reconnects and the slot, having seen player input, leaves the pad inactive.
	for pressed in [true, false]:
		var key := InputEventKey.new()
		key.keycode = KEY_SPACE
		key.pressed = pressed
		Input.parse_input_event(key)

	_generic_glyph.drawn.clear()
	_generic_glyph.update()


func _s_generic_override_tick(_delta: float) -> void:
	var joypads := _slot.get_connected_devices(false)
	if joypads.is_empty() and not _state["unplugged"]:
		_state["unplugged"] = true
		_log("generic_override: unplugged; drawn=%s" % [_generic_glyph.drawn])
	if _state["unplugged"] and joypads.size() > 0 and _state["replugged_at"] < 0.0:
		_state["replugged_at"] = _step_time
		var last := _slot.get_last_active_joypad_device()
		_state["last_active"] = _type_name(last.device_type) if last else "none"


func _s_generic_override_check() -> bool:
	return _state["replugged_at"] >= 0.0 and _step_time - _state["replugged_at"] >= 2.0


func _s_generic_override_exit() -> void:
	var device_type := _slot.get_joypad_device_type()
	var texture := _slot.get_action_glyph(
		_set, &"jump", 0, Vector2(64, 64), device_type
	)
	_log(
		(
			"generic_override: active=%s last active joypad at replug=%s (expect KEYBOARD, none); joypad type=%s glyph=%s; drawn=%s (expect a GENERIC redraw at unplug, then the pad's family with a size after replug); activations=%s"
			% [
				_active_name(),
				_state["last_active"],
				_type_name(device_type),
				str(texture.get_size()) if texture else "null",
				_generic_glyph.drawn,
				_activations,
			]
		)
	)


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_action_configuration_changed() -> void:
	_config_changes += 1
	_log("  action_configuration_changed (#%d)" % _config_changes)


func _on_cursor_visibility_changed(visible_now: bool) -> void:
	_cursor_visibility.append(visible_now)
	_log("  cursor_visibility_changed(%s)" % visible_now)


func _on_device_activated(d: StdInputDevice) -> void:
	var entry := "%s@%.1fs" % [_type_name(d.device_type), _step_time]
	_activations.append(entry)
	_log("  device_activated(%s)" % entry)


func _on_device_connected(d: StdInputDevice) -> void:
	_log("  device_connected(id=%d type=%s)" % [d.device_id, _type_name(d.device_type)])


func _on_device_disconnected(d: StdInputDevice) -> void:
	_log(
		(
			"  device_disconnected(id=%d type=%s)"
			% [d.device_id, _type_name(d.device_type)]
		)
	)


func _on_steam_bindings_changed() -> void:
	_log("  steam actions: bindings_changed")


func _on_steam_enabled_changed(value: Variant) -> void:
	_log("  steam_input_enabled -> %s" % value)

	if value and _late_slot and not _slot.is_inside_tree():
		_log("  mounting the slot after the joypad connected (--late-slot)")
		_mount_slot.call_deferred()


# -- HELPERS ------------------------------------------------------------------------- #


func _active_name() -> String:
	var d := _slot.get_active_device() if _slot else null
	return _type_name(d.device_type) if d else "none"


func _type_name(t: int) -> String:
	var values: Array = StdInputDevice.DeviceType.values()
	return str(StdInputDevice.DeviceType.keys()[values.find(t)])


func _jump_origin_count() -> int:
	var joy := _slot.get_connected_devices(false)
	if joy.is_empty():
		return 0
	return joy[0].get_action_origin_count(_set, &"jump")


func _max_move_strength() -> float:
	var m := 0.0
	for a in MOVE:
		m = maxf(m, Input.get_action_strength(a))
	return m


func _log_move(label: String) -> void:
	var strengths := MOVE.map(
		func(a): return snappedf(Input.get_action_strength(a), 0.01)
	)
	var pressed := MOVE.map(func(a): return Input.is_action_pressed(a))
	_log(
		(
			"%s: strengths L/R/U/D=%s pressed=%s get_vector=%s"
			% [
				label,
				strengths,
				pressed,
				Input.get_vector(MOVE[0], MOVE[1], MOVE[2], MOVE[3])
			]
		)
	)


## _begin_reveal_at caps the frame rate at `fps` and prepares a pointer ramp which starts
## once the pointer has rested for a second, so the speed at which the cursor reveals can
## be compared across rates.
func _begin_reveal_at(fps: int, retries: int = 0) -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = fps

	# NOTE: The pointer is moved to the ramp's start now, while the cursor is visible, so
	# the warp's echo lands inside the rest period instead of revealing the cursor.
	Input.warp_mouse(
		Vector2(REVEAL_RAMP_X, get_viewport().get_visible_rect().size.y / 2.0)
	)
	_state = {
		"fps": fps,
		"armed": false,
		"rest": 0.0,
		"last": Vector2(DisplayServer.mouse_get_position()),
		"t": 0.0,
		"x": REVEAL_RAMP_X,
		"speed": 0.0,
		"retries": retries,
	}


## _arm_reveal_at hides the cursor once the pointer has rested for a second, then warps
## the pointer along `x` at a speed which rises by `REVEAL_RAMP_STEP` px/s every half
## second, carrying the sub-pixel remainder so slow speeds still move whole pixels.
func _arm_reveal_at(delta: float) -> void:
	if not _state["armed"]:
		var position := Vector2(DisplayServer.mouse_get_position())
		if position == _state["last"]:
			_state["rest"] += delta
		else:
			_state["rest"] = 0.0
			_state["last"] = position

		if _state["rest"] < 1.0:
			return

		_state["armed"] = true
		_cursor.hide_cursor()
		_log(
			(
				"  pointer at rest; cursor hidden, ramping the pointer at %d fps"
				% _state["fps"]
			)
		)
		return

	_state["t"] += delta
	_state["speed"] = REVEAL_RAMP_START + REVEAL_RAMP_STEP * floorf(_state["t"] / 0.5)
	var before := int(_state["x"])
	_state["x"] += _state["speed"] * delta
	if int(_state["x"]) != before:
		Input.warp_mouse(
			Vector2(int(_state["x"]), get_viewport().get_visible_rect().size.y / 2.0)
		)


## _check_reveal_at reports whether the ramp revealed the cursor. A reveal before the ramp
## has moved the pointer a window's minimum is jitter from elsewhere, so the step re-arms
## up to `REVEAL_RETRIES` times rather than measuring it.
func _check_reveal_at() -> bool:
	if not _state["armed"] or not _cursor.get_is_visible():
		return false

	var moved: float = _state["x"] - REVEAL_RAMP_X
	if moved >= _set.cursor_reveal_distance_minimum.x:
		return true

	_state["retries"] = _state.get("retries", 0) + 1
	if _state["retries"] > REVEAL_RETRIES:
		_log("  reveal before the ramp moved %.0f px, out of retries" % moved)
		return true

	_log("  reveal before the ramp moved (%.1f px); re-arming" % moved)
	_begin_reveal_at(_state["fps"], _state["retries"])
	return false


## _end_reveal_at logs the commanded pointer speed at which the cursor revealed.
func _end_reveal_at() -> void:
	_log(
		(
			"reveal at %d fps (measured %.0f): revealed at %.0f px/s after %.1fs (threshold %s px over a %.2fs window, so about %.0f px/s)"
			% [
				_state["fps"],
				Engine.get_frames_per_second(),
				_state["speed"],
				_state["t"],
				_set.cursor_reveal_distance_minimum,
				_set.cursor_reveal_window,
				_set.cursor_reveal_distance_minimum.x / _set.cursor_reveal_window,
			]
		)
	)


## _log_action_origins logs the labels bound to `action` on the connected joypad, so an
## unbound action is obvious before a step waits on it.
func _log_action_origins(action: StringName) -> void:
	var joy := _slot.get_connected_devices(false)
	if joy.is_empty():
		_log("origins[%s]: no joypad" % action)
		return
	var device: StdInputDevice = joy[0]
	var labels := []
	for i in device.get_action_origin_count(_set, action):
		labels.append(device.get_action_origin_label(_set, action, i))
	_log("origins[%s]: %s" % [action, labels])


func _log_origins() -> void:
	var joy := _slot.get_connected_devices(false)
	if joy.is_empty():
		_log("origins: no joypad")
		return
	var device: StdInputDevice = joy[0]
	for action in [&"jump", &"cancel", &"move_left", &"move_up", &"fire", &"pointer"]:
		var count := device.get_action_origin_count(_set, action)
		var labels := []
		var glyphs := []
		for i in maxi(count, 1):
			labels.append(device.get_action_origin_label(_set, action, i))
			var tex := device.get_action_glyph(_set, action, i, Vector2(64, 64))
			glyphs.append(str(tex.get_size()) if tex else "null")
		_log(
			(
				"origins[%s]: count=%d labels=%s glyphs=%s"
				% [action, count, labels, glyphs]
			)
		)
	_log(
		(
			"origin count jump via device=%d via slot=%d; cycling glyph indices seen=%s"
			% [
				device.get_action_origin_count(_set, &"jump"),
				_slot.get_action_origin_count(_set, &"jump"),
				_glyph.seen
			]
		)
	)
	_glyph.seen.clear()


func _log(msg: String) -> void:
	var line := "[%7.2f] %s" % [Time.get_ticks_msec() / 1000.0, msg]
	print(line)
	_log_view.append_text(line.replace("[", "[lb]") + "\n")
	if _file:
		_file.store_line(line)
		_file.flush()
