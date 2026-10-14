class_name Loc
## Languages. Each locale/<code>.json maps English source text to its translation.
## English text in the code is the key, so anything untranslated falls back to English.

const LANGS := [
	["auto", "Auto"], ["en", "English"], ["es", "Español"], ["pt_BR", "Português (Brasil)"],
	["fr", "Français"], ["de", "Deutsch"], ["it", "Italiano"], ["pl", "Polski"], ["ru", "Русский"],
	["uk", "Українська"], ["tr", "Türkçe"], ["zh_CN", "简体中文"], ["zh_TW", "繁體中文"], ["ja", "日本語"], ["ko", "한국어"],
]

# Steam's getCurrentGameLanguage() names -> our codes.
const STEAM := {
	"english": "en", "spanish": "es", "latam": "es", "brazilian": "pt_BR", "portuguese": "pt_BR", "french": "fr",
	"german": "de", "italian": "it", "polish": "pl", "russian": "ru", "ukrainian": "uk", "turkish": "tr",
	"schinese": "zh_CN", "tchinese": "zh_TW", "japanese": "ja", "koreana": "ko",
}

static var _loaded := false
static var steam_lang := ""


static func load_all() -> void:
	if _loaded:
		return
	_loaded = true
	for l in LANGS:
		var code: String = l[0]
		var path := "res://locale/%s.json" % code
		if code in ["auto", "en"] or not FileAccess.file_exists(path):
			continue
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(parsed) != TYPE_DICTIONARY:
			push_warning("Bad translation file: " + path)
			continue
		var t := Translation.new()
		t.locale = code
		for k in parsed:
			var v := str(parsed[k])
			if v != "" and not k.begins_with("_"):
				t.add_message(k, v)
		TranslationServer.add_translation(t)


static func resolve(lang: String) -> String:
	if lang != "auto":
		return lang
	if steam_lang != "" and STEAM.has(steam_lang):
		return STEAM[steam_lang]
	var os := OS.get_locale()  # e.g. "pt_BR", "zh_CN", "de_DE"
	for l in LANGS:
		if l[0] == os:
			return os
	if os.begins_with("zh"):
		return "zh_TW" if ("TW" in os or "HK" in os or "Hant" in os) else "zh_CN"
	if os.begins_with("pt"):
		return "pt_BR"
	return OS.get_locale_language()


static func apply(lang: String) -> void:
	load_all()
	TranslationServer.set_locale(resolve(lang))


static func cjk_order() -> Array:
	## Preferred CJK font order for the active language (Han glyphs differ by region).
	var loc := TranslationServer.get_locale()
	if loc.begins_with("ja"):
		return ["ja", "ko", "zh_CN", "zh_TW"]
	if loc.begins_with("ko"):
		return ["ko", "ja", "zh_CN", "zh_TW"]
	if loc == "zh_TW":
		return ["zh_TW", "zh_CN", "ja", "ko"]
	return ["zh_CN", "zh_TW", "ja", "ko"]
