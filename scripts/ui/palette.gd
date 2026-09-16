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

const RUSTIC_DIR = "res://assets/ui/rustic/"
const ICON_REGIONS = {
	"nav_hearth": Rect2(0, 0, 40, 40),
	"nav_wilds": Rect2(40, 0, 40, 40),
	"nav_pack": Rect2(80, 0, 40, 40),
	"nav_forge": Rect2(120, 0, 40, 40),
	"nav_exchange": Rect2(160, 0, 40, 40),
	"nav_journal": Rect2(0, 40, 40, 40),
	"nav_settings": Rect2(40, 40, 40, 40),
	"action_map": Rect2(80, 40, 40, 40),
	"action_forge": Rect2(120, 40, 40, 40),
	"action_search": Rect2(160, 40, 40, 40),
}

static var body_font: Font
static var title_font: Font
static var icons: Texture2D
static var actors: Texture2D
static var rustic_icons: Texture2D
static var cache: Dictionary = {}
static var rustic_cache: Dictionary = {}

static func initialize() -> Theme:
	body_font = SystemFont.new()
	body_font.font_names = PackedStringArray(["Georgia", "Palatino Linotype", "Times New Roman", "DejaVu Serif"])
	title_font = SystemFont.new()
	title_font.font_names = PackedStringArray(["Georgia", "Palatino Linotype", "Times New Roman", "DejaVu Serif"])
	icons = load("res://assets/art/items.png") as Texture2D
	actors = load("res://assets/art/actors.png") as Texture2D
	rustic_icons = load(RUSTIC_DIR + "ui_icons.svg") as Texture2D

	var theme: Theme = Theme.new()
	theme.default_font = body_font
	theme.default_font_size = 16
	for kind in ["Label", "Button", "CheckButton", "OptionButton", "LineEdit", "SpinBox"]:
		theme.set_color("font_color", kind, PAPER)
		theme.set_color("font_outline_color", kind, Color("130f0a"))
	if title_font != null:
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

	var progress_bg: StyleBoxFlat = box(Color("151610"), Color("6e5736"), 1, 4)
	var progress_fill: StyleBoxFlat = box(Color("6f7b4e"), Color("b39156"), 1, 4)
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

static func texture_box(path: String, left: float, top: float, right: float, bottom: float, content_x: float = 14.0, content_y: float = 10.0) -> StyleBoxTexture:
	var style: StyleBoxTexture = StyleBoxTexture.new()
	style.texture = load(path) as Texture2D
	style.texture_margin_left = left
	style.texture_margin_top = top
	style.texture_margin_right = right
	style.texture_margin_bottom = bottom
	style.content_margin_left = content_x
	style.content_margin_right = content_x
	style.content_margin_top = content_y
	style.content_margin_bottom = content_y
	return style

static func button_box(kind: String = "normal") -> StyleBoxTexture:
	var filename: String = "button_normal.svg"
	match kind:
		"hover": filename = "button_hover.svg"
		"pressed": filename = "button_pressed.svg"
		"active": filename = "button_active.svg"
	return texture_box(RUSTIC_DIR + filename, 14.0, 8.0, 14.0, 8.0, 18.0, 8.0)

static func button_active_box() -> StyleBoxTexture:
	return button_box("active")

static func dark_panel_box() -> StyleBoxTexture:
	return texture_box(RUSTIC_DIR + "panel_dark.svg", 15.0, 8.0, 15.0, 8.0, 18.0, 14.0)

static func parchment_box() -> StyleBoxTexture:
	return texture_box(RUSTIC_DIR + "panel_parchment.svg", 20.0, 20.0, 20.0, 20.0, 26.0, 24.0)

static func parchment_card_box() -> StyleBoxTexture:
	return texture_box(RUSTIC_DIR + "panel_parchment.svg", 24.0, 18.0, 24.0, 18.0, 24.0, 18.0)

static func bar_box() -> StyleBoxTexture:
	return texture_box(RUSTIC_DIR + "bar_wood.svg", 18.0, 12.0, 18.0, 12.0, 14.0, 8.0)

