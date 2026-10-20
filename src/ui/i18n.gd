extends RefCounted
## Localisation. Source strings are the Brazilian Portuguese texts themselves;
## locale/strings.csv maps them to English and Spanish (Godot imports the CSV as
## translations, see project.godot). Untranslated strings fall back to Portuguese.
## Status values in the simulation stay in Portuguese (they are logic keys) and
## are translated only where they are shown.

const LANGS := [["", "Automático (sistema)"], ["pt_BR", "Português (Brasil)"], ["en", "English"], ["es", "Español"]]


static func t(s: String) -> String:
	return TranslationServer.translate(s)


## "" follows the operating system, falling back to Portuguese when its language
## is not one we ship.
static func apply(lang: String) -> void:
	if lang == "":
		var os := OS.get_locale_language()
		lang = os if os in ["en", "es"] else "pt_BR"
	TranslationServer.set_locale(lang)


static func current() -> String:
	return TranslationServer.get_locale()
