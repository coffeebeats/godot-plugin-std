##
## std/sound/music_test.gd
##
## Tests pertaining to `StdMusicPlayer`.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const MusicPlayer := preload("music.gd")

# -- TEST METHODS -------------------------------------------------------------------- #


func test_play_starts_music():
	# Given: A music player with a sound player available.
	var mp := _create_music_player()
	var event := _create_event()

	# When: Play is called.
	mp.play(event)

	# Then: Music is playing.
	assert_true(mp.is_playing())
	assert_not_null(mp.get_instance())


func test_same_event_is_noop():
	# Given: A music player already playing an event.
	var mp := _create_music_player()
	var event := _create_event()
	mp.play(event)
	var first_instance := mp.get_instance()

	# When: The same event is played again.
	mp.play(event)

	# Then: The instance is unchanged (no-op).
	assert_eq(mp.get_instance(), first_instance)


func test_different_event_stops_previous():
	# Given: A music player playing one event.
	var mp := _create_music_player()
	var event_a := _create_event()
	mp.play(event_a)
	var first_instance := mp.get_instance()

	# When: A different event is played.
	var event_b := _create_event()
	mp.play(event_b)

	# Then: The first instance was stopped.
	assert_true(first_instance.is_done())

	# Then: A new instance is active.
	assert_true(mp.is_playing())
	assert_ne(mp.get_instance(), first_instance)


func test_stop_clears_state():
	# Given: A music player with an active track.
	var mp := _create_music_player()
	mp.play(_create_event())

	# When: Stop is called.
	mp.stop()

	# Then: No music is playing.
	assert_false(mp.is_playing())
	assert_null(mp.get_instance())


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _create_event() -> StdSoundEvent1D:
	var event := StdSoundEvent1D.new()

	var stream := AudioStreamGenerator.new()
	stream.mix_rate = 44100.0
	stream.buffer_length = 1.0

	event.stream = stream

	var bus := StdAudioBusStatic.new()
	bus.name = &"Master"
	event.bus = bus

	return event


func _create_music_player() -> MusicPlayer:
	_create_sound_player()
	var mp := MusicPlayer.new()
	add_child_autofree(mp)
	return mp


func _create_sound_player() -> StdSoundEventPlayer:
	var player := StdSoundEventPlayer.new()

	var pool := StdAudioStreamPlayerPool1D.new()
	pool.size = 4

	player.pool_1d = pool
	player.add_child(pool)
	add_child_autofree(player)

	return player
