/**
    Niobium Example Triangle Application
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module app;
import niobium;
import inmath;
import numem;
import sdl;
import std.file : read;

NioSurface surfaceFromWindow(SDL_Window* window) {
    import sdl.properties;
	auto props = SDL_GetWindowProperties(window);
	version(Windows) {
		auto hinst = SDL_GetPointerProperty(props, SDL_PROP_WINDOW_WIN32_INSTANCE_POINTER, null);
		auto whndl = SDL_GetPointerProperty(props, SDL_PROP_WINDOW_WIN32_HWND_POINTER, null);
		return NioSurface.createForWindow(hinst, whndl);

	} else version(linux) {

		auto wldisplay = SDL_GetPointerProperty(props, SDL_PROP_WINDOW_WAYLAND_DISPLAY_POINTER, null);
		auto wlsurface = SDL_GetPointerProperty(props, SDL_PROP_WINDOW_WAYLAND_SURFACE_POINTER, null);
		auto xdisplay = SDL_GetPointerProperty(props, SDL_PROP_WINDOW_X11_DISPLAY_POINTER, null);
		auto xsurface = SDL_GetNumberProperty(props, SDL_PROP_WINDOW_X11_WINDOW_NUMBER, 0);
		
		if (wldisplay && wlsurface) {
			return NioSurface.createForWindow(wldisplay, wlsurface);
		} else if (xdisplay && xsurface) {
			return NioSurface.createForWindow(xdisplay, cast(uint)xsurface);
		} else return null;
		
	} else version(OSX) {
		import sdl.metal : SDL_Metal_CreateView, SDL_Metal_GetLayer;

		auto view = SDL_Metal_CreateView(window);
		return NioSurface.createForLayer(SDL_Metal_GetLayer(view));
	}
}

struct Vertex {
    vec2 vtx;
    vec3 color;
}

void main() {

    // Create Device
	auto device = NioDevice.systemDevices[0];
	auto queue = device.createQueue(NioCommandQueueDescriptor(
		maxCommandBuffers: 6
	));

    // Create Window and Surface
	SDL_Init(SDL_INIT_EVERYTHING);
	SDL_Window* window = SDL_CreateWindow("Niobium Triangle Example", 640, 480, SDL_WindowFlags.SDL_WINDOW_RESIZABLE | SDL_WindowFlags.SDL_WINDOW_TRANSPARENT);
	NioSurface surface = window.surfaceFromWindow();
	surface.device = device;
	surface.framesInFlight = 3;
	surface.presentMode = NioPresentMode.vsync;
	surface.size = NioExtent2D(640, 480);
	surface.format = NioPixelFormat.bgra8UnormSRGB;
	surface.transparent = true;

	// Create shaders
	version(OSX) NioShader shader = device.createShaderFromNativeSource("triangle", cast(ubyte[])read("triangle.metal"));
	else NioShader shader = device.createShaderFromNativeSource("triangle", cast(ubyte[])read("triangle.spv"));

	// Create pipeline
	NioRenderPipeline renderPipeline = device.createRenderPipeline(
		NioRenderPipelineDescriptor(
			vertexFunction: shader.getFunction("vertex_main"),
			fragmentFunction: shader.getFunction("fragment_main"),
			vertexDescriptor: NioVertexDescriptor(
				[NioVertexBindingDescriptor(NioVertexInputRate.perVertex, Vertex.sizeof)],
				[
					NioVertexAttributeDescriptor(NioVertexFormat.float2, 0, Vertex.vtx.offsetof), 
					NioVertexAttributeDescriptor(NioVertexFormat.float3, 0, Vertex.color.offsetof)
				],
			),
			colorAttachments: [NioRenderPipelineAttachmentDescriptor(
				format: surface.format,
				blending: true,
			)]
		)
	);

    // Create Vertex Buffer
    Vertex[3] vertices = [
        Vertex(vec2(-1,  -1), vec3(1, 0, 0)),
        Vertex(vec2( 1,  -1), vec3(0, 1, 0)),
        Vertex(vec2( 0,   1), vec3(0, 0, 1)), 
    ];
    NioBuffer buffer = device.createBuffer(NioBufferDescriptor(
        usage: NioBufferUsage.transfer | NioBufferUsage.vertexBuffer,
		storage: NioStorageMode.privateStorage,
        size: Vertex.sizeof*3
    )).upload(cast(void[])vertices[0..$], 0);

	bool closeRequested;
	SDL_Event ev;
	while(!closeRequested) {
		while(SDL_PollEvent(&ev)) {
			switch(ev.type) with(SDL_EventType) {
				default: break;

				case SDL_EVENT_QUIT:
					closeRequested = true;
					break;
				
				case SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED:
					version(linux)
					surface.size = NioExtent2D(ev.window.data1, ev.window.data2);
					break;
			}
		}

		if (NioDrawable drawable = surface.next()) {
			NioColorAttachmentDescriptor[] colorAttachments = [
				NioColorAttachmentDescriptor(
					texture: drawable.texture,
					loadAction: NioLoadAction.clear,
					storeAction: NioStoreAction.store,
					clearColor: NioColor(0, 0, 0, 0)
				)
			];
			if (auto cmdbuffer = queue.fetch()) {
				auto renderPass = cmdbuffer.beginRenderPass(NioRenderPassDescriptor(colorAttachments[]));
					renderPass.setPipeline(renderPipeline);
					renderPass.setVertexBuffer(buffer, 0, 0);
					renderPass.draw(NioPrimitive.triangles, 0, 3);
				renderPass.endEncoding();

				cmdbuffer.present(drawable);
				queue.commit(cmdbuffer);
				cmdbuffer.await();
				cmdbuffer.release();
			}
		}
	}

	renderPipeline.release();
	shader.release();
    buffer.release();
	queue.release();
	surface.release();
	SDL_DestroyWindow(window);
}