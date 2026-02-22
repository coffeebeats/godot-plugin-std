##
## std/logging/logger.gd
##
## StdLogger is a logging implementation which supports hierarchical logging contexts,
## standard verbosity levels, and pluggable formatting and output routing. Log messages
## pass through a two-stage pipeline: a formatter produces a string, then a sink routes
## the output to its destination.
##
## Per-category level filtering allows focusing on specific modules without changing the
## global threshold. The default level is `WARN`, meaning debug and info messages are
## off by default and function as opt-in breadcrumbs.
##

class_name StdLogger
extends RefCounted

# -- DEPENDENCIES -------------------------------------------------------------------- #

const LogLevels := preload("level.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

## Level re-exports the log severity enum from so that consumers can reference it as
## `StdLogger.Level` without a separate preload.
const Level := LogLevels.Level  # gdlint:ignore=constant-name

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

static var _formatter: StdLogFormatter = StdLogFormatterCompact.new()
static var _level_overrides: Dictionary = {}  # gdlint:ignore=class-definitions-order,max-line-len
static var _level: Level = LogLevels.LEVEL_WARN  # gdlint:ignore=class-definitions-order
static var _sink: StdLogSink = StdLogSinkGodot.new()  # gdlint:ignore=class-definitions-order

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## clear_level_override removes a per-category level override for the given prefix.
static func clear_level_override(prefix: StringName) -> void:
	_level_overrides.erase(prefix)


## clear_level_overrides removes all per-category level overrides.
static func clear_level_overrides() -> void:
	_level_overrides.clear()


## create returns a new logger with the specified name and base context.
static func create(value: StringName, ctx: Dictionary = {}) -> StdLogger:
	var logger := StdLogger.new()
	logger.name = value
	logger.context = ctx
	return logger


## get_effective_level returns the active log level for the given logger name. If a
## category-level override matches (longest prefix wins), that level is returned;
## otherwise the global level is used.
static func get_effective_level(logger_name: StringName) -> Level:
	var best_prefix := &""
	var best_len := 0

	for prefix in _level_overrides:
		var p := String(prefix)
		if String(logger_name).begins_with(p) and p.length() > best_len:
			best_prefix = prefix
			best_len = p.length()

	if best_len > 0:
		return _level_overrides[best_prefix]

	return _level


## set_formatter replaces the active formatter used by all loggers.
static func set_formatter(formatter: StdLogFormatter) -> void:
	if not formatter:
		assert(false, "invalid argument: missing formatter")
		return

	_formatter = formatter


## set_level sets the global log level threshold. Messages below this level are
## suppressed unless a per-category override applies.
static func set_level(level: Level) -> void:
	if not level is Level:
		assert(false, "invalid argument: missing level")
		return

	_level = level


## set_level_override sets a per-category level override. Logger names matching the
## given prefix (via `begins_with()`) will use this level instead of the global one;
## the longest matching prefix wins.
static func set_level_override(prefix: StringName, level: Level) -> void:
	_level_overrides[prefix] = level


## set_sink replaces the active sink used by all loggers.
static func set_sink(sink: StdLogSink) -> void:
	if not sink:
		assert(false, "invalid argument: missing sink")
		return

	_sink = sink


# Context methods


func named(value: StringName) -> StdLogger:
	name = value
	return self


## with returns a new child logger; the provided context and suffix will be
## derived from the current logger's context and name.
func with(ctx: Dictionary, suffix: StringName = &"") -> StdLogger:
	var logger := StdLogger.new()

	logger.name = (StringName(name + "/" + suffix) if suffix else name)

	logger.context = context.duplicate()
	logger.context.merge(ctx, true)

	logger.include_frame_physics = include_frame_physics
	logger.include_frame_process = include_frame_process
	logger.include_timestamp = include_timestamp

	return logger


## with_physics_frame updates this logger's `include_frame_physics` property
## and returns it.
func with_physics_frame(enabled: bool = true) -> StdLogger:
	include_frame_physics = enabled
	return self


## with_process_frame updates this logger's `include_frame_process` property
## and returns it.
func with_process_frame(enabled: bool = true) -> StdLogger:
	include_frame_process = enabled
	return self


## with_timestamp updates this logger's `include_timestamp` property and
## returns it.
func with_timestamp(enabled: bool = true) -> StdLogger:
	include_timestamp = enabled
	return self


# Log methods


## debug logs a debug-level message with the provided context `ctx`. Debug
## messages are suppressed in non-debug builds regardless of level settings.
func debug(msg: String, ctx: Dictionary = {}) -> void:
	if not OS.has_feature(&"debug"):
		return
	if not _should_log(LogLevels.LEVEL_DEBUG):
		return
	_emit(LogLevels.LEVEL_DEBUG, msg, _merge_context(ctx))


## error logs an error with the provided context `ctx`.
func error(msg: String, ctx: Dictionary = {}) -> void:
	if not _should_log(LogLevels.LEVEL_ERROR):
		return
	_emit(LogLevels.LEVEL_ERROR, msg, _merge_context(ctx))


## info logs an info-level message with the provided context `ctx`.
func info(msg: String, ctx: Dictionary = {}) -> void:
	if not _should_log(LogLevels.LEVEL_INFO):
		return
	_emit(LogLevels.LEVEL_INFO, msg, _merge_context(ctx))


## warn logs a warning with the provided context `ctx`.
func warn(msg: String, ctx: Dictionary = {}) -> void:
	if not _should_log(LogLevels.LEVEL_WARN):
		return
	_emit(LogLevels.LEVEL_WARN, msg, _merge_context(ctx))


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _emit(level: Level, msg: String, ctx: Dictionary) -> void:
	var formatted := _formatter.format(name, level, msg, ctx)
	_sink.output(name, level, msg, formatted, ctx, _formatter.bbcode)


func _merge_context(ctx: Dictionary) -> Dictionary:
	ctx = ctx.duplicate()
	ctx.merge(context, false)

	if include_timestamp:
		ctx[&"ts"] = Time.get_unix_time_from_system()
	if include_frame_physics:
		ctx[&"phf"] = Engine.get_physics_frames()
	if include_frame_process:
		ctx[&"prf"] = Engine.get_process_frames()

	return ctx


func _should_log(level: Level) -> bool:
	return level >= StdLogger.get_effective_level(name)
