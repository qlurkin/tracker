package tracker

import "core:fmt"
import "core:strings"
import rl "vendor:raylib"

hex_digits := "0123456789ABCDEF-"

FONT_SIZE: f32 = 24
DECIMAL_OFFSET: f32
ONE_OFFSET: f32
DASH_OFFSET: f32
DIGIT_WIDTH: f32
GAP: f32

compute_offsets :: proc() {
	a_size := f32(rl.MeasureText("A", i32(FONT_SIZE)))
	eight_size := f32(rl.MeasureText("8", i32(FONT_SIZE)))
	one_size := f32(rl.MeasureText("1", i32(FONT_SIZE)))
	dash_size := f32(rl.MeasureText("-", i32(FONT_SIZE)))
	aa_size := f32(rl.MeasureText("AA", i32(FONT_SIZE)))
	DECIMAL_OFFSET = ((a_size - eight_size) / 2)
	ONE_OFFSET = ((a_size - one_size) / 2)
	DASH_OFFSET = ((a_size - dash_size) / 2)
	DIGIT_WIDTH = (a_size)
	GAP = aa_size - 2 * a_size
}

hex_digit :: proc(x: f32, y: f32, value: u8, color: rl.Color = rl.WHITE) {
	offset: f32 = 0
	if value == 1 {
		offset = ONE_OFFSET
	} else if value < 10 {
		offset = DECIMAL_OFFSET
	} else if value == 16 {
		offset = DASH_OFFSET
	}

	rl.DrawTextCodepoint(
		rl.GetFontDefault(),
		rune(hex_digits[value]),
		rl.Vector2{x + offset, y},
		FONT_SIZE,
		color,
	)
}

hex_input :: proc(x: f32, y: f32, value: u8, color: rl.Color = rl.WHITE) {
	most := value / 16
	least := value % 16
	hex_digit(x, y, most, color)
	hex_digit(x + DIGIT_WIDTH + GAP, y, least, color)
}

label :: proc(x, y: f32, text: string, color: rl.Color = rl.WHITE) {
	text := strings.clone_to_cstring(text, allocator = context.temp_allocator)
	rl.DrawTextEx(rl.GetFontDefault(), text, rl.Vector2{x, y}, FONT_SIZE, GAP, color)
}

frame :: proc(area: rl.Rectangle, title: string) -> rl.Rectangle {
	title := strings.clone_to_cstring(title, allocator = context.temp_allocator)
	title_width := rl.MeasureText(title, i32(FONT_SIZE))
	xpos := area.x + (area.width - f32(title_width) - DIGIT_WIDTH) / 2
	rl.DrawTextEx(rl.GetFontDefault(), title, rl.Vector2{xpos, area.y}, FONT_SIZE, GAP, rl.RED)
	top := area.y + FONT_SIZE / 2
	bottom := area.y + area.height - FONT_SIZE / 2
	left := area.x + DIGIT_WIDTH / 2
	right := area.x + area.width - DIGIT_WIDTH / 2
	points: [6]rl.Vector2
	points[0] = rl.Vector2{xpos - DIGIT_WIDTH, top}
	points[1] = rl.Vector2{left, top}
	points[2] = rl.Vector2{left, bottom}
	points[3] = rl.Vector2{right, bottom}
	points[4] = rl.Vector2{right, top}
	points[5] = rl.Vector2{xpos + f32(title_width) + DIGIT_WIDTH, top}
	rl.DrawLineStrip(raw_data(points[:]), len(points), rl.WHITE)
	return rl.Rectangle {
		x = area.x + DIGIT_WIDTH,
		y = area.y + FONT_SIZE,
		width = area.width - 2 * DIGIT_WIDTH,
		height = area.height - 2 * FONT_SIZE,
	}
}

ui :: proc(area: rl.Rectangle, tracker: ^Tracker) {
	frame(area, "Hello Tracker !")
	label(10, 60, fmt.tprintf("Frequency: {}", tracker.oscillator.frequency))

	for i in 0 ..= 16 {
		hex_input(10, 100 + f32(i) * FONT_SIZE, u8(i) + 200)
	}
}
