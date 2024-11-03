##
## std/file/syncer.gd
##
## FileSyncer is a node which manages reading and writing to a file. All writes will be
## debounced, ensuring that performance does not degrade during frequent writes.
##
## NOTE: FileSyncer is *not* thread-safe.
##

@tool
class_name FileSyncer
extends Node

# -- SIGNALS ------------------------------------------------------------------------- #

## file_closed is emitted when this file syncer closes a file at the specified 'path'.
signal file_closed(path: String)

## file_opened is emitted when this file syncer opens a file at the specified 'path'.
signal file_opened(path: String)

## write_flushed is emitted whenever a requested write is flushed to disk.
signal write_flushed

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Debounce := preload("../timer/debounce.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

# -- CONFIGURATION ------------------------------------------------------------------- #

## close_on_tree_exited controls whether the file should be closed when this node is
## removed from the scene tree.
##
## NOTE: This should be set to 'false' only if the syncer will be added back to the
## scene tree and I/O will continue on the same file.
@export var close_on_tree_exited: bool = true

# NOTE: Insert a space to avoid overwriting global 'Timer' variable.
@export_subgroup("Debounce ")

## duration sets the minimum duration (in seconds) between writes to the file.
@export var duration: float = 0.25:
	set(value):
		duration = value
		if _debounce != null:
			_debounce.duration = value
			update_configuration_warnings()

## duration_max sets the maximum delay (in seconds) before a pending write request is
## written to the file.
@export var duration_max: float = 0.75:
	set(value):
		duration_max = value
		if _debounce != null:
			_debounce.duration_max = value
			update_configuration_warnings()

# -- INITIALIZATION ------------------------------------------------------------------ #

var _bytes: PackedByteArray = PackedByteArray()
var _debounce: Debounce = null
var _file: FileAccess = null
var _variant: Variant = null

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## open opens the file at 'path' for reading and writing. An 'Error' will be returned
## if the file couldn't be opened.
##
## NOTE: This method must be called prior to reading or writing its contents.
func open(path: String) -> Error:
	assert(is_inside_tree(), "invalid state: expected node to be in tree")
	assert(not _file, "invalid state: a file is already open")

	assert(path != "", "missing argument: path")
	assert(path.ends_with(".dat"), "invalid argument: past must end with '.dat'")
	assert(path.begins_with("res://") or path.begins_with("user://"), "invalid path")

	var path_absolute: String = ProjectSettings.globalize_path(path)

	var path_base_dir := path_absolute.get_base_dir()
	if not DirAccess.dir_exists_absolute(path_base_dir):
		var err := DirAccess.make_dir_recursive_absolute(path_base_dir)
		if err != OK:
			push_error("failed to make containing directory: %s" % path_base_dir)
			return err

	if not FileAccess.file_exists(path_absolute):
		if FileAccess.open(path_absolute, FileAccess.WRITE) == null:
			var err := FileAccess.get_open_error()
			if err != OK:
				push_error("failed to create file: %s" % path_absolute)
				return err

	var file := FileAccess.open(path_absolute, FileAccess.READ_WRITE)
	if file == null:
		var err := FileAccess.get_open_error()
		if err != OK:
			push_error("failed to open file for r+w: %s" % path_absolute)
			return err

	_file = file

	file_opened.emit(path_absolute)

	return OK


## close closes the file, preventing further writes. If 'flush' is true, any pending
## write requests will be flushed prior to closing, regardless of debounce state.
func close(flush: bool = true) -> void:
	assert(is_inside_tree(), "invalid state: expected node to be in tree")

	if not _file:
		assert(
			_debounce == null or not _debounce.is_debounced(),
			"invalid state: dangling debounce",
		)

		return

	if _debounce != null:
		_debounce.reset()

	# Only flush if there is a pending write (denoted by an active debounce). If there
	# isn't a debounce timer, then contents were already flushed when it was cleaned up.
	if flush and _debounce != null && _debounce.is_debounced():
		_flush()

	var path_absolute := _file.get_path_absolute()

	_file.close()
	_file = null

	file_closed.emit(path_absolute)


## is_open returns whether the underlying file is currently open for reading/writing.
func is_open() -> bool:
	return _file is FileAccess and _file.is_open()


## read_bytes returns the contents of the synced file.
##
## NOTE: This method always reads the file immediately and is not debounced. Invoking it
## too frequently may cause performance issues.
func read_bytes() -> PackedByteArray:
	assert(is_inside_tree(), "invalid state: expected node to be in tree")
	assert(_file is FileAccess, "invalid state: file not open")
	assert(_debounce is Debounce, "invalid state: missing Debounce timer")

	_file.seek(0)
	return _file.get_buffer(_file.get_length())


## read_var returns the contents of the synced file, serialized as a 'Variant'. By
## default this is done using the function 'bytes_to_var', but this can be controlled by
## overriding the method '_deserialize_var'.
##
## NOTE: This method always reads the file immediately and is not debounced. Invoking it
## too frequently may cause performance issues.
func read_var() -> Variant:
	return _deserialize_var(read_bytes())


## store_bytes requests that the provided data be written to the opened file. Note that
## because writes are debounced, this may not occur immediately.
##
## NOTE: The file must be opened via 'open' prior to writing contents. Any pending
## writes will be dropped.
func store_bytes(bytes: PackedByteArray) -> void:
	assert(is_inside_tree(), "invalid state: expected node to be in tree")
	assert(_file is FileAccess, "invalid state: file not open")
	assert(_debounce is Debounce, "invalid state: missing Debounce timer")

	_bytes = bytes
	_variant = null

	_debounce.start()


## store_var requests that the variant value be written to the opened file. By default
## the variant will be converted to bytes using 'var_to_bytes', but this behavior can be
## controlled by overriding the method '_serialize_var'. Note that because writes are
## debounced, the write may not occur immediately.
##
## This method should be preferred over 'store_bytes' when possible as it defers a
## potentially expensive serialization step until the write is actually flushed.
##
## NOTE: The file must be opened via 'open' prior to writing contents. Any pending
## writes will be dropped.
func store_var(variant: Variant) -> void:
	assert(is_inside_tree(), "invalid state: expected node to be in tree")
	assert(_file is FileAccess, "invalid state: file not open")
	assert(_debounce is Debounce, "invalid state: missing Debounce timer")

	_bytes = PackedByteArray()
	_variant = variant

	_debounce.start()


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _init() -> void:
	# NOTE: Set this in '_init' so that it can be overridden via the editor.
	process_mode = PROCESS_MODE_ALWAYS


func _enter_tree() -> void:
	var err := child_exiting_tree.connect(_on_Self_child_exiting_tree)
	assert(err == OK, "failed to connect to signal")


func _exit_tree() -> void:
	assert(_debounce == null, "invalid state: found dangling Debounce timer")

	if child_exiting_tree.is_connected(_on_Self_child_exiting_tree):
		child_exiting_tree.disconnect(_on_Self_child_exiting_tree)

	if close_on_tree_exited:
		# NOTE: Flush not required because child 'Debounce' timer just exited the tree,
		# triggering a flush due to its 'timeout_on_tree_exit' setting.
		close(false)


func _ready() -> void:
	assert(_debounce == null, "invalid state: found dangling Debounce timer")

	# Configure the 'Debounce' timer used to rate-limit file system writes.
	_debounce = _create_debounce_timer()
	assert(_debounce is Debounce, "invalid state: missing Debounce timer")

	add_child(_debounce, false, INTERNAL_MODE_FRONT)

	var result := _debounce.timeout.connect(_on_Debounce_timeout)
	assert(result == OK, "Failed to connect to signal!")


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _deserialize_var(bytes: PackedByteArray) -> Variant:
	return bytes_to_var(bytes)


func _serialize_var(variant: Variant) -> PackedByteArray:
	return var_to_bytes(variant)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## Creates a 'Debounce' timer node configured for file system writes.
func _create_debounce_timer() -> Debounce:
	var out := Debounce.new()

	out.duration_max = duration_max
	assert(
		out.duration_max == duration_max,
		"Invalid config; expected '%f' to be '%f'!" % [out.duration_max, duration_max]
	)

	out.duration = duration
	assert(
		out.duration == duration,
		"Invalid config; expected '%f' to be '%f'!" % [out.duration, duration]
	)

	out.execution_mode = Debounce.EXECUTION_MODE_TRAILING
	out.process_callback = Timer.TIMER_PROCESS_IDLE
	out.timeout_on_tree_exit = true

	return out


func _flush() -> void:
	if not _file:
		return

	var err := _file.resize(0)
	assert(err == OK, "failed to truncate file before write")

	var bytes: PackedByteArray = PackedByteArray()
	if _variant == null:
		assert(_bytes.size() > 0, "missing write data")
		bytes = _bytes
	else:
		assert(_bytes.size() == 0, "conflicting write data")
		bytes = _serialize_var(_variant)

	_bytes = PackedByteArray()
	_variant = null

	_file.seek(0)
	_file.store_buffer(bytes)
	_file.flush()

	write_flushed.emit()


func _get_configuration_warnings() -> PackedStringArray:
	var out := PackedStringArray()

	if not _debounce:
		return out

	assert(_debounce is Debounce, "invalid type: expected Debounce timer")

	if _debounce.duration != duration:
		out.append("Invalid config; expected valid 'duration' value!")
	if _debounce.duration_max != duration_max:
		out.append("Invalid config; expected valid 'duration_max' value!")

	return out


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_Self_child_exiting_tree(node: Node) -> void:
	if not node == _debounce:
		return

	# The debounce timer just flushed pending contents to disk, so the reference can be
	# safely cleaned up.
	_debounce = null


func _on_Debounce_timeout() -> void:
	_flush()
