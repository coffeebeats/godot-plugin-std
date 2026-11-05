##
## std/screen/panel.gd
##
## StdPanel is a node which opens and closes the `Control` at `control` over a running
## scene, such as a build or context menu, which a `StdScreen` would cover. It runs the
## control's transition, closes it on `close_actions` and on a click outside it, and
## follows its visibility, so a scene run alone needs no `StdScreenManager`.
##
## Nothing inside the control takes focus while it opens or closes, since its
## `focus_behavior_recursive` is disabled until `opened` and from `closing` on. A
## `StdInputCursorFocusScope` confines focus to the control, and a
## `StdInputActionSetLoader` set to `VISIBLE` holds what stays live, both while the
## panel and every panel around it are opening or open.
##
## NOTE: A call during a transition is recorded as the intent and runs once the
## transition finishes; nothing interrupts a transition. Two panels that overlap in time
## are two nodes.
##

class_name StdPanel
extends Node

# -- SIGNALS ------------------------------------------------------------------------- #

## opening is emitted when the panel starts to open, before its transition starts.
signal opening

## opened is emitted when the panel's open transition finishes.
signal opened

## closing is emitted when the panel starts to close, before its transition starts.
signal closing

## closed is emitted when the panel's close transition finishes.
signal closed

## close_requested is emitted when a close action or a click outside requests a close.
## Call `cancel.call()` from any handler to keep the panel open.
signal close_requested(event: InputEvent, cancel: Callable)

# -- DEFINITIONS --------------------------------------------------------------------- #

## Phase names where the panel is in its lifecycle.
enum Phase {
	CLOSED,  ## Hidden, and taking no input.
	OPENING,  ## Running its open transition; nothing inside takes input.
	OPEN,  ## Shown and taking input.
	CLOSING,  ## Running its close transition; nothing inside takes input.
}

## Intent names the call recorded during a transition, run once it finishes.
enum Intent {
	NONE,  ## No call is pending.
	OPEN,  ## `open` runs once the panel has closed.
	CLOSE,  ## `close` runs once the panel has opened.
}


## _Context is a transition context which marks the visibility changes its transition
## makes, so that the panel tells them apart from a game's.
class _Context:
	extends StdTransitionContext

	var panel: StdPanel = null

	func _mount() -> void:
		panel._is_transition_changing_visibility = true
		super()
		panel._is_transition_changing_visibility = false

	func _unmount() -> void:
		panel._is_transition_changing_visibility = true
		super()
		panel._is_transition_changing_visibility = false


# -- CONFIGURATION ------------------------------------------------------------------- #

## control is a path to the `Control` node this panel opens and closes.
@export var control: NodePath = NodePath("..")

@export_group("Transition")

## transition is the default transition for opening and closing the control. Without
## one, the panel opens and closes instantly.
@export var transition: StdTransition

@export_subgroup("Overrides")

## transition_open overrides `transition` for opening.
@export var transition_open: StdTransition

## transition_close overrides `transition` for closing.
@export var transition_close: StdTransition

@export_group("Input")

## close_actions are input actions that request a close while the panel is opening or
## open. A press no node inside took is marked handled, as a screen's is.
@export var close_actions: Array[StringName] = []

## click_outside_to_close is a bitmask of mouse buttons whose press outside the
## control's rect, on nothing inside the control, requests a close while the panel is
## opening or open and uncovered. The press goes on to whatever it lands on, so a HUD
## button beside the panel closes it and presses, and the world selects what was hit.
@export_flags("Left:1", "Right:2", "Middle:4") var click_outside_to_close: int = 0

@export_group("Visibility")

## close_on_hide closes the panel at once, stopping any transition, when the control is
## hidden by anything other than the panel, including a hidden ancestor.
@export var close_on_hide: bool = true

## open_on_show opens the panel at once when the control is shown by anything other than
## the panel.
@export var open_on_show: bool = true

## close_when_covered closes the panel at once when a screen covers its scene. Otherwise
## it stays open, and what it holds is released until the scene is uncovered.
@export var close_when_covered: bool = false

@export_group("Sound")

## sound_open is played when `open` starts the open transition.
@export var sound_open: StdSoundEvent

## sound_close is played when `close` starts the close transition.
@export var sound_close: StdSoundEvent

# -- INITIALIZATION ------------------------------------------------------------------ #

## NOTIFICATION_PANEL_PHASE_CHANGED is propagated to the control's subtree each time the
## panel's phase changes.
static var NOTIFICATION_PANEL_PHASE_CHANGED: int = (1 << 24) + 3  # gdlint:ignore=class-definitions-order,class-variable-name,max-line-length

## _panels maps each control in the tree with a panel to that panel.
static var _panels: Dictionary[Control, StdPanel] = {}  # gdlint:ignore=class-definitions-order,max-line-length

var _control: Control = null

## _covered is whether another screen covers the one holding this panel.
var _covered: bool = false

## _focus_behavior is the control's `focus_behavior_recursive` as authored, which the
## panel restores once a transition finishes.
var _focus_behavior := Control.FOCUS_BEHAVIOR_INHERITED

