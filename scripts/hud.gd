extends CanvasLayer
## AC-style HUD: bells pill, quest card, pocket row, toast banners.

var bells_label: Label
var bells_pill: PanelContainer
var quest_card: PanelContainer
var quest_list: VBoxContainer
var pocket: HBoxContainer
var toast_holder: Control
var _shown_bells := 0
var _bells_tween: Tween

func _ready() -> void:
	layer = 5
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	# bells pill
	bells_pill = PanelContainer.new()
	bells_pill.add_theme_stylebox_override("panel", UiKit.box(UiKit.CREAM, 30))
	bells_pill.position = Vector2(24, 20)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	var coin := Panel.new()
	coin.custom_minimum_size = Vector2(34, 34)
	coin.add_theme_stylebox_override("panel", UiKit.box(Color("#ffc94a"), 17, false, 4, Color("#e09b1a")))
	var cl := UiKit.label("B", 18, Color("#9a5b00"))
	cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cl.set_anchors_preset(Control.PRESET_FULL_RECT)
	coin.add_child(cl)
	hb.add_child(coin)
	bells_label = UiKit.label("0", 28)
	bells_label.custom_minimum_size.x = 80
	hb.add_child(bells_label)
	bells_pill.add_child(hb)
	root.add_child(bells_pill)
	# quest card
	quest_card = PanelContainer.new()
	var qs := UiKit.box(UiKit.CREAM, 26)
	qs.content_margin_left = 20
	qs.content_margin_right = 20
	qs.content_margin_top = 14
	qs.content_margin_bottom = 14
	quest_card.add_theme_stylebox_override("panel", qs)
	quest_card.anchor_left = 1.0
	quest_card.anchor_right = 1.0
	quest_card.offset_left = -330
	quest_card.offset_right = -24
	quest_card.offset_top = 20
	quest_card.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	var qv := VBoxContainer.new()
	qv.add_theme_constant_override("separation", 6)
	var qt := UiKit.label("Quests", 24, Color("#d07a2a"))
	qv.add_child(qt)
	quest_list = VBoxContainer.new()
	quest_list.add_theme_constant_override("separation", 6)
	qv.add_child(quest_list)
	quest_card.add_child(qv)
	root.add_child(quest_card)
	# pocket
	var pocket_bg := PanelContainer.new()
	var ps := UiKit.box(Color(1.0, 0.97, 0.9, 0.92), 40)
	ps.content_margin_left = 16
	ps.content_margin_right = 16
	ps.content_margin_top = 10
	ps.content_margin_bottom = 10
	pocket_bg.add_theme_stylebox_override("panel", ps)
	pocket_bg.anchor_top = 1.0
	pocket_bg.anchor_bottom = 1.0
	pocket_bg.offset_left = 24
	pocket_bg.offset_top = -96
	pocket_bg.offset_bottom = -20
	pocket_bg.grow_vertical = Control.GROW_DIRECTION_BEGIN
	pocket = HBoxContainer.new()
	pocket.add_theme_constant_override("separation", 8)
	pocket_bg.add_child(pocket)
	root.add_child(pocket_bg)
	# toasts
	toast_holder = Control.new()
	toast_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	toast_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toast_holder)
	GameState.inventory_changed.connect(refresh_pocket)
	GameState.inventory_changed.connect(refresh_quests)
	GameState.quests_changed.connect(refresh_quests)
	GameState.bells_changed.connect(_on_bells)
	_shown_bells = GameState.bells
	bells_label.text = str(_shown_bells)
	refresh_pocket()
	refresh_quests()

func _on_bells(v: int) -> void:
	if _bells_tween:
		_bells_tween.kill()
	_bells_tween = create_tween()
	_bells_tween.tween_method(func(x: float):
		_shown_bells = int(x)
		bells_label.text = str(_shown_bells), float(_shown_bells), float(v), 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	bells_pill.pivot_offset = bells_pill.size * 0.5
	var t := create_tween()
	t.tween_property(bells_pill, "scale", Vector2(1.15, 1.15), 0.1)
	t.tween_property(bells_pill, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play("coin")

func _icon(item: String, sz: float) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = Art.item_icon(item)
	tr.self_modulate = Art.item_modulate(item)
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(sz, sz)
	return tr

func refresh_pocket() -> void:
	for c in pocket.get_children():
		c.queue_free()
	var shown := 0
	var order: Array = GameState.ITEMS.duplicate()
	for k in GameState.inventory.keys():
		if not k in order:
			order.append(k)
	for item in order:
		var n := GameState.count(item)
		if n <= 0:
			continue
		shown += 1
		pocket.add_child(_slot(item, n))
	for i in range(shown, 6):
		pocket.add_child(_slot("", 0))

func _slot(item: String, n: int) -> Control:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(56, 56)
	p.add_theme_stylebox_override("panel", UiKit.box(Color("#f3e3c0") if item == "" else Color.WHITE, 28, false, 3, Color("#e6cfa2")))
	if item != "":
		var ic := _icon(item, 40)
		ic.position = Vector2(8, 8)
		p.add_child(ic)
		var l := UiKit.label(str(n), 18, Color.WHITE)
		l.add_theme_color_override("font_outline_color", UiKit.BROWN)
		l.add_theme_constant_override("outline_size", 6)
		l.position = Vector2(38, 30)
		p.add_child(l)
	return p

func refresh_quests() -> void:
	for c in quest_list.get_children():
		c.queue_free()
	var act := GameState.active_quests()
	if act.is_empty():
		quest_list.add_child(UiKit.label("Talk to villagers!", 18, Color("#a08060")))
	for q in act:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.add_child(_icon(q["item"], 32))
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", -4)
		var title := UiKit.label(str(q["title"]), 18)
		title.custom_minimum_size.x = 170
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(title)
		v.add_child(UiKit.label("for %s  |  %d bells" % [Art.NPC_NAMES.get(q["npc"], q["npc"]), int(q["reward"])], 14, Color("#a08060")))
		row.add_child(v)
		var have := mini(GameState.count(q["item"]), int(q["count"]))
		if q.has("progress"):
			have = mini(int(q["progress"]), int(q["count"]))
		var prog := UiKit.label("%d/%d" % [have, int(q["count"])], 22, Color("#3aa35b") if have >= int(q["count"]) else UiKit.BROWN)
		row.add_child(prog)
		quest_list.add_child(row)

func toast(text: String, color := Color("#ff8fab")) -> void:
	var p := PanelContainer.new()
	var sb := UiKit.box(color, 30)
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	p.add_theme_stylebox_override("panel", sb)
	var l := UiKit.label(text, 30, Color.WHITE)
	l.add_theme_color_override("font_outline_color", color.darkened(0.4))
	l.add_theme_constant_override("outline_size", 8)
	p.add_child(l)
	toast_holder.add_child(p)
	await get_tree().process_frame
	var vw := get_viewport().get_visible_rect().size.x
	p.position = Vector2((vw - p.size.x) * 0.5, -80)
	p.pivot_offset = p.size * 0.5
	var t := p.create_tween()
	t.tween_property(p, "position:y", 96.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(1.8)
	t.tween_property(p, "position:y", -80.0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.tween_callback(p.queue_free)