static func header_box() -> StyleBoxTexture:
	return texture_box(RUSTIC_DIR + "bar_wood.svg", 16.0, 10.0, 16.0, 10.0, 12.0, 8.0)

static func small_sign_box() -> StyleBoxTexture:
	return texture_box(RUSTIC_DIR + "button_normal.svg", 9.0, 8.0, 9.0, 8.0, 12.0, 7.0)

static func world_frame_box() -> StyleBoxTexture:
	return texture_box(RUSTIC_DIR + "frame_world.svg", 18.0, 18.0, 18.0, 18.0, 0.0, 0.0)

static func rustic_icon(name: String) -> Texture2D:
	if rustic_cache.has(name):
		return rustic_cache[name]
	if rustic_icons == null or not ICON_REGIONS.has(name):
		return null
	var result: AtlasTexture = AtlasTexture.new()
	result.atlas = rustic_icons
	result.region = ICON_REGIONS[name]
	result.filter_clip = true
	rustic_cache[name] = result
	return result

static func logo_texture() -> Texture2D:
	return load(RUSTIC_DIR + "logo_tree.svg") as Texture2D

static func box(fill: Color, border: Color = LINE, width: int = 1, corners: int = 4) -> StyleBoxFlat:
	var result: StyleBoxFlat = StyleBoxFlat.new()
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
	var node: Label = Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	if heading:
		node.add_theme_font_override("font", title_font)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

static func paragraph(text: String, font_size: int = 16, color: Color = MUTED) -> Label:
	var node: Label = label(text, font_size, color)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node

static func button(text: String, callback: Callable, height: float = 42) -> Button:
	var node: Button = Button.new()
	node.text = text
	node.custom_minimum_size.y = height
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.pressed.connect(callback)
	return node

static func panel(parent: Node, rect: Rect2, fill: Color = PANEL) -> PanelContainer:
	var node: PanelContainer = PanelContainer.new()
	node.position = rect.position
	node.size = rect.size
	if fill == PANEL:
		node.add_theme_stylebox_override("panel", dark_panel_box())
	else:
		node.add_theme_stylebox_override("panel", box(fill))
	parent.add_child(node)
	return node

static func icon(index: int, dimension: float = 64, actor: bool = false) -> TextureRect:
	var node: TextureRect = TextureRect.new()
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
	var result: AtlasTexture = AtlasTexture.new()
	result.atlas = actors if actor else icons
	if actor:
		var regions: Array[Rect2] = [Rect2(18, 4, 392, 414), Rect2(433, 3, 344, 411),
			Rect2(808, 73, 474, 335), Rect2(1295, 80, 477, 309),
			Rect2(17, 447, 416, 429), Rect2(440, 428, 350, 448),
			Rect2(814, 444, 483, 434), Rect2(1304, 385, 468, 502)]
		result.region = regions[clampi(index, 0, 7)]
	else:
		var cell: Vector2 = Vector2(icons.get_width() / 4.0, icons.get_height() / 4.0)
		result.region = Rect2(Vector2(index % 4, index / 4) * cell, cell)
	result.filter_clip = true
	cache[key] = result
	return result

static func rule(parent: Node) -> void:
	var line: TextureRect = TextureRect.new()
	line.texture = load(RUSTIC_DIR + "divider.svg") as Texture2D
	line.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	line.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	line.custom_minimum_size = Vector2(0, 18)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)

static func row(parent: Node) -> HBoxContainer:
	var node: HBoxContainer = HBoxContainer.new()
	parent.add_child(node)
	return node

static func column(parent: Node) -> VBoxContainer:
	var node: VBoxContainer = VBoxContainer.new()
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(node)
	return node

static func spacer(parent: Node, height: float = 10) -> void:
	var node: Control = Control.new()
	node.custom_minimum_size.y = height
	parent.add_child(node)

static func scroll_column(parent: Node) -> VBoxContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)
	var content: VBoxContainer = column(scroll)
	return content
