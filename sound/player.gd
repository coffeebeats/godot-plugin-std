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

# -- PUBLIC METHODS ------------------------------------------------------------------ #

@warning_ignore("INT_AS_ENUM_WITHOUT_CAST")
@warning_ignore("INT_AS_ENUM_WITHOUT_MATCH")


## play instantiates and plays the provided sound event. The sound can be faded in using
## the provided fade parameters.
func play(
	event: StdSoundEvent,
	fade_in: float = 0.0,
	fade_transition: Tween.TransitionType = -1,
	fade_ease: Tween.EaseType = -1,
) -> StdSoundInstance:
	assert(event is StdSoundEvent, "invalid argument; wrong type")

	var player: Node = null
	var pool: StdObjectPool = null

	if event is StdSoundEvent:
		pool = pool_1d
		assert(pool is StdAudioStreamPlayerPool1D, "invalid state; missing pool")

		player = pool_1d.claim()
		assert(player is AudioStreamPlayer, "invalid state; missing player")

	if event is StdSoundEvent2D:
		pool = pool_2d
		assert(pool is StdAudioStreamPlayerPool2D, "invalid state; missing pool")

		player = pool_2d.claim()
		assert(player is AudioStreamPlayer2D, "invalid state; missing player")

	assert(player and pool, "invalid state; unrecognized event type")

	var instance := event.instantiate(player)
	instance.done.connect(pool.reclaim.bind(player), CONNECT_ONE_SHOT)

	instance.start(fade_in, fade_transition, fade_ease)

	return instance


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	assert(StdGroup.is_empty(GROUP_SOUND_PLAYER), "invalid state; duplicate node found")
	StdGroup.with_id(GROUP_SOUND_PLAYER).add_member(self)


func _exit_tree() -> void:
	StdGroup.with_id(GROUP_SOUND_PLAYER).remove_member(self)

	if pool_1d is StdAudioStreamPlayerPool1D:
		pool_1d.clear()
	if pool_2d is StdAudioStreamPlayerPool2D:
		pool_2d.clear()
