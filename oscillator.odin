package tracker

import "core:fmt"
import "core:math"

Oscillator :: struct {
	frequency:       f32,
	phase:           u32,
	phase_increment: u32,
	prev_output:     f32, // Only used for band limited triangle
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


make_oscillator :: proc(frequency: f32 = 440) -> Oscillator {
	res := Oscillator{}
	set_frequency(&res, frequency)
	return res
}

set_frequency :: proc(oscillator: ^Oscillator, frequency: f32) {
	oscillator.frequency = frequency
	oscillator.phase_increment = u32(f64(frequency) * (4294967296 / f64(SAMPLE_RATE)))
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

saw :: proc(oscillator: Oscillator) -> f32 {
	return 2.0 * f32(oscillator.phase) / 4294967296.0 - 1.0
}

next_saw :: proc(oscillator: ^Oscillator) -> f32 {
	increment(oscillator)
	return saw(oscillator^)
}

band_limited_saw :: proc(oscillator: Oscillator) -> f32 {
	y := saw(oscillator)
	y -= poly_blep(oscillator)
	return y
}

next_band_limited_saw :: proc(oscillator: ^Oscillator) -> f32 {
	increment(oscillator)
	return band_limited_saw(oscillator^)
}

triangle :: proc(oscillator: Oscillator) -> f32 {
	y := -1.0 + (2.0 * f32(oscillator.phase) / 4294967296.0)
	y = 2.0 * (abs(y) - 0.5)
	return y
}

next_triangle :: proc(oscillator: ^Oscillator) -> f32 {
	increment(oscillator)
	return triangle(oscillator^)
}

// Done by integrating the band limited square
next_band_limited_triangle :: proc(oscillator: ^Oscillator) -> f32 {
	// Leaky integrator: y[n] = A * x[n] + (1 - A) * y[n-1]
	mPhaseIncrement := f32(oscillator.phase_increment) / 4294967296.0 * 2 * math.PI
	x := next_band_limited_square(oscillator)
	y := mPhaseIncrement * x + (1 - mPhaseIncrement) * oscillator.prev_output
	oscillator.prev_output = y
	return y
}

sine :: proc(oscillator: Oscillator) -> f32 {
	phase := f32(oscillator.phase) / 4294967296.0 * 2 * math.PI
	return math.sin(phase)
}

next_sine :: proc(oscillator: ^Oscillator) -> f32 {
	increment(oscillator)
	return sine(oscillator^)
}

Waveform :: enum {
	Sine,
	Saw,
	Triangle,
	Square,
}

WaveformProcs :: [Waveform]proc(oscillator: ^Oscillator) -> f32 {
	.Sine     = next_sine,
	.Saw      = next_band_limited_saw,
	.Triangle = next_band_limited_triangle,
	.Square   = next_band_limited_square,
}


