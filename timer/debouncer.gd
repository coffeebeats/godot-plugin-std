##
## std/timer/debouncer.gd
##
## Debouncer is a base class for nodes which want to debounce an operation.
##

@tool
extends Node

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Signals := preload("../event/signal.gd")
const Debounce := preload("debounce.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

## duration sets the minimum duration (in seconds) between stat store requests.
@export var duration: float = 5.0:
	set(value):
		duration = value
		if _debounce != null:
			_debounce.duration = value
			update_configuration_warnings()

## duration_max sets the maximum delay (in seconds) before a pending stat store request
## is sent to the statistics API.
@export var duration_max: float = 10.0:
	set(value):
		duration_max = value
		if _debounce != null:
			_debounce.duration_max = value
			update_configuration_warnings()

# -- INITIALIZATION ------------------------------------------------------------------ #

var _debounce: Debounce = null

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	Signals.connect_safe(child_exiting_tree, _on_self_child_exiting_tree)


func _exit_tree() -> void:
	assert(_debounce == null, "invalid state: found dangling Debounce timer")
	Signals.disconnect_safe(child_exiting_tree, _on_self_child_exiting_tree)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if not _debounce:
		return warnings

	assert(_debounce is Debounce, "invalid type: expected Debounce timer")

	if _debounce.duration != duration:
		warnings.append("Invalid config; expected valid 'duration' value!")
	if _debounce.duration_max != duration_max:
		warnings.append("Invalid config; expected valid 'duration_max' value!")

	return warnings


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	# Configure the 'Debounce' timer used to rate-limit statistics storage calls.
	assert(_debounce == null, "invalid state: found dangling Debounce timer")
	_debounce = _create_debounce_timer()
	add_child(_debounce, false, INTERNAL_MODE_FRONT)
	Signals.connect_safe(_debounce.timeout, _timeout)


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _timeout() -> void:
	pass


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _cancel() -> void:
	assert(_debounce is Debounce, "invalid state; missing debounce timer")
	_debounce.reset()


## Creates a 'Debounce' timer node configured for file system writes.
func _create_debounce_timer() -> Debounce:
	var out := Debounce.new()

	out.duration_max = duration_max
	assert(
		out.duration_max == duration_max,
		"Invalid config; expected '%f' to be '%f'!" % [out.duration_max, duration_max]
	)

	out.duration = duration
	assert(
		out.duration == duration,
		"Invalid config; expected '%f' to be '%f'!" % [out.duration, duration]
	)

	out.execution_mode = Debounce.EXECUTION_MODE_TRAILING
	out.process_callback = Timer.TIMER_PROCESS_IDLE
	out.timeout_on_tree_exit = true

	return out


func _start() -> void:
	assert(_debounce is Debounce, "invalid state; missing debounce timer")
	_debounce.start()


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_self_child_exiting_tree(node: Node) -> void:
	if node != _debounce:
		return

	# The debounce timer just flushed pending contents to disk, so the reference can be
	# safely cleaned up.
	_debounce = null
