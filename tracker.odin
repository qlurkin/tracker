package tracker

import "core:container/queue"
import "core:fmt"
import "core:math"

Frame :: distinct [2]Sample

Biquad :: struct {
	b0, b1, b2: Sample,
	a1, a2:     Sample,
	x1, x2:     Sample,
	y1, y2:     Sample,
}

Memory :: struct {
	value: [2]Sample,
}

VoiceCreationRequest :: struct {
	note: u8,
}

Tracker :: struct {
	highpass:             [2]Biquad,
	lowpass:              [2]Biquad,
	memory:               Memory,
	bpm:                  u8,
	phrase:               [16]u8,
	samples_in_tick:      u32,
	cursor:               PhraseCursor,
	synth:                SimpleSynth,
	voices:               [dynamic]Voice,
	voice_creation_queue: queue.Queue(VoiceCreationRequest),
}

// arg goes between 0 and 1 (from left to right)
pan :: proc(x: Sample, arg: Sample) -> Frame {
	return Frame{x * math.sqrt(1 - arg), x * math.sqrt(arg)}
}

make_lowpass :: proc(cutoff: Sample) -> Biquad {
	w0 := 2 * math.PI * cutoff / f64(SAMPLE_RATE)
	c := math.cos(w0)
	s := math.sin(w0)
	a := s * math.sqrt(f64(2)) / 2
	a0 := 1 + a

	return Biquad {
		b0 = (1 - c) / 2 / a0,
		b1 = (1 - c) / a0,
		b2 = (1 - c) / 2 / a0,
		a1 = -2 * c / a0,
		a2 = (1 - a) / a0,
	}
}

make_highpass :: proc(cutoff: Sample) -> Biquad {
	w0 := 2 * math.PI * cutoff / f64(SAMPLE_RATE)
	c := math.cos(w0)
	s := math.sin(w0)
	a := s * math.sqrt(f64(2)) / 2
	a0 := 1 + a

	return Biquad {
		b0 = (1 + c) / 2 / a0,
		b1 = -(1 + c) / a0,
		b2 = (1 + c) / 2 / a0,
		a1 = -2 * c / a0,
		a2 = (1 - a) / a0,
	}
}


make_tracker :: proc() -> ^Tracker {
	res := new(Tracker)
	res.highpass[0] = make_highpass(20)
	res.highpass[1] = res.highpass[0]
	res.lowpass[0] = make_lowpass(18000)
	res.lowpass[1] = res.lowpass[0]
	res.bpm = 128
	res.phrase = [16]u8{31, 255, 255, 255, 31, 255, 255, 255, 31, 255, 255, 255, 31, 255, 255, 255}
	// res.synth = SimpleSynth {
	// 	attack   = 0.0,
	// 	decay    = 1.0,
	// 	sustain  = 0.0,
	// 	release  = 1.0,
	// 	hold     = 0.0,
	// 	waveform = Waveform.Sine,
	// }
	res.synth = SimpleSynth {
		waveform  = .Sine,
		functions = [2]ModulatorFunction{make_adsr(0.0, 0.7, 0.0, 0.7), nil},
	}
	queue.init(&res.voice_creation_queue)
	return res
}

delete_tracker :: proc(tracker: ^Tracker) {
	delete(tracker.voices)
	queue.destroy(&tracker.voice_creation_queue)
}

process_biquad_mono :: proc(bq: ^Biquad, x: Sample) -> Sample {
	y := bq.b0 * x + bq.b1 * bq.x1 + bq.b2 * bq.x2 - bq.a1 * bq.y1 - bq.a2 * bq.y2

	bq.x2 = bq.x1
	bq.x1 = x

	bq.y2 = bq.y1
	bq.y1 = y

	return y
}

process_biquad_stereo :: proc(bq: ^[2]Biquad, f: Frame) -> Frame {
	res: Frame
	for i in 0 ..< 2 {
		res[i] = process_biquad_mono(&bq[i], f[i])
	}
	return res
}

process_biquad :: proc {
	process_biquad_mono,
	process_biquad_stereo,
}


process_numeric_protection :: proc(memory: ^Memory, f: Frame) -> Frame {
	res: Frame
	for i in 0 ..< 2 {
		x := f[i]
		if math.is_nan(x) || math.is_inf(x) {
			x = memory.value[i]
		}
		memory.value[i] = x
		res[i] = x
	}
	return res
}

process_limiter :: proc(f: Frame) -> Frame {
	res: Frame
	for i in 0 ..< 2 {
		res[i] = f[i] / (1 + math.abs(f[i]))
	}
	return res
}

process :: proc(tracker: ^Tracker, f: Frame) -> Frame {
	res: Frame

	res = process_biquad(&tracker.highpass, f)
	res = process_biquad(&tracker.lowpass, res)
	res = process_numeric_protection(&tracker.memory, res)
	res = process_limiter(res)

	return res
}

tick :: proc(tracker: ^Tracker) {
	update_phrase_cursor(tracker)
}

update_tick :: proc(tracker: ^Tracker) {
	spt := samples_per_tick(tracker.bpm)
	tracker.samples_in_tick += 1
	if tracker.samples_in_tick == spt {
		tracker.samples_in_tick = 0
		tick(tracker)
	}
}

synthesize :: proc(tracker: ^Tracker) -> Frame {
	clean_voices(tracker)
	update_tick(tracker)
	s: Sample = 0

	for &voice in tracker.voices {
		s += next_voice(&voice)
	}

	f := pan(s, 0.5)
	f = process(tracker, f)

	return f
}

step :: proc(tracker: ^Tracker) {
	note := tracker.phrase[tracker.cursor.step]
	if note < OFF {
		queue.push(&tracker.voice_creation_queue, VoiceCreationRequest{note})
	}
}

PhraseCursor :: struct {
	step: u8,
	tick: u32,
}

update_phrase_cursor :: proc(tracker: ^Tracker) {
	tps := PPQ / 4
	tracker.cursor.tick += 1
	if tracker.cursor.tick == tps {
		tracker.cursor.tick = 0
		tracker.cursor.step += 1
		if tracker.cursor.step == 16 {
			tracker.cursor.step = 0
		}
		step(tracker)
	}
}

clean_voices :: proc(tracker: ^Tracker) {
	for i in 0 ..< len(tracker.voices) {
		if tracker.voices[i].released {
			if tracker.voices[i].modulators[ModulatorDestination.Volume] != nil {
				if tracker.voices[i].last_volume < 0.001 {
					unordered_remove(&tracker.voices, i)
					return
				}
			} else {
				unordered_remove(&tracker.voices, i)
				return
			}
		}
	}
}

handle_voice_creation_request :: proc(tracker: ^Tracker) {
	for queue.len(tracker.voice_creation_queue) > 0 {
		for &voice in tracker.voices {
			voice.released = true
		}
		rq := queue.dequeue(&tracker.voice_creation_queue)
		append(&tracker.voices, make_voice(&tracker.synth, f64(rq.note), 1.0))
	}
}
