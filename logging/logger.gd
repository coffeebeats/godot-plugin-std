##
## std/logging/logger.gd
##
## StdLogger is a logging implementation which supports hierarchical logging contexts
## and standard verbosity levels. Three output modes are auto-detected at startup:
## `RICH` (colored BBCode in-editor), `COMPACT` (plain text for exported games), and
## `SILENT` (suppressed during headless/CI runs); error and warning engine notifications
## are preserved in all modes.
##

class_name StdLogger
extends RefCounted

# -- DEFINITIONS --------------------------------------------------------------------- #

enum Mode { RICH, COMPACT, SILENT }

const _DEBUG_PREFIX_RICH := &"[b][color=cyan]DEBUG[/color]:[/b]"
const _DEBUG_PREFIX_PLAIN := &"DEBUG:"
const _ERROR_PREFIX_RICH := &"[b][color=red]ERROR[/color]:[/b]"
const _ERROR_PREFIX_PLAIN := &"ERROR:"
const _INFO_PREFIX_RICH := &"[b][color=green]INFO[/color]:[/b]"
const _INFO_PREFIX_PLAIN := &"INFO:"
const _WARN_PREFIX_RICH := &"[b][color=yellow]WARN[/color]:[/b]"
const _WARN_PREFIX_PLAIN := &"WARN:"

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

static var _mode: Mode = _detect_mode()  # gdlint:ignore=class-definitions-order

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## create returns a new logger with the specified name and base context.
static func create(value: StringName, ctx: Dictionary = {}) -> StdLogger:
	var logger := StdLogger.new()
	logger.name = value
	logger.context = ctx
	return logger


## set_mode overrides the auto-detected output mode.
static func set_mode(mode: Mode) -> void:
	_mode = mode


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
	if _mode == Mode.SILENT:
		push_error(msg)
		return

	var fields := _log(msg, _ERROR_PREFIX_RICH, _ERROR_PREFIX_PLAIN, ctx)
	push_error(msg, fields)


## warn logs a warning with the provided context `ctx`.
func warn(msg: String, ctx: Dictionary = {}) -> void:
	if _mode == Mode.SILENT:
		push_warning(msg)
		return

	var fields := _log(msg, _WARN_PREFIX_RICH, _WARN_PREFIX_PLAIN, ctx)
	push_warning(msg, fields)


## info logs an info-level message with the provided context `ctx`.
func info(msg: String, ctx: Dictionary = {}) -> void:
	if _mode == Mode.SILENT:
		return

	_log(msg, _INFO_PREFIX_RICH, _INFO_PREFIX_PLAIN, ctx)


## debug logs a debug-level message with the provided context `ctx`.
func debug(msg: String, ctx: Dictionary = {}) -> void:
	if not OS.has_feature(&"debug"):
		return

	if _mode == Mode.SILENT:
		return

	_log(msg, _DEBUG_PREFIX_RICH, _DEBUG_PREFIX_PLAIN, ctx)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


static func _detect_mode() -> Mode:
	if not OS.has_feature("editor"):
		return Mode.COMPACT

	if DisplayServer.get_name() == "headless":
		return Mode.SILENT

	return Mode.RICH


func _format_context(ctx: Dictionary) -> String:
	var is_rich := _mode == Mode.RICH
	var fields := PackedStringArray()

	if include_timestamp:
		fields.append("ts=%f" % Time.get_unix_time_from_system())
	if include_frame_physics:
		fields.append("phf=%d" % Engine.get_physics_frames())
	if include_frame_process:
		fields.append("prf=%d" % Engine.get_process_frames())

	for key in ctx:
		var field := "%s=%s" % [key, str(ctx[key])]
		if is_rich:
			field = "[color=gray]%s[/color]" % field

		fields.append(field)

	if not fields:
		return ""

	if is_rich:
		return "\n\t" + "\n\t".join(fields)

	return " (%s)" % ",".join(fields)


func _format_name() -> String:
	if not name:
		return ""

	return (
		"[%s]"
		% ("[color=gray]%s[/color]" % name if _mode == Mode.RICH else String(name))
	)


func _log(
	msg: String,
	prefix_rich: StringName,
	prefix_plain: StringName,
	ctx: Dictionary,
) -> String:
	ctx = ctx.duplicate()
	ctx.merge(context, false)

	var is_rich := _mode == Mode.RICH

	var message := "[color=white]%s[/color]" % msg if is_rich else msg
	var prefix := "%s %s " % [_format_name(), prefix_rich if is_rich else prefix_plain]

	var fields: String = ""
	if ctx:
		fields = _format_context(ctx)

	if is_rich:
		print_rich(prefix, message, fields)
	else:
		print(prefix, message, fields)

	return fields
