extends SceneTree

const SAMPLE_RATE := 44100

const SAMPLE_SPECS := {
	"drum_low": {"start_hz": 118.0, "end_hz": 54.0, "noise": 0.10, "duration": 0.62, "seed": 101},
	"drum_mid": {"start_hz": 190.0, "end_hz": 92.0, "noise": 0.18, "duration": 0.34, "seed": 202},
	"drum_rim": {"start_hz": 430.0, "end_hz": 245.0, "noise": 0.48, "duration": 0.16, "seed": 303},
	"drum_fail": {"start_hz": 92.0, "end_hz": 42.0, "noise": 0.22, "duration": 0.78, "seed": 404},
}


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/audio/fubo_guling"))
	for sample_name in SAMPLE_SPECS:
		var result := _write_sample(sample_name, SAMPLE_SPECS[sample_name])
		if result != OK:
			push_error("Failed to write %s.wav: %s" % [sample_name, error_string(result)])
			quit(1)
			return
	print("Generated four Fubo Guling drum samples.")
	quit(0)


func _write_sample(sample_name: String, spec: Dictionary) -> Error:
	var frame_count := int(float(spec.duration) * SAMPLE_RATE)
	var pcm := PackedByteArray()
	pcm.resize(frame_count * 2)
	var random := RandomNumberGenerator.new()
	random.seed = int(spec.seed)
	var phase := 0.0
	for frame in frame_count:
		var time := float(frame) / SAMPLE_RATE
		var progress := float(frame) / maxf(1.0, frame_count - 1.0)
		var frequency := lerpf(float(spec.start_hz), float(spec.end_hz), progress)
		phase += TAU * frequency / SAMPLE_RATE
		var attack := minf(1.0, time / 0.004)
		var decay := exp(-6.2 * progress)
		var body := sin(phase) + 0.34 * sin(phase * 1.73) + 0.16 * sin(phase * 2.47)
		var noise_value := random.randf_range(-1.0, 1.0) * float(spec.noise)
		var value := clampf((body * (1.0 - float(spec.noise) * 0.45) + noise_value) * attack * decay * 0.72, -1.0, 1.0)
		pcm.encode_s16(frame * 2, int(value * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = pcm
	return stream.save_to_wav("res://assets/audio/fubo_guling/%s" % sample_name)
