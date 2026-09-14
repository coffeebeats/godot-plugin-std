##
## std/logging/sink_void.gd
##
## StdLogSinkVoid is a no-op sink that discards all log output. Use this sink to fully
## suppress logging (e.g. during headless/CI runs or testing).
##

class_name StdLogSinkVoid
extends StdLogSink
