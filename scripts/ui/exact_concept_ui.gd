class_name ExactConceptUI
extends RefCounted

const DATA_DIR := "res://assets/ui/concept/data/"
const ATLAS_CHUNKS := [
	DATA_DIR + "exact30_00.b64",
	DATA_DIR + "exact30_01.b64",
	DATA_DIR + "exact30_02.b64",
	DATA_DIR + "exact30_03.b64",
	DATA_DIR + "exact30_04.b64",
	DATA_DIR + "exact30_05.b64",
	DATA_DIR + "exact30_06.b64",
	DATA_DIR + "exact30_07.b64",
]

const RECTS := {
	"header_brand_exact": Rect2(4, 4, 375, 112),
	"nav_hearth": Rect2(383, 4, 163, 81),
	"nav_hearth_active": Rect2(550, 4, 163, 82),
	"nav_wilds": Rect2(717, 4, 159, 81),
	"nav_wilds_active": Rect2(880, 4, 159, 82),
	"nav_pack": Rect2(1043, 4, 159, 81),
	"nav_pack_active": Rect2(1206, 4, 159, 82),
	"nav_forge": Rect2(1369, 4, 158, 81),
	"nav_forge_active": Rect2(1531, 4, 158, 82),
	"nav_exchange": Rect2(1693, 4, 170, 81),
	"nav_exchange_active": Rect2(1867, 4, 170, 82),
	"nav_journal": Rect2(4, 120, 172, 81),
	"nav_journal_active": Rect2(180, 120, 172, 82),
	"nav_settings": Rect2(356, 120, 213, 79),
	"sign_hearthforge": Rect2(573, 120, 179, 102),
	"sign_trading": Rect2(756, 120, 179, 102),
	"sign_chest": Rect2(939, 120, 171, 102),
	"sign_wilds": Rect2(1114, 120, 184, 102),
	"action_map_exact": Rect2(1302, 120, 358, 86),
	"action_map_hover": Rect2(1664, 120, 353, 86),
	"action_map_pressed": Rect2(4, 226, 370, 86),
	"action_forge_exact": Rect2(378, 226, 358, 86),
	"action_forge_hover": Rect2(740, 226, 353, 86),
	"action_forge_pressed": Rect2(1097, 226, 370, 86),
	"action_search_exact": Rect2(1471, 226, 358, 88),
	"action_search_hover": Rect2(4, 318, 353, 88),
	"action_search_pressed": Rect2(361, 318, 370, 88),
	"hub_title_plaque": Rect2(735, 318, 475, 115),
	"button_normal": Rect2(1214, 318, 358, 86),
	"button_hover": Rect2(1576, 318, 353, 86),
	"button_pressed": Rect2(4, 437, 370, 86),
	"sign_blank": Rect2(378, 437, 179, 102),
	"divider_wood": Rect2(561, 437, 290, 26),
	"sidebar_blank": Rect2(855, 437, 392, 680),
	"resource_bar_blank": Rect2(4, 1121, 1015, 50),
	"footer_bar_blank": Rect2(1023, 1121, 370, 50),
	"world_frame_exact": Rect2(4, 1175, 980, 680),
	"panel_dark_blank": Rect2(988, 1175, 482, 167),
	"card_parchment_blank": Rect2(1474, 1175, 494, 225),
}

static var atlas: Texture2D
static var cache: Dictionary = {}

static func initialize() -> void:
	if atlas != null:
		return
	var encoded := ""
	for path_value in ATLAS_CHUNKS:
		var path := str(path_value)
		if not FileAccess.file_exists(path):
			push_error("Missing concept UI texture chunk: " + path)
			return
		encoded += FileAccess.get_file_as_string(path).strip_edges()
	var bytes := Marshalls.base64_to_raw(encoded)
	var image := Image.new()
	var error := image.load_webp_from_buffer(bytes)
	if error != OK:
		push_error("Failed to decode exact concept UI atlas: %s" % error_string(error))
		return
	atlas = ImageTexture.create_from_image(image)

static func texture(name: String) -> Texture2D:
	initialize()
	if atlas == null or not RECTS.has(name):
		return null
	if cache.has(name):
		return cache[name]
	var result := AtlasTexture.new()
	result.atlas = atlas
	result.region = RECTS[name]
	result.filter_clip = true
	cache[name] = result
	return result

static func style(name: String, margins: Vector4, content: Vector2 = Vector2(16, 9)) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = texture(name)
	box.texture_margin_left = margins.x
	box.texture_margin_top = margins.y
	box.texture_margin_right = margins.z
	box.texture_margin_bottom = margins.w
	box.content_margin_left = content.x
	box.content_margin_right = content.x
	box.content_margin_top = content.y
	box.content_margin_bottom = content.y
	return box
