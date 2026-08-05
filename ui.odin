package tracker

import "core:fmt"
import "core:strings"
import rl "vendor:raylib"

HEX_DIGITS := "0123456789ABCDEF-"

FONT_SIZE: f32 = 20
DECIMAL_OFFSET: f32
ONE_OFFSET: f32
DASH_OFFSET: f32
DIGIT_WIDTH: f32
CHAR_WIDTH: f32
GAP: f32
CHAR_OFFSETS: [96]f32

compute_offsets :: proc() {
	a_size := f32(rl.MeasureText("A", i32(FONT_SIZE)))
	char_size := f32(rl.MeasureText("W", i32(FONT_SIZE)))
	eight_size := f32(rl.MeasureText("8", i32(FONT_SIZE)))
	one_size := f32(rl.MeasureText("1", i32(FONT_SIZE)))
	dash_size := f32(rl.MeasureText("-", i32(FONT_SIZE)))
	ww_size := f32(rl.MeasureText("WW", i32(FONT_SIZE)))
	DECIMAL_OFFSET = ((a_size - eight_size) / 2)
	ONE_OFFSET = ((a_size - one_size) / 2)
	DASH_OFFSET = ((a_size - dash_size) / 2)
	DIGIT_WIDTH = (a_size)
	CHAR_WIDTH = char_size
	GAP = ww_size - 2 * char_size
	for i in 0 ..< 96 {
		r := u8(i + 32)
		s := string([]u8{r})
		cs := strings.clone_to_cstring(s, allocator = context.temp_allocator)
		w := f32(rl.MeasureText(cs, i32(FONT_SIZE)))
		CHAR_OFFSETS[i] = (char_size - w) / 2
	}
}

monospaced_text_width :: proc(text: string) -> f32 {
	l := f32(len(text))
	return l * CHAR_WIDTH + (l - 1) * GAP
}

draw_monospaced_text :: proc(x: f32, y: f32, text: string, color: rl.Color = rl.WHITE) -> f32 {
	cx := x
	for c in text {
		rl.DrawTextCodepoint(
			rl.GetFontDefault(),
			c,
			rl.Vector2{cx + CHAR_OFFSETS[c - 32], y},
			FONT_SIZE,
			color,
		)
		cx += CHAR_WIDTH + GAP
	}
	return cx - x - GAP
}

draw_text :: proc(x: f32, y: f32, text: string, color: rl.Color = rl.WHITE) {
	text := strings.clone_to_cstring(text, allocator = context.temp_allocator)
	rl.DrawTextEx(rl.GetFontDefault(), text, rl.Vector2{x, y}, FONT_SIZE, GAP, color)
}


draw_hex_digit :: proc(x: f32, y: f32, value: u8, color: rl.Color = rl.WHITE) {
	d := rune(HEX_DIGITS[value])
	rl.DrawTextCodepoint(
		rl.GetFontDefault(),
		d,
		rl.Vector2{x + CHAR_OFFSETS[d - 32], y},
		FONT_SIZE,
		color,
	)
}

Hex :: union {
	u8,
}

hex_digit :: proc(value: u8, color: rl.Color = rl.WHITE) {
	layout := current_layout()
	x := layout.cursor.x
	y := layout.cursor.y
	draw_hex_digit(x, y, value, color)
	finish_widget(DIGIT_WIDTH, FONT_SIZE)
}

note_input :: proc(value: u8, color: rl.Color = rl.WHITE) {
	layout := current_layout()
	x := layout.cursor.x
	y := layout.cursor.y

	width := draw_monospaced_text(x, y, note_to_string(value))
	finish_widget(width, FONT_SIZE)
}

hex_input :: proc(value: Hex, color: rl.Color = rl.WHITE) {
	layout := current_layout()
	x := layout.cursor.x
	y := layout.cursor.y
	switch v in value {
	case u8:
		most := v / 16
		least := v % 16
		draw_hex_digit(x, y, most, color)
		draw_hex_digit(x + DIGIT_WIDTH + GAP, y, least, color)
	case nil:
		draw_hex_digit(x, y, 16, color)
		draw_hex_digit(x + DIGIT_WIDTH + GAP, y, 16, color)
	}
	finish_widget(DIGIT_WIDTH * 2 + GAP, FONT_SIZE)
}

