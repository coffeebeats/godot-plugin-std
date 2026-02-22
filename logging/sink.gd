##
## std/logging/sink.gd
##
## StdLogSink is the base class for log output destinations. Sinks receive a formatted
## `String` plus raw log components and route the output to a target (e.g. Godot
## console, file, network, etc.). Sinks do not know about BBCode, field ordering, or
## string layout.
##

class_name StdLogSink
extends Resource

# -- PUBLIC METHODS (OVERRIDES) ------------------------------------------------------ #


## output routes a log message to this sink's destination.
##
## NOTE: This method *must* be overridden to customize log routing; the base
## implementation is a no-op.
func output(
	_name: StringName,
	_level: int,
	_msg: String,
	_formatted: String,
	_ctx: Dictionary,
	_use_bbcode: bool,
) -> void:
	pass
