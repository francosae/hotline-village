class_name Art
extends RefCounted
## ONE place for every texture path and frame/region. Swap art here only.

const S := "res://assets/sprout/"
const TILE := 16

const SHEETS := {
	"player": {"path": S + "Characters/Basic Charakter Spritesheet.png", "frame": Vector2i(48, 48),
		"dirs": {"down": 0, "up": 1, "left": 2, "right": 3}, "idle": [0, 1], "walk": [2, 3], "fps": 5.0},
	"maple": {"path": S + "Characters/Free Cow Sprites.png", "frame": Vector2i(32, 32),
		"idle_row": 0, "idle_count": 3, "fps": 3.0, "scale": 1.0, "modulate": Color(1, 1, 1)},
	"clucky": {"path": S + "Characters/Free Chicken Sprites.png", "frame": Vector2i(16, 16),
		"idle_row": 0, "idle_count": 4, "fps": 5.0, "scale": 1.5, "modulate": Color(1, 1, 1)},
	"juniper": {"path": S + "Characters/Basic Charakter Spritesheet.png", "frame": Vector2i(48, 48),
		"idle_row": 0, "idle_count": 2, "fps": 3.0, "scale": 1.0, "modulate": Color(1.0, 0.86, 0.84)},
}

const ITEMS := {
	"egg": {"path": S + "Objects/Egg item.png", "region": Rect2(0, 0, 16, 16)},
	"milk": {"path": S + "Objects/Simple Milk and grass item.png", "region": Rect2(16, 0, 16, 16)},
	"wheat": {"path": S + "Objects/Basic Plants.png", "region": Rect2(80, 0, 16, 16)},
	"tomato": {"path": S + "Objects/Basic Plants.png", "region": Rect2(96, 16, 16, 16), "modulate": Color(1.3, 0.6, 0.55)},
	"pumpkin": {"path": S + "Objects/Basic Plants.png", "region": Rect2(96, 16, 16, 16), "modulate": Color(1.6, 1.0, 0.35)},
	"wood": {"path": S + "Objects/Basic Grass Biom things 1.png", "region": Rect2(80, 32, 16, 16)},
	"flower": {"path": S + "Objects/Basic Grass Biom things 1.png", "region": Rect2(112, 48, 16, 16)},
	"mushroom": {"path": S + "Objects/Basic Grass Biom things 1.png", "region": Rect2(96, 0, 16, 16)},
	# round 2 (farming)
	"seed_wheat": {"path": S + "Objects/Basic Plants.png", "region": Rect2(0, 0, 16, 16)},
	"seed_tomato": {"path": S + "Objects/Basic Plants.png", "region": Rect2(0, 16, 16, 16)},
	"sapling": {"path": S + "Objects/Basic Grass Biom things 1.png", "region": Rect2(96, 16, 16, 16)},
	"plant_tree": {"path": S + "Objects/Basic Grass Biom things 1.png", "region": Rect2(0, 0, 16, 32)},
}

# In-world look of collectibles (no white icon outline, sits on the pixel grid)
const ITEM_WORLD := {
	"egg": {"path": S + "Characters/Egg_And_Nest.png", "region": Rect2(32, 0, 16, 16)},
	"wheat": {"path": S + "Objects/Basic Plants.png", "region": Rect2(64, 0, 16, 16)},
	"tomato": {"path": S + "Objects/Basic Plants.png", "region": Rect2(64, 16, 16, 16), "modulate": Color(1.3, 0.75, 0.7)},
	"pumpkin": {"path": S + "Objects/Basic Plants.png", "region": Rect2(64, 16, 16, 16), "modulate": Color(1.5, 1.05, 0.5)},
}

const UI_SHEET := S + "ui/Sprite sheet for Basic Pack.png"
const UI_ICONS := {
	"coin": Rect2(627, 98, 9, 12), "star": Rect2(529, 97, 14, 13), "heart": Rect2(579, 98, 11, 12),
	"face_grin": Rect2(356, 148, 9, 9), "face_smile": Rect2(372, 148, 9, 9), "face_neutral": Rect2(388, 148, 9, 9),
	"face_sad": Rect2(404, 148, 9, 9), "face_angry": Rect2(420, 148, 9, 9),
	"bang": Rect2(614, 209, 4, 14), "question": Rect2(674, 195, 12, 12),
}
# emote kind -> [ui icon id, modulate]
const EMOTE_ICONS := {
	"happy": ["face_grin", Color.WHITE], "laugh": ["face_smile", Color.WHITE], "love": ["heart", Color.WHITE],
	"surprised": ["bang", Color("#f08a3c")], "question": ["question", Color("#5b8bd9")], "angry": ["face_angry", Color.WHITE],
	"sad": ["face_sad", Color.WHITE], "idea": ["star", Color.WHITE], "music": ["star", Color.WHITE],
	"sleepy": ["face_neutral", Color.WHITE], "think": ["question", Color("#a08060")], "book": ["bang", Color("#2a9d8f")],
}
const DOOR := {"path": S + "Tilesets/Doors.png", "region": Rect2(0, 16, 16, 16)}
const FONT_BOLD := "res://fonts/MPlusRounded1c-ExtraBold.ttf"
const FONT_BODY := "res://fonts/MPlusRounded1c-Bold.ttf"

const ITEM_NAMES := {"egg": "egg", "milk": "milk", "wheat": "wheat", "tomato": "tomato",
	"pumpkin": "pumpkin", "wood": "wood", "flower": "flower", "mushroom": "mushroom",
	"seed_wheat": "wheat seeds", "seed_tomato": "tomato seeds", "sapling": "sapling", "plant_tree": "trees planted"}

const BIOM := S + "Objects/Basic Grass Biom things 1.png"
const PROPS := {
	"tree_small": {"path": BIOM, "region": Rect2(0, 0, 16, 32), "solid": Vector2(6, 4)},
	"tree_big": {"path": BIOM, "region": Rect2(16, 0, 32, 32), "solid": Vector2(10, 5)},
	"tree_fruit": {"path": BIOM, "region": Rect2(48, 0, 32, 32), "solid": Vector2(10, 5)},
	"bush": {"path": BIOM, "region": Rect2(16, 48, 16, 16), "solid": Vector2(6, 3)},
	"bush_berry": {"path": BIOM, "region": Rect2(0, 48, 16, 16), "solid": Vector2(6, 3)},
	"rock": {"path": BIOM, "region": Rect2(128, 16, 16, 16), "solid": Vector2(6, 3)},
	"sunflower": {"path": BIOM, "region": Rect2(128, 32, 16, 32), "solid": Vector2.ZERO},
	"flower_y": {"path": BIOM, "region": Rect2(96, 32, 16, 16), "solid": Vector2.ZERO},
	"flower_y2": {"path": BIOM, "region": Rect2(112, 32, 16, 16), "solid": Vector2.ZERO},
	"flower_p": {"path": BIOM, "region": Rect2(96, 48, 16, 16), "solid": Vector2.ZERO},
	"flower_b": {"path": BIOM, "region": Rect2(80, 48, 16, 16), "solid": Vector2.ZERO},
	"sprout": {"path": BIOM, "region": Rect2(96, 16, 16, 16), "solid": Vector2.ZERO},
	"lily": {"path": BIOM, "region": Rect2(112, 64, 16, 16), "solid": Vector2.ZERO},
	"fence_h": {"path": S + "Tilesets/Fences.png", "region": Rect2(16, 48, 48, 16), "solid": Vector2(22, 3)},
	"fence_post": {"path": S + "Tilesets/Fences.png", "region": Rect2(0, 48, 16, 16), "solid": Vector2(3, 3)},
	"coop": {"path": S + "Objects/Free_Chicken_House.png", "region": Rect2(0, 0, 48, 48), "solid": Vector2(18, 8)},
	"chest": {"path": S + "Objects/Chest.png", "region": Rect2(0, 0, 48, 48), "solid": Vector2(8, 4)},
	# house = roof block over two framed wall blocks (composed in main.gd)
	"house_roof": {"path": S + "Tilesets/Wooden_House_Roof_Tilset.png", "region": Rect2(48, 32, 64, 48), "solid": Vector2.ZERO},
	"house_wall": {"path": S + "Tilesets/Wooden_House_Walls_Tilset.png", "region": Rect2(48, 0, 32, 32), "solid": Vector2.ZERO},
}

