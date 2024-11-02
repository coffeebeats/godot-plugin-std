##
## std/fs/syncer.gd
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

signal error(err: Error, message: String)

signal file_closed
signal file_opened

signal write_requested
signal write_flushed

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Debounce := preload("../timer/debounce.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

# -- CONFIGURATION ------------------------------------------------------------------- #

@export var path: String:
	set(value):
		path = value
		update_configuration_warnings()

@export var open_on_tree_entered: bool = true
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

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## open opens the file at 'filepath' for reading and writing. An 'Error' will be
## returned if the file couldn't be opened.
##
## NOTE: This method must be called prior to reading or writing its contents.
func open() -> Error:
	assert(is_inside_tree(), "invalid state: expected node to be in tree")
	assert(not _file, "invalid state: file is already open")

	assert(path != "", "missing argument: path")
	assert(path.ends_with(".dat"), "invalid argument: past must end with '.dat'")
	assert(path.begins_with("res://") or path.begins_with("user://"), "invalid path")

	var path_absolute: String = ProjectSettings.globalize_path(path)

	if not DirAccess.dir_exists_absolute(path_absolute.get_base_dir()):
		var err := DirAccess.make_dir_recursive_absolute(path_absolute.get_base_dir())
		if err != OK:
			error.emit(
				err,
				"failed to make containing directory: %s" % path_absolute.get_base_dir()
			)
			return err

	if not FileAccess.file_exists(path_absolute):
		if FileAccess.open(path_absolute, FileAccess.WRITE) == null:
			var err := FileAccess.get_open_error()
			if err != OK:
				error.emit(err, "failed to create file: %s" % path_absolute)
				return err

	var file := FileAccess.open(path_absolute, FileAccess.READ_WRITE)
	if file == null:
		var err := FileAccess.get_open_error()
		if err != OK:
			error.emit(err, "failed to open file for r+w: %s" % path_absolute)
			return err

	_file = file

	file_opened.emit()

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

	_file.close()
	_file = null

	file_closed.emit()


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


## store_bytes requests the contents at 'filepath' to be overwritten with the provided
## value. Note that because writes are debounced, this may not occur immediately.
##
## NOTE: The file must be opened via 'open' prior to writing contents.
func store_bytes(bytes: PackedByteArray) -> void:
	assert(is_inside_tree(), "invalid state: expected node to be in tree")
	assert(_file is FileAccess, "invalid state: file not open")
	assert(_debounce is Debounce, "invalid state: missing Debounce timer")

	_bytes = bytes
	_debounce.start()

	write_requested.emit()


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _init() -> void:
	# NOTE: Set this in '_init' so that it can be overridden via the editor.
	process_mode = PROCESS_MODE_ALWAYS


func _enter_tree() -> void:
	var err := child_exiting_tree.connect(_on_Self_child_exiting_tree)
	assert(err == OK, "failed to connect to signal")

	if open_on_tree_entered:
		open()


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

	_file.seek(0)
	_file.store_buffer(_bytes)
	_file.flush()

	write_flushed.emit()


func _get_configuration_warnings() -> PackedStringArray:
	var out := PackedStringArray()

	if path == "":
		out.append("Invalid config; missing property 'path'!")
	elif not (path.begins_with("res://") or path.begins_with("user://")):
		out.append(
			"Invalid config; property 'path' should start with 'res://' or 'user://'!"
		)

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
