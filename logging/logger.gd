##
## std/logging/logger.gd
##
## StdLogger is a logging implementation which supports hierachical logging contexts and
## standard verbosity levels. All logs are routed to the engine via one of `print`,
## `print_rich`, `push_warning`, or `push_error`, depending on where the game's running.
##

class_name StdLogger
extends RefCounted

# -- DEFINITIONS --------------------------------------------------------------------- #

const _DEBUG_PREFIX := &"[color=cyan]DEBUG[/color]:"
const _ERROR_PREFIX := &"[color=red]ERROR[/color]:"
const _INFO_PREFIX := &"[color=green]INFO[/color]:"
const _WARN_PREFIX := &"[color=yellow]WARN[/color]:"

# -- CONFIGURATION ------------------------------------------------------------------- #

## name is the name of the logger.
@export var name: StringName = &""

@export_subgroup("Logging context")

## context is a mapping of this logger's context fields. These will be included with
## each logged message, regardless of level.
@export var context: Dictionary = {}

## include_frame_physics determines whether the current physics frame count will be
## included in the logged context fields.
@export var include_frame_physics: bool = false

## include_frame_process determines whether the current process frame count will be
## included in the logged context fields.
@export var include_frame_process: bool = false

## include_timestamp determines whether the current unix timestamp will be included in
## the logged context fields.
@export var include_timestamp: bool = false

# -- INITIALIZATION ------------------------------------------------------------------ #

static var _is_editor: bool = OS.has_feature("editor")

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## create returns a new logger with the specified name and base context.
static func create(value: StringName, ctx: Dictionary = {}) -> StdLogger:
	var logger := StdLogger.new()
	logger.name = value
	logger.context = ctx
	return logger


# Context methods


func named(value: StringName) -> StdLogger:
	name = value
	return self


## with returns a new child logger; the provided context and suffix will be derived from
## the current logger's context and name.
func with(ctx: Dictionary, suffix: StringName = &"") -> StdLogger:
	var logger := StdLogger.new()

	logger.name = StringName(name + "/" + suffix) if suffix else name

	logger.context = context.duplicate()
	logger.context.merge(ctx, true)

	logger.include_frame_physics = include_frame_physics
	logger.include_frame_process = include_frame_process
	logger.include_timestamp = include_timestamp

	return logger


## with_timestamp updates this logger's `include_frame_physics` property and returns it.
func with_physics_frame(enabled: bool = true) -> StdLogger:
	include_frame_physics = enabled
	return self


## with_timestamp updates this logger's `include_frame_process` property and returns it.
func with_process_frame(enabled: bool = true) -> StdLogger:
	include_frame_process = enabled
	return self


## with_timestamp updates this logger's `include_timestamp` property and returns it.
func with_timestamp(enabled: bool = true) -> StdLogger:
	include_timestamp = enabled
	return self


# Log methods


## error logs an error with the provided context `ctx`.
func error(msg: String, ctx: Dictionary = {}) -> void:
	ctx = ctx.duplicate()
	ctx.merge(context, false)

	var message := msg
	if _is_editor:
		message = "[color=white]%s[/color]" % msg

	var prefix := _format_name() + " "
	if _is_editor:
		prefix += _ERROR_PREFIX + " "

	var fields: String = ""
	if ctx:
		fields = " " + _format_context(ctx)

	print_rich(prefix, message, fields)
	push_error(msg, fields)


## warn logs a warning with the provided context `ctx`.
func warn(msg: String, ctx: Dictionary = {}) -> void:
	ctx = ctx.duplicate()
	ctx.merge(context, false)

	var message := msg
	if _is_editor:
		message = "[color=white]%s[/color]" % msg

	var prefix := _format_name() + " "
	if _is_editor:
		prefix += _WARN_PREFIX + " "

	var fields: String = ""
	if ctx:
		fields = " " + _format_context(ctx)

	print_rich(prefix, message, fields)
	push_warning(msg, fields)


## info logs an info-level message with the provided context `ctx`.
func info(msg: String, ctx: Dictionary = {}) -> void:
	ctx = ctx.duplicate()
	ctx.merge(context, false)

	var message := msg
	if _is_editor:
		message = "[color=white]%s[/color]" % msg

	var prefix := _format_name() + " "
	if _is_editor:
		prefix += _INFO_PREFIX + " "

	var fields: String = ""
	if ctx:
		fields = " " + _format_context(ctx)

	print_rich(prefix, message, fields)


## debug logs a debug-level message with the provided context `ctx`.
func debug(msg: String, ctx: Dictionary = {}) -> void:
	if not _is_editor:
		return

	ctx = ctx.duplicate()
	ctx.merge(context, false)

	var message := msg
	if _is_editor:
		message = "[color=white]%s[/color]" % msg

	var prefix := _format_name() + " "
	if _is_editor:
		prefix += _DEBUG_PREFIX + " "

	var fields: String = ""
	if ctx:
		fields = " " + _format_context(ctx)

	print_rich(prefix, message, fields)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _format_context(ctx: Dictionary) -> String:
	var fields := PackedStringArray()

	if include_timestamp:
		fields.append("ts=%f" % Time.get_unix_time_from_system())
	if include_frame_physics:
		fields.append("phf=%d" % Engine.get_physics_frames())
	if include_frame_process:
		fields.append("prf=%d" % Engine.get_process_frames())

	for key in ctx:
		fields.append("%s=%s" % [key, str(ctx[key])])

	return "(%s)" % ",".join(fields) if fields else ""


func _format_name() -> String:
	if not name:
		return ""

	return "[%s]" % ("[color=white]%s[/color]" % name if _is_editor else String(name))