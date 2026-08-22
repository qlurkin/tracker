package tracker

import "core:fmt"
import "core:math"
import "core:math/rand"

Sample :: f64

Waveform :: enum {
	Sine,
	Saw,
	Triangle,
	Square,
	PolySquare,
	PolySaw,
	PolyTriangle,
	Noise,
}

// WaveformProcs :: [Waveform]proc(oscillator: ^Oscillator) -> f32 {
// 	.Sine     = next_sine,
// 	.Saw      = next_band_limited_saw,
// 	.Triangle = next_band_limited_triangle,
// 	.Square   = next_band_limited_square,
// }

Oscillator :: struct {
	waveform:    Waveform,
	phase:       u32,
	last_output: Sample, // Only used for band limited triangle
}

noise :: proc() -> Sample {
	return rand.float64()
}

square :: proc(phase: u32) -> Sample {
	res: Sample
	if phase < 2147483648 {
		res = -1
	} else {
		res = 1
	}
	return res
}

saw :: proc(phase: u32) -> Sample {
	return 2.0 * f64(phase) / 4294967296.0 - 1.0
}

triangle :: proc(phase: u32) -> Sample {
	y := -1.0 + (2.0 * f64(phase) / 4294967296.0)
	y = 2.0 * (abs(y) - 0.5)
	return y
}

sine :: proc(phase: u32) -> Sample {
	phase := f64(phase) / 4294967296.0 * 2.0 * math.PI
	return math.sin(phase)
}


poly_blep :: proc(phase: u32, phase_increment: u32) -> Sample {
	t := f64(phase) / 4294967296
	dt := f64(phase_increment) / 4294967296

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

poly_square :: proc(phase: u32, phase_increment: u32) -> Sample {
	y := square(phase)
	y += poly_blep(phase, phase_increment)
	y -= poly_blep(phase + 2147483648, phase_increment)
	return y
}

poly_saw :: proc(phase: u32, phase_increment: u32) -> Sample {
	y := saw(phase)
	y -= poly_blep(phase, phase_increment)
	return y
}

// Done by integrating the band limited square
poly_triangle :: proc(phase: u32, phase_increment: u32, last_output: Sample) -> Sample {
	// Leaky integrator: y[n] = A * x[n] + (1 - A) * y[n-1]
	mPhaseIncrement := f64(phase_increment) / 4294967296.0 * 2 * math.PI
	x := poly_square(phase, phase_increment)
	y := mPhaseIncrement * x + (1 - mPhaseIncrement) * last_output
	return y
}

next_oscillator :: proc(oscillator: ^Oscillator, frequency: Sample) -> Sample {
	phase_increment := u32(frequency * (4294967296 / f64(SAMPLE_RATE)))
	oscillator.phase += phase_increment

	res: Sample

	switch oscillator.waveform {
	case .Square:
		res = square(oscillator.phase)
	case .Saw:
		res = saw(oscillator.phase)
	case .Triangle:
		res = triangle(oscillator.phase)
	case .Sine:
		res = sine(oscillator.phase)
	case .PolySquare:
		res = poly_square(oscillator.phase, phase_increment)
	case .PolyTriangle:
		res = poly_triangle(oscillator.phase, phase_increment, oscillator.last_output)
	case .PolySaw:
		res = poly_saw(oscillator.phase, phase_increment)
	case .Noise:
		res = noise()
	}

	oscillator.last_output = res
	return res
}
