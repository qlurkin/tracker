package tracker

import rt "base:runtime"
import "core:fmt"
import "core:mem"
import ma "vendor:miniaudio"
import rl "vendor:raylib"


Window :: struct {
	name:          cstring,
	width:         i32,
	height:        i32,
	fps:           i32,
	control_flags: rl.ConfigFlags,
}

Oscillator :: struct {
	phase:           u32,
	phase_increment: u32,
}


Frame :: struct {
	left:  [dynamic]f32,
	right: [dynamic]f32,
}


oscillator_buffer: Frame


make_oscillator :: proc(frequency: f32, sample_rate: u32) -> Oscillator {
	return Oscillator {
		phase = 0,
		phase_increment = u32(f64(frequency) * (4294967296 / f64(sample_rate))),
	}
}

square :: proc(oscillator: ^Oscillator, frame: Frame) {
	frame_count := u32(len(frame.left))
	oscillator^.phase = oscillator^.phase + frame_count * oscillator^.phase_increment
}

custom_context: rt.Context

data_callback :: proc "c" (
	pDevice: ^ma.device,
	pOutput: rawptr,
	pInput: rawptr,
	frame_count: u32,
) {
	context = custom_context
	fmt.println(frame_count)
}


main :: proc() {
	when ODIN_DEBUG {
		fmt.println("DEBUG MODE")
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
				for _, entry in track.allocation_map {
					fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
				}
			}
			mem.tracking_allocator_destroy(&track)
		}
	}

	custom_context = context

	fmt.println("Hello Tracker!")

	x := new(int)

	x^ = 42


	window := Window{"Tracker", 1200, 800, 60, rl.ConfigFlags{.WINDOW_RESIZABLE}}

	rl.InitWindow(window.width, window.height, window.name)
	rl.SetWindowState(window.control_flags)
	rl.SetTargetFPS(window.fps)

	fontsize: f32 = 64
	scale := rl.GetWindowScaleDPI()

	font := rl.LoadFontEx("JetBrainsMonoNerdFont-Regular.ttf", i32(scale.x * fontsize), nil, 0)

	config := ma.device_config_init(ma.device_type.playback)
	config.playback.format = ma.format.f32
	config.playback.channels = 2
	config.sampleRate = 48000
	config.dataCallback = data_callback

	device: ma.device

	if ma.device_init(nil, &config, &device) != ma.result.SUCCESS {
		fmt.println("Failed to initialize device")
		return
	}

	oscillator_buffer = Frame {
		left  = make([dynamic]f32, 480),
		right = make([dynamic]f32, 480),
	}


	ma.device_start(&device)

	for !rl.WindowShouldClose() {
		if rl.IsWindowResized() {
			window.width = rl.GetScreenWidth()
			window.height = rl.GetScreenHeight()
		}

		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)

		rl.DrawText("Hello Tracker !", 10, 10, 40, rl.WHITE)
		rl.DrawText("00", 10, 60, 40, rl.WHITE)
		rl.DrawText("11", 10, 100, 40, rl.WHITE)
		rl.DrawText("--", 10, 140, 40, rl.WHITE)
		rl.DrawText("FF", 10, 180, 40, rl.WHITE)
		rl.DrawTextEx(font, "FF", rl.Vector2{10, 220}, 40, 0, rl.WHITE)
		rl.DrawTextEx(font, "11", rl.Vector2{10, 260}, fontsize, 0, rl.WHITE)


		rl.EndDrawing()
	}

	ma.device_uninit(&device)

	free(x)
}
