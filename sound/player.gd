##
## std/sound/player.gd
##
## StdSoundEventPlayer is a singleton node which manages pools of audio players and uses
## them to play sound events.
##

class_name StdSoundEventPlayer
extends Node

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Signals := preload("../event/signal.gd")
const StdObjectPool := preload("pool.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

const GROUP_SOUND_PLAYER := &"std/sound:player"

# -- CONFIGURATION ------------------------------------------------------------------- #

## pool_1d is an object pool of `AudioStreamPlayer` nodes.
@export var pool_1d: StdAudioStreamPlayerPool1D = null

## pool_2d is an object pool of `AudioStreamPlayer2D` nodes.
@export var pool_2d: StdAudioStreamPlayerPool2D = null

# -- INITIALIZATION ------------------------------------------------------------------ #

static var _logger := StdLogger.create(&"std/sound/player")  # gdlint:ignore=class-definitions-order,max-line-length

var _active_instances: Dictionary[Node, StdSoundInstance] = {}
var _active_events: Dictionary[Node, StdSoundEvent] = {}

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## play instantiates and plays the provided sound event. Returns null if the pool is
## exhausted and no lower-priority sound can be stolen.
func play(
	event: StdSoundEvent,
	fade_curve: StdTweenCurve = null,
) -> StdSoundInstance:
	assert(event is StdSoundEvent, "invalid argument; wrong type")

	var pool: StdObjectPool = null

	if event is StdSoundEvent2D:
		pool = pool_2d
		assert(pool is StdAudioStreamPlayerPool2D, "invalid state; missing pool")
	elif event is StdSoundEvent:
		pool = pool_1d
		assert(pool is StdAudioStreamPlayerPool1D, "invalid state; missing pool")

	var player: Node = pool.claim()

	if not player:
		player = _steal(pool, event)

	if not player:
		_logger.warn("Pool exhausted; no stealable player found.")
		return null

	# NOTE: Ensure the player is fully stopped before reuse. The pool resets players on
	# reclaim, but engine timing can leave `playing` true briefly after a very short
	# stream completes.
	if player.playing:
		player.stop()

	var instance := event.instantiate(player)

	if instance.is_done():
		pool.reclaim(player)
		return null

	instance.done.connect(pool.reclaim.bind(player), CONNECT_ONE_SHOT)
	instance.done.connect(_on_instance_done.bind(player), CONNECT_ONE_SHOT)

	_active_instances[player] = instance
	_active_events[player] = event

	instance.start(fade_curve)

	return instance


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	assert(StdGroup.is_empty(GROUP_SOUND_PLAYER), "invalid state; duplicate node found")
	StdGroup.with_id(GROUP_SOUND_PLAYER).add_member(self)


func _exit_tree() -> void:
	StdGroup.with_id(GROUP_SOUND_PLAYER).remove_member(self)

	_active_instances.clear()
	_active_events.clear()

	if pool_1d is StdAudioStreamPlayerPool1D:
		pool_1d.clear()
	if pool_2d is StdAudioStreamPlayerPool2D:
		pool_2d.clear()


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _steal(pool: StdObjectPool, event: StdSoundEvent) -> Node:
	var is_1d: bool = pool is StdAudioStreamPlayerPool1D

	var lowest_priority: int = event.priority
	var steal_player: Node = null

	for p: Node in _active_events:
		if not (
			(is_1d and p is AudioStreamPlayer)
			or (not is_1d and p is AudioStreamPlayer2D)
		):
			continue

		if _active_events[p].priority < lowest_priority:
			lowest_priority = _active_events[p].priority
			steal_player = p

	if not steal_player:
		return null

	var victim: StdSoundInstance = _active_instances[steal_player]

	# NOTE: Stopping without fade emits done synchronously, triggering
	# `pool.reclaim` and `_on_instance_done` via connected signals.
	victim.stop()

	var claimed: Node = pool.claim()
	assert(claimed != null, "invalid state; reclaim did not free a slot")

	return claimed


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_instance_done(player: Node) -> void:
	_active_instances.erase(player)
	_active_events.erase(player)
