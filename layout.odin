package tracker

import "core:fmt"
import rl "vendor:raylib"


Flow :: enum {
	Horizontal,
	Vertical,
}

Padding :: struct {
	top:    f32,
	right:  f32,
	bottom: f32,
	left:   f32,
}

// area is inside the padding
Layout :: struct {
	area:    rl.Rectangle,
	flow:    Flow,
	cursor:  rl.Vector2,
	width:   f32,
	height:  f32,
	padding: Padding,
}

add_padding :: proc(rect: rl.Rectangle, padding: Padding) -> rl.Rectangle {
	return rl.Rectangle {
		x = rect.x - padding.left,
		y = rect.y - padding.top,
		width = rect.width + padding.left + padding.right,
		height = rect.height + padding.top + padding.bottom,
	}
}

remove_padding :: proc(rect: rl.Rectangle, padding: Padding) -> rl.Rectangle {
	return rl.Rectangle {
		x = rect.x + padding.left,
		y = rect.y + padding.top,
		width = rect.width - padding.left - padding.right,
		height = rect.height - padding.top - padding.bottom,
	}
}

outside_rect :: proc(layout: Layout) -> rl.Rectangle {
	return add_padding(layout.area, layout.padding)
}

_LAYOUTS: [dynamic]Layout

// area includes padding
begin_layout :: proc(
	area: rl.Rectangle,
	flow: Flow = Flow.Vertical,
	padding: Padding = Padding{},
) {
	area := remove_padding(area, padding)
	clear(&_LAYOUTS)
	append(
		&_LAYOUTS,
		Layout{area = area, cursor = rl.Vector2{area.x, area.y}, flow = flow, padding = padding},
	)
}

end_layout :: proc() {
	pop(&_LAYOUTS)
}

current_layout :: proc() -> ^Layout {
	return &_LAYOUTS[len(_LAYOUTS) - 1]
}

cursor_rectangle :: proc() -> rl.Rectangle {
	layout := current_layout()
	return rl.Rectangle {
		x = layout.cursor.x,
		y = layout.cursor.y,
		width = layout.area.x + layout.area.width - layout.cursor.x,
		height = layout.area.y + layout.area.height - layout.cursor.y,
	}
}

//width and height includes padding
push_layout :: proc(
	flow: Flow = Flow.Vertical,
	width: f32 = 0,
	height: f32 = 0,
	padding: Padding = Padding{},
) {
	layout := current_layout()
	area := rl.Rectangle {
		x      = layout.cursor.x + padding.left,
		y      = layout.cursor.y + padding.top,
		width  = width - padding.left - padding.right,
		height = height - padding.top - padding.bottom,
	}
	append(
		&_LAYOUTS,
		Layout{area = area, flow = flow, cursor = rl.Vector2{area.x, area.y}, padding = padding},
	)
}

pop_layout :: proc() {
	layout := pop(&_LAYOUTS)
	finish_widget(
		layout.area.width + layout.padding.left + layout.padding.right,
		layout.area.height + layout.padding.top + layout.padding.bottom,
	)
}

finish_widget :: proc(width, height: f32) {
	layout := current_layout()
	w := layout.cursor.x + width - layout.area.x
	if w > layout.width {
		layout.width = w
	}
	if layout.width > layout.area.width {
		layout.area.width = layout.width
	}
	h := layout.cursor.y + height - layout.area.y
	if h > layout.height {
		layout.height = h
	}
	if layout.height > layout.area.height {
		layout.area.height = layout.height
	}
	switch layout.flow {
	case Flow.Vertical:
		layout.cursor.y = layout.area.y + layout.height
		layout.cursor.x = layout.area.x
	case Flow.Horizontal:
		layout.cursor.x = layout.area.x + layout.width
		layout.cursor.y = layout.area.y
	}
}

delete_layout :: proc() {
	delete(_LAYOUTS)
}

layout_width_percent :: proc(value: f32) -> f32 {
	layout := current_layout()
	return layout.area.width * value / 100
}

layout_height_percent :: proc(value: f32) -> f32 {
	layout := current_layout()
	return layout.area.height * value / 100
}

remaining_height_percent :: proc(value: f32) -> f32 {
	layout := current_layout()
	return (layout.area.height - (layout.cursor.y - layout.area.y)) * value / 100
}

remaining_width_percent :: proc(value: f32) -> f32 {
	layout := current_layout()
	return (layout.area.width - (layout.cursor.x - layout.area.x)) * value / 100
}
