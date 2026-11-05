# gdlint:ignore=max-public-methods
# gdlint:disable=max-file-lines
##
## std/screen/panel_test.gd
##
## Tests pertaining to `StdPanel`, with its `StdInputCursorFocusScope` and loader, over
## a map pushed onto a `StdTestScreenManager`. The slot runs Godot's real action map, so
## a key reaches only the actions the loaded sets bind.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const DeviceActions := preload("../input/godot/device_actions.gd")
const SlotTest := preload("../input/slot_test.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

## _ACTION_CLOSE closes a panel; it's bound to Escape.
const _ACTION_CLOSE := &"panel_test_close"

## _ACTION_PAUSE pauses the map; it's bound to Escape.
const _ACTION_PAUSE := &"panel_test_pause"

## _ACTION_SELECT selects what the world was clicked on; it's bound to the left button.
const _ACTION_SELECT := &"panel_test_select"

## _ACTIONS_UI are the GUI's own actions, which every set here declares.
const _ACTIONS_UI: Array[StringName] = [&"ui_accept", &"ui_down", &"ui_up"]

## _PATH_PAUSE is where the pause menu's packed scene is cached.
const _PATH_PAUSE := "res://screen/_test_panel_pause.tscn"

## _PATH_PUSHER is where the pause pusher's packed scene is cached.
const _PATH_PUSHER := "res://screen/_test_panel_pusher.tscn"

## _PANEL_RECT is where each panel's control sits.
const _PANEL_RECT := Rect2(400, 200, 300, 200)


## _World stands in for a map's world, counting the pauses, closes and selections it
## receives.
class _World:
	extends Node

	var closed: int = 0
	var paused: int = 0
	var selected: int = 0

	func _unhandled_input(event: InputEvent) -> void:
		if event.is_action_pressed(_ACTION_CLOSE):
			closed += 1
		if event.is_action_pressed(_ACTION_PAUSE):
			paused += 1
		if event.is_action_pressed(_ACTION_SELECT):
			selected += 1


## _Opener opens `panel` from its own `_ready`, as a child of the panel's control.
class _Opener:
	extends Node

	var panel: StdPanel = null

	func _ready() -> void:
		panel.open()


# -- INITIALIZATION ------------------------------------------------------------------ #

## _cached holds the packed scenes cached by path, which the cache doesn't keep alive.
var _cached: Array[PackedScene] = []

var _cursor: StdInputCursor = null
var _gameplay: StdInputActionSet = null
var _hud: Button = null
var _input: StdTestInput = null
var _manager: StdTestScreenManager = null
var _map: Control = null
var _map_loader: StdInputActionSetLoader = null
var _menu: StdInputActionSet = null
var _pause: StdScreen = null
var _select_layer: StdInputActionSetLayer = null
var _slot: StdInputSlot = null
var _viewport_world: _World = null
var _world: _World = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_panel_escape_closes_the_panel_and_never_pauses(
	params = use_parameters([false, true])
) -> void:
	# Given: A map, with its panel before or after the map's loader in tree order.
	var panel := _add_panel(_map, params)
	await _mount()

	# When: The panel is opened.
	panel.open()

	# When: Escape is pressed.
	_press(KEY_ESCAPE)

	# Then: The panel is closed and the map isn't paused.
	assert_eq(panel.get_phase(), StdPanel.Phase.CLOSED)
	assert_eq(_world.paused, 0)

	# When: Escape is pressed again.
	_press(KEY_ESCAPE)

	# Then: The map is paused.
	assert_eq(_world.paused, 1)

	# When: The panel is opened.
	panel.open()

	# When: A pause menu is pushed and popped.
	await _push_and_pop_pause()

	# When: Escape is pressed.
	_press(KEY_ESCAPE)

	# Then: The panel is closed and the map isn't paused again.
	assert_eq(panel.get_phase(), StdPanel.Phase.CLOSED)
	assert_eq(_world.paused, 1)

	# When: Escape is pressed again.
	_press(KEY_ESCAPE)

	# Then: The map is paused, since its set is back.
	assert_eq(_world.paused, 2)
	assert_eq(_slot.actions.get_action_set(_slot.device_id), _gameplay)


func test_panel_listing_only_a_layer_takes_escape_from_the_pause_pusher() -> void:
	# Given: A panel which only adds a layer holding its close action to the map's set.
	var panel := _add_panel(_map)
	var loader := _find_loader(panel)
	loader.action_set = null
	loader.action_set_layers = (
		[_make_layer(&"PanelTestClose", _gameplay, [_ACTION_CLOSE])]
		as Array[StdInputActionSetLayer]
	)

	# Given: The map's screen carries a pusher which pushes the pause menu on pause.
	_pause.scene_path = _cache_pause_scene()
	await _mount(false, _cache_pusher_scene())
	panel.open()

	# When: Escape is pressed.
	_press(KEY_ESCAPE)
	await wait_process_frames(2)

	# Then: The panel is closed and nothing is paused.
	#
	# NOTE: A screen's attachments read a press before its scene, so this holds only
	# because the layer takes Escape from the pause action while it's enabled.
	assert_eq(panel.get_phase(), StdPanel.Phase.CLOSED)
	assert_eq(_manager.get_depth(), 2)
	assert_eq(_world.paused, 0)

	# When: Escape is pressed again.
	_press(KEY_ESCAPE)
	await wait_process_frames(2)

	# Then: The pusher pushes the pause menu, since the key is the map's again.
	assert_eq(_manager.get_depth(), 3)


func test_panel_two_panels_confine_to_the_later_and_return_to_the_earlier() -> void:
	# Given: Two panels listing one layer, with the cursor hidden.
	var shared := _make_layer(&"PanelTestShared", _menu, [])
	var first := _add_panel(_map)
	var second := _add_panel(_map)
	_find_loader(first).action_set_layers.append(shared)
	_find_loader(second).action_set_layers.append(shared)
	await _mount()
	_cursor.hide_cursor()

	# Given: The first panel is open with its second button focused.
	first.open()
	await wait_process_frames(1)
	_press(KEY_DOWN)
	var first_last := _find_buttons(first)[1]
	assert_eq(_focus_owner(), first_last)

	# When: The second panel opens.
	second.open()
	await wait_process_frames(1)

	# Then: Focus is confined to the second panel.
	assert_eq(_cursor.get_focus_root(), _control(second))
	assert_eq(_focus_owner(), _find_buttons(second)[0])

	# When: The second panel closes.
	second.close()
	await wait_process_frames(1)

	# Then: Focus returns to the first panel's last control, and the layer stays on.
	assert_eq(_cursor.get_focus_root(), _control(first))
	assert_eq(_focus_owner(), first_last)
	assert_has(_slot.list_action_set_layers(), shared)


func test_panel_opened_from_another_panels_button_closes_first() -> void:
	# Given: A parent panel holding a child panel, which opens from a parent's button.
	var parent := _add_panel(_map)
	parent.click_outside_to_close = MOUSE_BUTTON_MASK_LEFT
	var child := _add_panel(_control(parent))
	_control(child).position = Vector2(250, 50)
	_control(child).size = Vector2(140, 140)
	child.click_outside_to_close = MOUSE_BUTTON_MASK_LEFT
	await _mount()
	_cursor.hide_cursor()
	parent.open()
	await wait_process_frames(1)
	_find_buttons(parent)[0].pressed.connect(child.open)

	# When: The parent's button is pressed.
	_press(KEY_ENTER)
	await wait_process_frames(1)

	# Then: The child is open and holds focus.
	assert_eq(child.get_phase(), StdPanel.Phase.OPEN)
	assert_eq(_focus_owner(), _find_buttons(child)[0])

	# When: A button on the child, past the parent's edge, is clicked.
	var clicks := [0]
	_find_buttons(child)[1].pressed.connect(func() -> void: clicks[0] += 1)
	_cursor.show_cursor()
	_input.click(_find_buttons(child)[1])

	# Then: The button is pressed and both stay open.
	assert_eq(clicks[0], 1)
	assert_true(child.is_open())
	assert_true(parent.is_open())

	# When: Escape is pressed.
	_press(KEY_ESCAPE)

	# When: The cursor hides again.
	_cursor.hide_cursor()
	await wait_process_frames(1)

	# Then: Only the child is closed, and the parent regains focus.
	assert_eq(child.get_phase(), StdPanel.Phase.CLOSED)
	assert_true(parent.is_open())
	assert_true(_control(parent).is_ancestor_of(_focus_owner()))


func test_panel_child_open_in_a_closing_parent_releases_its_claim_and_set() -> void:
	# Given: A parent panel which fades, holding a child panel.
	var parent := _add_panel(_map)
	parent.transition = _make_fade(0.2)
	var child := _add_panel(_control(parent))
	await _mount()

	# Given: The cursor is hidden.
	_cursor.hide_cursor()
	var root := _cursor.get_focus_root()

	# Given: The parent is open.
	parent.open()
	await wait_for_signal(parent.opened, 1.0)

	# Given: The child is open inside it.
	child.open()
	await wait_process_frames(1)
	assert_eq(_cursor.get_focus_root(), _control(child))
	assert_eq(_slot.actions.get_action_set(_slot.device_id), _menu)

	# When: The parent starts to close.
	parent.close()
	await wait_process_frames(1)

	# Then: Mid-fade, the child is open but holds no claim, set or layer.
	assert_eq(parent.get_phase(), StdPanel.Phase.CLOSING)
	assert_true(child.is_open())
	assert_eq(_cursor.get_focus_root(), root)
	assert_eq(_slot.actions.get_action_set(_slot.device_id), _gameplay)
	assert_does_not_have(_slot.list_action_set_layers(), _select_layer)

	# When: The parent's close finishes.
	await wait_for_signal(parent.closed, 1.0)
	await wait_process_frames(1)

	# Then: The child is closed, and the map's set and the claim beneath stay.
	assert_eq(child.get_phase(), StdPanel.Phase.CLOSED)
	assert_eq(_cursor.get_focus_root(), root)
	assert_eq(_slot.actions.get_action_set(_slot.device_id), _gameplay)
	assert_does_not_have(_slot.list_action_set_layers(), _select_layer)


func test_panel_hidden_under_a_pause_closes_and_the_pop_restores_the_map() -> void:
	# Given: The HUD button focused under a hidden cursor.
	var panel := _add_panel(_map)
	await _mount()
	_cursor.hide_cursor()
	_hud.grab_focus()

	# Given: The panel is open.
	panel.open()
	await wait_process_frames(1)
	assert_true(_control(panel).is_ancestor_of(_focus_owner()))

	# When: A pause menu is pushed.
	await _push_pause()

	# When: The scene hides the panel.
	_control(panel).hide()

	# When: The pause menu is popped.
	_manager.pop()
	await wait_process_frames(2)

	# Then: The panel is closed and focus returns to the HUD button.
	assert_eq(panel.get_phase(), StdPanel.Phase.CLOSED)
	assert_eq(_focus_owner(), _hud)


func test_panel_left_open_under_a_pause_releases_its_claim_and_layers() -> void:
	# Given: An open panel which stays open when covered.
	var panel := _add_panel(_map)
	await _mount()
	panel.open()
	await wait_process_frames(1)

	# When: A pause menu is pushed.
	await _push_pause()

	# Then: The panel stays open without its claim or layers.
	assert_true(panel.is_open())
	assert_false(_control(panel).is_ancestor_of(_cursor.get_focus_root()))
	assert_does_not_have(_slot.list_action_set_layers(), _select_layer)

	# When: The menu is popped.
	_manager.pop()
	await wait_process_frames(2)

	# Then: The claim and layers are back, above the map's set.
	assert_eq(_cursor.get_focus_root(), _control(panel))
	assert_eq(_slot.actions.get_action_set(_slot.device_id), _menu)
	assert_has(_slot.list_action_set_layers(), _select_layer)


func test_panel_closing_when_covered_is_closed_on_uncover() -> void:
	# Given: An open panel which closes when covered.
	var panel := _add_panel(_map)
	panel.close_when_covered = true
	await _mount()
	panel.open()

	# When: A pause menu is pushed and popped.
	await _push_and_pop_pause()

	# Then: The panel is closed and the map's set is loaded.
	assert_eq(panel.get_phase(), StdPanel.Phase.CLOSED)
	assert_false(_control(panel).visible)
	assert_eq(_slot.actions.get_action_set(_slot.device_id), _gameplay)


func test_panel_mouse_under_a_hidden_cursor_releases_focus_and_stays_open() -> void:
	# Given: A panel closing on a click outside, whose layer holds the world's select.
	var panel := _add_panel(_map)
	panel.click_outside_to_close = MOUSE_BUTTON_MASK_LEFT
	await _mount()

	# Given: The panel is open and holds focus under a hidden cursor.
	_cursor.hide_cursor()
	panel.open()
	await wait_process_frames(1)
	assert_eq(_focus_owner(), _find_buttons(panel)[0])

	# When: The mouse moves.
	_input.move_mouse(Vector2(900, 600), Vector2(200, 200))

	# Then: Focus is released and the panel stays open.
	assert_true(_cursor.get_is_visible())
	assert_null(_focus_owner())
	assert_true(panel.is_open())

	# When: The cursor hides again.
	_cursor.hide_cursor()
	await wait_process_frames(1)

	# Then: Focus returns to the panel.
	assert_true(_control(panel).is_ancestor_of(_focus_owner()))

	# When: The world beside the panel is clicked.
	_cursor.show_cursor()
	_input.click_at(Vector2(900, 600))

	# Then: The panel is closed and the world selects.
	assert_eq(panel.get_phase(), StdPanel.Phase.CLOSED)
	assert_eq(_viewport_world.selected, 1)


func test_panel_click_on_a_hud_button_presses_it_and_closes_the_panel() -> void:
	# Given: An open panel which closes on a click outside.
	var panel := _add_panel(_map)
	panel.click_outside_to_close = MOUSE_BUTTON_MASK_LEFT
	await _mount()
	panel.open()
	await wait_process_frames(1)

	# When: The HUD button beside it is clicked.
	var clicks := [0]
	_hud.pressed.connect(func() -> void: clicks[0] += 1)
	_input.click(_hud)

	# Then: The button is pressed and the panel closed.
	assert_eq(clicks[0], 1)
	assert_eq(panel.get_phase(), StdPanel.Phase.CLOSED)


func test_panel_click_on_a_covering_screen_leaves_the_panel_open() -> void:
	# Given: An open panel which closes on a click outside and stays open when covered.
	var panel := _add_panel(_map)
	panel.click_outside_to_close = MOUSE_BUTTON_MASK_LEFT
	await _mount()
	panel.open()

	# Given: A pause menu is pushed over the map.
	await _push_pause()

	# When: The pause menu is clicked beside the panel.
	_input.click_at(Vector2(900, 600))

	# Then: The panel stays open.
	assert_true(panel.is_open())


func test_panel_call_during_a_transition_runs_once_it_finishes() -> void:
	# Given: A panel which fades.
	var panel := _add_panel(_map)
	panel.transition = _make_fade(0.2)
	await _mount()

	# When: It's closed while opening.
	panel.open()
	panel.close()

	# Then: The close waits for the open to finish.
	assert_eq(panel.get_phase(), StdPanel.Phase.OPENING)
	assert_eq(panel.get_intent(), StdPanel.Intent.CLOSE)
	await wait_for_signal(panel.opened, 1.0)
	assert_eq(panel.get_phase(), StdPanel.Phase.CLOSING)

	# When: It's opened while closing.
	panel.open()

	# Then: The open waits for the close to finish.
	assert_eq(panel.get_intent(), StdPanel.Intent.OPEN)
	await wait_for_signal(panel.closed, 1.0)
	assert_eq(panel.get_phase(), StdPanel.Phase.OPENING)
	await wait_for_signal(panel.opened, 1.0)
	assert_eq(panel.get_phase(), StdPanel.Phase.OPEN)


func test_panel_input_during_a_fade_reaches_nothing() -> void:
	# Given: A panel which fades, under a hidden cursor.
	var panel := _add_panel(_map)
	panel.transition = _make_fade(0.2)
	await _mount()
	_cursor.hide_cursor()
	_hud.grab_focus()
	var presses := [0]
	_find_buttons(panel)[0].pressed.connect(func() -> void: presses[0] += 1)
	var hud_presses := [0]
	_hud.pressed.connect(func() -> void: hud_presses[0] += 1)

	# When: It starts to open.
	panel.open()
	await wait_process_frames(2)

	# When: Enter and a click on its button land during the fade.
	_press(KEY_ENTER)
	_cursor.show_cursor()
	_input.click(_find_buttons(panel)[0])
	_cursor.hide_cursor()

	# Then: Nothing inside or behind it is pressed or focused.
	assert_eq(panel.get_phase(), StdPanel.Phase.OPENING)
	assert_eq(presses[0], 0)
	assert_eq(hud_presses[0], 0)
	assert_null(_focus_owner())

	# When: It has opened.
	await wait_for_signal(panel.opened, 1.0)
	await wait_process_frames(1)

	# When: Enter is pressed.
	_press(KEY_ENTER)

	# Then: The anchor is pressed.
	assert_eq(presses[0], 1)

	# When: It starts to close.
	panel.close()

	# When: A click on its button lands during the fade.
	_cursor.show_cursor()
	_input.click(_find_buttons(panel)[0])

	# Then: The button isn't pressed.
	assert_eq(panel.get_phase(), StdPanel.Phase.CLOSING)
	assert_eq(presses[0], 1)
	await wait_for_signal(panel.closed, 1.0)


func test_panel_opening_under_a_resting_mouse_hovers_its_button() -> void:
	# Given: A panel which fades, with the mouse resting where its button will be.
	var panel := _add_panel(_map)
	panel.transition = _make_fade(0.1)
	await _mount()
	var button := _find_buttons(panel)[0]
	_input.move_mouse(_PANEL_RECT.position + button.position + button.size / 2.0)

	# When: It opens.
	panel.open()
	await wait_for_signal(panel.opened, 1.0)
	await wait_process_frames(1)

	# Then: Its button is hovered.
	assert_true(button.is_hovered())


func test_panel_opened_from_a_childs_ready_takes_no_click_during_its_fade() -> void:
	# Given: A panel which fades and is opened from its control's child's `_ready`.
	var panel := _add_panel(_map)
	panel.transition = _make_fade(0.2)
	var opener := _Opener.new()
	opener.panel = panel
	_control(panel).add_child(opener)
	_control(panel).move_child(opener, 0)

	# When: The map is mounted.
	await _mount()

	# Then: The panel is opening.
	assert_eq(panel.get_phase(), StdPanel.Phase.OPENING)

	# When: Its button is clicked during the fade.
	var presses := [0]
	_find_buttons(panel)[0].pressed.connect(func() -> void: presses[0] += 1)
	_input.click(_find_buttons(panel)[0])

	# Then: The button isn't pressed.
	assert_eq(presses[0], 0)
	await wait_for_signal(panel.opened, 1.0)


func test_panel_control_freed_while_opening_releases_its_claim_and_layers() -> void:
	# Given: A panel which fades.
	var panel := _add_panel(_map)
	panel.transition = _make_fade(0.2)
	await _mount()
	var control := _control(panel)

	# Given: It's opening.
	panel.open()
	await wait_process_frames(1)
	assert_eq(_cursor.get_focus_root(), control)
	assert_has(_slot.list_action_set_layers(), _select_layer)

	# When: Its control is freed.
	control.free()
	await wait_process_frames(1)

	# Then: Its claim and layers are released, and the map's set is back.
	assert_ne(_cursor.get_focus_root(), control)
	assert_eq(_slot.actions.get_action_set(_slot.device_id), _gameplay)
	assert_does_not_have(_slot.list_action_set_layers(), _select_layer)


func test_panel_control_without_a_handler_behind_it_never_holds_focus() -> void:
	# Given: A focusable control without a handler below the panel.
	var bare := Button.new()
	bare.position = Vector2(_PANEL_RECT.position.x, _PANEL_RECT.end.y + 20)
	bare.size = Vector2(100, 40)
	_map.add_child(bare)
	var panel := _add_panel(_map)
	await _mount()

	# Given: The panel is open under a hidden cursor.
	_cursor.hide_cursor()
	panel.open()
	await wait_process_frames(1)

	# When: Down is pressed past the panel's last button.
	_press(KEY_DOWN)
	_press(KEY_DOWN)
	await wait_process_frames(1)

	# Then: Focus stays inside the panel.
	assert_true(_control(panel).is_ancestor_of(_focus_owner()))


func test_panel_runs_alike_without_a_manager(
	params = use_parameters([false, true])
) -> void:
	# Given: A map with a panel, mounted bare or onto the fixture.
	var panel := _add_panel(_map)
	await _mount(params)
	_cursor.hide_cursor()

	# When: The panel opens.
	panel.open()
	await wait_process_frames(1)

	# Then: It holds focus and its set.
	assert_eq(_focus_owner(), _find_buttons(panel)[0])
	assert_eq(_slot.actions.get_action_set(_slot.device_id), _menu)

	# When: Escape is pressed.
	_press(KEY_ESCAPE)
	await wait_process_frames(1)

	# Then: It's closed, with the map's set and focus back.
	assert_eq(panel.get_phase(), StdPanel.Phase.CLOSED)
	assert_eq(_slot.actions.get_action_set(_slot.device_id), _gameplay)
	assert_false(_control(panel).is_ancestor_of(_focus_owner()))


func test_panel_close_requested_cancelled_keeps_it_open() -> void:
	# Given: An open panel whose close requests are cancelled.
	var panel := _add_panel(_map)
	panel.close_requested.connect(func(_e: InputEvent, cancel: Callable): cancel.call())

	# Given: A probe which takes unhandled input after the panel.
	var probe := _World.new()
	_map.add_child(probe)
	_map.move_child(probe, 0)
	await _mount()
	panel.open()

	# When: Escape is pressed.
	_press(KEY_ESCAPE)

	# Then: It stays open, and the press never reaches a node behind it.
	assert_true(panel.is_open())
	assert_eq(probe.closed, 0)


func test_panel_follows_the_controls_visibility() -> void:
	# Given: A panel whose control is shown when it enters the tree.
	var panel := _add_panel(_map)
	_control(panel).show()
	await _mount()

	# Then: It starts open.
	assert_eq(panel.get_phase(), StdPanel.Phase.OPEN)

	# When: The map hides.
	_map.hide()

	# Then: It's closed and its control hidden, so showing the map leaves it closed.
	assert_eq(panel.get_phase(), StdPanel.Phase.CLOSED)
	assert_false(_control(panel).visible)
	_map.show()
	assert_eq(panel.get_phase(), StdPanel.Phase.CLOSED)

	# When: Its control is shown.
	_control(panel).show()

	# Then: It's open.
	assert_eq(panel.get_phase(), StdPanel.Phase.OPEN)


func test_panel_for_node_finds_the_nearest_panel() -> void:
	# Given: A panel holding another panel.
	var parent := _add_panel(_map)
	var child := _add_panel(_control(parent))
	await _mount()

	# Then: Each node finds the panel owning its nearest ancestor.
	assert_eq(StdPanel.for_node(_find_buttons(parent)[0]), parent)
	assert_eq(StdPanel.for_node(_find_buttons(child)[0]), child)
	assert_eq(StdPanel.for_node(_control(child)), child)
	assert_null(StdPanel.for_node(_hud))


# -- TEST HOOKS ---------------------------------------------------------------------- #


func after_each() -> void:
	# NOTE: The slot's action map rebinds `InputMap` for every action, so the project's
	# bindings are restored for the tests after this one.
	InputMap.load_from_project_settings()


func before_all() -> void:
	_bind(_ACTION_CLOSE, _make_key(KEY_ESCAPE))
	_bind(_ACTION_PAUSE, _make_key(KEY_ESCAPE))

	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	_bind(_ACTION_SELECT, click)


func before_each() -> void:
	_cached.clear()

	_gameplay = _make_set(&"PanelTestGameplay", [_ACTION_PAUSE, _ACTION_SELECT])
	_menu = _make_set(&"PanelTestMenu", [_ACTION_CLOSE])
	_select_layer = _make_layer(&"PanelTestSelect", _menu, [_ACTION_SELECT])

	_map = Control.new()
	_map.name = &"Map"
	_map.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var container := SubViewportContainer.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	var viewport := SubViewport.new()
	_viewport_world = _World.new()
	viewport.add_child(_viewport_world)
	container.add_child(viewport)
	_map.add_child(container)

	_hud = _make_button(Vector2(20, 20), true)
	_map.add_child(_hud)

	_world = _World.new()
	_map.add_child(_world)

	_map_loader = StdInputActionSetLoader.new()
	_map_loader.action_set = _gameplay
	_map.add_child(_map_loader)

	_pause = StdScreen.new()


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _add_panel adds a hidden panel to `parent`, with a scope, a loader holding the menu
## set and the select layer, and two buttons whose first is an anchor. With `first` set
## it goes before the map's loader in tree order.
func _add_panel(parent: Control, first: bool = false) -> StdPanel:
	var control := Control.new()
	control.name = &"Panel"
	control.position = _PANEL_RECT.position
	control.size = _PANEL_RECT.size
	control.hide()

	var panel := StdPanel.new()
	panel.close_actions = [_ACTION_CLOSE] as Array[StringName]
	control.add_child(panel)

	control.add_child(StdInputCursorFocusScope.new())

	var loader := StdInputActionSetLoader.new()
	loader.active_while = StdInputActionSetLoader.ActiveWhile.VISIBLE
	loader.action_set = _menu
	loader.action_set_layers = [_select_layer] as Array[StdInputActionSetLayer]
	control.add_child(loader)

	control.add_child(_make_button(Vector2(10, 10), true))
	control.add_child(_make_button(Vector2(10, 60), false))

	parent.add_child(control)
	if first:
		parent.move_child(control, _map_loader.get_index())

	return panel


## _bind defines `action` with `event` as its default binding.
func _bind(action: StringName, event: InputEvent) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	ProjectSettings.set_setting(
		&"input/" + action, {"deadzone": 0.5, "events": [event]}
	)


## _cache_pause_scene caches a pause menu's packed scene and returns its path.
func _cache_pause_scene() -> String:
	var scene := Control.new()
	scene.set_anchors_preset(Control.PRESET_FULL_RECT)

	var packed := PackedScene.new()
	packed.pack(scene)
	scene.free()
	packed.take_over_path(_PATH_PAUSE)
	_cached.append(packed)

	return _PATH_PAUSE


## _cache_pusher_scene caches the packed scene of a pusher which pushes the pause menu
## on the pause action, and returns its path.
func _cache_pusher_scene() -> String:
	var pusher := StdScreenPusher.new()
	pusher.screen = _pause
	pusher.push_actions = [_ACTION_PAUSE] as Array[StringName]

	var packed := PackedScene.new()
	packed.pack(pusher)
	pusher.free()
	packed.take_over_path(_PATH_PUSHER)
	_cached.append(packed)

	return _PATH_PUSHER


## _control returns the control `panel` opens.
func _control(panel: StdPanel) -> Control:
	return panel.get_parent() as Control


## _find_buttons returns the buttons directly under `panel`'s control.
func _find_buttons(panel: StdPanel) -> Array[Button]:
	var buttons: Array[Button] = []
	for child in _control(panel).get_children():
		if child is Button:
			buttons.append(child)
	return buttons


## _find_loader returns the loader under `panel`'s control.
func _find_loader(panel: StdPanel) -> StdInputActionSetLoader:
	for child in _control(panel).get_children():
		if child is StdInputActionSetLoader:
			return child
	return null


## _focus_owner returns the control holding focus.
func _focus_owner() -> Control:
	return get_viewport().gui_get_focus_owner()


## _make_button returns a button at `position` with a focus handler, an anchor if
## `anchor` is set.
func _make_button(position: Vector2, anchor: bool) -> Button:
	var button := Button.new()
	button.position = position
	button.size = Vector2(100, 40)

	var handler := StdInputCursorFocusHandler.new()
	handler.use_as_anchor = anchor
	button.add_child(handler)

	return button


## _make_fade returns a fade lasting `duration` seconds each way.
func _make_fade(duration: float) -> StdTransitionFade:
	var fade := StdTransitionFade.new()
	fade.curve = StdTweenCurve.new()
	fade.curve.duration = duration
	return fade


## _make_key returns a binding of `keycode`.
func _make_key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	return event


## _make_layer returns a layer called `id` under `parent` declaring `actions`.
func _make_layer(
	id: StringName, parent: StdInputActionSet, actions: Array[StringName]
) -> StdInputActionSetLayer:
	var layer := StdInputActionSetLayer.new()
	layer.name = id
	layer.parent = parent
	layer.actions_digital = actions
	return layer


## _make_set returns a set called `id` declaring `actions` and the GUI's actions.
func _make_set(id: StringName, actions: Array[StringName]) -> StdInputActionSet:
	var action_set := StdInputActionSet.new()
	action_set.name = id
	action_set.actions_digital = actions + _ACTIONS_UI
	return action_set


## _mount mounts the slot and the map, onto a screen manager unless `bare` is set, with
## the scene at `attachment` attached if set, and returns once the map's loader has
## synced.
func _mount(bare: bool = false, attachment: String = "") -> void:
	_slot = SlotTest.make_slot()

	var scope := StdSettingsScope.new()
	scope.is_loaded = true

	var actions := DeviceActions.new()
	actions.scope = scope

	for component in [_slot.actions_kbm, _slot.actions_joy]:
		_slot.remove_child(component)
		component.free()
	_slot.actions_kbm = actions
	_slot.actions_joy = actions
	_slot.add_child(actions)
	_slot.prefer_activate_joypad_on_ready = false

	_cursor = _slot.cursor

	var root := Node.new()
	root.add_child(_slot)

	if bare:
		root.add_child(_map)
	else:
		_manager = StdTestScreenManager.new()
		root.add_child(_manager)

	_input = await StdTestInput.mount(self, root)
	autofree(_slot.get_active_device())

	if not bare:
		var screen := StdScreen.new()
		if attachment:
			screen.attachment_scenes = PackedStringArray([attachment])
		await _manager.push_and_wait(screen, _map, StdTransition.new())

	await wait_process_frames(1)


## _press presses and releases `keycode`.
func _press(keycode: Key) -> void:
	_input.press_key(keycode)
	_input.release_key(keycode)


## _push_and_pop_pause pushes the pause menu and pops it.
func _push_and_pop_pause() -> void:
	await _push_pause()
	_manager.pop()
	await wait_process_frames(2)


## _push_pause pushes a pause menu, whose loader holds a set of its own.
func _push_pause() -> void:
	var scene := Control.new()
	scene.set_anchors_preset(Control.PRESET_FULL_RECT)

	var loader := StdInputActionSetLoader.new()
	loader.action_set = _make_set(&"PanelTestPause", [])
	scene.add_child(loader)
	scene.add_child(_make_button(Vector2(600, 600), true))

	await _manager.push_and_wait(_pause, scene, StdTransition.new())
