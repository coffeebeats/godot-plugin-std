##
## std/setting/observer.gd
##
## `StdSettingsObserver` is a type which listens to changes to the specified settings
## properties.
##

class_name StdSettingsObserver
extends Node

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Config := preload("../config/config.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

## should_call_on_value_loaded controls whether this observer will be called when one of
## the matching properties is first loaded from disk.
@export var should_call_on_value_loaded: bool = true

# -- INITIALIZATION ------------------------------------------------------------------ #

var _connected: Dictionary = {}

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready() -> void:
	assert(not _connected, "found dangling callbacks")

	var properties := _get_settings_properties()

	for p in properties:
		var fn := func(v): _handle_value_change(p, v)

		var err := p.value_changed.connect(fn)
		assert(err == OK, "failed to connect to signal")

		_connected[p] = fn

	if should_call_on_value_loaded:
		for p in properties:
			_handle_value_change(p, p.get_value())


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_settings_properties() -> Array[StdSettingsProperty]:
	assert(false, "unimplemented")
	return []


func _handle_value_change(_property: StdSettingsProperty, _value) -> void:
	assert(false, "unimplemented")
