extends Node2D
## A planted sapling: grows (scale tween) into a fruit tree; shake it for wood.

const BIOM := "res://assets/sprout/Objects/Basic Grass Biom things 1.png"

var grow_time := 20.0
var grown := false
var cooldown := 0.0
var sprite: Sprite2D

func _ready() -> void:
	sprite = Sprite2D.new()
	sprite.texture = Art.atlas(BIOM, Rect2(96, 16, 16, 16))
	sprite.offset = Vector2(0, -6)
	add_child(sprite)
	sprite.scale = Vector2(0.4, 1.6)
	var tw := create_tween()
	tw.tween_property(sprite, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	# halfway: small tree, then full fruit tree
	var g := create_tween()
	g.tween_interval(grow_time * 0.5)
	g.tween_callback(_to_stage.bind(Rect2(0, 0, 16, 32), 0.55))
	g.tween_property(sprite, "scale", Vector2(0.8, 0.8), grow_time * 0.5)
	g.tween_callback(_to_stage.bind(Rect2(48, 0, 32, 32), 0.7))
	g.tween_property(sprite, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	g.tween_callback(_done)

func _to_stage(region: Rect2, from: float) -> void:
	sprite.texture = Art.atlas(BIOM, region)
	sprite.offset = Vector2(0, -region.size.y * 0.5 + 2)
	sprite.scale = Vector2(from * 1.2, from * 0.8)
	Fx.burst(get_parent(), position + Vector2(0, -10), "sparkle")

func _done() -> void:
	grown = true
	Sfx.play("pop", 0.1)
	var b := StaticBody2D.new()
	var c := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(10, 5)
	c.shape = r
	c.position = Vector2(0, -2.5)
	b.add_child(c)
	add_child(b)

func _process(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)

func shake() -> bool:
	if not grown or cooldown > 0.0:
		return false
	cooldown = 2.5
	var tw := create_tween()
	for a in [0.12, -0.1, 0.07, -0.04, 0.0]:
		tw.tween_property(sprite, "rotation", a, 0.07)
	sprite.scale = Vector2(1.08, 0.94)
	create_tween().tween_property(sprite, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	return true
