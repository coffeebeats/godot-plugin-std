##
## std/sound/pool.gd
##
## A base class for a simple object pool.
##

extends Node

# -- SIGNALS ------------------------------------------------------------------------- #

## claimed is emitted when an object is borrowed from the pool.
signal claimed(object: Variant)

## reclaimed is emitted when an object is returned to the pool.
signal reclaimed(object: Variant)

# -- CONFIGURATION ------------------------------------------------------------------- #

## size configures the size of the pool.
##
## TODO: Update this to work at runtime.
@export var size: int = 1

# -- INITIALIZATION ------------------------------------------------------------------ #

# gdlint:ignore=class-definitions-order
static var _logger := StdLogger.create("std/sound/pool")

var _pool: Array[Variant] = []

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## clear immediately frees all of the objects within the pool, rendering it empty.
##
## NOTE: Be sure that no pooled objects are in use when invoking `clear`, as a crash may
## occur when using a freed object.
func clear() -> void:
	_logger.info("Destroying object pool.")

	for object in _pool:
		_on_reclaim(object) # NOTE: Reclaim here to reduce risk of use-after-free error.
		_destroy_object(object)

		if is_instance_valid(object):
			object.free()

	_pool.clear()


## claim borrows an object from the pool. If no object is available, `null` is returned.
func claim() -> Variant:
	var object: Variant = _pool.pop_back()
	if not object:
		_logger.warn("No object available in pool.")
		return null

	_on_claim(object)

	_logger.debug("Claimed pool object.", {&"available": _pool.size()})

	claimed.emit(object)
	return object


## reclaim returns a previously-borrowed object to the pool.
func reclaim(object: Variant) -> void:
	assert(object not in _pool, "invalid state; object already reclaimed")

	if not _validate_object(object):
		assert(false)
		return

	_on_reclaim(object)

	reclaimed.emit(object)

	_reset_object(object)
	_pool.append(object)

	_logger.debug("Reclaimed pool object.", {&"available": _pool.size()})

	assert(_pool.size() <= size)


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready() -> void:
	assert(size > 0, "invalid config; pool size must be positive")

	for _i in size:
		var object: Variant = _create_object()
		if not object:
			assert(false)
			continue

		if not _validate_object(object):
			assert(false)
			continue

		_pool.append(object)

	assert(_pool.size() == size, "invalid state; pool incorrectly configured")


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _create_object() -> Variant:
	return null


func _destroy_object(_object: Variant) -> void:
	pass


func _on_claim(_object: Variant) -> void:
	pass


func _on_reclaim(_object: Variant) -> void:
	pass


func _reset_object(_object: Variant) -> void:
	pass


func _validate_object(_object: Variant) -> bool:
	return true
