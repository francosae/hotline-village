extends StaticBody2D
## Villager: idle anim, name tag, talk prompt, emotes and tool animations.

var npc_id := "maple"
var sprite: AnimatedSprite2D
var body: Node2D       # squash/stretch root
var pill_holder: Node2D
var pill: PanelContainer
var _bubble: Node2D
var _anim_tween: Tween
var _prompt_tween: Tween
var _near := false
var _base_scale := Vector2.ONE

func setup(id: String) -> void:
	npc_id = id

func _ready() -> void:
	var d: Dictionary = Art.SHEETS[npc_id]
	body = Node2D.new()
	add_child(body)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Art.npc_frames(npc_id)
	var fs: Vector2i = d["frame"]
	sprite.offset = Vector2(0, -fs.y * 0.5 + (fs.y * 0.2 if fs.x == 48 else 2))
	sprite.modulate = d["modulate"]
	sprite.flip_h = npc_id == "maple"
	_base_scale = Vector2.ONE * float(d["scale"])
	body.scale = _base_scale
	body.add_child(sprite)
	sprite.play("default")
	sprite.frame = randi() % 2
	var col := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = 6.0
	col.shape = sh
	col.position = Vector2(0, -3)
	add_child(col)
	_build_pill()
	# idle breathing
	var t := create_tween().set_loops()
	t.tween_property(sprite, "scale", Vector2(1.04, 0.96), 0.9).set_trans(Tween.TRANS_SINE)
	t.tween_property(sprite, "scale", Vector2.ONE, 0.9).set_trans(Tween.TRANS_SINE)

func _head_y() -> float:
	var d: Dictionary = Art.SHEETS[npc_id]
	match npc_id:
		"maple": return 24.0
		"clucky": return 20.0
		_: return 26.0

func _label(text: String, size: int, col: Color, outline: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", Art.world_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", outline)
	l.add_theme_constant_override("outline_size", 14)
	l.scale = Vector2(0.2, 0.2)
	l.z_index = 40
	return l

func _place(l: Label, y: float) -> void:
	var sz := l.get_minimum_size()
	l.position = Vector2(-sz.x * 0.1, y - sz.y * 0.2)

func _build_pill() -> void:
	pill_holder = Node2D.new()
	pill_holder.z_index = 40
	pill_holder.position = Vector2(0, -_head_y() - 4)
	add_child(pill_holder)
	var inner := Node2D.new()
	inner.scale = Vector2(0.2, 0.2)
	pill_holder.add_child(inner)
	pill = PanelContainer.new()
	var sb := UiKit.box(UiKit.CREAM, 30, true)
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(0, 5)
	sb.content_margin_left = 22
	sb.content_margin_right = 12
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	pill.add_theme_stylebox_override("panel", sb)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	var name_l := UiKit.bold(Art.NPC_NAMES[npc_id], 34, UiKit.BROWN)
	name_l.add_theme_font_override("font", Art.world_font())
	hb.add_child(name_l)
	var key := PanelContainer.new()
	var ks := UiKit.box(Art.NPC_COLORS[npc_id], 22, false)
	ks.content_margin_left = 12
	ks.content_margin_right = 12
	ks.content_margin_top = 0
	ks.content_margin_bottom = 2
	key.add_theme_stylebox_override("panel", ks)
	var kl := UiKit.bold("E", 28, Color.WHITE)
	kl.add_theme_font_override("font", Art.world_font())
	key.add_child(kl)
	hb.add_child(key)
	pill.add_child(hb)
	inner.add_child(pill)
	pill.reset_size()
	pill.position = Vector2(-pill.get_combined_minimum_size().x * 0.5, -pill.get_combined_minimum_size().y)
	pill_holder.scale = Vector2.ZERO
	pill_holder.visible = false

