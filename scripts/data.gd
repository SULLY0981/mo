class_name Data
## All game content and balance numbers live here. Distances are meters, speeds m/s.

const DAWN_TIME := 720.0

# Store link for the demo's Wishlist button. Replace with your app's page once it exists,
# e.g. "https://store.steampowered.com/app/1234560/The_Last_Lantern/".
const STEAM_URL := "https://store.steampowered.com/search/?term=The+Last+Lantern"


static func demo() -> bool:
	## Demo builds export with the "demo" feature tag; --demo on the command line tests it.
	return OS.has_feature("demo") or "--demo" in OS.get_cmdline_user_args()

const ENEMIES := {
	"wisp":     {"hp": 9.0,   "speed": 2.3, "r": 0.4,  "dmg": 7.0,  "xp": 1.0, "color": "8a5cff"},
	"bat":      {"hp": 5.0,   "speed": 4.0, "r": 0.34, "dmg": 5.0,  "xp": 1.0, "color": "ff4d8d", "erratic": true, "hover": 0.9},
	"spitter":  {"hp": 20.0,  "speed": 1.9, "r": 0.45, "dmg": 6.0,  "xp": 2.0, "color": "a8ff2a", "ranged": true},
	"brute":    {"hp": 70.0,  "speed": 1.4, "r": 0.65, "dmg": 14.0, "xp": 4.0, "color": "4dc3ff", "heavy": 0.75},
	"splitter": {"hp": 28.0,  "speed": 1.95, "r": 0.45, "dmg": 9.0, "xp": 2.0, "color": "ffb52e", "splits": true},
	"mite":     {"hp": 7.0,   "speed": 3.2, "r": 0.28, "dmg": 5.0,  "xp": 1.0, "color": "ffb52e"},
	"ghoul":    {"hp": 110.0, "speed": 1.85, "r": 0.52, "dmg": 18.0, "xp": 6.0, "color": "ff6a1a", "heavy": 0.5},
	"gourd":    {"hp": 32.0,  "speed": 2.7, "r": 0.45, "dmg": 20.0, "xp": 3.0, "color": "ff8a2a", "fuse": true},
	# Scarecrows only move while they are outside your lantern's light.
	"scarecrow": {"hp": 60.0, "speed": 4.4, "r": 0.5, "dmg": 16.0, "xp": 4.0, "color": "c9a35a", "stalker": true},
}

const BOSSES := {
	"warden": {"name": "The Ashen Warden", "hp": 1800.0,  "r": 1.3, "speed": 2.25, "dmg": 24.0, "xp": 120.0, "color": "ff3d6e", "moves": ["dash", "dash", "ring"]},
	"choir":  {"name": "The Hollow Choir", "hp": 4500.0,  "r": 1.4, "speed": 1.7,  "dmg": 22.0, "xp": 220.0, "color": "a46bff", "moves": ["ring", "summon", "spiral"]},
	"witch":  {"name": "The Harvest Witch", "hp": 9000.0, "r": 1.2, "speed": 2.0, "dmg": 22.0, "xp": 300.0, "color": "9dff5c", "moves": ["gourds", "spiral", "blink", "ring"]},
	"king":   {"name": "The Hollow King",  "hp": 22000.0, "r": 1.8, "speed": 1.95, "dmg": 32.0, "xp": 600.0, "color": "ffd166", "moves": ["dash", "ring", "summon", "spiral"]},
}

# [time, boss, hp multiplier]
const BOSS_SCHEDULE := [[180.0, "warden", 1.0], [360.0, "choir", 1.0], [540.0, "witch", 1.0], [720.0, "king", 1.0]]

# [time, enemy, count, message]
const EVENTS := [
	[90.0, "bat", 28, "A swarm approaches!"],
	[250.0, "wisp", 46, "They surround you..."],
	[430.0, "bat", 60, "A great swarm descends!"],
	[600.0, "brute", 32, "The night closes in..."],
	[680.0, "ghoul", 40, "The final hour!"],
]

