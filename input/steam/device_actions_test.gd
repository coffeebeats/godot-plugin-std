##
## Tests pertaining to the Steam implementation of `StdInputDeviceActions`.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const SteamDeviceActions := preload("device_actions.gd")

# -- TEST METHODS -------------------------------------------------------------------- #


func test_split_analog_2d_presses_each_direction_at_its_axis_strength() -> void:
	# When: A stick deflected left and up is split for the `move` action on slot 0.
	var got := SteamDeviceActions.split_analog_2d(&"move", Vector2(-0.5, 0.25), 7, 0)

	# Then: The four directional actions are in `Input.get_vector` order.
	assert_eq(
		got.map(func(e): return e.action),
		[&"move_left", &"move_right", &"move_up", &"move_down"],
	)

	# Then: Each is pressed at the strength of its half of the axis, or released.
	assert_eq(got.map(func(e): return e.strength), [0.5, 0.0, 0.25, 0.0])
	assert_eq(got.map(func(e): return e.pressed), [true, false, true, false])

	# Then: Each carries the slot and the stick's action handle.
	for event in got:
		assert_eq(event.device, 0)
		assert_eq(event.event_index, 7)
