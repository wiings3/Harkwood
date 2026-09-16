class_name HarkCatalog
extends RefCounted
## Read-only game content. Runtime gear stores a unique UID, rolls, and rank.

const SLOTS = ["weapon", "head", "body", "feet"]
const MATERIALS = {
	"wood": {"name": "Heartwood", "icon": 8, "value": 3},
	"hide": {"name": "Wild hide", "icon": 9, "value": 4},
	"iron": {"name": "Bog iron", "icon": 10, "value": 7},
	"amber": {"name": "Ember resin", "icon": 11, "value": 12},
	"core": {"name": "Hollow heart", "icon": 14, "value": 25},
}
const ITEMS = {
	"worn_blade": {"name": "Worn blade", "slot": "weapon", "tier": 0, "icon": 0, "stats": {"attack": 5.0}, "cost": {}, "gold": 0},
	"traveler_coat": {"name": "Traveler's coat", "slot": "body", "tier": 0, "icon": 2, "stats": {"health": 12.0, "armor": 2.0}, "cost": {}, "gold": 0},
	"iron_blade": {"name": "Hearthforged blade", "slot": "weapon", "tier": 1, "icon": 0, "stats": {"attack": 10.0}, "cost": {"wood": 3, "iron": 2}, "gold": 12},
	"hide_hood": {"name": "Hide hood", "slot": "head", "tier": 1, "icon": 1, "stats": {"health": 18.0, "armor": 3.0}, "cost": {"hide": 3, "wood": 1}, "gold": 8},
	"hide_vest": {"name": "Wayfarer's vest", "slot": "body", "tier": 1, "icon": 2, "stats": {"health": 28.0, "armor": 5.0}, "cost": {"hide": 4, "wood": 2}, "gold": 12},
	"hide_boots": {"name": "Trailworn boots", "slot": "feet", "tier": 1, "icon": 3, "stats": {"armor": 3.0, "haste": 0.06}, "cost": {"hide": 2, "wood": 2}, "gold": 8},
	"ranger_blade": {"name": "Briarsteel saber", "slot": "weapon", "tier": 2, "icon": 4, "stats": {"attack": 18.0, "crit": 0.04}, "cost": {"iron": 5, "amber": 2, "wood": 3}, "gold": 35},
	"ranger_crown": {"name": "Antler circlet", "slot": "head", "tier": 2, "icon": 5, "stats": {"health": 30.0, "armor": 6.0, "crit": 0.03}, "cost": {"hide": 4, "amber": 2}, "gold": 25},
	"ranger_coat": {"name": "Mosswarden coat", "slot": "body", "tier": 2, "icon": 6, "stats": {"health": 45.0, "armor": 10.0}, "cost": {"hide": 6, "iron": 3, "amber": 2}, "gold": 35},
	"ranger_boots": {"name": "Briarstep boots", "slot": "feet", "tier": 2, "icon": 7, "stats": {"armor": 6.0, "haste": 0.12}, "cost": {"hide": 4, "iron": 3}, "gold": 25},
	"hollow_blade": {"name": "Hollowthorn", "slot": "weapon", "tier": 3, "icon": 4, "stats": {"attack": 28.0, "leech": 0.08}, "cost": {"iron": 7, "amber": 4, "core": 2}, "gold": 65},
	"hollow_crown": {"name": "Crown of the old wood", "slot": "head", "tier": 3, "icon": 5, "stats": {"health": 48.0, "armor": 10.0, "crit": 0.05}, "cost": {"hide": 6, "amber": 3, "core": 1}, "gold": 45},
	"hollow_coat": {"name": "Heartroot mantle", "slot": "body", "tier": 3, "icon": 6, "stats": {"health": 70.0, "armor": 16.0}, "cost": {"hide": 8, "iron": 5, "core": 2}, "gold": 65},
	"hollow_boots": {"name": "Wraithwalkers", "slot": "feet", "tier": 3, "icon": 7, "stats": {"armor": 10.0, "haste": 0.18}, "cost": {"iron": 5, "amber": 3, "core": 1}, "gold": 45},
}
const RARITIES = ["Common", "Fine", "Enchanted"]
const QUALITY_MULT = [1.0, 1.18, 1.4]
const AFFIXES = [
	{"name": "of the Hart", "stat": "health", "value": 15.0},
	{"name": "of Thorns", "stat": "attack", "value": 3.0},
	{"name": "of Haste", "stat": "haste", "value": 0.08},
	{"name": "of Embers", "stat": "crit", "value": 0.06},
	{"name": "of Old Bark", "stat": "armor", "value": 5.0},
	{"name": "of Bloodroot", "stat": "leech", "value": 0.04},
	{"name": "of the Stag", "stat": "health", "value": 24.0},
	{"name": "of Cinders", "stat": "attack", "value": 5.0},
]
const ENEMIES = {
	"boar": {"name": "Mossback boar", "art": 2, "health": 34.0, "attack": 7.0, "armor": 1.0, "interval": 1.9, "xp": 12, "gold": 6, "loot": {"hide": 2, "wood": 2}},
	"wolf": {"name": "Hungerwolf", "art": 3, "health": 42.0, "attack": 8.0, "armor": 2.0, "interval": 1.6, "xp": 15, "gold": 8, "loot": {"hide": 2, "iron": 1}},
	"shroom": {"name": "Sporeling", "art": 4, "health": 50.0, "attack": 9.0, "armor": 3.0, "interval": 2.0, "xp": 18, "gold": 10, "loot": {"wood": 3, "amber": 1}},
	"bandit": {"name": "Briar brigand", "art": 5, "health": 88.0, "attack": 15.0, "armor": 5.0, "interval": 1.6, "xp": 25, "gold": 16, "loot": {"iron": 3, "hide": 2}},
	"golem": {"name": "Rootbound sentinel", "art": 6, "health": 120.0, "attack": 19.0, "armor": 12.0, "interval": 2.2, "xp": 32, "gold": 20, "loot": {"iron": 3, "amber": 2, "core": 1}},
	"elder": {"name": "The Hollow Hart", "art": 7, "health": 320.0, "attack": 28.0, "armor": 16.0, "interval": 1.9, "xp": 120, "gold": 80, "loot": {"amber": 5, "core": 3}},
}
const ZONES = [
	{"id": "verge", "name": "The Mosslight Verge", "subtitle": "Where the lanterns end", "level": 1, "unlock": "", "waves": ["boar", "wolf", "shroom"], "reward": 15, "description": "Old trails beneath an unquiet canopy. A forgiving place to gather hide, heartwood and your courage.", "drops": "Heartwood · Hide · Bog iron · Resin"},
	{"id": "quarry", "name": "Briarstone Quarry", "subtitle": "Something stirs below", "level": 3, "unlock": "verge", "waves": ["bandit", "golem", "bandit"], "reward": 30, "description": "The abandoned quarry has grown teeth. Craft a full set of gear before disturbing its rootbound keepers.", "drops": "Bog iron · Resin · Hollow hearts"},
	{"id": "hollow", "name": "The Elder Hollow", "subtitle": "The heart of Harkwood", "level": 5, "unlock": "quarry", "waves": ["golem", "bandit", "elder"], "reward": 60, "description": "Beyond the oldest stones, the Hollow Hart waits. Bring upgraded gear and healing draughts.", "drops": "Hollow hearts · Enchanted gear"},
]
const QUESTS = [
	{"id": "first_forge", "name": "A blade of your own", "text": "Craft any piece of equipment at the Hearthforge.", "counter": "crafted", "target": 1, "gold": 20, "materials": {"hide": 4}},
	{"id": "first_trail", "name": "Beyond the lanterns", "text": "Complete an expedition through the Mosslight Verge.", "counter": "verge", "target": 1, "gold": 25, "materials": {"iron": 3, "amber": 2}},
	{"id": "outfitted", "name": "Dressed for the dark", "text": "Equip an item in all four equipment slots.", "counter": "equipped", "target": 4, "gold": 30, "materials": {"iron": 3, "hide": 3}},
	{"id": "quarry_clear", "name": "Stone remembers", "text": "Complete the Briarstone Quarry expedition.", "counter": "quarry", "target": 1, "gold": 50, "materials": {"amber": 4, "core": 2}},
	{"id": "elder_clear", "name": "A light in the hollow", "text": "Defeat the Hollow Hart and finish the prototype's story.", "counter": "hollow", "target": 1, "gold": 100, "materials": {"core": 5}},
]

static func zone(id: String) -> Dictionary:
	for entry in ZONES:
		if entry.id == id:
			return entry
	return {}

static func stats_text(stats: Dictionary) -> String:
	var parts: PackedStringArray = []
	for key in ["attack", "health", "armor", "haste", "crit", "leech"]:
		if not stats.has(key) or is_zero_approx(float(stats[key])):
			continue
		var value = float(stats[key])
		if key in ["haste", "crit", "leech"]:
			parts.append("+%d%% %s" % [roundi(value * 100), key.capitalize()])
		else:
			parts.append("+%d %s" % [roundi(value), key.capitalize()])
	return "  ·  ".join(parts)
