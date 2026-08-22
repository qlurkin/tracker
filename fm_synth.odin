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

ExpDown :: struct {
	coef:   Sample,
	amount: Sample,
}

ExpDownInstance :: struct {
	using exp: ^ExpDown,
	value:     Sample,
}

make_exp_down :: proc(amount: Sample, time: Sample) -> ExpDown {
	return ExpDown{coef = compute_transition_coef(duration_to_samples(time)), amount = amount}
}

make_exp_down_instance :: proc(exp: ^ExpDown) -> ExpDownInstance {
	return ExpDownInstance{exp = exp, value = exp.amount}
}

next_exp_down :: proc(exp: ^ExpDownInstance) -> Sample {
	exp.value -= exp.value * exp.coef
	return exp.value
}

RampDown :: struct {
	total_samples: u32,
	amount:        Sample,
}

RampDownInstance :: struct {
	using ramp: ^RampDown,
	samples:    u32,
}

make_ramp_down :: proc(amount: Sample, time: Sample) -> RampDown {
	return RampDown{total_samples = duration_to_samples(time), amount = amount}
}

make_ramp_down_instance :: proc(ramp: ^RampDown) -> RampDownInstance {
	return RampDownInstance{ramp = ramp}
}

next_ramp_down :: proc(ramp: ^RampDownInstance) -> Sample {
	progress := min(f64(ramp.samples) / f64(ramp.total_samples), 1)
	ramp.samples += 1
	return ramp.amount * (1 - progress)
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
	ExpDown,
	RampDown,
}

Modulator :: union {
	AdsrInstance,
	ExpDownInstance,
	RampDownInstance,
}

ModulatorDestination :: enum {
	Level,
	Semitone,
	Ratio,
	Feedback,
}

make_modulator :: proc(function: ^ModulatorFunction) -> Modulator {
	res: Modulator
	switch &f in function {
	case Adsr:
		res = make_adsr_instance(&f)
	case ExpDown:
		res = make_exp_down_instance(&f)
	case RampDown:
		res = make_ramp_down_instance(&f)
	}
	return res
}

next_modulator :: proc(modulator: ^Modulator, released: bool = false) -> Sample {
	res: Sample = 1
	switch &m in modulator {
	case AdsrInstance:
		res = next_adsr(&m, released)
	case ExpDownInstance:
		res = next_exp_down(&m)
	case RampDownInstance:
		res = next_ramp_down(&m)
	}
	return res
}

Operator :: struct {
	waveform:  Waveform,
	functions: [4]ModulatorFunction,
	level:     Sample,
	ratio:     Sample,
	feedback:  Sample,
}

OperatorInstance :: struct {
	oscillator:  Oscillator,
	operator:    ^Operator,
	modulators:  [4]Modulator,
	last_level:  Sample,
	last_output: Sample,
}

make_operator_instance :: proc(operator: ^Operator) -> OperatorInstance {
	return OperatorInstance {
		operator = operator,
		oscillator = Oscillator{waveform = operator.waveform},
		modulators = [4]Modulator {
			make_modulator(&operator.functions[0]),
			make_modulator(&operator.functions[1]),
			make_modulator(&operator.functions[2]),
			make_modulator(&operator.functions[3]),
		},
	}
}

next_operator :: proc(
	operator: ^OperatorInstance,
	semitone: Sample,
	level: Sample,
	input: Sample,
	released: bool,
) -> Sample {
	if operator.operator.level == 0 {
		return 0
	}

	level := level * operator.operator.level
	semitone := semitone

	level *= max(next_modulator(&operator.modulators[ModulatorDestination.Level], released), 0)
	semitone += clamp(
		next_modulator(&operator.modulators[ModulatorDestination.Semitone], released),
		0,
		127,
	)

	frequency :=
		440 * math.pow(2, (semitone - 69) / 12) * operator.operator.ratio +
		input +
		operator.operator.feedback * operator.last_output

	res := next_oscillator(&operator.oscillator, frequency)

	operator.last_level = level
	operator.last_output = level * res
	return operator.last_output
}

Algorithm :: enum {
	AandB,
	AtoB,
}

FmSynth :: struct {
	operators: [2]Operator,
	algorithm: Algorithm,
}

FmVoice :: struct {
	synth:      ^FmSynth,
	operators:  [2]OperatorInstance,
	last_level: Sample,
	semitone:   Sample,
	velocity:   Sample,
	released:   bool,
}

make_voice :: proc(synth: ^FmSynth, semitone: Sample, velocity: Sample) -> FmVoice {
	return FmVoice {
		synth = synth,
		operators = [2]OperatorInstance {
			make_operator_instance(&synth.operators[0]),
			make_operator_instance(&synth.operators[1]),
		},
		semitone = semitone,
		velocity = velocity,
		released = false,
	}
}

next_voice :: proc(voice: ^FmVoice) -> Sample {
	res: Sample
	switch voice.synth.algorithm {
	case .AandB:
		A := next_operator(&voice.operators[0], voice.semitone, voice.velocity, 0, voice.released)
		B := next_operator(&voice.operators[1], voice.semitone, voice.velocity, 0, voice.released)
		res = A + B
		voice.last_level = max(voice.operators[0].last_level, voice.operators[1].last_level)
	case .AtoB:
		A := next_operator(&voice.operators[0], voice.semitone, voice.velocity, 0, voice.released)
		B := next_operator(&voice.operators[1], voice.semitone, voice.velocity, A, voice.released)
		res = B
		voice.last_level = voice.operators[1].last_level
	}

	return res
}
