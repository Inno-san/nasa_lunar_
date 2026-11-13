extends Node
## Simple sound hooks with a mute toggle. No audio files are required:
## short placeholder tones are generated in code. To use real sounds, drop
## click / alarm / win / lose (.ogg or .wav) into assets/audio/ and they are picked up automatically.

signal mute_changed(is_muted: bool)

const SAMPLE_RATE := 22050
const SOUNDS := {
	"click": {"notes": [[880.0, 0.05]], "volume": 0.3},
	"alarm": {"notes": [[920.0, 0.18], [680.0, 0.18]], "volume": 0.35},
	"win": {"notes": [[523.0, 0.14], [659.0, 0.14], [784.0, 0.14], [1047.0, 0.35]], "volume": 0.35},
	"lose": {"notes": [[392.0, 0.25], [330.0, 0.25], [262.0, 0.45]], "volume": 0.35},
}

var muted: bool = false
var _players: Dictionary = {}
var _alarm_timer: Timer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for sound_name in SOUNDS:
		var player := AudioStreamPlayer.new()
		player.stream = _load_or_make(sound_name)
		add_child(player)
		_players[sound_name] = player
	_alarm_timer = Timer.new()
	_alarm_timer.wait_time = 0.9
	_alarm_timer.timeout.connect(func() -> void: play("alarm"))
	add_child(_alarm_timer)
	# Every button in the game gets a click sound automatically.
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if node is BaseButton and not node.has_meta("sfx_hooked"):
		node.set_meta("sfx_hooked", true)
		node.pressed.connect(play.bind("click"))


func play(sound_name: String) -> void:
	if muted or not _players.has(sound_name):
		return
	var player: AudioStreamPlayer = _players[sound_name]
	player.play()


func start_alarm() -> void:
	play("alarm")
	_alarm_timer.start()


func stop_alarm() -> void:
	_alarm_timer.stop()


func set_muted(value: bool) -> void:
	muted = value
	if muted:
		stop_alarm()
	mute_changed.emit(muted)


func toggle_mute() -> void:
	set_muted(not muted)


func _load_or_make(sound_name: String) -> AudioStream:
	for ext in ["ogg", "wav"]:
		var path := "res://assets/audio/%s.%s" % [sound_name, ext]
		if ResourceLoader.exists(path):
			var res: Resource = load(path)
			if res is AudioStream:
				return res
	return _make_tone(SOUNDS[sound_name]["notes"], float(SOUNDS[sound_name]["volume"]))


func _make_tone(notes: Array, volume: float) -> AudioStreamWAV:
	var data := PackedByteArray()
	for note in notes:
		var freq: float = note[0]
		var count := int(SAMPLE_RATE * float(note[1]))
		for i in count:
			var t := float(i) / SAMPLE_RATE
			# Short fade in and out so the tone does not click.
			var fade := minf(1.0, minf(float(i) / 200.0, float(count - i) / 400.0))
			var sample := int(sin(TAU * freq * t) * 32767.0 * volume * fade)
			data.append(sample & 0xFF)
			data.append((sample >> 8) & 0xFF)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream
