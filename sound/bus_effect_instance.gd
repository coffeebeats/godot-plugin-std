##
## std/sound/bus_effect_instance.gd
##
## StdSoundBusEffectInstance is a handle to a live audio effect on a bus. It supports
## blending, animated removal, and immediate reset.
##

class_name StdSoundBusEffectInstance
extends RefCounted

# -- INITIALIZATION ------------------------------------------------------------------ #

var _bus_index: int = -1
var _effect: StdSoundBusEffect = null
var _is_removing: bool = false
var _is_valid: bool = true
var _owner: Node = null
var _resource: AudioEffect = null
var _tween: Tween = null

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## is_valid returns whether this instance still holds a live effect on the bus.
func is_valid() -> bool:
	return _is_valid


## remove transitions all effect properties back to their off values, then removes the
## effect from the bus. Safe to call multiple times; subsequent calls are no-ops once
## removal has started.
func remove() -> void:
	if not _is_valid or _is_removing:
		return

	_is_removing = true

	if _tween:
		_tween.kill()
		_tween = null

	var tween: Tween = null
	if is_instance_valid(_owner):
		for p in _effect.properties:
			if not p.transition_out or p.property == &"":
				continue
			if not tween:
				tween = _owner.create_tween().set_parallel(true)

			var path := NodePath(String(p.property))
			p.transition_out.tween_property(tween, _resource, path, p.value_off)

	if tween:
		tween.set_parallel(false)
		tween.tween_callback(_remove_effect)
		_tween = tween
	else:
		_remove_effect()


## reset immediately removes the effect from the bus with no transition.
func reset() -> void:
	if not _is_valid:
		return

	if _tween:
		_tween.kill()
		_tween = null

	_remove_effect()


## set_blend interpolates effect properties between their `value_off` and `value_on`.
func set_blend(t: float) -> void:
	assert(_effect is StdSoundBusEffect, "invalid state; missing description")
	assert(_is_valid, "invalid state; instance is not valid")
	assert(_resource is AudioEffect, "invalid state; missing resource")

	for p in _effect.properties:
		if p.property == &"":
			continue

		_resource.set(p.property, lerpf(p.value_off, p.value_on, t))


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _init(
	owner: Node,
	effect: StdSoundBusEffect,
	resource: AudioEffect,
	bus_index: int,
) -> void:
	_bus_index = bus_index
	_effect = effect
	_owner = owner
	_resource = resource


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _find_effect_index() -> int:
	for i in AudioServer.get_bus_effect_count(_bus_index):
		if AudioServer.get_bus_effect(_bus_index, i) == _resource:
			return i

	return -1


func _remove_effect() -> void:
	if not _is_valid:
		return

	var idx := _find_effect_index()
	if idx > -1:
		AudioServer.remove_bus_effect(_bus_index, idx)

	_is_valid = false
	_tween = null
