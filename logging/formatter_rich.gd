##
## std/logging/formatter_rich.gd
##
## StdLogFormatterRich produces single-line BBCode-formatted log messages suitable for
## Godot's `print_rich()` output.
##

class_name StdLogFormatterRich
extends StdLogFormatter

# -- CONFIGURATION ------------------------------------------------------------------- #

@export_group("Color")

## color_name is the color used for the logger name.
@export_color_no_alpha var color_name: Color = Color.GRAY

## color_context is the color used for extra logged context.
@export_color_no_alpha var color_context: Color = Color.GRAY

@export_subgroup("Labels")

## color_debug is the color used for `DEBUG` level labels.
@export_color_no_alpha var color_debug: Color = Color.CYAN

## color_info is the color used for `INFO` level labels.
@export_color_no_alpha var color_info: Color = Color.GREEN

## color_warn is the color used for `WARN` level labels.
@export_color_no_alpha var color_warn: Color = Color.YELLOW

## color_error is the color used for `ERROR` level labels.
@export_color_no_alpha var color_error: Color = Color.RED

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## format produces a single-line BBCode string of the log message.
func format(
	name: StringName, level: int, _ts: float, msg: String, ctx: Dictionary
) -> String:
	var out := ""

	if name:
		var name_hex := "#" + color_name.to_html(false)
		out = "[color=" + name_hex + "]" + str(name) + "[/color] "

	var level_hex := _level_color(level)
	var level_label := LogLevels.level_name(level)
	out += "[b][color=" + level_hex + "]" + level_label + "[/color][/b] "
	out += msg

	if ctx:
		var ctx_hex := "#" + color_context.to_html(false)
		var sep := " [color=" + ctx_hex + "]"
		for key in ctx:
			out += str(sep, key, "=", ctx[key])
			sep = " "
		out += "[/color]"

	return out


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _init() -> void:
	bbcode = true


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _level_color returns the BBCode color string for the given level.
func _level_color(level: int) -> String:
	match level:
		LogLevels.LEVEL_DEBUG:
			return "#" + color_debug.to_html(false)
		LogLevels.LEVEL_INFO:
			return "#" + color_info.to_html(false)
		LogLevels.LEVEL_WARN:
			return "#" + color_warn.to_html(false)
		LogLevels.LEVEL_ERROR:
			return "#" + color_error.to_html(false)
		_:
			return "white"
