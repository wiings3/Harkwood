extends Node
## Small original synthesized cues; no runtime downloads or dependencies.
var muted = false
var voices: Array[AudioStreamPlayer] = []
var samples: Dictionary = {}

func _ready() -> void:
	for i in range(6):
		var voice = AudioStreamPlayer.new()
		voice.volume_db = -20
		add_child(voice)
		voices.append(voice)
	for cue in ["click", "forge", "hit", "hurt", "win", "heal", "lose"]:
		samples[cue] = make_sample(cue)

func play(cue: String) -> void:
	if muted or DisplayServer.get_name() == "headless":
		return
	for voice in voices:
		if not voice.playing:
			voice.stream = samples.get(cue, samples.click)
			voice.play()
			return

func make_sample(cue: String) -> AudioStreamWAV:
	var frequencies = {"click": 510.0, "forge": 780.0, "hit": 190.0, "hurt": 110.0,
		"win": 523.25, "heal": 659.25, "lose": 146.83}
	var duration = 0.45 if cue in ["win", "heal", "lose"] else 0.13
	var rate = 22050
	var count = int(rate * duration)
	var bytes = PackedByteArray()
	bytes.resize(count * 2)
	var base = frequencies[cue]
	for i in range(count):
		var t = float(i) / rate
		var envelope = sin(minf(t * 90, PI / 2)) * pow(1.0 - t / duration, 2.0)
		var tone = sin(TAU * base * t) * 0.65 + sin(TAU * base * 1.5 * t) * 0.2
		if cue in ["forge", "hit", "hurt"]:
			tone += sin(t * 17131) * sin(t * 57123) * 0.2
		bytes.encode_s16(i * 2, int(clampf(tone * envelope, -1, 1) * 25000))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = bytes
	return stream