# up[i] describes the upgrade to level i + 2
const WEAPONS := {
	"bolt":   {"name": "Ember Bolt", "color": "ffaa44", "max": 6, "desc": "Hurls homing embers at the nearest enemies.",
		"up": ["+5 Damage", "+1 Ember", "+1 Pierce", "+1 Ember", "+10 Damage, faster casting"]},
	"halo":   {"name": "Sun Halo", "color": "ffd24a", "max": 6, "desc": "Orbs of flame circle you, scorching all they touch.",
		"up": ["+1 Orb", "+35% Damage", "+1 Orb, +15% Radius", "+35% Damage, faster spin", "+2 Orbs"]},
	"pulse":  {"name": "Lantern Pulse", "color": "ff6bd6", "max": 6, "desc": "A burst of light that damages and repels nearby foes.",
		"up": ["+15% Radius", "+8 Damage", "-15% Cooldown", "+15% Radius, +8 Damage", "Pulses twice"]},
	"arc":    {"name": "Storm Arc", "color": "7fd8ff", "max": 6, "desc": "Lightning that leaps from enemy to enemy.",
		"up": ["+1 Chain", "+6 Damage", "+2 Chains", "-20% Cooldown", "+2 Chains, +8 Damage"]},
	"scythe": {"name": "Moon Scythe", "color": "c9a0ff", "max": 6, "desc": "Spectral blades that fly out and return to you.",
		"up": ["+8 Damage", "+1 Scythe", "+25% Size", "+1 Scythe, +8 Damage", "+12 Damage, faster throws"]},
	"mines":  {"name": "Lantern Seeds", "color": "9dff5c", "max": 6, "desc": "Plants seeds of fire that burst when enemies draw near.",
		"up": ["+8 Damage", "+1 Seed", "+20% Blast Radius", "-20% Cooldown", "+1 Seed, +15 Damage"]},
	"frost":  {"name": "Frost Shards", "color": "a0e9ff", "max": 6, "desc": "Bursts icy shards in every direction, slowing enemies.",
		"up": ["+2 Shards", "+6 Damage", "+1 Pierce", "+4 Shards", "+10 Damage, -20% Cooldown"]},
}

const PASSIVES := {
	"vigor":   {"name": "Hearthstone", "color": "ff5d73", "desc": "+20% Max HP", "max": 5},
	"swift":   {"name": "Wind Boots",  "color": "7cf5c8", "desc": "+8% Move Speed", "max": 5},
	"might":   {"name": "Ember Heart", "color": "ff8a3d", "desc": "+10% Damage", "max": 5},
	"haste":   {"name": "Hourglass",   "color": "ffd166", "desc": "-7% Cooldowns", "max": 5},
	"reach":   {"name": "Wide Lens",   "color": "b38cff", "desc": "+10% Area", "max": 5},
	"multi":   {"name": "Twin Wick",   "color": "ffe08a", "desc": "+1 Projectile", "max": 2},
	"magnet":  {"name": "Lodestone",   "color": "6ec6ff", "desc": "+30% Pickup Range", "max": 5},
	"wisdom":  {"name": "Old Tome",    "color": "c4f07a", "desc": "+8% XP Gain", "max": 5},
	"plating": {"name": "Iron Ward",   "color": "b0b8c8", "desc": "+1 Armor", "max": 5},
	"renewal": {"name": "Sap Vial",    "color": "7dff9a", "desc": "+0.3 HP/s Recovery", "max": 5},
	"luck":    {"name": "Four-Leaf",   "color": "5dff8f", "desc": "+10% Luck", "max": 5},
	"light":   {"name": "Bright Oil",  "color": "fff3b0", "desc": "+15% Light Radius. Enemies in your light take +15% damage.", "max": 3},
	"cinder":  {"name": "Cinder Step", "color": "ff7a3d", "desc": "Your dash scorches enemies in its path and recharges 15% faster.", "max": 3},
}

