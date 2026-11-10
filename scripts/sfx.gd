extends Node
## Tiny sfx pool + music.

const SOUNDS := {
	"pickup": "res://assets/kenney/sfx/pluck_001.ogg",
	"pop": "res://assets/kenney/sfx/pluck_002.ogg",
	"emote": "res://assets/kenney/sfx/drop_002.ogg",
	"open": "res://assets/kenney/sfx/open_001.ogg",
	"close": "res://assets/kenney/sfx/close_001.ogg",
	"quest": "res://assets/kenney/sfx/maximize_006.ogg",
	"jingle": "res://assets/kenney/sfx/confirmation_002.ogg",
	"coin": "res://assets/kenney/sfx/glass_006.ogg",
	"select": "res://assets/kenney/sfx/select_001.ogg",
	"error": "res://assets/kenney/sfx/error_004.ogg",
	"talk": "res://assets/kenney/sfx/question_002.ogg",
}
const MUSIC := "res://assets/music/chill.ogg"

var _players: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.volume_db = -14.0
	add_child(_music)

func play(name: String, pitch_var: float = 0.08, vol_db: float = -4.0) -> void:
	var path: String = SOUNDS.get(name, "")
	if path == "" or not ResourceLoader.exists(path):
		return
	for p in _players:
		if not p.playing:
			p.stream = load(path)
			p.pitch_scale = randf_range(1.0 - pitch_var, 1.0 + pitch_var)
			p.volume_db = vol_db
			p.play()
			return

func music_on() -> void:
	if _music.playing or not ResourceLoader.exists(MUSIC):
		return
	var s: AudioStream = load(MUSIC)
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	_music.stream = s
	_music.play()

func duck(on: bool) -> void:
	create_tween().tween_property(_music, "volume_db", -24.0 if on else -14.0, 0.4)
