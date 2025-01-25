##
## std/timer/debounce.gd
##
## A utility class (with an API similar to 'Timer') which manages a "debounce" effect:
## repeated calls to 'start' will restart the internal 'Timer' by the configured
## 'duration' amount. Only when 'duration' has elapsed since the last 'start' call will
## the 'timeout' signal trigger.
##
## NOTE: This is effectively clustering 'start' calls into batches, where the 'timeout'
## signal is only triggered once per cluster.
##
## NOTE: By default, this class cannot provide high-resolution timing due to its
## reliance on idle or physics frames for advancing its timer. However, if 'process'
## is set to 'PROCCESS_MODE_DISABLED', then this class can be manually controlled via
## its public 'tick' method. High-resolution timing (e.g. in a for loop) would then be
## possible.
##

@tool
extends Node

# -- SIGNALS ------------------------------------------------------------------------- #

## Emitted when "execution" is ready, following a call to 'start'.
signal timeout

# -- DEFINITIONS --------------------------------------------------------------------- #

## Defines when "execution" occurs for the debounce effect. For 'LEADING', "execution"
## is at the start of a cluster; 'TRAILING' "execution" is at the end of a cluster.
enum ExecutionMode {LEADING, TRAILING}

const EXECUTION_MODE_LEADING := ExecutionMode.LEADING

const EXECUTION_MODE_TRAILING := ExecutionMode.TRAILING

const MICROSECONDS_PER_SECOND := 1e6

# -- CONFIGURATION ------------------------------------------------------------------- #

@export_category("Debounce")

## Sets the "debounce" effect duration. This controls how long of a duration 'start'
## must not be called (since the last call to 'start') until the 'timeout' signal is
## emitted.
@export var duration: float = 0.0:
	set(value):
		duration = value
		if Engine.is_editor_hint():
			update_configuration_warnings()

## Sets the maximum duration for a debounce effect. This ensures that even when there
## are repeated calls to 'start' continuing the debounce cluster, the effect will be
## reset after this duration.
##
## NOTE: This value must be greater than the 'duration' value. If the value is `0`, then
## that will be treated as `INF`.
@export var duration_max: float = INF:
	set(value):
		# NOTE: Due to a Godot engine bug [1], this value will be overwritten to `0` by
		# the inspector. Catch these cases and set to `INF`, despite `0` technically
		# being a valid value (why use a debounce timer in that case, though).
		#
		# [1] https://github.com/godotengine/godot/issues/88006
		duration_max = value if value > 0 else INF
		if Engine.is_editor_hint():
			update_configuration_warnings()

@export_group("Behavior")

## Sets the "debounce" effect to use a "leading" edge pattern, meaning that 'Timeout'
## will be triggered immediately on the first call to 'start', but subsequent calls
## occuring within the last 'duration' seconds since the prior 'start' call get dropped.
@export var execution_mode := EXECUTION_MODE_TRAILING:
	set(value):
		assert(value is ExecutionMode, "Invalid argument; expected an 'ExecutionMode'!")
		assert(
			not is_inside_tree() or not is_debounced(),
			"Invalid usage; do not modify while 'Timer' is running!"
		)

		execution_mode = value

## Whether to trigger a 'Timeout' (potentially ahead of schedule) if this 'Node' is
## removed from the 'SceneTree'.
@export var timeout_on_tree_exit := false

# NOTE: Insert a space to avoid overwriting global 'Timer' variable.
@export_category("Timer ")

## Determines whether the internal timer is advanced during physics or render frames.
@export var process_callback: Timer.TimerProcessCallback = Timer.TIMER_PROCESS_IDLE:
	set(value):
		process_callback = value
		match value:
			Timer.TIMER_PROCESS_IDLE:
				set_process(true)
				set_physics_process(false)
			Timer.TIMER_PROCESS_PHYSICS:
				set_process(false)
				set_physics_process(true)

# -- INITIALIZATION ------------------------------------------------------------------ #

## The remaining duration of the internal timer (in microseconds).
var _remaining_micros: int = 0

