package tracker

import "core:fmt"
import "core:math"

note_frequency :: proc(note: u8) -> f32 {
	return 440 * math.pow(2, (f32(note) - 69) / 12)
}

SEMI_TONE_CHAR := "CCDDEFFGGAAB"
SEMI_TONE_SHARP := "-#-#--#-#-#-"
OCATAVE_CHAR := "-0123456789"


// note are u8 between 0 and 127 inclusive. 128 id the OFF note. 255 means no note.
OFF: u8 = 128
NO_NOTE: u8 = 255

note_to_string :: proc(note: u8) -> string {
	if note == OFF {
		return "OFF"
	}
	if note == NO_NOTE {
		return "---"
	}

	semi_tone := note % 12
	octave := note / 12
	return fmt.tprintf(
		"{}{}{}",
		SEMI_TONE_CHAR[semi_tone:semi_tone + 1],
		SEMI_TONE_SHARP[semi_tone:semi_tone + 1],
		OCATAVE_CHAR[octave:octave + 1],
	)
}

// timing: BPM = number of quarter note (black) per minute
//         PPQ = number of ticks per quater note

PPQ: u32 = 240

samples_per_tick :: proc(bpm: u8) -> u32 {
	return SAMPLE_RATE * 60 / (u32(bpm) * PPQ)
}
