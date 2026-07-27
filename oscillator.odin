package tracker

Oscillator :: struct {
	phase:           u32,
	phase_increment: u32,
}


make_oscillator :: proc(frequency: f32) -> Oscillator {
	return Oscillator {
		phase = 0,
		phase_increment = u32(f64(frequency) * (4294967296 / f64(SAMPLE_RATE))),
	}
}

square :: proc(oscillator: ^Oscillator) -> f32 {
	oscillator.phase = oscillator.phase + oscillator.phase_increment
	res: f32
	if oscillator.phase < 2147483648 {
		res = -1
	}
	else {
		res = 1
	}
	return res
}
