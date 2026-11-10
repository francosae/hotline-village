extends CanvasLayer
## Animal Crossing style speech box driven by Hotline events.

var root: Control
var box: PanelContainer
var name_tag: PanelContainer
var name_label: Label
var portrait: TextureRect
var text_label: Label
var player_bubble: PanelContainer
var player_label: Label
var indicator: Panel
var indicator_label: Label
var hint: Label
var npc := ""
var open := false
var _target_text := ""
var _shown := 0.0
var _npc_speaking := false
var _level := 0.0
var _t := 0.0
var _connecting := false

func _ready() -> void:
	layer = 10
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	box = PanelContainer.new()
	var sb := UiKit.box(UiKit.CREAM, 56)
	sb.content_margin_left = 40
	sb.content_margin_right = 48
	sb.content_margin_top = 34
	sb.content_margin_bottom = 26
	sb.shadow_size = 18
	box.add_theme_stylebox_override("panel", sb)
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.anchor_top = 1.0
	box.anchor_bottom = 1.0
	box.offset_left = -470
	box.offset_right = 470
	box.offset_top = -230
	box.offset_bottom = -24
	root.add_child(box)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 26)
	box.add_child(hb)
	var pframe := Panel.new()
	pframe.custom_minimum_size = Vector2(130, 130)
	pframe.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pframe.add_theme_stylebox_override("panel", UiKit.box(Color("#f5e6c4"), 65, false, 5, Color("#e8d3a6")))
	portrait = TextureRect.new()
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.position = Vector2(5, 5)
	portrait.size = Vector2(120, 120)
	pframe.add_child(portrait)
	hb.add_child(pframe)
	text_label = UiKit.label("", 30, Color("#5b4636"))
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text_label.custom_minimum_size = Vector2(560, 120)
	hb.add_child(text_label)
	# indicator (right side, inside box area)
	indicator = Panel.new()
	indicator.custom_minimum_size = Vector2(64, 64)
	indicator.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	indicator.pivot_offset = Vector2(32, 32)
	hb.add_child(indicator)
	indicator_label = UiKit.label("", 15, Color("#8a6d52"))
	indicator_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	indicator_label.position = Vector2(-28, 66)
	indicator_label.size = Vector2(120, 20)
	indicator.add_child(indicator_label)
	# name tag (tilted, over top-left)
	name_tag = PanelContainer.new()
	var ns := UiKit.box(Color("#e8a04a"), 26, true)
	ns.content_margin_left = 26
	ns.content_margin_right = 26
	ns.content_margin_top = 4
	ns.content_margin_bottom = 6
	name_tag.add_theme_stylebox_override("panel", ns)
	name_label = UiKit.label("Maple", 30, Color.WHITE)
	name_tag.add_child(name_label)
	name_tag.rotation = -0.07
	root.add_child(name_tag)
	# player bubble
	player_bubble = PanelContainer.new()
	var pb := UiKit.box(Color("#d8f0ff"), 24)
	pb.content_margin_left = 20
	pb.content_margin_right = 20
	player_bubble.add_theme_stylebox_override("panel", pb)
	player_label = UiKit.label("", 20, Color("#2b5a7a"))
	player_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	player_label.custom_minimum_size.x = 120
	player_bubble.add_child(player_label)
	root.add_child(player_bubble)
	hint = UiKit.label("Esc  hang up", 16, Color("#a08060"))
	root.add_child(hint)
	_set_visible(false)

func _set_visible(v: bool) -> void:
	box.visible = v
	name_tag.visible = v
	hint.visible = v
	player_bubble.visible = v and player_label.text != ""

func _layout() -> void:
	var vs := root.get_viewport_rect().size
	var bx := vs.x * 0.5 - 470
	var by := vs.y - 230
	name_tag.position = Vector2(bx + 40, by - 34)
	hint.position = Vector2(bx + 940 - 130, vs.y - 52)
	var pw := minf(player_label.get_minimum_size().x + 40, 520)
	player_label.custom_minimum_size.x = minf(maxf(player_label.get_minimum_size().x, 120), 480)
	player_bubble.position = Vector2(bx + 940 - player_bubble.size.x - 30, by - player_bubble.size.y - 14)

