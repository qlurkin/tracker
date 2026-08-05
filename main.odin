package tracker

import rt "base:runtime"
import "core:fmt"
import "core:mem"
import "core:strings"
import ma "vendor:miniaudio"
import rl "vendor:raylib"

SAMPLE_RATE: u32 = 48000

Window :: struct {
	name:          cstring,
	width:         i32,
	height:        i32,
	fps:           i32,
	control_flags: rl.ConfigFlags,
}


custom_context: rt.Context
tracker: ^Tracker

data_callback :: proc "c" (
	pDevice: ^ma.device,
	pOutput: rawptr,
	pInput: rawptr,
	frame_count: u32,
) {
	context = custom_context

	ptr := cast([^]f32)pOutput
	output := ptr[:frame_count * 2]

	f: Frame
	for i in 0 ..< frame_count {
		f = synthesize(tracker)
		output[i * 2] = f[0]
		output[i * 2 + 1] = f[1]
	}
}


main :: proc() {
	when ODIN_DEBUG {
		fmt.println("DEBUG MODE")
		track: mem.Tracking_Allocator
		tmp_track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		mem.tracking_allocator_init(&tmp_track, context.temp_allocator)
		context.allocator = mem.tracking_allocator(&track)
		context.temp_allocator = mem.tracking_allocator(&tmp_track)

		defer {
			if len(track.allocation_map) > 0 {
				fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
				for _, entry in track.allocation_map {
					fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
				}
			}
			mem.tracking_allocator_destroy(&track)

			if len(tmp_track.allocation_map) > 0 {
				fmt.eprintf(
					"=== %v temporary allocations not freed: ===\n",
					len(tmp_track.allocation_map),
				)
				for _, entry in tmp_track.allocation_map {
					fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
				}
			}
			mem.tracking_allocator_destroy(&tmp_track)
		}
	}

	custom_context = context

	fmt.println("Hello Tracker!")

	window := Window{"Tracker", 1280, 800, 60, rl.ConfigFlags{.WINDOW_RESIZABLE}}

	rl.InitWindow(window.width, window.height, window.name)
	rl.SetWindowState(window.control_flags)
	rl.SetTargetFPS(window.fps)

	fontsize: i32 = 24
	scale := rl.GetWindowScaleDPI()

	//font := rl.LoadFontEx("JetBrainsMonoNerdFont-Regular.ttf", i32(scale.x * fontsize), nil, 0)

	config := ma.device_config_init(ma.device_type.playback)
	config.playback.format = ma.format.f32
	config.playback.channels = 2
	config.sampleRate = SAMPLE_RATE
	config.dataCallback = data_callback

	device: ma.device

	if ma.device_init(nil, &config, &device) != ma.result.SUCCESS {
		fmt.println("Failed to initialize device")
		return
	}

	tracker = make_tracker()

	set_note(tracker, 69)
	fmt.println(note_frequency(0))
	fmt.println(note_frequency(127))

	ma.device_start(&device)

	compute_offsets()


	for !rl.WindowShouldClose() {
		if rl.IsWindowResized() {
			window.width = rl.GetScreenWidth()
			window.height = rl.GetScreenHeight()
		}

		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)

		ui(rl.Rectangle{0, 0, f32(window.width), f32(window.height)}, tracker)

		// for i in 32 ..< 72 {
		// 	rl.DrawText(
		// 		fmt.caprint(i, allocator = context.temp_allocator),
		// 		10,
		// 		i32(f32(i - 32) * FONT_SIZE),
		// 		i32(FONT_SIZE),
		// 		rl.GRAY,
		// 	)
		// 	rl.DrawTextCodepoint(
		// 		rl.GetFontDefault(),
		// 		rune(i),
		// 		rl.Vector2{50, f32(i - 32) * FONT_SIZE},
		// 		FONT_SIZE,
		// 		rl.WHITE,
		// 	)
		// }

		// for i in 72 ..< 112 {
		// 	rl.DrawText(
		// 		fmt.caprint(i, allocator = context.temp_allocator),
		// 		100,
		// 		i32(f32(i - 72) * FONT_SIZE),
		// 		i32(FONT_SIZE),
		// 		rl.GRAY,
		// 	)
		// 	r := u8(i)
		// 	s := string([]u8{r})
		// 	draw_monospaced_text(150, f32(i - 72) * FONT_SIZE, s)
		// 	// rl.DrawTextCodepoint(
		// 	// 	rl.GetFontDefault(),
		// 	// 	rune(i),
		// 	// 	rl.Vector2{150, f32(i - 72) * FONT_SIZE},
		// 	// 	FONT_SIZE,
		// 	// 	rl.WHITE,
		// 	// )
		// }

		// for i in 112 ..< 152 {
		// 	rl.DrawText(
		// 		fmt.caprint(i, allocator = context.temp_allocator),
		// 		200,
		// 		i32(f32(i - 112) * FONT_SIZE),
		// 		i32(FONT_SIZE),
		// 		rl.GRAY,
		// 	)
		// 	rl.DrawTextCodepoint(
		// 		rl.GetFontDefault(),
		// 		rune(i),
		// 		rl.Vector2{250, f32(i - 112) * FONT_SIZE},
		// 		FONT_SIZE,
		// 		rl.WHITE,
		// 	)
		// }

		rl.EndDrawing()
		free_all(context.temp_allocator)
	}

	delete_layout()

	ma.device_uninit(&device)

	free(tracker)
}