Alignement :: enum {
	Left,
	Right,
	Center,
}

label :: proc(
	text: string,
	color: rl.Color = rl.WHITE,
	width: f32 = 0,
	alignement: Alignement = Alignement.Left,
) {
	text := strings.clone_to_cstring(text, allocator = context.temp_allocator)
	text_width := f32(rl.MeasureText(text, i32(FONT_SIZE)))
	width := width
	if text_width > width {
		width = text_width
	}
	offset: f32 = 0
	switch alignement {
	case Alignement.Left:
		offset = 0
	case Alignement.Right:
		offset = width - text_width
	case Alignement.Center:
		offset = (width - text_width) / 2
	}
	layout := current_layout()
	rl.DrawTextEx(
		rl.GetFontDefault(),
		text,
		rl.Vector2{layout.cursor.x + offset, layout.cursor.y},
		FONT_SIZE,
		GAP,
		color,
	)
	finish_widget(width, FONT_SIZE)
}

draw_frame :: proc(area: rl.Rectangle, title: string) -> rl.Rectangle {
	title := strings.clone_to_cstring(title, allocator = context.temp_allocator)
	title_width := rl.MeasureText(title, i32(FONT_SIZE))
	xpos := area.x + (area.width - f32(title_width)) / 2
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

begin_frame :: proc(
	flow: Flow = Flow.Vertical,
	width: f32 = 0,
	height: f32 = 0,
	padding: Padding = Padding{},
) {
	push_layout(
		flow,
		width,
		height,
		Padding {
			FONT_SIZE + padding.top,
			DIGIT_WIDTH + padding.right,
			FONT_SIZE + padding.bottom,
			DIGIT_WIDTH + padding.left,
		},
	)
}

end_frame :: proc(title: string) {
	layout := current_layout()
	frame_rect := outside_rect(layout^)
	draw_frame(frame_rect, title)
	pop_layout()
}

to_string :: proc(arg: any) -> string {
	return fmt.tprintf("{}", arg)
}

label_column :: proc() {
	push_layout()
	for i in 0 ..< 16 {
		hex_digit(u8(i), rl.GRAY)
	}
	pop_layout()
}

hex_column :: proc(values: [16]Hex) {
	push_layout()
	for v in values {
		hex_input(v)
	}
	pop_layout()
}

note_column :: proc(values: [16]u8) {
	push_layout()
	for v in values {
		note_input(v)
	}
	pop_layout()
}

cursor_column :: proc(cursor: PhraseCursor) {
	push_layout()
	for i in 0 ..< 16 {
		if u8(i) == cursor.step {
			label(">")
		} else {
			v(FONT_SIZE)
		}
	}
	pop_layout()
}

v :: proc(size: f32) {
	finish_widget(width = 0, height = size)
}

h :: proc(size: f32) {
	finish_widget(width = size, height = 0)
}

ui :: proc(area: rl.Rectangle, tracker: ^Tracker) {
	begin_layout(area)
	begin_frame(width = layout_width_percent(100), height = layout_height_percent(100))
	push_layout(width = layout_width_percent(100), height = 200)
	pop_layout()

	push_layout(
		Flow.Horizontal,
		width = layout_width_percent(100),
		height = remaining_height_percent(100),
	)

	begin_frame(height = layout_height_percent(100))

	push_layout(Flow.Horizontal)
	label("Frequency", rl.RED, width = 150, alignement = Alignement.Right)
	h(DIGIT_WIDTH)
	label(to_string(tracker.oscillator.frequency))
	pop_layout()

	push_layout(Flow.Horizontal)
	label("Note", rl.RED, width = 150, alignement = Alignement.Right)
	h(DIGIT_WIDTH)
	label(note_to_string(tracker.note))
	pop_layout()

	push_layout(Flow.Horizontal)
	label_column()
	h(5)
	cursor_column(tracker.cursor)
	h(5)
	note_column(tracker.phrase)
	pop_layout()

	end_frame("Menu")

	pop_layout()

	end_frame("Tracker")
	end_layout()
}
