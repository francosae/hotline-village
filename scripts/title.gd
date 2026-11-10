extends Control
## Title screen: AC-style live diorama (Sprout Lands art), ribbon logo, pill buttons.

const ORANGE := Color("#f39c3d")
const GREEN := Color("#6cbf6a")
const CREAM := Color("#fff8e7")
const BROWN := Color("#6b4a32")

var ribbon: Node2D
var press_pill: PanelContainer

func _ready() -> void:
	_build_sky()
	_build_confetti()
	_build_diorama()
	_build_petals()
	_build_logo()
	_build_pills()
	if OS.get_environment("HV_SHOT") != "":
		await get_tree().create_timer(1.2).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/hv_0_title.png")
		print("[shot] /tmp/hv_0_title.png")
		_go()

# ---------------- background ----------------
func _build_sky() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
void fragment(){
	vec2 uv = UV;
	vec3 sky = mix(vec3(0.66, 0.87, 0.98), vec3(1.0, 0.94, 0.84), uv.y * 1.3);
	float stripe = step(0.5, fract((uv.x * 1.78 - uv.y) * 7.0 + TIME * 0.03));
	sky = mix(sky, sky + vec3(0.035), stripe);
	COLOR = vec4(sky, 1.0);
}"""
	var m := ShaderMaterial.new()
	m.shader = sh
	bg.material = m
	add_child(bg)

func _build_confetti() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var icons := ["star"]
	var tints := [Color("#ffd36b"), Color("#ff9fb8"), Color("#9fd8ff"), Color("#fff3c4")]
	for i in 22:
		var s := Sprite2D.new()
		s.texture = Art.ui_icon(icons[i % icons.size()])
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.position = Vector2(rng.randf_range(30, 1250), rng.randf_range(20, 420))
		s.scale = Vector2.ONE * rng.randf_range(1.6, 2.6)
		s.rotation = rng.randf_range(-0.6, 0.6)
		s.modulate = Color(tints[i % tints.size()], rng.randf_range(0.7, 0.95))
		add_child(s)
		var t := s.create_tween().set_loops()
		t.tween_property(s, "rotation", s.rotation + 0.4, rng.randf_range(1.6, 2.6)).set_trans(Tween.TRANS_SINE)
		t.tween_property(s, "rotation", s.rotation - 0.4, rng.randf_range(1.6, 2.6)).set_trans(Tween.TRANS_SINE)
	# leaves: small sprout sprites
	for i in 10:
		var l := Sprite2D.new()
		l.texture = Art.prop("sprout")
		l.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		l.position = Vector2(rng.randf_range(30, 1250), rng.randf_range(20, 400))
		l.scale = Vector2.ONE * 2.0
		l.rotation = rng.randf_range(-1.0, 1.0)
		l.modulate = Color(1, 1, 1, 0.4)
		add_child(l)

func _grass_texture() -> Texture2D:
	var img: Image = Art.ground_image(Art.GROUND["grass_path"])
	var r: Rect2i = Art.GROUND["grass"][0]
	return ImageTexture.create_from_image(img.get_region(r))

func _build_diorama() -> void:
	var top := 450.0
	var pts := PackedVector2Array()
	var edge := PackedVector2Array()
	for i in 65:
		var x := i * 20.0
		var y := top + sin(x * 0.012) * 14.0 + sin(x * 0.031 + 1.0) * 6.0
		pts.append(Vector2(x, y))
		edge.append(Vector2(x, y))
	pts.append(Vector2(1280, 720))
	pts.append(Vector2(0, 720))
	var g := Polygon2D.new()
	g.polygon = pts
	g.texture = _grass_texture()
	g.texture_scale = Vector2(0.25, 0.25)
	g.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	g.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(g)
	var line := Line2D.new()
	line.points = edge
	line.width = 10
	line.default_color = CREAM
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	add_child(line)
	var stage := Node2D.new()
	stage.y_sort_enabled = true
	add_child(stage)
	# trees framing the sides, flowers sprinkled
	var props := [
		["tree_big", Vector2(80, 560)], ["tree_fruit", Vector2(205, 520)], ["tree_small", Vector2(1080, 525)],
		["tree_big", Vector2(1200, 575)], ["bush_berry", Vector2(300, 640)], ["bush", Vector2(990, 650)],
		["sunflower", Vector2(470, 520)], ["flower_y", Vector2(540, 690)], ["flower_p", Vector2(760, 690)],
		["flower_b", Vector2(1010, 560)], ["flower_y2", Vector2(130, 690)], ["flower_p", Vector2(1150, 690)],
		["sunflower", Vector2(820, 515)], ["rock", Vector2(390, 700)], ["flower_b", Vector2(260, 560)],
	]
	for p in props:
		var s := Sprite2D.new()
		s.texture = Art.prop(p[0])
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.centered = true
		s.offset = Vector2(0, -s.texture.get_size().y * 0.5)
		s.scale = Vector2.ONE * 4.0
		s.position = p[1]
		stage.add_child(s)
		if String(p[0]).begins_with("tree"):
			var t := s.create_tween().set_loops()
			t.tween_property(s, "skew", 0.03, 1.8).set_trans(Tween.TRANS_SINE)
			t.tween_property(s, "skew", -0.03, 1.8).set_trans(Tween.TRANS_SINE)
	# villagers idling
	var cast := [["maple", Vector2(390, 630), 4.0, true], ["juniper", Vector2(640, 660), 3.5, false], ["clucky", Vector2(880, 630), 3.5, false]]
	for c in cast:
		var a := AnimatedSprite2D.new()
		a.sprite_frames = Art.npc_frames(c[0])
		a.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		a.modulate = Art.SHEETS[c[0]]["modulate"]
		var fs: Vector2i = Art.SHEETS[c[0]]["frame"]
		a.offset = Vector2(0, -fs.y * 0.5)
		a.scale = Vector2.ONE * c[2] * float(Art.SHEETS[c[0]].get("scale", 1.0)) / (1.5 if c[0] == "clucky" else 1.0)
		a.flip_h = c[3]
		a.position = c[1]
		a.play()
		stage.add_child(a)
		var t := a.create_tween().set_loops()
		t.tween_interval(randf() * 0.8)
		t.tween_property(a, "scale:y", a.scale.y * 0.95, 0.5).set_trans(Tween.TRANS_SINE)
		t.tween_property(a, "scale:y", a.scale.y, 0.5).set_trans(Tween.TRANS_SINE)

func _build_petals() -> void:
	for col in [Color("#ffc4d6"), Color("#ffe7a8"), Color("#ffffff")]:
		var p := CPUParticles2D.new()
		p.amount = 18
		p.lifetime = 11.0
		p.preprocess = 11.0
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		p.emission_rect_extents = Vector2(900, 10)
		p.position = Vector2(760, -20)
		p.direction = Vector2(-0.35, 1)
		p.spread = 20
		p.gravity = Vector2(0, 8)
		p.initial_velocity_min = 30
		p.initial_velocity_max = 60
		p.angular_velocity_min = -140
		p.angular_velocity_max = 140
		p.scale_amount_min = 4
		p.scale_amount_max = 8
		p.color = col
		add_child(p)

# ---------------- logo ----------------
func _ribbon_band(w: float, h: float, col: Color, notch: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(-w, -h), Vector2(w, -h), Vector2(w - notch, 0), Vector2(w, h), Vector2(-w, h), Vector2(-w + notch, 0)])

func _build_logo() -> void:
	ribbon = Node2D.new()
	ribbon.position = Vector2(640, 175)
	ribbon.rotation = deg_to_rad(-4)
	add_child(ribbon)
	var shadow := Polygon2D.new()
	shadow.polygon = _ribbon_band(520, 72, Color.BLACK, 40)
	shadow.color = Color(0.3, 0.18, 0.08, 0.22)
	shadow.position = Vector2(8, 12)
	ribbon.add_child(shadow)
	var tails := Polygon2D.new()
	tails.polygon = _ribbon_band(520, 60, GREEN, 40)
	tails.color = GREEN
	tails.position = Vector2(0, 14)
	ribbon.add_child(tails)
	var band := Polygon2D.new()
	band.polygon = PackedVector2Array([Vector2(-460, -72), Vector2(460, -72), Vector2(460, 72), Vector2(-460, 72)])
	band.color = ORANGE
	ribbon.add_child(band)
	for y in [-58.0, 58.0]:
		var stitch := Line2D.new()
		stitch.points = PackedVector2Array([Vector2(-448, y), Vector2(448, y)])
		stitch.width = 4
		stitch.default_color = Color(1, 0.97, 0.9, 0.85)
		ribbon.add_child(stitch)
	var logo := UiKit.bold("Hotline Village", 118, Color("#7a4524"))
	logo.add_theme_color_override("font_outline_color", CREAM)
	logo.add_theme_constant_override("outline_size", 34)
	logo.add_theme_color_override("font_shadow_color", Color(0.3, 0.15, 0.05, 0.35))
	logo.add_theme_constant_override("shadow_offset_x", 4)
	logo.add_theme_constant_override("shadow_offset_y", 10)
	logo.add_theme_constant_override("shadow_outline_size", 34)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	logo.size = Vector2(1100, 180)
	logo.position = Vector2(-550, -98)
	ribbon.add_child(logo)
	var t := ribbon.create_tween().set_loops()
	t.tween_property(ribbon, "position:y", 165.0, 1.5).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(ribbon, "rotation", deg_to_rad(-3), 1.5).set_trans(Tween.TRANS_SINE)
	t.tween_property(ribbon, "position:y", 175.0, 1.5).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(ribbon, "rotation", deg_to_rad(-4.5), 1.5).set_trans(Tween.TRANS_SINE)

# ---------------- pills ----------------
func _pill(text: String, size: int, bg: Color, fg: Color, border: Color, y: float, bold := true) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := UiKit.box(bg, 40, true, 4, border)
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	sb.content_margin_top = 6
	sb.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", sb)
	var l := UiKit.bold(text, size, fg) if bold else UiKit.label(text, size, fg)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	add_child(p)
	p.reset_size()
	p.position = Vector2(640 - p.size.x * 0.5, y)
	p.pivot_offset = p.size * 0.5
	return p

func _build_pills() -> void:
	_pill("Talk to your neighbors. Out loud.", 28, CREAM, BROWN, Color("#e8d5b0"), 285)
	press_pill = _pill("Press Enter", 38, CREAM, Color("#e07a3d"), ORANGE, 365)
	press_pill.mouse_filter = Control.MOUSE_FILTER_STOP
	press_pill.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	press_pill.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: _go())
	var tp := press_pill.create_tween().set_loops()
	tp.tween_property(press_pill, "scale", Vector2(1.07, 1.07), 0.65).set_trans(Tween.TRANS_SINE)
	tp.tween_property(press_pill, "scale", Vector2.ONE, 0.65).set_trans(Tween.TRANS_SINE)
	if OS.has_feature("web") and not Hotline.has_key():
		var note := _pill("Voice calls need a Vapi public key: the page will ask for it.", 18, Color(1, 1, 1, 0.85), BROWN, Color.TRANSPARENT, 440, false)
		note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var foot := UiKit.label("Powered by Vapi · Deepgram · Exa", 17, CREAM)
	foot.add_theme_color_override("font_outline_color", Color("#3d6b45"))
	foot.add_theme_constant_override("outline_size", 7)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.anchor_right = 1
	foot.position.y = 690
	add_child(foot)

func _unhandled_input(e: InputEvent) -> void:
	if (e is InputEventKey and e.pressed and (e.physical_keycode == KEY_ENTER or e.physical_keycode == KEY_KP_ENTER or e.physical_keycode == KEY_SPACE)) \
		or (e is InputEventMouseButton and e.pressed):
		_go()

var _going := false
func _go() -> void:
	if _going:
		return
	_going = true
	Sfx.play("select")
	# Tutorial overlay + "H: help" pill live on the root so they survive the scene change.
	if get_tree().root.get_node_or_null("Tutorial") == null:
		var tut := CanvasLayer.new()
		tut.name = "Tutorial"
		tut.set_script(load("res://scripts/tutorial.gd"))
		get_tree().root.add_child.call_deferred(tut)
	get_tree().change_scene_to_file("res://scenes/main.tscn")
