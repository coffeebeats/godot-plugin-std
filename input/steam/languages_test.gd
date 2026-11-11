##
## Tests for `StdInputSteamLanguages`, the locales Steam's languages are written for.
##

extends GutTest

# -- TEST METHODS -------------------------------------------------------------------- #


func test_locales_every_locale_is_standard() -> void:
	for language in StdInputSteamLanguages.LOCALES:
		# When: The locale for one of Steam's languages is read.
		var locale := StdInputSteamLanguages.LOCALES[language]

		# Then: Godot keeps it as written, so no region is dropped.
		assert_eq(TranslationServer.standardize_locale(locale), locale, language)


func test_locales_regional_language_names_its_region(
	params = use_parameters(
		(
			ParameterFactory
			. named_parameters(
				["language", "expected"],
				[
					["portuguese", "pt_PT"],
					["brazilian", "pt_BR"],
					["spanish", "es_ES"],
					["latam", "es_MX"],
					["schinese", "zh_CN"],
					["tchinese", "zh_TW"],
				]
			)
		)
	)
) -> void:
	# When: The locale for a language Steam has regional variants of is read.
	var locale := StdInputSteamLanguages.LOCALES[params.language]

	# Then: It names the region, so a game with both catalogues gets the right one.
	assert_eq(locale, params.expected)