## The elapsed time (in microseconds) since the start of the current 'debounce' effect.
var _elapsed_micros: int = 0

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## Returns whether the "debounce" effect is active; when 'false', there have been no
## prior calls to 'start' in the last 'duration' seconds.
func is_debounced() -> bool:
	assert(is_inside_tree(), "Invalid usage; 'Node' is not in the 'SceneTree'!")
	assert(_remaining_micros >= 0, "Invalid config; expected a value >= 0!")

	return _remaining_micros > 0


## Resets this 'Debounce' instance, clearing any history of prior "executions".
func reset() -> void:
	assert(is_inside_tree(), "Invalid usage; 'Node' is not in the 'SceneTree'!")
	assert(_remaining_micros >= 0, "Invalid config; expected a value >= 0!")

	_elapsed_micros = 0
	_remaining_micros = 0


## Starts the internal 'Timer' node, triggering a 'timeout' signal emission after
## 'duration' seconds. If 'start' is called again before that time has elapsed, then
## the 'Timer' is reset from the point of the second 'start' call.
func start() -> void:
	assert(is_inside_tree(), "Invalid usage; 'Node' is not in the 'SceneTree'!")
	assert(_remaining_micros >= 0, "Invalid config; expected a value >= 0!")
	assert(
		duration_max > duration, "Invalid config; expected 'duration_max' > 'duration'!"
	)

	var is_emit_needed := (
		execution_mode == EXECUTION_MODE_LEADING and _remaining_micros == 0
	)

	_remaining_micros = int(duration * MICROSECONDS_PER_SECOND)

	if is_emit_needed:
		emit_signal(timeout.get_name())


## Manually advance the timer by the specified amount (in seconds), triggering a
## 'timeout' signal emission if the timer completes. If the timer was already stopped,
## then this is a no-op.
##
## NOTE: This will be called automatically by the engine in processing functions, unless
## 'process_mode' is set to 'PROCESS_MODE_DISABLED'. This configuration can be used to
## manually control the internal timing of this 'Node', for example if high-resolution
## timing is needed within a process loop.
func tick(delta: float) -> void:
	assert(delta >= 0, "Invalid argument; expected a value >= 0!")
	assert(_remaining_micros >= 0, "Invalid config; expected a value >= 0!")

	# Nothing needs doing.
	if _remaining_micros == 0:
		return

	var tick_micros := int(delta * MICROSECONDS_PER_SECOND)

	_elapsed_micros += tick_micros
	_remaining_micros = max(_remaining_micros - tick_micros, 0)

	if (
		_remaining_micros == 0
		or (_elapsed_micros >= int(duration_max * MICROSECONDS_PER_SECOND))
	):
		_elapsed_micros = 0
		_remaining_micros = 0

		if execution_mode == EXECUTION_MODE_TRAILING:
			timeout.emit()


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _exit_tree() -> void:
	if (
		timeout_on_tree_exit
		and execution_mode == EXECUTION_MODE_TRAILING
		and _remaining_micros > 0
	):
		timeout.emit()


func _get_configuration_warnings() -> PackedStringArray:
	var out := PackedStringArray()

	if duration == 0.0:
		out.append("Missing value 'duration'; no debouncing will occur.")

	if duration_max <= duration:
		out.append("Value 'duration_max' must be greater than 'duration'.")

	return out


func _notification(what):
	match what:
		NOTIFICATION_ENTER_TREE, NOTIFICATION_EXIT_TREE:
			_remaining_micros = 0


func _physics_process(delta: float) -> void:
	assert(
		not is_processing() and not is_processing_internal(),
		"Invalid config; detected double-processing!"
	)
	tick(delta)


func _process(delta: float) -> void:
	assert(
		not is_physics_processing() and not is_physics_processing_internal(),
		"Invalid config; detected double-processing!"
	)
	tick(delta)


func _ready():
	# NOTE: Calls to 'set_process' and 'set_physics_process' are ignored prior to
	# '_ready', so manually run it again via the 'process_callback' setter.
	process_callback = process_callback