func open_for(id: String) -> void:
	npc = id
	open = true
	name_label.text = Art.NPC_NAMES.get(id, id)
	var ns: StyleBoxFlat = name_tag.get_theme_stylebox("panel").duplicate()
	ns.bg_color = Art.NPC_COLORS.get(id, Color("#e8a04a"))
	name_tag.add_theme_stylebox_override("panel", ns)
	portrait.texture = Art.npc_portrait(id)
	portrait.modulate = Art.SHEETS[id]["modulate"]
	portrait.flip_h = id == "maple"
	_target_text = ""
	_shown = 0.0
	text_label.text = ""
	player_label.text = ""
	_connecting = true
	_set_visible(true)
	box.pivot_offset = Vector2(470, 200)
	UiKit.pop_in(box, 0.85)
	UiKit.pop_in(name_tag, 0.5)
	Sfx.play("open")
	Sfx.duck(true)

func close() -> void:
	if not open:
		return
	open = false
	Sfx.play("close")
	Sfx.duck(false)
	var t := box.create_tween()
	t.tween_property(box, "scale", Vector2(0.9, 0.9), 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(box, "modulate:a", 0.0, 0.15)
	t.parallel().tween_property(name_tag, "modulate:a", 0.0, 0.12)
	t.tween_callback(func():
		_set_visible(false)
		box.scale = Vector2.ONE
		box.modulate.a = 1.0
		name_tag.modulate.a = 1.0)

func on_status(st: String, msg: String) -> void:
	if not open:
		return
	match st:
		"connecting":
			_connecting = true
		"live":
			_connecting = false
		"error":
			_connecting = false
			_target_text = "(The line crackles...) " + msg
			_shown = 0.0

func on_speech(who: String, text: String, _final: bool) -> void:
	if not open:
		return
	_connecting = false
	if who == "npc":
		# a new utterance replaces the old; partials grow in place
		if not text.begins_with(_target_text.substr(0, mini(8, _target_text.length()))) or text.length() < _target_text.length():
			_shown = 0.0
		_target_text = text
	else:
		player_label.text = text
		player_bubble.visible = text != ""
		if text != "":
			player_bubble.reset_size()

func on_speaking(on: bool) -> void:
	_npc_speaking = on

func on_volume(level: float) -> void:
	_level = level

func _process(delta: float) -> void:
	if not open and not box.visible:
		return
	_t += delta
	_layout()
	if _shown < _target_text.length():
		_shown = minf(_shown + delta * 55.0, float(_target_text.length()))
		var before := text_label.text.length()
		text_label.text = _target_text.substr(0, int(_shown))
		if text_label.text.length() != before and int(_shown) % 4 == 0:
			Sfx.play("talk", 0.25, -22.0)
	elif text_label.text != _target_text:
		text_label.text = _target_text
	if _connecting:
		var dots := ".".repeat(1 + int(_t * 3.0) % 3)
		if _target_text == "":
			text_label.text = "Ring ring" + dots
		indicator_label.text = "connecting"
		_style_indicator(Color("#c9b79c"), 1.0 + 0.08 * sin(_t * 6.0))
	elif _npc_speaking:
		indicator_label.text = "speaking"
		_style_indicator(Art.NPC_COLORS.get(npc, Color("#e8a04a")), 1.0 + 0.35 * _level)
	else:
		indicator_label.text = "listening"
		_style_indicator(Color("#5cc98a"), 1.0 + 0.1 * sin(_t * 4.0) + 0.3 * _level)
	_level = lerpf(_level, 0.0, 1.0 - exp(-6.0 * delta))

var _ind_col := Color.TRANSPARENT
func _style_indicator(c: Color, s: float) -> void:
	if c != _ind_col:
		_ind_col = c
		var sb := UiKit.box(c, 32, false, 6, c.lightened(0.45))
		indicator.add_theme_stylebox_override("panel", sb)
	indicator.scale = Vector2(s, s)