# Nights: difficulty levels. Winning Night N unlocks N+1. Effects stack.
const NIGHTS := [
	"The night as you know it.",
	"Shadows endure: enemies have +30% health.",
	"The dark hastens: enemies move 12% faster.",
	"Tyrants rise: bosses have +50% health and elites come more often.",
	"The longest night: healing is halved and the Blood Moon never sets.",
]
const NIGHT_HP := 1.3
const NIGHT_SPEED := 1.12
const NIGHT_BOSS_HP := 1.5
const NIGHT_REWARD := 0.25  # extra Embers per Night above the first

# Awakening: a maxed weapon + its paired relic -> the next chest awakens it.
const AWAKEN := {"bolt": "might", "halo": "light", "pulse": "reach", "arc": "haste", "scythe": "swift", "mines": "luck", "frost": "plating"}
# What each weapon gains on top of the damage and speed when awakened.
const AWAKEN_DESC := {
	"bolt": "Embers explode on impact.",
	"halo": "Its orbs burn hotter and wider.",
	"pulse": "Each enemy struck heals you a little.",
	"arc": "Lightning leaps further.",
	"scythe": "Blades grow larger and hit harder.",
	"mines": "Seeds burst in a much wider blast.",
	"frost": "Slowed enemies shatter, hurting those nearby.",
}
const AWAKEN_DMG := 1.4
const AWAKEN_RATE := 1.15

# Dash: seconds of cooldown, speed while dashing (m/s), and duration.
const DASH_CD := 3.2
const DASH_SPEED := 21.0
const DASH_TIME := 0.2

const CHAR_ORDER := ["keeper", "warden", "reaper", "seer", "alchemist", "saint", "ember"]
const CHARS := {
	"keeper":    {"name": "The Keeper", "weapon": "bolt", "color": "6a4bb0", "desc": "Balanced in all things. The last of the lamplighters.", "mods": {}},
	"warden":    {"name": "The Warden", "weapon": "halo", "color": "b0462e", "desc": "+30% HP, +1 Armor, -10% Speed.", "mods": {"hp": 1.3, "armor": 1, "speed": 0.9}, "unlock": "ACH_SURVIVE_5"},
	"reaper":    {"name": "The Reaper", "weapon": "scythe", "color": "2a2a3a", "desc": "+15% Damage, +10% Speed, -25% HP.", "mods": {"hp": 0.75, "might": 1.15, "speed": 1.1}, "unlock": "ACH_BOSS"},
	"seer":      {"name": "The Seer", "weapon": "arc", "color": "2e7f9a", "desc": "+25% XP gain, -20% HP.", "mods": {"hp": 0.8, "growth": 0.25}, "unlock": "ACH_KILLS_1000"},
	"alchemist": {"name": "The Alchemist", "weapon": "mines", "color": "3d7a2e", "desc": "+20% Area, +10% Luck.", "mods": {"area": 1.2, "luck": 0.1}, "unlock": "ACH_SURVIVE_10"},
	"saint":     {"name": "The Pale Saint", "weapon": "frost", "color": "c8d6e8", "desc": "-15% Cooldowns, -15% HP.", "mods": {"hp": 0.85, "cd": 0.85}, "unlock": "ACH_DAWN"},
	"ember":     {"name": "The Ember Child", "weapon": "pulse", "color": "b03a7a", "desc": "+1 Projectile, +20% Light, -10% Damage.", "mods": {"amount": 1, "light": 1.2, "might": 0.9}, "unlock": "ACH_ENDLESS_20"},
}

