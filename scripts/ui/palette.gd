class_name HarkUI
extends RefCounted
const INK = Color("101b17")
const PANEL = Color("18251f")
const RAISED = Color("22322a")
const LINE = Color("445044")
const PAPER = Color("eadfc8")
const MUTED = Color("a2ac98")
const GOLD = Color("d1ad70")
const GREEN = Color("8fb69a")
const RED = Color("d58e7c")
const QUALITY = [Color("c0c2b3"), Color("89b99c"), Color("c5a1d8")]
static var body_font: Font
static var title_font: Font
static var icons: Texture2D
static var actors: Texture2D
static var cache: Dictionary = {}

static func initialize() -> Theme:
	body_font = SystemFont.new()
	body_font.font_names = PackedStringArray(["Segoe UI", "Arial", "DejaVu Sans"])
	title_font = SystemFont.new()
	title_font.font_names = PackedStringArray(["Georgia", "Times New Roman", "DejaVu Serif"])
	icons = load("res://assets/art/items.png")
	actors = load("res://assets/art/actors.png")
	var theme = Theme.new()
	theme.default_font = body_font
	theme.default_font_size = 16
	for kind in ["Label", "Button", "CheckButton", "OptionButton", "LineEdit", "SpinBox"]:
		theme.set_color("font_color", kind, PAPER)
	theme.set_stylebox("normal", "Button", box(RAISED, LINE))
	theme.set_stylebox("hover", "Button", box(Color("33483a"), GOLD))
	theme.set_stylebox("pressed", "Button", box(Color("40553e"), GOLD))
	theme.set_stylebox("disabled", "Button", box(Color("1b251f"), Color("303c32")))
	theme.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), GOLD, 2))
	theme.set_color("font_hover_color", "Button", PAPER)
	theme.set_color("font_pressed_color", "Button", GOLD)
	theme.set_color("font_disabled_color", "Button", Color("738071"))
	theme.set_stylebox("panel", "PanelContainer", box(PANEL, LINE))
	theme.set_stylebox("panel", "Panel", box(PANEL, LINE))
	var progress_bg = box(Color("111a15"), LINE, 1, 4)
	var progress_fill = box(Color("708c67"), Color("93af7f"), 0, 4)
	for style in [progress_bg, progress_fill]:
		style.content_margin_top = 0
		style.content_margin_bottom = 0
		style.content_margin_left = 0
		style.content_margin_right = 0
	theme.set_stylebox("background", "ProgressBar", progress_bg)
	theme.set_stylebox("fill", "ProgressBar", progress_fill)
	theme.set_stylebox("normal", "LineEdit", box(INK, LINE))
	theme.set_stylebox("focus", "LineEdit", box(INK, GOLD))
	theme.set_constant("separation", "VBoxContainer", 12)
	theme.set_constant("separation", "HBoxContainer", 12)
	theme.set_stylebox("panel", "TooltipPanel", box(INK, GOLD))
	theme.set_color("font_color", "TooltipLabel", PAPER)
	return theme

static func box(fill: Color, border: Color = LINE, width: int = 1, corners: int = 6) -> StyleBoxFlat:
	var result = StyleBoxFlat.new()
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
	var node = Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	if heading:
		node.add_theme_font_override("font", title_font)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

static func paragraph(text: String, font_size: int = 16, color: Color = MUTED) -> Label:
	var node = label(text, font_size, color)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node

static func button(text: String, callback: Callable, height: float = 42) -> Button:
	var node = Button.new()
	node.text = text
	node.custom_minimum_size.y = height
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.pressed.connect(callback)
	return node

static func panel(parent: Node, rect: Rect2, fill: Color = PANEL) -> PanelContainer:
	var node = PanelContainer.new()
	node.position = rect.position
	node.size = rect.size
	node.add_theme_stylebox_override("panel", box(fill))
	parent.add_child(node)
	return node

static func icon(index: int, dimension: float = 64, actor: bool = false) -> TextureRect:
	var node = TextureRect.new()
	node.texture = atlas(index, actor)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.custom_minimum_size = Vector2(dimension, dimension)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

static func atlas(index: int, actor: bool = false) -> AtlasTexture:
	var key = str(index) + str(actor)
	if cache.has(key):
		return cache[key]
	var result = AtlasTexture.new()
	result.atlas = actors if actor else icons
	if actor:
		var regions = [Rect2(18, 4, 392, 414), Rect2(433, 3, 344, 411),
			Rect2(808, 73, 474, 335), Rect2(1295, 80, 477, 309),
			Rect2(17, 447, 416, 429), Rect2(440, 428, 350, 448),
			Rect2(814, 444, 483, 434), Rect2(1304, 385, 468, 502)]
		result.region = regions[clampi(index, 0, 7)]
	else:
		var cell = Vector2(icons.get_width() / 4.0, icons.get_height() / 4.0)
		result.region = Rect2(Vector2(index % 4, index / 4) * cell, cell)
	result.filter_clip = true
	cache[key] = result
	return result

static func rule(parent: Node) -> void:
	var line = HSeparator.new()
	line.modulate = LINE
	parent.add_child(line)

static func row(parent: Node) -> HBoxContainer:
	var node = HBoxContainer.new()
	parent.add_child(node)
	return node

static func column(parent: Node) -> VBoxContainer:
	var node = VBoxContainer.new()
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(node)
	return node

static func spacer(parent: Node, height: float = 10) -> void:
	var node = Control.new()
	node.custom_minimum_size.y = height
	parent.add_child(node)

static func scroll_column(parent: Node) -> VBoxContainer:
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)
	var content = column(scroll)
	return content
