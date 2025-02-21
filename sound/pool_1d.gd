##
## std/sound/pool_1d.gd
##
## StdAudioStreamPlayerPool1D is an object pool of `AudioStreamPlayer` nodes.
##

class_name StdAudioStreamPlayerPool1D
extends "pool.gd"

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _create_object() -> Variant:
	var player := AudioStreamPlayer.new()
	add_child(player, false)

	return player


func _destroy_object(object: Variant) -> void:
	var player: AudioStreamPlayer = object
	assert(player is AudioStreamPlayer, " invalid argument; wrong type")
	assert(player in get_children(), "invalid input; not a child node")

	if player.playing:
		player.stop()

	remove_child(player)
	player.free()


func _on_reclaim(object: Variant) -> void:
	var player: AudioStreamPlayer = object
	assert(player is AudioStreamPlayer, " invalid argument; wrong type")

	for connection in player.finished.get_connections():
		player.finished.disconnect(connection["callable"])

	if player.playing:
		player.stop()


func _reset_object(object: Variant) -> void:
	var player: AudioStreamPlayer = object
	assert(player is AudioStreamPlayer, " invalid argument; wrong type")

	player.autoplay = false
	player.bus = &"Master"
	player.max_polyphony = 1
	player.mix_target = AudioStreamPlayer.MIX_TARGET_STEREO
	player.pitch_scale = 1.0
	player.playback_type = AudioServer.PLAYBACK_TYPE_DEFAULT
	player.playing = false
	player.stream = null
	player.stream_paused = false
	player.volume_db = 0.0


func _validate_object(object: Variant) -> bool:
	if not object is AudioStreamPlayer:
		return false

	return object in get_children()