const SHOP := [
	{"id": "hp",     "name": "Vitality",     "desc": "+10 Max HP",          "max": 5, "base": 60},
	{"id": "might",  "name": "Might",        "desc": "+5% Damage",          "max": 5, "base": 100},
	{"id": "armor",  "name": "Armor",        "desc": "+1 Armor",            "max": 3, "base": 150},
	{"id": "regen",  "name": "Recovery",     "desc": "+0.1 HP/s",           "max": 5, "base": 80},
	{"id": "speed",  "name": "Swiftness",    "desc": "+4% Move Speed",      "max": 3, "base": 90},
	{"id": "cd",     "name": "Haste",        "desc": "-3% Cooldowns",       "max": 3, "base": 200},
	{"id": "area",   "name": "Reach",        "desc": "+4% Area",            "max": 3, "base": 150},
	{"id": "magnet", "name": "Attraction",   "desc": "+15% Pickup Range",   "max": 3, "base": 50},
	{"id": "growth", "name": "Growth",       "desc": "+4% XP Gain",         "max": 5, "base": 120},
	{"id": "greed",  "name": "Greed",        "desc": "+10% Embers earned",  "max": 5, "base": 80},
	{"id": "luck",   "name": "Luck",         "desc": "+5% Luck",            "max": 3, "base": 120},
	{"id": "reroll", "name": "Fate",         "desc": "+1 Reroll per run",   "max": 3, "base": 150},
	{"id": "revive", "name": "Second Flame", "desc": "Revive once per run", "max": 1, "base": 1000},
]

static func shop_cost(item: Dictionary, lvl: int) -> int:
	return int(round(item.base * (1 + lvl) * pow(1.35, lvl)))

const ACHIEVEMENTS := [
	{"id": "ACH_FIRST_NIGHT", "name": "First Night", "desc": "Finish your first run."},
	{"id": "ACH_SURVIVE_5", "name": "Holding the Line", "desc": "Survive for 5 minutes."},
	{"id": "ACH_SURVIVE_10", "name": "Deep Night", "desc": "Survive for 10 minutes."},
	{"id": "ACH_BOSS", "name": "Wardenbane", "desc": "Defeat a boss."},
	{"id": "ACH_DAWN", "name": "Dawnbringer", "desc": "Defeat the Hollow King and bring the dawn."},
	{"id": "ACH_ENDLESS_20", "name": "Endless Night", "desc": "Survive for 20 minutes."},
	{"id": "ACH_KILLS_1000", "name": "Thousand Shadows", "desc": "Defeat 1,000 enemies in a single run."},
	{"id": "ACH_KILLS_TOTAL", "name": "Lightkeeper", "desc": "Defeat 10,000 enemies in total."},
	{"id": "ACH_LEVEL_30", "name": "Radiant", "desc": "Reach level 30 in a single run."},
	{"id": "ACH_MAX_WEAPON", "name": "Perfected", "desc": "Upgrade a weapon to its maximum level."},
	{"id": "ACH_ARSENAL", "name": "Full Arsenal", "desc": "Hold 6 weapons at once."},
	{"id": "ACH_RICH", "name": "Hoarder", "desc": "Have 2,000 Embers saved."},
	{"id": "ACH_NO_HIT_3", "name": "Untouchable", "desc": "Survive the first 3 minutes without taking damage."},
	{"id": "ACH_ALL_CHARS", "name": "Fellowship of Flame", "desc": "Unlock every Keeper."},
	{"id": "ACH_SHRINE", "name": "Rekindled", "desc": "Light a lantern shrine."},
	{"id": "ACH_SHRINES_25", "name": "Keeper of Shrines", "desc": "Light 25 lantern shrines in total."},
	{"id": "ACH_MEMORIES", "name": "Keeper of Memory", "desc": "Recover every memory of the Order."},
	{"id": "ACH_PUMPKINS", "name": "Trick or Treat", "desc": "Smash 100 jack-o'-lanterns."},
	{"id": "ACH_AWAKEN", "name": "Awakening", "desc": "Awaken a weapon with its paired relic."},
	{"id": "ACH_NIGHT_5", "name": "The Longest Night", "desc": "Bring the dawn on Night 5."},
]

