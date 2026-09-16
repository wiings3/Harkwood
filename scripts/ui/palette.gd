class_name HarkUI
extends RefCounted

const INK = Color("231b13")
const PANEL = Color("171d18")
const RAISED = Color("202a22")
const LINE = Color("725536")
const PAPER = Color("ead8b8")
const MUTED = Color("b6a98e")
const GOLD = Color("d8a34d")
const GREEN = Color("95a16f")
const RED = Color("c97c67")
const QUALITY = [Color("c8c0aa"), Color("91b58e"), Color("c6a0d4")]
const DATA_DIR = "res://assets/ui/concept/data/"

const ATLAS_A_CHUNKS = [
	DATA_DIR + "a_00.b64", DATA_DIR + "a_01.b64", DATA_DIR + "a_02.b64",
	DATA_DIR + "a_03.b64", DATA_DIR + "a_04.b64", DATA_DIR + "a_05.b64"
]

const ATLAS_RECTS = {
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
	"action_forge_exact": Rect2(4, 226, 358, 86),
	"action_forge_hover": Rect2(366, 226, 353, 86),
	"action_search_exact": Rect2(723, 226, 358, 88),
	"action_search_hover": Rect2(1085, 226, 353, 88),
	"hub_title_plaque": Rect2(1442, 226, 475, 115),
	"button_normal": Rect2(4, 345, 358, 86),
	"button_hover": Rect2(366, 345, 353, 86),
	"button_pressed": Rect2(723, 345, 370, 86),
	"sign_blank": Rect2(1097, 345, 179, 102),
	"divider_wood": Rect2(1280, 345, 290, 26)
}

static var body_font: Font
static var title_font: Font
static var icons: Texture2D
static var actors: Texture2D
static var atlas_a: Texture2D
static var sidebar_exact: Texture2D
static var resource_exact: Texture2D
static var world_frame_exact: Texture2D
static var cache: Dictionary = {}
static var texture_cache: Dictionary = {}

static func _load_webp_b64(paths: Array) -> Texture2D:
	var encoded: String = ""
	for raw_path in paths:
		var path: String = str(raw_path)
		if not FileAccess.file_exists(path):
			push_error("Missing Harkwood UI data: " + path)
			return null
		encoded += FileAccess.get_file_as_string(path).strip_edges()
	var bytes: PackedByteArray = Marshalls.base64_to_raw(encoded)
	if bytes.is_empty():
		push_error("Harkwood UI texture data decoded to an empty buffer.")
		return null
	var image := Image.new()
	var error: int = image.load_webp_from_buffer(bytes)
	if error != OK:
		push_error("Could not decode Harkwood UI WebP data. Error %d" % int(error))
		return null
	return ImageTexture.create_from_image(image)

static func _load_single_b64(filename: String) -> Texture2D:
	return _load_webp_b64([DATA_DIR + filename])

static func initialize() -> Theme:
	body_font = SystemFont.new()
	body_font.font_names = PackedStringArray(["Georgia", "Palatino Linotype", "Times New Roman", "DejaVu Serif"])
	title_font = SystemFont.new()
	title_font.font_names = PackedStringArray(["Georgia", "Palatino Linotype", "Times New Roman", "DejaVu Serif"])
	icons = load("res://assets/art/items.png") as Texture2D
	actors = load("res://assets/art/actors.png") as Texture2D
	atlas_a = _load_webp_b64(ATLAS_A_CHUNKS)
	sidebar_exact = _load_single_b64("sidebar_exact.b64")
	resource_exact = _load_single_b64("resource_exact.b64")
	world_frame_exact = _load_single_b64("world_frame_exact.b64")
	texture_cache.clear()

	var theme := Theme.new()
	theme.default_font = body_font
	theme.default_font_size = 16
	for kind in ["Label", "Button", "CheckButton", "OptionButton", "LineEdit", "SpinBox"]:
		theme.set_color("font_color", kind, PAPER)
		theme.set_color("font_outline_color", kind, Color("130f0a"))
	theme.set_font("font", "Button", title_font)
	theme.set_stylebox("normal", "Button", button_box("normal"))
	theme.set_stylebox("hover", "Button", button_box("hover"))
	theme.set_stylebox("pressed", "Button", button_box("pressed"))
	theme.set_stylebox("disabled", "Button", button_box("pressed"))
	theme.set_stylebox("focus", "Button", button_box("hover"))
	theme.set_color("font_hover_color", "Button", Color("ffe1a1"))
	theme.set_color("font_pressed_color", "Button", GOLD)
	theme.set_color("font_disabled_color", "Button", Color("796f5b"))
	theme.set_constant("outline_size", "Button", 1)
	theme.set_stylebox("panel", "PanelContainer", dark_panel_box())
	theme.set_stylebox("panel", "Panel", dark_panel_box())
	var progress_bg := box(Color("100e0a"), Color("6e5736"), 1, 3)
	var progress_fill := box(Color("78825a"), Color("c39856"), 1, 3)
	for style in [progress_bg, progress_fill]:
		style.content_margin_top = 0
		style.content_margin_bottom = 0
		style.content_margin_left = 0
		style.content_margin_right = 0
	theme.set_stylebox("background", "ProgressBar", progress_bg)
	theme.set_stylebox("fill", "ProgressBar", progress_fill)
	theme.set_stylebox("normal", "LineEdit", dark_panel_box())
	theme.set_stylebox("focus", "LineEdit", button_box("hover"))
	theme.set_constant("separation", "VBoxContainer", 12)
	theme.set_constant("separation", "HBoxContainer", 10)
	theme.set_stylebox("panel", "TooltipPanel", dark_panel_box())
	theme.set_color("font_color", "TooltipLabel", PAPER)
	return theme

