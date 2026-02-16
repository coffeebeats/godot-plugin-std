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
const Signals := preload("../event/signal.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

## should_call_on_value_loaded controls whether this observer will be called when one of
## the matching properties is first loaded from disk.
@export var should_call_on_value_loaded: bool = true

# -- INITIALIZATION ------------------------------------------------------------------ #

var _connected: Dictionary = {}

## _pending_scopes tracks scopes that haven't yet emitted `loaded`; used for cleanup.
var _pending_scopes: Array[StdSettingsScope] = []

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready() -> void:
	assert(not _connected, "found dangling callbacks")

	var properties := _get_settings_properties()

	for p in properties:
		var fn := func(v): _handle_value_change(p, v)

		var err := p.value_changed.connect(fn)
		assert(err == OK, "failed to connect to signal")

		_connected[p] = fn

	if not should_call_on_value_loaded:
		return

	var scopes := {}
	for p in properties:
		if p.scope and p.scope not in scopes:
			scopes[p.scope] = true

	for s in scopes:
		if not s.is_loaded:
			_pending_scopes.append(s)
			s.loaded.connect(_on_scope_loaded, CONNECT_ONE_SHOT)

	if _pending_scopes.is_empty():
		_on_all_scopes_loaded()


func _exit_tree() -> void:
	for s in _pending_scopes:
		Signals.disconnect_safe(s.loaded, _on_scope_loaded)

	_pending_scopes = []


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_settings_properties() -> Array[StdSettingsProperty]:
	assert(false, "unimplemented")
	return []


## _settings_ready is a virtual hook called immediately before initial values are read
## from hydrated configuration. Subclasses can override this to run initialization that
## depends on loaded config data.
func _settings_ready() -> void:
	pass


func _handle_value_change(_property: StdSettingsProperty, _value) -> void:
	assert(false, "unimplemented")


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_all_scopes_loaded() -> void:
	if not is_inside_tree():
		return

	_settings_ready()

	for p in _connected:
		_handle_value_change(p, p.get_value())


func _on_scope_loaded() -> void:
	_pending_scopes = _pending_scopes.filter(
		func(s: StdSettingsScope) -> bool: return not s.is_loaded
	)

	if _pending_scopes.is_empty():
		_on_all_scopes_loaded()