# ---------------------------------------------------------------- map
# Regions of the night. The starting clearing is always the Graveyard.
const REGIONS := [
	{"name": "The Graveyard", "color": "b9a7ff"},
	{"name": "The Pumpkin Fields", "color": "ff9a3d"},
	{"name": "The Dead Woods", "color": "7fd8a0"},
	{"name": "The Chapel Ruins", "color": "c8c0d8"},
]
const SHRINE_TIME := 2.5  # seconds standing beside a shrine to kindle it
const BLESSINGS := [
	{"id": "warmth", "name": "Blessing of Warmth", "desc": "Your wounds close."},
	{"id": "insight", "name": "Blessing of Insight", "desc": "You grow stronger."},
	{"id": "fury", "name": "Blessing of Fury", "desc": "+50% damage for 30 seconds."},
	{"id": "haste", "name": "Blessing of Haste", "desc": "Faster weapons and feet for 30 seconds."},
]

# ---------------------------------------------------------------- story
const INTRO := [
	"One hundred nights ago, the sun did not rise.",
	"The Lamplighters kept the shrines burning and the dark at bay. One by one, their lights went out.",
	"Now only one lantern remains. Yours.",
	"Survive until dawn. Rekindle the shrines. Remember.",
]
const MEMORIES := [
	{"title": "The First Lamp", "text": "Before the Order, before the shrines, a girl carried a candle into the woods so her brother could find his way home. She never stopped carrying it. Every Lamplighter since is her child."},
	{"title": "The Three Vows", "text": "Keep the flame. Share the flame. Never hoard the flame. Every Lamplighter speaks the three vows on the night of their first watch."},
	{"title": "Aldric", "text": "Aldric was the best of us. He could light a lantern with a whisper. He was also the most afraid: of the dark, of the cold, of losing anyone at all."},
	{"title": "Hallow's Eve", "text": "Every Hallow's Eve the villages carved faces into pumpkins and set our embers inside, so the dead could find their way. The dead found their way. So did other things."},
	{"title": "The Ashen Warden", "text": "The Warden guarded the eastern road for forty years. When the dark took him, he kept guarding it. He only forgot what he was guarding it from."},
	{"title": "The Hollow Choir", "text": "Seven sisters sang the lantern hymns at the great shrine. When the dark came they would not stop singing. They are singing still. The words are wrong now."},
	{"title": "The Theft", "text": "Aldric climbed the eastern hill before dawn and opened his lantern wide. The sun went in, and did not come out. \"Now it can never go out,\" he said. \"Now no one will ever be cold.\""},
	{"title": "Hollow", "text": "A lantern that holds the sun has no room for anything else. Aldric's name went first. Then his face. What remains wears a crown of dead candles and calls itself King."},
	{"title": "The Shrines Go Dark", "text": "Without the dawn, the shrines burn only what we give them. We gave them oil, then wood, then our own warmth. One by one, the Keepers went quiet."},
	{"title": "The Pumpkin Fields", "text": "The fields still glow every Hallow's Eve. No one carves the pumpkins anymore. They carve themselves, and wait for someone to bring them a light."},
	{"title": "The Last Keeper", "text": "When they lit your lantern, they told you the truth: you would not be strong enough. Then they told you the rest: you would not be alone. Every flame you rekindle remembers us."},
	{"title": "What the King Fears", "text": "He does not fear your fire. He fears the moment you open your lantern and let the light go. He has forgotten that light given away is never lost."},
]
# ---------------------------------------------------------------- dialogue
# Speakers: "self" (the Keeper you play), a boss id, or "spirit". [speaker, line]
const SPEAKERS := {
	"spirit": {"name": "Lamplighter's Spirit", "color": "a8d8ff"},
}
# Each Keeper says one of these as a run begins.
const KEEPER_LINES := {
	"keeper": ["Another night. Another walk into the dark. Stay lit, little flame.", "The Order is gone. The vows are not."],
	"warden": ["I held the western gate for twenty years. I can hold one more night.", "Shield up. Light high. Let them come."],
	"reaper": ["They call me Reaper. I only cut what the dark has already taken.", "Quick hands, short night."],
	"seer": ["I have seen this night end. I have not seen how.", "The storm remembers the sky. So do I."],
	"alchemist": ["Seeds of fire, a pinch of luck, and no plan at all. Perfect.", "Every shadow burns at the right temperature."],
	"saint": ["The cold does not frighten me. I was born in it.", "Be still, little lights. I am here."],
	"ember": ["I was lit from the last ember of the great shrine. I will not go out.", "Is it always this dark? Then I will burn brighter."],
}
# Conversations that pause the game the first time they happen.
const DIALOGUE := {
	"boss_warden": [
		["warden", "Halt. None pass the eastern road after dark."],
		["self", "Warden, it is always dark now. The sun is gone."],
		["warden", "Then none shall pass. Ever. Those are my orders."],
	],
	"boss_choir": [
		["choir", "Sing with us, little light. Sing the hymn of the long night."],
		["self", "Those are not the lantern hymns. You have changed the words."],
		["choir", "The words changed us. Come. There is room in the chorus."],
	],
	"boss_witch": [
		["witch", "Oh, a little lantern, wandering my fields on Hallow's Eve! How delicious."],
		["self", "These fields belonged to the villages. Where are the people who planted them?"],
		["witch", "Sleeping under the pumpkins, dearie. And every pumpkin needs a candle."],
	],
	"boss_king": [
		["king", "Another lantern. How many of you must I put out before you understand?"],
		["self", "Aldric. The Order remembers you."],
		["king", "That name is gone. I gave it away, with my face and my warmth, to keep the sun safe."],
		["king", "Out there it would have set. In here, it never ends. No one will ever be cold again."],
		["self", "Everyone is cold, Aldric. You took the sun from all of us."],
		["king", "Then come and take it back, if your little flame can bear it."],
	],
}
# One-line remarks that never pause the game.
const BARKS := {
	"boss_warden": [["warden", "None pass."]],
	"boss_warden2": [["warden", "I held the road. I will hold it again. And again. And again."]],
	"boss_choir": [["choir", "Sing with us..."]],
	"boss_king": [["king", "Another lantern. Again."]],
	"boss_witch": [["witch", "Back for another treat, dearie?"]],
	"defeat_witch": [["witch", "My lovely pumpkins... who will carve you now?"]],
	"defeat_warden": [["warden", "The road... is clear. Tell the captain... I held."]],
	"defeat_choir": [["choir", "Ah... we remember the old tune now. Thank you."]],
	"defeat_king": [["king", "It is... so warm. I had forgotten. Thank you, Keeper."]],
	"shrine": [
		["spirit", "You came. We waited so long in the dark."],
		["spirit", "Our flame is yours now. Carry it further than we could."],
		["spirit", "I was a Lamplighter once. Remember us when the sun returns."],
		["spirit", "Warm... it is warm again. Go on, Keeper."],
		["spirit", "Aldric was my friend. Save him, if anything is left to save."],
	],
}
# The true ending, after bringing the dawn on Night 5.
const ENDING_TRUE := [
	"On the longest night, a Keeper walked where no one had walked before, and did not go out.",
	"The Order's shrines blaze again, one after another, across the whole of the world.",
	"In the first light, the spirits of the Lamplighters gather around you. Aldric stands among them, his face returned.",
	"\"Keep the flame,\" they say together. \"You always did.\"",
]

const ENDING := [
	"The King's lantern cracks, and the stolen dawn spills across the graves and the fields.",
	"Somewhere in the light, a tired voice says a name it had forgotten, Aldric, and is warm at last.",
	"The night is over. But the Order teaches that there is always another night, and always someone who needs a light.",
	"Keep the flame. Share the flame.",
]

static func ach_by_id(id: String) -> Dictionary:
	for a in ACHIEVEMENTS:
		if a.id == id:
			return a
	return {}

static func char_unlocked_by(ach_id: String) -> String:
	for k in CHARS:
		if CHARS[k].get("unlock", "") == ach_id:
			return k
	return ""

static func item_def(id: String) -> Dictionary:
	return WEAPONS[id] if WEAPONS.has(id) else PASSIVES.get(id, {})
