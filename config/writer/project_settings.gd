##
## std/config/writer/project_settings.gd
##
## StdProjectSettingsConfigWriter synchronizes the provided `Config` instance with the
## project settings override file. File contents will be written as UTF8-encoded text.
##
## WARNING: Parsing `ConfigFile` objects from files is insecure [1]. If possible, avoid
## the use of this `ConfigWriter`. However, project settings overrides are currently the
## only means of configuring different settings at startup, so the tradeoff can be made.
##
## [1] https://github.com/godotengine/godot/issues/80562
##

class_name StdProjectSettingsConfigWriter
extends StdConfigWriter

# -- INITIALIZATION ------------------------------------------------------------------ #

var _config_file: ConfigFile = null

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	assert(_get_filepath() != "", "missing project settings override path")
	_config_file = ConfigFile.new()
	_logger = _logger.named(&"std/config/writer/project-settings")


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _deserialize_var(bytes: PackedByteArray) -> Variant:
	var out: Dictionary = {}

	var cfg := ConfigFile.new()
	var err := cfg.parse(bytes.get_string_from_utf8())
	if err != OK:
		return out

	for section in cfg.get_sections():
		var category := {}
		out[section] = category

		for key in cfg.get_section_keys(section):
			var value: Variant = cfg.get_value(section, key)
			assert(value != null, "parsed invalid value from file")

			category[key] = value

	return out


# NOTE: This method must be overridden.
func _get_filepath() -> String:
	return ProjectSettings.get_setting_with_override(
		&"application/config/project_settings_override"
	)


func _serialize_var(variant: Variant) -> PackedByteArray:
	assert(variant is Dictionary, "invalid input: expected dictionary")

	var cfg := ConfigFile.new()

	for category in variant:
		var values: Dictionary = variant[category]
		assert(values is Dictionary, "invalid input: expected dictionary")

		for key in values:
			cfg.set_value(category, key, values[key])

	return cfg.encode_to_text().to_utf8_buffer()
