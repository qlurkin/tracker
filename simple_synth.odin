package tracker

import "core:fmt"
import "core:math"

Transition :: struct {
	coef:  Sample,
	value: Sample,
}

duration_to_samples :: proc(time: Sample) -> u32 {
	return max(u32(time * f64(SAMPLE_RATE)), 16)
}

compute_transition_coef :: proc(samples: u32, eps: Sample = 0.001) -> Sample {
	return 1 - math.pow(eps, 1 / f64(samples))
}

make_transition :: proc(from: Sample, time: f64) -> Transition {
	return Transition{coef = compute_transition_coef(duration_to_samples(time)), value = from}
}

// env = env + (target - env) * coef
next_transition :: proc(transition: ^Transition, target: Sample) -> Sample {
	transition.value += (target - transition.value) * transition.coef
	return transition.value
}


Adsr :: struct {
	attack:       u32,
	decay_coef:   Sample,
	sustain:      Sample,
	release_coef: Sample,
}

AdsrInstance :: struct {
	using adsr: ^Adsr,
	samples:    u32,
	value:      Sample,
}

make_adsr :: proc(attack: Sample, decay: Sample, sustain: Sample, release: Sample) -> Adsr {
	return Adsr {
		attack = duration_to_samples(attack),
		decay_coef = compute_transition_coef(duration_to_samples(decay)),
		sustain = sustain,
		release_coef = compute_transition_coef(duration_to_samples(release)),
	}
}

make_adsr_instance :: proc(adsr: ^Adsr) -> AdsrInstance {
	return AdsrInstance{adsr = adsr}
}

// env = env + (target - env) * coef
next_adsr :: proc(adsr: ^AdsrInstance, released: bool = false) -> Sample {
	res: Sample
	if adsr.samples < adsr.attack {
		adsr.value = f64(adsr.samples) / f64(adsr.attack)
	} else {
		target, coef: Sample
		if released {
			target = 0
			coef = adsr.release_coef
		} else {
			target = adsr.sustain
			coef = adsr.decay_coef
		}
		adsr.value += (target - adsr.value) * coef
	}

	adsr.samples += 1
	return adsr.value
}

ModulatorFunction :: union {
	Adsr,
}

ModulatorFunctionInstance :: union {
	AdsrInstance,
}

ModulatorDestination :: enum {
	Off,
	Volume,
	Semitone,
}

ModulatorSettings :: struct {
	function:    ModulatorFunction,
	destination: ModulatorDestination,
}

Modulator :: struct {
	using settings: ^ModulatorSettings,
	instance:       ModulatorFunctionInstance,
}

make_modulator :: proc(settings: ^ModulatorSettings) -> Modulator {
	res: Modulator
	switch &f in settings.function {
	case Adsr:
		res = Modulator {
			settings = settings,
			instance = make_adsr_instance(&f),
		}
	}
	return res
}

SimpleSynth :: struct {
	waveform:   Waveform,
	modulators: [2]ModulatorSettings,
}

Voice :: struct {
	oscillator: Oscillator,
	synth:      ^SimpleSynth,
	modulators: [2]Modulator,
	volume:     Sample,
	semitone:   Sample,
	released:   bool,
}

make_voice :: proc(synth: ^SimpleSynth, semitone: Sample, volume: Sample) -> Voice {
	return Voice {
		synth = synth,
		oscillator = Oscillator{waveform = synth.waveform},
		released = false,
		modulators = [2]Modulator {
			make_modulator(&synth.modulators[0]),
			make_modulator(&synth.modulators[1]),
		},
		volume = volume,
		semitone = semitone,
	}
}

next_voice :: proc(voice: ^Voice) -> Sample {
	volume := voice.volume
	semitone := voice.semitone

	res := next_oscillator(&voice.oscillator, semitone)

	return volume * res
	// if voice.ads.samples == voice.hold {
	// 	voice.release.released = true
	// }

	// p := WaveformProcs

	// res := 0.25 * p[voice.synth.waveform](&voice.oscillator)
	// env := next_ads(&voice.ads)
	// rel := next_release(&voice.release)
	// return env * res * rel
}

stop_voice :: proc(voice: ^Voice) {
	voice.released = true
}
