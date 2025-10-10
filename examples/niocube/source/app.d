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
		auto view = SDL_Metal_CreateView(window);
		return NioSurface.createForLayer(DL_Metal_GetLayer(view));
	}
}

struct Vertex {
    vec3 vtx;
    vec3 color;
}

const Vertex[] vertices = [

	// Front face
	Vertex(vec3(-1, -1,  1), vec3(0, 0, 1)),
	Vertex(vec3(-1,  1,  1), vec3(0, 0, 1)),
	Vertex(vec3( 1, -1,  1), vec3(0, 0, 1)),
	Vertex(vec3( 1,  1,  1), vec3(0, 0, 1)),

	// Back face
	Vertex(vec3(-1, -1, -1), vec3(0, 0, 1)),
	Vertex(vec3(-1,  1, -1), vec3(0, 0, 1)),
	Vertex(vec3( 1, -1, -1), vec3(0, 0, 1)),
	Vertex(vec3( 1,  1, -1), vec3(0, 0, 1)),

	// Top face
	Vertex(vec3(-1,  1, -1), vec3(0, 1, 0)),
	Vertex(vec3(-1,  1,  1), vec3(0, 1, 0)),
	Vertex(vec3( 1,  1, -1), vec3(0, 1, 0)),
	Vertex(vec3( 1,  1,  1), vec3(0, 1, 0)),

	// Bottom face
	Vertex(vec3(-1, -1, -1), vec3(0, 1, 0)),
	Vertex(vec3(-1, -1,  1), vec3(0, 1, 0)),
	Vertex(vec3( 1, -1, -1), vec3(0, 1, 0)),
	Vertex(vec3( 1, -1,  1), vec3(0, 1, 0)),

	// Right face
	Vertex(vec3( 1, -1, -1), vec3(1, 0, 0)),
	Vertex(vec3( 1, -1,  1), vec3(1, 0, 0)),
	Vertex(vec3( 1,  1, -1), vec3(1, 0, 0)),
	Vertex(vec3( 1,  1,  1), vec3(1, 0, 0)),

	// Left face
	Vertex(vec3(-1, -1, -1), vec3(1, 0, 0)),
	Vertex(vec3(-1, -1,  1), vec3(1, 0, 0)),
	Vertex(vec3(-1,  1, -1), vec3(1, 0, 0)),
	Vertex(vec3(-1,  1,  1), vec3(1, 0, 0)),
];

const uint[] indices = [

	// Front face
	0,  1,  2,
	2,  1,  3,

	// Back face
	4,  5,  6,
	6,  5,  7,

	// Top face
	8,  9,  10,
	10, 9,  11,

	// Bottom face
	12, 13, 14,
	14, 13, 15,

	// Left face
	16, 17, 18,
	18, 17, 19,

	// Right face
	20, 21, 22,
	22, 21, 23,
];

void main() {

    // Create Device
	auto device = NioDevice.systemDevices[0];
	auto queue = device.createQueue(NioCommandQueueDescriptor(
		maxCommandBuffers: 4
	));

    // Create Window and Surface
	SDL_Init(SDL_INIT_EVERYTHING);
	SDL_Window* window = SDL_CreateWindow("Niobium Cube", 640, 480, SDL_WindowFlags.SDL_WINDOW_RESIZABLE);
	NioSurface surface = window.surfaceFromWindow();
	surface.device = device;
	surface.framesInFlight = 3;
	surface.presentMode = NioPresentMode.vsync;
	surface.size = NioExtent2D(640, 480);
	surface.format = NioPixelFormat.bgra8UnormSRGB;

	// Create shaders
	NirLibrary shaderLibrary = nogc_new!NirLibrary();
	version(OSX) {
		shaderLibrary.addShader(NirShader(
			name: "cube",
			type: NirShaderType.msl,
			code: cast(ubyte[])read("cube.metal")
		));
	} else {
		shaderLibrary.addShader(NirShader(
			name: "cube",
			type: NirShaderType.nir,
			code: cast(ubyte[])read("cube.spv")
		));
	}
	NioShader shader = device.createShader(shaderLibrary);

	// Create pipeline
	NioRenderPipeline renderPipeline = device.createRenderPipeline(
		NioRenderPipelineDescriptor(
			vertexFunction: shader.getFunction("vertex_main").released(),
			fragmentFunction: shader.getFunction("fragment_main").released(),
			vertexDescriptor: NioVertexDescriptor(
				[NioVertexBindingDescriptor(NioVertexInputRate.perVertex, Vertex.sizeof)],
				[
					NioVertexAttributeDescriptor(NioVertexFormat.float3, 0, Vertex.vtx.offsetof), 
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
    NioBuffer vtxbuffer = device.createBuffer(NioBufferDescriptor(
        usage: NioBufferUsage.transfer | NioBufferUsage.vertexBuffer,
		storage: NioStorageMode.privateStorage,
        size: cast(uint)(vertices.length*Vertex.sizeof)
    )).upload(cast(void[])vertices[0..$], 0);
    NioBuffer idxbuffer = device.createBuffer(NioBufferDescriptor(
        usage: NioBufferUsage.transfer | NioBufferUsage.indexBuffer,
		storage: NioStorageMode.privateStorage,
        size: cast(uint)(indices.length * uint.sizeof)
    )).upload(cast(void[])indices[0..$], 0);

	bool closeRequested;
	SDL_Event ev;
	while(!closeRequested) {
		while(SDL_PollEvent(&ev)) {
			if (ev.type == SDL_EventType.SDL_EVENT_QUIT)
				closeRequested = true;
		}

		if (NioDrawable drawable = surface.next()) {
			NioColorAttachmentDescriptor[] colorAttachments = [
				NioColorAttachmentDescriptor(
					texture: drawable.texture,
					loadAction: NioLoadAction.clear,
					storeAction: NioStoreAction.store,
					clearColor: NioColor(0, 0, 0, 1)
				)
			];
			if (auto cmdbuffer = queue.fetch()) {
				auto renderPass = cmdbuffer.beginRenderPass(NioRenderPassDescriptor(colorAttachments[]));
					renderPass.setPipeline(renderPipeline);
					renderPass.setCulling(NioCulling.none);
					renderPass.setVertexBuffer(vtxbuffer, 0, 0);
					renderPass.drawIndexed(NioPrimitive.triangles, idxbuffer, NioIndexType.u32, cast(uint)indices.length);
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
    vtxbuffer.release();
    idxbuffer.release();
	queue.release();
	surface.release();
	SDL_DestroyWindow(window);
}