var _intent: Intent = Intent.NONE
var _intent_transition: StdTransition = null

## _is_transition_changing_visibility is whether the running transition is showing or
## hiding the control, so the change isn't taken as a game's.
var _is_transition_changing_visibility: bool = false

var _phase: Phase = Phase.CLOSED

## _transition is the duplicate of the transition being run, held until it finishes,
## since `stop` needs it and nothing else keeps it alive.
var _transition: StdTransition = null

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## for_node returns the panel owning `node` or its nearest ancestor that a panel owns,
## or null if there is none.
static func for_node(node: Node) -> StdPanel:
	while node:
		var owned := node as Control
		if owned and _panels.has(owned):
			return _panels[owned]
		node = node.get_parent()

	return null


## is_node_open returns whether every panel owning `node` or an ancestor is opening or
## open, or true if there is none. A child panel inside a closing parent is not.
static func is_node_open(node: Node) -> bool:
	while node:
		var owned := node as Control
		if owned and _panels.has(owned) and not _panels[owned].is_open():
			return false
		node = node.get_parent()

	return true


## close starts the close transition, using `transition_override` in place of the
## configured one if set. While the panel opens, the close runs once it has opened.
func close(transition_override: StdTransition = null) -> void:
	assert(is_inside_tree(), "invalid state; not in the tree")

	match _phase:
		Phase.OPEN:
			_start(Phase.CLOSING, transition_override)
		Phase.OPENING:
			_set_intent(Intent.CLOSE, transition_override)
		_:
			_set_intent(Intent.NONE)


## get_intent returns the call recorded to run once the current transition finishes.
func get_intent() -> Intent:
	return _intent


## get_phase returns where the panel is in its lifecycle.
func get_phase() -> Phase:
	return _phase


## is_open returns whether the panel is opening or open.
func is_open() -> bool:
	return _phase == Phase.OPENING or _phase == Phase.OPEN


## open starts the open transition, using `transition_override` in place of the
## configured one if set. While the panel closes, the open runs once it has closed, and
## before the control is ready, once it is.
func open(transition_override: StdTransition = null) -> void:
	assert(is_inside_tree(), "invalid state; not in the tree")

	match _phase:
		Phase.CLOSED:
			# NOTE: An input blocker can't be added while the control sets up children.
			if _control.is_node_ready():
				_start(Phase.OPENING, transition_override)
				return

			_set_intent(Intent.OPEN, transition_override)
			if not _control.ready.is_connected(_apply_intent):
				_control.ready.connect(_apply_intent, CONNECT_ONE_SHOT)
		Phase.CLOSING:
			_set_intent(Intent.OPEN, transition_override)
		_:
			_set_intent(Intent.NONE)


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	_control = get_node(control) as Control
	assert(_control is Control, "invalid config; missing control")
	assert(not _panels.has(_control), "invalid config; control has another panel")

	_panels[_control] = self
	_focus_behavior = _control.focus_behavior_recursive
	_phase = Phase.OPEN if _control.is_visible_in_tree() else Phase.CLOSED

	_control.visibility_changed.connect(_on_control_visibility_changed)


func _exit_tree() -> void:
	_stop_transition()
	_set_intent(Intent.NONE)

	if _control.ready.is_connected(_apply_intent):
		_control.ready.disconnect(_apply_intent)

	_control.visibility_changed.disconnect(_on_control_visibility_changed)
	_control.focus_behavior_recursive = _focus_behavior
	_panels.erase(_control)

	_phase = Phase.CLOSED


# NOTE: A press is read before the GUI takes it, since a screen's overlay and a map's
# `SubViewportContainer` stop every click on the world from reaching unhandled input.
func _input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if (
		mb
		and mb.pressed
		and (1 << (mb.button_index - 1)) & click_outside_to_close
		and is_open()
		and not _covered
		and not _is_over_control(mb)
	):
		_request_close(event)


func _notification(what: int) -> void:
	match what:
		StdScreenManager.NOTIFICATION_SCREEN_COVERED:
			_covered = true
			if close_when_covered and _phase != Phase.CLOSED:
				_close_now()
		StdScreenManager.NOTIFICATION_SCREEN_UNCOVERED:
			_covered = false


func _unhandled_input(event: InputEvent) -> void:
	if not is_open():
		return

	for action in close_actions:
		if event.is_action_pressed(action):
			get_viewport().set_input_as_handled()
			_request_close(event)
			return


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _apply_intent runs the recorded call and clears it.
func _apply_intent() -> void:
	var intent := _intent
	var transition_override := _intent_transition
	_set_intent(Intent.NONE)

	match intent:
		Intent.OPEN:
			open(transition_override)
		Intent.CLOSE:
			close(transition_override)


## _close_now closes the panel without a transition, stopping any that's running, and
## hides the control if it's still shown under a hidden ancestor.
func _close_now() -> void:
	_stop_transition()
	_set_intent(Intent.NONE)

	if _control.visible:
		_is_transition_changing_visibility = true
		_control.hide()
		_is_transition_changing_visibility = false

	if _phase != Phase.CLOSING:
		_enter_phase(Phase.CLOSING)
	_enter_phase(Phase.CLOSED)


