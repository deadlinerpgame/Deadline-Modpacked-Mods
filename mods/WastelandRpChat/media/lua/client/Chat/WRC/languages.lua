if not isClient() then return end -- only in MP
WRC = WRC or {}

-- Define possible languages
WRC.Languages = {}
WRC.Languages["en"] = {
    name = "English",
    partialUnderstanding = {
        ["pen"] = 20,
        ["pcm"] = 20,
    },
}
WRC.Languages["pen"] = {
    name = "Broken English",
    noFullSelfUnderstand = true,
    partialUnderstanding = {
        ["en"] = 20,
        ["pen"] = 20,
    },
}
WRC.Languages["asl"] = {
    name = "American Sign Language",
}
WRC.Languages["es"] = {
    name = "Spanish",
    partialUnderstanding = {
        ["pt"] = 22,
    },
}
WRC.Languages["fr"] = {
    name = "French",
}
WRC.Languages["de"] = {
    name = "German",
    partialUnderstanding = {
        ["yi"] = 15,
    },
    canFullyUnderstand = {"nl"},
}
WRC.Languages["it"] = {
    name = "Italian",
    partialUnderstanding = {
        ["es"] = 18,
        ["pt"] = 15,
        ["ro"] = 12,
    },
}
WRC.Languages["ru"] = {
    name = "Russian",
    partialUnderstanding = {
        ["bg"] = 14,
    },
    canFullyUnderstand = {"uk"},
}
WRC.Languages["zh"] = {
    name = "Chinese",
}
WRC.Languages["ja"] = {
    name = "Japanese",
}
WRC.Languages["ko"] = {
    name = "Korean",
}
WRC.Languages["pt"] = {
    name = "Portuguese",
    partialUnderstanding = {
        ["es"] = 22,
    },
}
WRC.Languages["pl"] = {
    name = "Polish",
}
WRC.Languages["sv"] = {
    name = "Swedish",
    partialUnderstanding = {
        ["no"] = 22,
        ["da"] = 16,
    },
}
WRC.Languages["nl"] = {
    name = "Dutch",
    partialUnderstanding = {
        ["af"] = 24,
    },
    canFullyUnderstand = {"de"},
}
WRC.Languages["cs"] = {
    name = "Czech",
    partialUnderstanding = {
        ["sk"] = 25,
    },
}
WRC.Languages["hu"] = {
    name = "Hungarian",
}
WRC.Languages["fn"] = {
    name = "Finnish",
}
WRC.Languages["tr"] = {
    name = "Turkish",
}
WRC.Languages["no"] = {
    name = "Norwegian",
    partialUnderstanding = {
        ["sv"] = 22,
        ["da"] = 18,
    },
}
WRC.Languages["da"] = {
    name = "Danish",
    partialUnderstanding = {
        ["sv"] = 16,
        ["no"] = 18,
    },
}
WRC.Languages["ro"] = {
    name = "Romanian",
    partialUnderstanding = {
        ["it"] = 12,
    },
}
WRC.Languages["bg"] = {
    name = "Bulgarian",
    partialUnderstanding = {
        ["ru"] = 14,
        ["sr"] = 16,
    },
}
WRC.Languages["el"] = {
    name = "Greek",
}
WRC.Languages["uk"] = {
    name = "Ukrainian",
    canFullyUnderstand = {"ru"},
}
WRC.Languages["sk"] = {
    name = "Slovak",
    partialUnderstanding = {
        ["cs"] = 25,
    },
}
WRC.Languages["hr"] = {
    name = "Croatian",
    partialUnderstanding = {
        ["sr"] = 24,
        ["bo"] = 24,
        ["sl"] = 16,
    },
}
WRC.Languages["sr"] = {
    name = "Serbian",
    partialUnderstanding = {
        ["hr"] = 24,
        ["bg"] = 16,
        ["bo"] = 24,
    },
}
WRC.Languages["sl"] = {
    name = "Slovenian",
    partialUnderstanding = {
        ["hr"] = 16,
        ["sr"] = 14,
        ["bo"] = 15,
    },
}
WRC.Languages["lt"] = {
    name = "Lithuanian",
}
WRC.Languages["lv"] = {
    name = "Latvian",
}
WRC.Languages["et"] = {
    name = "Estonian",
}
WRC.Languages["ar"] = {
    name = "Arabic",
}
WRC.Languages["he"] = {
    name = "Hebrew",
}
WRC.Languages["th"] = {
    name = "Thai",
}
WRC.Languages["vi"] = {
    name = "Vietnamese",
}
WRC.Languages["id"] = {
    name = "Indonesian",
    partialUnderstanding = {
        ["ms"] = 24,
        ["fi"] = 8,
        ["ta"] = 8,
    },
}
WRC.Languages["ms"] = {
    name = "Malay",
    partialUnderstanding = {
        ["id"] = 24,
        ["fi"] = 8,
        ["ta"] = 8,
    },
}
WRC.Languages["hi"] = {
    name = "Hindi",
    partialUnderstanding = {
        ["ur"] = 24,
        ["mr"] = 14,
        ["pnb"] = 12,
        ["gu"] = 10,
        ["bho"] = 18,
    },
}
WRC.Languages["bn"] = {
    name = "Bengali",
}
WRC.Languages["fa"] = {
    name = "Persian",
    canFullyUnderstand = {"prs"},
}
WRC.Languages["ur"] = {
    name = "Urdu",
    partialUnderstanding = {
        ["hi"] = 24,
    },
}
WRC.Languages["sw"] = {
    name = "Swahili",
}
WRC.Languages["af"] = {
    name = "Afrikaans",
    partialUnderstanding = {
        ["nl"] = 24,
    },
}
WRC.Languages["eo"] = {
    name = "Esperanto",
}
WRC.Languages["is"] = {
    name = "Icelandic",
}
WRC.Languages["cy"] = {
    name = "Welsh",
}
WRC.Languages["yi"] = {
    name = "Yiddish",
    partialUnderstanding = {
        ["de"] = 15,
    },
}
WRC.Languages["la"] = {
    name = "Latin",
}
WRC.Languages["ga"] = {
    name = "Gaelic",
}
WRC.Languages["hw"] = {
    name = "Hawaiian",
}
WRC.Languages["al"] = {
    name = "Albanian",
}
WRC.Languages["bo"] = {
    name = "Bosnian",
    partialUnderstanding = {
        ["hr"] = 24,
        ["sr"] = 24,
        ["sl"] = 15,
    },
}
WRC.Languages["fi"] = {
    name = "Filipino",
    partialUnderstanding = {
        ["ms"] = 8,
        ["id"] = 8,
        ["ta"] = 20,
    },
    canFullyUnderstand = {"ta"},
}
WRC.Languages["ta"] = {
    name = "Tagalog",
    partialUnderstanding = {
        ["ms"] = 8,
        ["id"] = 8,
        ["fi"] = 20,
    },
    canFullyUnderstand = {"fi"},
}
WRC.Languages["pcm"] = {
    name = "Nigerian Pidgin",
    partialUnderstanding = {
        ["en"] = 20,
        ["pen"] = 14,
    },
}
WRC.Languages["mr"] = {
    name = "Marathi",
    partialUnderstanding = {
        ["hi"] = 14,
    },
}
WRC.Languages["te"] = {
    name = "Telugu",
    partialUnderstanding = {
        ["tam"] = 10,
    },
}
WRC.Languages["ha"] = {
    name = "Hausa",
}
WRC.Languages["tam"] = {
    name = "Tamil",
    partialUnderstanding = {
        ["te"] = 10,
    },
    canFullyUnderstand = {"si"},
}
WRC.Languages["pnb"] = {
    name = "Western Punjabi",
    partialUnderstanding = {
        ["hi"] = 12,
        ["ur"] = 16,
    },
}
WRC.Languages["jv"] = {
    name = "Javanese",
}
WRC.Languages["gu"] = {
    name = "Gujarati",
    partialUnderstanding = {
        ["hi"] = 10,
    },
}
WRC.Languages["bho"] = {
    name = "Bhojpuri",
    partialUnderstanding = {
        ["hi"] = 18,
    },
}
WRC.Languages["si"] = {
    name = "Sinhala",
    canFullyUnderstand = {"tam"},
}
WRC.Languages["prs"] = {
    name = "Farsi",
    canFullyUnderstand = {"fa"},
}
WRC.Languages["sal"] = {
    name = "Salish",
}
WRC.Languages["nad"] = {
    name = "Na-Dene",
}
WRC.Languages["uto"] = {
    name = "Uto-Aztecan",
}
WRC.Languages["apa"] = {
    name = "Apachean",
    partialUnderstanding = {
        ["nad"] = 5,
    },
}
WRC.Languages["alg"] = {
    name = "Algonquian",
}
WRC.Languages["inu"] = {
    name = "Inuit",
}
WRC.Languages["iro"] = {
    name = "Iroquoian",
}
WRC.Languages["sio"] = {
    name = "Siouan",
}
WRC.Languages["sah"] = {
    name = "Sahaptian",
}
WRC.Languages["mus"] = {
    name = "Muskogean ",
}
