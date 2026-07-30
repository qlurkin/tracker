package tracker

Oscillator :: struct {
	frequency:       f32,
	phase:           u32,
	phase_increment: u32,
}

poly_blep :: proc(osc: Oscillator, shift: u32 = 0) -> f32 {
	t := f32(osc.phase + shift) / 4294967296
	dt := f32(osc.phase_increment) / 4294967296

	if t < dt {
		x := t / dt
		return x + x - x * x - 1.0
	}

	if t > 1.0 - dt {
		x := (t - 1.0) / dt
		return x * x + x + x + 1.0
	}

	return 0.0
}


make_oscillator :: proc(frequency: f32) -> Oscillator {
	return Oscillator {
		frequency = frequency,
		phase = 0,
		phase_increment = u32(f64(frequency) * (4294967296 / f64(SAMPLE_RATE))),
	}
}

increment :: proc(oscillator: ^Oscillator) {
	oscillator.phase = oscillator.phase + oscillator.phase_increment
}

square :: proc(oscillator: Oscillator) -> f32 {
	res: f32
	if oscillator.phase < 2147483648 {
		res = -1
	} else {
		res = 1
	}
	return res
}

next_square :: proc(oscillator: ^Oscillator) -> f32 {
	increment(oscillator)
	return square(oscillator^)
}

band_limited_square :: proc(oscillator: Oscillator) -> f32 {
	y := square(oscillator)
	y += poly_blep(oscillator)
	y -= poly_blep(oscillator, 2147483648)
	return y
}

next_band_limited_square :: proc(oscillator: ^Oscillator) -> f32 {
	increment(oscillator)
	return band_limited_square(oscillator^)
}