## _enter_phase moves the panel to `phase`, keeps focus out of the control while a
## transition runs, tells the control's subtree and emits the phase's signal.
func _enter_phase(phase: Phase) -> void:
	_phase = phase

	var is_settled := phase == Phase.OPEN or phase == Phase.CLOSED
	_control.focus_behavior_recursive = (
		_focus_behavior if is_settled else Control.FOCUS_BEHAVIOR_DISABLED
	)

	_control.propagate_notification(NOTIFICATION_PANEL_PHASE_CHANGED)

	match phase:
		Phase.OPENING:
			opening.emit()
		Phase.OPEN:
			_refresh_hover()
			opened.emit()
		Phase.CLOSING:
			closing.emit()
		Phase.CLOSED:
			closed.emit()


## _find_cursor returns the `StdInputCursor`, or null if there is none.
func _find_cursor() -> StdInputCursor:
	if StdGroup.is_empty(StdInputCursor.GROUP_INPUT_CURSOR):
		return null

	return StdGroup.get_sole_member(StdInputCursor.GROUP_INPUT_CURSOR)


## _force_hover_recalculation sends a motion at the mouse's position, so that a control
## shown under a resting mouse is hovered without waiting for it to move.
func _force_hover_recalculation() -> void:
	if not is_inside_tree():
		return

	StdInputEvent.refresh_hover(get_viewport())


## _is_over_control returns whether `event` lands inside the control's rect or on a
## control inside it, such as a child panel reaching past its edge.
func _is_over_control(event: InputEventMouseButton) -> bool:
	var local := _control.make_input_local(event) as InputEventMouseButton
	if Rect2(Vector2.ZERO, _control.size).has_point(local.position):
		return true

	# NOTE: The viewport updates its hovered control for a press before `_input` runs,
	# with or without a motion first, so it's the control the press lands on.
	var target := get_viewport().gui_get_hovered_control()
	return target != null and _control.is_ancestor_of(target)


## _open_now opens the panel without a transition.
func _open_now() -> void:
	_set_intent(Intent.NONE)
	_enter_phase(Phase.OPENING)
	_enter_phase(Phase.OPEN)


## _play_sound plays `event` through the `StdSoundEventPlayer`, if there is one.
func _play_sound(event: StdSoundEvent) -> void:
	if not event or StdGroup.is_empty(StdSoundEventPlayer.GROUP_SOUND_PLAYER):
		return

	var player: StdSoundEventPlayer = StdGroup.get_sole_member(
		StdSoundEventPlayer.GROUP_SOUND_PLAYER
	)
	player.play(event)


## _refresh_hover hovers the control under a resting mouse while the cursor shows.
func _refresh_hover() -> void:
	var cursor := _find_cursor()
	if cursor and cursor.get_is_visible():
		_force_hover_recalculation.call_deferred()


## _request_close emits `close_requested` and closes the panel unless a handler cancels.
func _request_close(event: InputEvent) -> void:
	# NOTE: An array, since a lambda can't rebind a local.
	var cancelled := [false]
	close_requested.emit(event, func() -> void: cancelled[0] = true)

	if not cancelled[0]:
		close()


## _set_intent records `intent` with its transition override.
func _set_intent(intent: Intent, transition_override: StdTransition = null) -> void:
	_intent = intent
	_intent_transition = transition_override


## _start moves the panel to `phase`, `OPENING` or `CLOSING`, and runs the transition.
func _start(phase: Phase, transition_override: StdTransition) -> void:
	var is_opening := phase == Phase.OPENING

	var resolved := transition_override
	if not resolved:
		resolved = transition_open if is_opening else transition_close
	if not resolved:
		resolved = transition

	if resolved:
		_transition = resolved.duplicate()
	else:
		_transition = StdTransition.new()
		_transition.block_input = false

	var context := _Context.new(_control)
	context.panel = self
	if is_opening:
		context.entering = _control
	else:
		context.exiting = _control
	context.finished.connect(_on_transition_finished, CONNECT_ONE_SHOT)

	_enter_phase(phase)
	_play_sound(sound_open if is_opening else sound_close)

	# NOTE: An instant transition finishes inside this call, so nothing may follow it.
	if is_opening:
		_transition.enter(context)
	else:
		_transition.exit(context)


## _stop_transition stops the running transition, if any, without finishing it.
func _stop_transition() -> void:
	if _transition:
		_transition.stop()
		_transition = null


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_control_visibility_changed() -> void:
	if _is_transition_changing_visibility:
		return

	if _control.is_visible_in_tree():
		if open_on_show and _phase == Phase.CLOSED:
			_open_now()
	elif close_on_hide and _phase != Phase.CLOSED:
		_close_now()


func _on_transition_finished() -> void:
	_transition = null
	_enter_phase(Phase.OPEN if _phase == Phase.OPENING else Phase.CLOSED)
	_apply_intent()
