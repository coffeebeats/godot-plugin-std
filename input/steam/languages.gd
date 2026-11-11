##
## std/input/steam/languages.gd
##
## StdInputSteamLanguages names the locale each of Steam's API languages is written for.
##
## NOTE: This 'Object' should *not* be instanced and/or added to the 'SceneTree'.
##

class_name StdInputSteamLanguages
extends Object

# -- DEFINITIONS --------------------------------------------------------------------- #

## LOCALES maps each of Steam's API language names to the locale it is written for, as
## Godot spells it. A language precedes its regional variants, so a locale equally close
## to two of them, such as `pt`, matches the language. See
## https://partner.steamgames.com/doc/store/localization/languages.
##
## NOTE: Godot drops the `419` region Steam names for `latam`, so it is `es_MX` here.
const LOCALES: Dictionary[String, String] = {
	"english": "en",
	"arabic": "ar",
	"bulgarian": "bg",
	"czech": "cs",
	"danish": "da",
	"dutch": "nl",
	"finnish": "fi",
	"french": "fr",
	"german": "de",
	"greek": "el",
	"hungarian": "hu",
	"indonesian": "id",
	"italian": "it",
	"japanese": "ja",
	"koreana": "ko",
	"malay": "ms",
	"norwegian": "nb",
	"polish": "pl",
	"portuguese": "pt_PT",
	"brazilian": "pt_BR",
	"romanian": "ro",
	"russian": "ru",
	"spanish": "es_ES",
	"latam": "es_MX",
	"swedish": "sv",
	"schinese": "zh_CN",
	"tchinese": "zh_TW",
	"thai": "th",
	"turkish": "tr",
	"ukrainian": "uk",
	"vietnamese": "vi",
}
