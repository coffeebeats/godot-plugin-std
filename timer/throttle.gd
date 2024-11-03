##
## std/timer/throttle.gd
##
## A utility class which manages a "throttle" effect: repeated calls to 'start' will be
## dropped if they occur less than 'duration' seconds since the last call to 'start'.
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

const MICROSECONDS_PER_SECOND := 1e6

# -- CONFIGURATION ------------------------------------------------------------------- #

@export_category("Throttle")

## Sets the "throttle" effect duration in seconds. This controls how long of a duration
## 'start' must not be called (since the last call to 'start') until the 'timeout'
## signal is emitted.
@export var duration: float = 0.0:
	set(value):
		duration = value
		if Engine.is_editor_hint():
			update_configuration_warnings()

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

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## Returns whether the "throttle" effect is active; when 'false', the next call to
## 'start' is able to execute immediately.
func is_throttled() -> bool:
	assert(is_inside_tree(), "Invalid usage; 'Node' is not in the 'SceneTree'!")
	assert(_remaining_micros >= 0, "Invalid config; expected a value >= 0!")

	return _remaining_micros > 0


## Resets this 'Throttle' instance, clearing any history of prior "executions".
func reset() -> void:
	assert(is_inside_tree(), "Invalid usage; 'Node' is not in the 'SceneTree'!")
	assert(_remaining_micros >= 0, "Invalid config; expected a value >= 0!")

	_remaining_micros = 0


## Attempts an "execution", returning 'true' if one occurred. Repeated calls to 'start'
## for the subsequent 'duration' seconds will return 'false'.
func start() -> bool:
	assert(is_inside_tree(), "Invalid usage; 'Node' is not in the 'SceneTree'!")
	assert(_remaining_micros >= 0, "Invalid config; expected a value >= 0!")

	var is_ready := _remaining_micros == 0
	if is_ready:
		_remaining_micros = int(duration * MICROSECONDS_PER_SECOND)

	return is_ready


## Manually advance the timer by the specified amount (in seconds). If the timer was
## already stopped, then this is a no-op.
##
## NOTE: This will be called automatically by the engine in processing functions, unless
## 'process_mode' is set to 'PROCESS_MODE_DISABLED'. This configuration can be used to
## manually control the internal timing of this 'Node', for example if high-resolution
## timing is needed within a process loop.
func tick(delta: float) -> void:
	assert(_remaining_micros >= 0, "Invalid config; expected a value >= 0!")

	# Nothing needs doing.
	if _remaining_micros == 0:
		return

	_remaining_micros = max(_remaining_micros - int(delta * MICROSECONDS_PER_SECOND), 0)

	if _remaining_micros == 0:
		timeout.emit()


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _get_configuration_warnings() -> PackedStringArray:
	var out := PackedStringArray()

	if duration == 0.0:
		out.append("Missing value 'duration'; no debouncing will occur.")

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