static func tex(name: String) -> Texture2D:
	if texture_cache.has(name):
		return texture_cache[name]
	if name == "sidebar_blank":
		return sidebar_exact
	if name == "resource_bar_blank" or name == "footer_bar_blank":
		return resource_exact
	if name == "world_frame_exact":
		return world_frame_exact
	if not ATLAS_RECTS.has(name) or atlas_a == null:
		return null
	var result := AtlasTexture.new()
	result.atlas = atlas_a
	result.region = ATLAS_RECTS[name]
	result.filter_clip = true
	texture_cache[name] = result
	return result

static func texture_box(name: String, margins: Vector4, content: Vector2 = Vector2(18, 10)) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = tex(name)
	style.texture_margin_left = margins.x
	style.texture_margin_top = margins.y
	style.texture_margin_right = margins.z
	style.texture_margin_bottom = margins.w
	style.content_margin_left = content.x
	style.content_margin_right = content.x
	style.content_margin_top = content.y
	style.content_margin_bottom = content.y
	return style

static func button_box(kind: String = "normal") -> StyleBoxTexture:
	var source: String = "button_normal"
	if kind == "hover" or kind == "active":
		source = "button_hover"
	elif kind == "pressed":
		source = "button_pressed"
	return texture_box(source, Vector4(30, 22, 30, 22), Vector2(20, 9))

static func button_active_box() -> StyleBoxTexture:
	return button_box("active")

static func dark_panel_box() -> StyleBoxTexture:
	return texture_box("button_normal", Vector4(34, 22, 34, 22), Vector2(20, 15))

static func parchment_box() -> StyleBoxFlat:
	return box(Color("c9a978"), Color("68451f"), 3, 3)

static func parchment_card_box() -> StyleBoxFlat:
	return parchment_box()

static func bar_box() -> StyleBoxTexture:
	return texture_box("resource_bar_blank", Vector4(34, 23, 34, 23), Vector2(14, 8))

static func header_box() -> StyleBoxTexture:
	return bar_box()

static func small_sign_box() -> StyleBoxTexture:
	return texture_box("sign_blank", Vector4(34, 26, 34, 26), Vector2(12, 7))

static func world_frame_box() -> StyleBoxTexture:
	return texture_box("world_frame_exact", Vector4(78, 45, 35, 30), Vector2.ZERO)

static func box(fill: Color, border: Color = LINE, width: int = 1, corners: int = 4) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = fill
	result.border_color = border
	result.set_border_width_all(width)
	result.set_corner_radius_all(corners)
	result.content_margin_left = 14
	result.content_margin_right = 14
	result.content_margin_top = 10
	result.content_margin_bottom = 10
	return result

static func label(text: String, font_size: int = 16, color: Color = PAPER, heading: bool = false) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	if heading:
		node.add_theme_font_override("font", title_font)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

static func paragraph(text: String, font_size: int = 16, color: Color = MUTED) -> Label:
	var node := label(text, font_size, color)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node

static func button(text: String, callback: Callable, height: float = 42) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size.y = height
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.pressed.connect(callback)
	return node

static func texture_button(normal_name: String, active_name: String, callback: Callable) -> TextureButton:
	var node := TextureButton.new()
	node.texture_normal = tex(normal_name)
	node.texture_hover = tex(active_name)
	node.texture_pressed = tex(active_name)
	node.ignore_texture_size = true
	node.stretch_mode = TextureButton.STRETCH_SCALE
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.pressed.connect(callback)
	return node

static func panel(parent: Node, rect: Rect2, fill: Color = PANEL) -> PanelContainer:
	var node := PanelContainer.new()
	node.position = rect.position
	node.size = rect.size
	node.add_theme_stylebox_override("panel", dark_panel_box() if fill == PANEL else box(fill))
	parent.add_child(node)
	return node

static func icon(index: int, dimension: float = 64, actor: bool = false) -> TextureRect:
	var node := TextureRect.new()
	node.texture = atlas(index, actor)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.custom_minimum_size = Vector2(dimension, dimension)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

static func atlas(index: int, actor: bool = false) -> AtlasTexture:
	var key: String = str(index) + str(actor)
	if cache.has(key):
		return cache[key]
	var result := AtlasTexture.new()
	result.atlas = actors if actor else icons
	if actor:
		var regions: Array[Rect2] = [Rect2(18, 4, 392, 414), Rect2(433, 3, 344, 411), Rect2(808, 73, 474, 335), Rect2(1295, 80, 477, 309), Rect2(17, 447, 416, 429), Rect2(440, 428, 350, 448), Rect2(814, 444, 483, 434), Rect2(1304, 385, 468, 502)]
		result.region = regions[clampi(index, 0, 7)]
	else:
		var cell := Vector2(icons.get_width() / 4.0, icons.get_height() / 4.0)
		result.region = Rect2(Vector2(index % 4, index / 4) * cell, cell)
	result.filter_clip = true
	cache[key] = result
	return result

static func rule(parent: Node) -> void:
	var line := TextureRect.new()
	line.texture = tex("divider_wood")
	line.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	line.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	line.custom_minimum_size = Vector2(0, 18)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)

static func row(parent: Node) -> HBoxContainer:
	var node := HBoxContainer.new()
	parent.add_child(node)
	return node

static func column(parent: Node) -> VBoxContainer:
	var node := VBoxContainer.new()
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(node)
	return node

static func spacer(parent: Node, height: float = 10) -> void:
	var node := Control.new()
	node.custom_minimum_size.y = height
	parent.add_child(node)

static func scroll_column(parent: Node) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)
	var content := column(scroll)
	return content
