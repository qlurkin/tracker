package tracker

import "core:math"

Transition :: struct {
	coef:   f32,
	value:  f32,
	target: f32,
}

duration_to_samples :: proc(time: f32) -> u32 {
	return max(u32(time * f32(SAMPLE_RATE)), 16)
}

compute_transition_coef :: proc(samples: u32, eps: f32 = 0.001) -> f32 {
	return 1 - math.pow(eps, 1 / f32(samples))
}

make_transition :: proc(from: f32, to: f32, time: f32) -> Transition {
	return Transition {
		coef = compute_transition_coef(duration_to_samples(time)),
		value = from,
		target = to,
	}
}

// env = env + (target - env) * coef
next_transition :: proc(transition: ^Transition) -> f32 {
	res := transition.value
	transition.value += (transition.target - transition.value) * transition.coef
	return res
}


Release :: struct {
	transition: Transition,
	released:   bool,
}


make_release :: proc(time: f32, eps: f32 = 0.001) -> Release {
	return Release{transition = make_transition(1, 0, time), released = false}
}

next_release :: proc(release: ^Release) -> f32 {
	if release.released {
		return next_transition(&release.transition)
	} else {
		return 1
	}
}

Ads :: struct {
	transition:     Transition,
	attack_samples: u32,
	decay_coef:     f32,
	sustain:        f32,
	samples:        u32,
}

make_ads :: proc(attack_time: f32, decay_time: f32, sustain: f32) -> Ads {
	attack := duration_to_samples(attack_time)
	return Ads {
		transition = Transition{coef = compute_transition_coef(attack), value = 0, target = 1},
		attack_samples = attack,
		decay_coef = compute_transition_coef(duration_to_samples(decay_time)),
		sustain = sustain,
		samples = 0,
	}
}

next_ads :: proc(ads: ^Ads) -> f32 {
	res := next_transition(&ads.transition)

	if ads.samples == ads.attack_samples {
		ads.transition.coef = ads.decay_coef
		ads.transition.target = ads.sustain
	}

	ads.samples += 1
	return res
}

SimpleSynth :: struct {
	attack:  f32,
	decay:   f32,
	sustain: f32,
	release: f32,
	hold:    f32,
}

Voice :: struct {
	oscillator: Oscillator,
	synth:      ^SimpleSynth,
	ads:        Ads,
	release:    Release,
	hold:       u32,
}

make_voice :: proc(synth: ^SimpleSynth, frequency: f32) -> Voice {
	return Voice {
		synth = synth,
		oscillator = make_oscillator(frequency),
		release = make_release(synth.release),
		ads = make_ads(synth.attack, synth.decay, synth.sustain),
		hold = duration_to_samples(synth.hold),
	}
}

next_voice :: proc(voice: ^Voice) -> f32 {
	if voice.ads.samples == voice.hold {
		voice.release.released = true
	}
	res := 0.25 * next_band_limited_square(&voice.oscillator)
	env := next_ads(&voice.ads)
	rel := next_release(&voice.release)
	return env * res * rel
}

stop_voice :: proc(voice: ^Voice) {
	voice.release.released = true
}
