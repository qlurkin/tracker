package tracker

Ads :: struct {
	attack:  u32,
	decay:   u32,
	sustain: f32,
	samples: u32,
}

Release :: struct {
	release:  u32,
	samples:  u32,
	released: bool,
}

SimpleSynth :: struct {
	oscillator: Oscillator,
	ads:        Ads,
}
