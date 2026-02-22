##
## std/logging/formatter_json.gd
##
## StdLogFormatterJson produces single-line JSON-formatted log messages. Each message is
## a valid JSON object containing "name", "level", "msg", and any context fields.
##

class_name StdLogFormatterJson
extends StdLogFormatter

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## format produces a single-line JSON string of the log message.
func format(
	name: StringName, level: int, ts: float, msg: String, ctx: Dictionary
) -> String:
	var data := {}

	data[&"ts"] = Time.get_datetime_string_from_unix_time(int(ts))
	data[&"name"] = String(name)
	data[&"level"] = level
	data[&"msg"] = msg

	data.merge(ctx, true)

	return JSON.stringify(data)