func set_near(on: bool) -> void:
	if on == _near:
		return
	_near = on
	if _prompt_tween:
		_prompt_tween.kill()
	_prompt_tween = create_tween()
	if on:
		pill_holder.visible = true
		_prompt_tween.tween_property(pill_holder, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_prompt_tween.tween_property(pill_holder, "scale", Vector2.ZERO, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		_prompt_tween.tween_callback(func(): pill_holder.visible = false)

func hide_prompt() -> void:
	set_near(false)

# ---- tools ----
const EMOTES := {
	"happy": ["^ ^", Color("#ffb703")], "love": ["<3", Color("#ef476f")], "laugh": ["haha", Color("#fb8500")],
	"surprised": ["!!", Color("#e63946")], "question": ["?", Color("#4361ee")], "angry": ["grr", Color("#d62828")],
	"sad": ["T T", Color("#4895ef")], "idea": ["!", Color("#f4a261")], "music": ["la~", Color("#9b5de5")],
	"sleepy": ["zzz", Color("#577590")], "think": ["...", Color("#8d6e63")], "book": ["?!", Color("#2a9d8f")],
}

func emote(kind: String) -> void:
	if _bubble and is_instance_valid(_bubble):
		_bubble.queue_free()
	var e: Array = EMOTES.get(kind, EMOTES["happy"])
	var b := Node2D.new()
	b.z_index = 45
	b.position = Vector2(12, -_head_y() - 14)
	var panel := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiKit.CREAM
	sb.set_corner_radius_all(40)
	sb.border_color = Color("#ead9b8")
	sb.set_border_width_all(5)
	sb.shadow_color = Color(0, 0, 0, 0.18)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 4)
	panel.add_theme_stylebox_override("panel", sb)
	var holder := Node2D.new()
	holder.scale = Vector2(0.2, 0.2)
	holder.add_child(panel)
	b.add_child(holder)
	var ic: Array = Art.EMOTE_ICONS.get(kind, ["face_smile", Color.WHITE])
	if not Art.UI_ICONS.has(ic[0]):
		ic = ["star", Color.WHITE]
	if true:  # always a single pixel icon; never text (text could overflow the bubble)
		panel.size = Vector2(100, 90)
		panel.position = Vector2(-50, -90)
		var spr := Sprite2D.new()
		spr.texture = Art.ui_icon(ic[0])
		spr.modulate = ic[1]
		spr.position = Vector2(0, -9)
		b.add_child(spr)
		var wt := spr.create_tween().set_loops()
		wt.tween_property(spr, "rotation", 0.18, 0.18).set_trans(Tween.TRANS_SINE)
		wt.tween_property(spr, "rotation", -0.18, 0.36).set_trans(Tween.TRANS_SINE)
		wt.tween_property(spr, "rotation", 0.0, 0.18).set_trans(Tween.TRANS_SINE)
		wt.tween_interval(0.3)
	else:
		var l := Label.new()
		l.text = e[0]
		l.add_theme_font_override("font", Art.world_font())
		l.add_theme_font_size_override("font_size", 52)
		l.add_theme_color_override("font_color", e[1])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var w := maxf(l.get_minimum_size().x + 40, 90)
		panel.size = Vector2(w, 80)
		panel.position = Vector2(-w * 0.5, -80)
		l.size = panel.size
		panel.add_child(l)
	add_child(b)
	_bubble = b
	b.scale = Vector2.ZERO
	var t := b.create_tween()
	t.tween_property(b, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(b, "position:y", b.position.y - 2, 0.4).set_trans(Tween.TRANS_SINE)
	t.tween_property(b, "position:y", b.position.y, 0.4).set_trans(Tween.TRANS_SINE)
	t.tween_property(b, "position:y", b.position.y - 2, 0.4).set_trans(Tween.TRANS_SINE)
	t.tween_property(b, "position:y", b.position.y, 0.4).set_trans(Tween.TRANS_SINE)
	t.tween_interval(0.8)
	t.tween_property(b, "scale", Vector2.ZERO, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.tween_callback(b.queue_free)
	Sfx.play("emote")

func animate(kind: String) -> void:
	if _anim_tween:
		_anim_tween.kill()
	sprite.position = Vector2.ZERO
	sprite.rotation = 0.0
	var t := create_tween()
	_anim_tween = t
	var s := _base_scale
	match kind:
		"jump":
			t.tween_property(body, "scale", s * Vector2(1.25, 0.75), 0.08)
			t.tween_property(body, "scale", s * Vector2(0.8, 1.25), 0.1)
			t.parallel().tween_property(sprite, "position:y", -10.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			t.tween_property(sprite, "position:y", 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			t.parallel().tween_property(body, "scale", s, 0.18)
			t.tween_property(body, "scale", s * Vector2(1.2, 0.8), 0.06)
			t.tween_property(body, "scale", s, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		"spin":
			t.tween_property(body, "scale", s * Vector2(1.15, 0.85), 0.08)
			t.tween_property(body, "scale:x", -s.x, 0.12)
			t.tween_property(body, "scale:x", s.x, 0.12)
			t.tween_property(body, "scale:x", -s.x, 0.12)
			t.tween_property(body, "scale:x", s.x, 0.12)
			t.tween_property(body, "scale", s, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		"shake":
			for i in 6:
				t.tween_property(sprite, "position:x", 2.0 if i % 2 == 0 else -2.0, 0.05)
			t.tween_property(sprite, "position:x", 0.0, 0.05)
		"dance":
			for i in 4:
				t.tween_property(sprite, "rotation", 0.25 if i % 2 == 0 else -0.25, 0.15).set_trans(Tween.TRANS_SINE)
				t.parallel().tween_property(sprite, "position:y", -4.0, 0.075)
				t.parallel().tween_property(sprite, "position:y", 0.0, 0.075).set_delay(0.075)
			t.tween_property(sprite, "rotation", 0.0, 0.15)
	Sfx.play("pop", 0.15, -10.0)
