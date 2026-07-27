package tracker

import "core:math"

Frame :: distinct [2]f32

Biquad :: struct {
	b0, b1, b2: f32,
	a1, a2:     f32,
	x1, x2:     f32,
	y1, y2:     f32,
}

Memory :: struct {
	value: [2]f32,
}

Tracker :: struct {
	highpass: [2]Biquad,
	lowpass:  [2]Biquad,
	memory:   Memory,
	oscillator: Oscillator,
}

// arg goes between 0 and 1 (from left to right)
pan :: proc(x: f32, arg: f32) -> Frame {
	return Frame{x * math.sqrt(1-arg), x * math.sqrt(arg)}
}

make_lowpass :: proc(cutoff: f32) -> Biquad {
	w0 := 2*math.PI*cutoff/f32(SAMPLE_RATE)
	c := math.cos(w0)
	s := math.sin(w0)
	a := s*math.sqrt(f32(2))/2
	a0 := 1 + a

	return Biquad {
		b0 = (1-c)/2/a0,
		b1 = (1-c)/a0,
		b2 = (1-c)/2/a0,
		a1 = -2*c/a0,
		a2 = (1 - a)/a0,
	}
}

make_highpass :: proc(cutoff: f32) -> Biquad {
	w0 := 2*math.PI*cutoff/f32(SAMPLE_RATE)
	c := math.cos(w0)
	s := math.sin(w0)
	a := s*math.sqrt(f32(2))/2
	a0 := 1 + a

	return Biquad {
		b0 = (1+c)/2/a0,
		b1 = -(1+c)/a0,
		b2 = (1+c)/2/a0,
		a1 = -2*c/a0,
		a2 = (1 - a)/a0,
	}
}

make_tracker :: proc() -> ^Tracker {
	res := new(Tracker)
	res.oscillator = make_oscillator(440)
	res.highpass[0] = make_highpass(20)
	res.highpass[1] = res.highpass[0]
	res.lowpass[0] = make_lowpass(18000)
	res.lowpass[1] = res.lowpass[0]
	return res
}

process_biquad_mono :: proc(bq: ^Biquad, x: f32) -> f32 {
	y := bq.b0 * x + bq.b1 * bq.x1 + bq.b2 * bq.x2 - bq.a1 * bq.y1 - bq.a2 * bq.y2

	bq.x2 = bq.x1
	bq.x1 = x

	bq.y2 = bq.y1
	bq.y1 = y

	return y
}

process_biquad_stereo :: proc(bq: ^[2]Biquad, f: Frame) -> Frame {
	res: Frame
	for i in 0..<2 {
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
	for i in 0..<2 {
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
	for i in 0..<2 {
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

synthesize :: proc(tracker: ^Tracker) -> Frame {
	s := next_band_limited_square(&tracker.oscillator)
	//s := next_square(&tracker.oscillator)
	f := pan(s, 0.5)
	f = process(tracker, f)
	return f
}
