##
## router/history.gd
##
## StdRouterHistory is a typed stack data structure for navigation
## history entries. Each entry records a route and its associated
## params. This class has no navigation semantics — it is a pure
## data structure used by StdRouterLayer.
##

class_name StdRouterHistory
extends RefCounted

# -- DEFINITIONS ------------------------------------------------------------- #


## Entry represents a previously active route state.
class Entry:
	extends RefCounted

	var route: StdRoute
	var params: StdRouteParams


# -- INITIALIZATION ---------------------------------------------------------- #

var _entries: Array[Entry] = []

# -- PUBLIC METHODS ---------------------------------------------------------- #


## push appends an entry to the top of the stack.
func push(route: StdRoute, params: StdRouteParams) -> void:
	var entry := Entry.new()
	entry.route = route
	entry.params = params
	_entries.append(entry)


## pop removes and returns the topmost entry, or null if empty.
func pop() -> Entry:
	if _entries.is_empty():
		return null
	return _entries.pop_back()


## peek returns the topmost entry without removing it, or null.
func peek() -> Entry:
	if _entries.is_empty():
		return null
	return _entries.back()


## is_empty returns whether the stack has no entries.
func is_empty() -> bool:
	return _entries.is_empty()


## size returns the number of entries in the stack.
func size() -> int:
	return _entries.size()


## clear removes all entries from the stack.
func clear() -> void:
	_entries.clear()


## entries returns the backing array (read-only contract).
func entries() -> Array[Entry]:
	return _entries
