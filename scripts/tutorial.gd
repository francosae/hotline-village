extends CanvasLayer
## AC-style "how to play" card. Shows once on first start (flag in user://), H toggles it,
## and a small "H: help" pill sits in the bottom-right corner. Added to the root by title.gd.

const FLAG := "user://tutorial_seen"
const CREAM := Color("#fff8e7")
const BROWN := Color("#6b4a32")
const ORANGE := Color("#f39c3d")
const STEPS := [
	["WASD / Arrows", "walk around"],
	["E", "talk to a villager (just speak, no button)"],
	["Esc", "hang up"],
	["F", "farm: till, plant, water, harvest"],
	["Q", "switch seeds"],
	["Ask", "villagers anything, or give orders: \"follow me\", \"water my crops\", \"show me how to plant\""],
]

var dim: ColorRect
var card: PanelContainer
var shown := false

func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_hint()
	_build_card()
	var shot := OS.get_environment("HV_SHOT") != ""
	if shot or not FileAccess.file_exists(FLAG):
		await get_tree().create_timer(0.35).timeout
		_show(true)
	if shot:
		await get_tree().create_timer(0.6).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/hv_0b_tutorial.png")
		print("[shot] /tmp/hv_0b_tutorial.png")
		_show(false)

func _build_hint() -> void:
	var p := PanelContainer.new()
	var sb := UiKit.box(CREAM, 20, true, 3, Color("#e8d5b0"))
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 4
	sb.content_margin_bottom = 5
	p.add_theme_stylebox_override("panel", sb)
	var l := UiKit.bold("H: help", 18, BROWN)
	p.add_child(l)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: _show(not shown))
	add_child(p)
	p.reset_size()
	p.position = Vector2(1280 - p.size.x - 22, 720 - p.size.y - 22)

func _build_card() -> void:
	dim = ColorRect.new()
	dim.color = Color(0.2, 0.13, 0.06, 0.35)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: _show(false))
	dim.visible = false
	add_child(dim)
	card = PanelContainer.new()
	var sb := UiKit.box(CREAM, 34, true, 6, Color("#f2c27a"))
	sb.content_margin_left = 40
	sb.content_margin_right = 40
	sb.content_margin_top = 26
	sb.content_margin_bottom = 26
	card.add_theme_stylebox_override("panel", sb)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	card.add_child(v)
	var title := UiKit.bold("How to play", 40, Color("#e07a3d"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	for i in STEPS.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var num := PanelContainer.new()
		var nb := UiKit.box(ORANGE, 18, false)
		nb.content_margin_left = 0
		nb.content_margin_right = 0
		nb.content_margin_top = 0
		nb.content_margin_bottom = 0
		num.add_theme_stylebox_override("panel", nb)
		num.custom_minimum_size = Vector2(36, 36)
		var nl := UiKit.bold(str(i + 1), 20, CREAM)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		num.add_child(nl)
		num.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(num)
		var key := PanelContainer.new()
		var kb := UiKit.box(Color("#f6e6c4"), 12, false)
		kb.content_margin_left = 12
		kb.content_margin_right = 12
		kb.content_margin_top = 2
		kb.content_margin_bottom = 4
		key.add_theme_stylebox_override("panel", kb)
		key.add_child(UiKit.bold(STEPS[i][0], 22, BROWN))
		key.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(key)
		var d := UiKit.label(STEPS[i][1], 22, BROWN)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(560, 0)
		row.add_child(d)
		v.add_child(row)
	var foot := UiKit.bold("Enter / E / click to start", 20, Color("#b08a64"))
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(foot)
	card.visible = false
	add_child(card)

func _show(on: bool) -> void:
	shown = on
	dim.visible = on
	card.visible = on
	if on:
		card.reset_size()
		card.position = (Vector2(1280, 720) - card.size) * 0.5
		card.pivot_offset = card.size * 0.5
		UiKit.pop_in(card, 0.85)
	elif not FileAccess.file_exists(FLAG):
		var f := FileAccess.open(FLAG, FileAccess.WRITE)
		if f:
			f.store_string("1")

func _input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed and not e.echo):
		return
	var k: int = e.physical_keycode
	if k == KEY_H:
		_show(not shown)
		get_viewport().set_input_as_handled()
	elif shown and k in [KEY_ENTER, KEY_KP_ENTER, KEY_E, KEY_ESCAPE, KEY_SPACE]:
		_show(false)
		get_viewport().set_input_as_handled()
