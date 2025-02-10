##
## std/sound/event_1d.gd
##
## StdSoundEvent1D is a description of a non-positional sound, like UI effects or
## background music.
##

class_name StdSoundEvent1D
extends StdSoundEvent

# -- CONFIGURATION ------------------------------------------------------------------- #

@export_subgroup("Player")

## mix_target sets the `mix_target` property on the associated `AudioStreamPlayer`.
@export var mix_target: AudioStreamPlayer.MixTarget = AudioStreamPlayer.MIX_TARGET_STEREO

## pitch_scale sets the `pitch_scale` property on the associated `AudioStreamPlayer`.
@export var pitch_scale: float = 1.0

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _configure(player: AudioStreamPlayer) -> void:
	assert(player is AudioStreamPlayer)
	assert(player.is_inside_tree())

	player.autoplay = false
	player.bus = bus.get_bus_name()
	player.max_polyphony = 1
	player.mix_target = mix_target
	player.pitch_scale = pitch_scale
	player.playback_type = AudioServer.PLAYBACK_TYPE_DEFAULT
	player.playing = false
	player.stream = stream
	player.stream_paused = false
	player.volume_db = volume_db