# Ground tiles (blitted into one big texture by main.gd)
const GROUND := {
	"grass_path": S + "Tilesets/Grass.png",
	"grass": [Rect2i(16, 0, 16, 16), Rect2i(32, 0, 16, 16), Rect2i(16, 16, 16, 16), Rect2i(0, 0, 16, 16), Rect2i(48, 0, 16, 16), Rect2i(80, 0, 16, 16)],
	"grass_weights": [10, 6, 6, 1, 1, 1],
	"path_path": S + "Tilesets/Tilled Dirt.png",
	"path": Rect2i(16, 16, 16, 16),
	"water_path": S + "Tilesets/Water.png",
	"water": Rect2i(0, 0, 16, 16),
}

const NPC_COLORS := {"maple": Color("#e8964a"), "clucky": Color("#e86a6a"), "juniper": Color("#6cbf6a")}
const NPC_NAMES := {"maple": "Maple", "clucky": "Clucky", "juniper": "Juniper"}

static var _font: Font
static var _bold: Font

static func font_bold() -> Font:
	if _bold == null:
		_bold = load(FONT_BOLD) if ResourceLoader.exists(FONT_BOLD) else ThemeDB.fallback_font
	return _bold

static func ui_icon(id: String) -> AtlasTexture:
	return atlas(UI_SHEET, UI_ICONS[id])

static func item_world(id: String) -> Texture2D:
	if ITEM_WORLD.has(id):
		return atlas(ITEM_WORLD[id]["path"], ITEM_WORLD[id]["region"])
	return item_icon(id)

static func item_world_modulate(id: String) -> Color:
	if ITEM_WORLD.has(id):
		return ITEM_WORLD[id].get("modulate", Color.WHITE)
	return item_modulate(id)
static var _cache := {}

static func tex(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path]
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		t = load(path)
	if t == null:
		var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		img.fill(Color(1, 0, 1))
		t = ImageTexture.create_from_image(img)
	_cache[path] = t
	return t

static func atlas(path: String, region: Rect2) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = tex(path)
	a.region = region
	return a

static func item_icon(id: String) -> Texture2D:
	var d: Dictionary = ITEMS.get(id, ITEMS["egg"])
	return atlas(d["path"], d["region"])

static func item_modulate(id: String) -> Color:
	return ITEMS.get(id, {}).get("modulate", Color.WHITE)

static func prop(id: String) -> AtlasTexture:
	var d: Dictionary = PROPS[id]
	return atlas(d["path"], d["region"])

static func player_frames() -> SpriteFrames:
	var d: Dictionary = SHEETS["player"]
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var fs: Vector2i = d["frame"]
	for dir in d["dirs"]:
		var row: int = d["dirs"][dir]
		for kind in ["idle", "walk"]:
			var anim: String = kind + "_" + dir
			sf.add_animation(anim)
			sf.set_animation_speed(anim, d["fps"] * (1.6 if kind == "walk" else 1.0))
			for c in d[kind]:
				sf.add_frame(anim, atlas(d["path"], Rect2(c * fs.x, row * fs.y, fs.x, fs.y)))
	return sf

static func npc_frames(id: String) -> SpriteFrames:
	var d: Dictionary = SHEETS[id]
	var sf := SpriteFrames.new()
	sf.set_animation_speed("default", d["fps"])
	var fs: Vector2i = d["frame"]
	for c in range(d["idle_count"]):
		sf.add_frame("default", atlas(d["path"], Rect2(c * fs.x, d["idle_row"] * fs.y, fs.x, fs.y)))
	return sf

static func npc_portrait(id: String) -> Texture2D:
	var d: Dictionary = SHEETS[id]
	var fs: Vector2i = d["frame"]
	return atlas(d["path"], Rect2(0, d["idle_row"] * fs.y, fs.x, fs.y))

static func ground_image(path: String) -> Image:
	var img: Image = tex(path).get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	return img

## Crisp world-space font (MSDF) for labels drawn under the zoomed camera.
static func world_font() -> Font:
	if _font == null:
		var base: FontFile = load(FONT_BOLD if ResourceLoader.exists(FONT_BOLD) else "res://fonts/Fredoka.ttf")
		var f: FontFile = base.duplicate()
		f.multichannel_signed_distance_field = true
		f.msdf_pixel_range = 16
		_font = f
	return _font

static func item_name(id: String) -> String:
	return ITEM_NAMES.get(id, id.replace("_", " "))
