##
## std/sound/bus_effect_test.gd
##
## Tests pertaining to `StdSoundBusEffect` and `StdSoundBusEffectInstance`.
##

extends GutTest

# -- INITIALIZATION ------------------------------------------------------------------ #

var _instances: Array[StdSoundBusEffectInstance] = []

# -- TEST METHODS -------------------------------------------------------------------- #


func test_multiple_applies_are_independent():
	# Given: Two separate bus effect applications.
	var effect := _create_effect()

	var bus_index := 0
	var count_before := AudioServer.get_bus_effect_count(bus_index)

	var a := _apply(effect, bus_index)
	var b := _apply(effect, bus_index)

	# Then: Two effects were added.
	assert_eq(AudioServer.get_bus_effect_count(bus_index), count_before + 2)

	# When: One is reset.
	a.reset()

	# Then: The other is still valid.
	assert_true(b.is_valid())
	assert_eq(AudioServer.get_bus_effect_count(bus_index), count_before + 1)


func test_transition_starts_at_off_value():
	# Given: A bus effect with a transition_in configured.
	var transition := StdTweenCurve.new()
	transition.duration = 0.5

	var effect := _create_effect(&"cutoff_hz", 20500.0, 1400.0, transition)

	# When: Applied.
	var instance := _apply(effect)

	# Then: The initial property value is value_off (tween hasn't run).
	assert_almost_eq(
		instance._resource.get(&"cutoff_hz") as float,
		20500.0,
		0.01,
	)


func test_remove_without_transition_removes_immediately():
	# Given: An applied bus effect with no transition curves.
	var effect := _create_effect()

	var bus_index := 0
	var count_before := AudioServer.get_bus_effect_count(bus_index)
	var instance := _apply(effect, bus_index)

	# When: The instance is removed.
	instance.remove()

	# Then: The effect is removed and the instance is invalid.
	assert_false(instance.is_valid())
	assert_eq(AudioServer.get_bus_effect_count(bus_index), count_before)


func test_remove_is_idempotent():
	# Given: An applied bus effect that has already been removed.
	var effect := _create_effect()

	var bus_index := 0
	var count_before := AudioServer.get_bus_effect_count(bus_index)
	var instance := _apply(effect, bus_index)

	instance.remove()

	# When: remove() is called again.
	instance.remove()

	# Then: No crash, no extra effects removed.
	assert_false(instance.is_valid())
	assert_eq(AudioServer.get_bus_effect_count(bus_index), count_before)


func test_remove_kills_active_apply_tween():
	# Given: A bus effect applied with a long transition_in.
	var transition := StdTweenCurve.new()
	transition.duration = 10.0

	var effect := _create_effect(&"cutoff_hz", 20500.0, 1400.0, transition)

	var bus_index := 0
	var count_before := AudioServer.get_bus_effect_count(bus_index)
	var instance := _apply(effect, bus_index)

	# Then: The apply tween is running.
	assert_true(instance._tween.is_running())

	# When: The instance is removed immediately (no transition_out).
	instance.remove()

	# Then: The effect is removed and the tween is killed.
	assert_false(instance.is_valid())
	assert_null(instance._tween)
	assert_eq(
		AudioServer.get_bus_effect_count(bus_index),
		count_before,
	)


func test_remove_with_transition_defers_removal():
	# Given: A bus effect with a transition_out configured.
	var transition := StdTweenCurve.new()
	transition.duration = 0.5

	var effect := _create_effect_with_transitions(
		&"cutoff_hz", 20500.0, 1400.0, null, transition
	)

	var bus_index := 0
	var count_before := AudioServer.get_bus_effect_count(bus_index)
	var instance := _apply(effect, bus_index)

	# When: The instance is removed (has transition_out).
	instance.remove()

	# Then: The effect is still on the bus (tween is running).
	assert_true(instance._is_removing)
	assert_eq(AudioServer.get_bus_effect_count(bus_index), count_before + 1)


func test_reset_during_remove_transition():
	# Given: A bus effect with a long transition_out, mid-removal.
	var transition := StdTweenCurve.new()
	transition.duration = 10.0

	var effect := _create_effect_with_transitions(
		&"cutoff_hz", 20500.0, 1400.0, null, transition
	)

	var bus_index := 0
	var count_before := AudioServer.get_bus_effect_count(bus_index)
	var instance := _apply(effect, bus_index)

	instance.remove()

	# Then: Removal is in progress but effect is still on bus.
	assert_true(instance._is_removing)
	assert_eq(AudioServer.get_bus_effect_count(bus_index), count_before + 1)

	# When: `reset()` is called during the removal transition.
	instance.reset()

	# Then: The effect is removed immediately.
	assert_false(instance.is_valid())
	assert_eq(AudioServer.get_bus_effect_count(bus_index), count_before)


# -- TEST HOOKS ---------------------------------------------------------------------- #


func after_each() -> void:
	for instance in _instances:
		if instance.is_valid():
			instance.reset()

	_instances.clear()


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _apply(effect: StdSoundBusEffect, bus_index: int = 0) -> StdSoundBusEffectInstance:
	var instance := effect.apply(bus_index, self)
	_instances.append(instance)

	return instance


func _create_effect(
	prop: StringName = &"",
	off: float = 0.0,
	on: float = 0.0,
	trans_in: StdTweenCurve = null,
) -> StdSoundBusEffect:
	return _create_effect_with_transitions(prop, off, on, trans_in, null)


func _create_effect_with_transitions(
	prop: StringName = &"",
	off: float = 0.0,
	on: float = 0.0,
	trans_in: StdTweenCurve = null,
	trans_out: StdTweenCurve = null,
) -> StdSoundBusEffect:
	var effect := StdSoundBusEffect.new()
	effect.effect = AudioEffectLowPassFilter.new()

	if prop != &"":
		var p := StdSoundBusEffectProperty.new()
		p.property = prop
		p.value_off = off
		p.value_on = on
		p.transition_in = trans_in
		p.transition_out = trans_out
		effect.properties = [p]

	return effect
