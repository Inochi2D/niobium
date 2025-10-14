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
import sdl.timer;
import std.file : read;
import niobium.vk.shader.shader;

NioSurface surfaceFromWindow(SDL_Window* window) {
	import std.stdio;
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

// Uniform data
struct Uniform {
	mat4 mvp;
}

// Vertex data
struct Vertex {
    vec3 vtx;
    vec3 color;
}

const Vertex[] vertices = [

	// Front face
	Vertex(vec3(-32,-32, 32), vec3(0, 0, 1)),
	Vertex(vec3(-32, 32, 32), vec3(0, 0, 1)),
	Vertex(vec3( 32,-32, 32), vec3(0, 0, 1)),
	Vertex(vec3( 32, 32, 32), vec3(0, 0, 1)),

	// Back face
	Vertex(vec3(-32,-32,-32), vec3(0, 0, 1)),
	Vertex(vec3(-32, 32,-32), vec3(0, 0, 1)),
	Vertex(vec3( 32,-32,-32), vec3(0, 0, 1)),
	Vertex(vec3( 32, 32,-32), vec3(0, 0, 1)),

	// Top face
	Vertex(vec3(-32, 32,-32), vec3(0, 1, 0)),
	Vertex(vec3(-32, 32, 32), vec3(0, 1, 0)),
	Vertex(vec3( 32, 32,-32), vec3(0, 1, 0)),
	Vertex(vec3( 32, 32, 32), vec3(0, 1, 0)),

	// Bottom face
	Vertex(vec3(-32,-32,-32), vec3(0, 1, 0)),
	Vertex(vec3(-32,-32, 32), vec3(0, 1, 0)),
	Vertex(vec3( 32,-32,-32), vec3(0, 1, 0)),
	Vertex(vec3( 32,-32, 32), vec3(0, 1, 0)),

	// Right face
	Vertex(vec3( 32,-32,-32), vec3(1, 0, 0)),
	Vertex(vec3( 32,-32, 32), vec3(1, 0, 0)),
	Vertex(vec3( 32, 32,-32), vec3(1, 0, 0)),
	Vertex(vec3( 32, 32, 32), vec3(1, 0, 0)),

	// Left face
	Vertex(vec3(-32,-32,-32), vec3(1, 0, 0)),
	Vertex(vec3(-32,-32, 32), vec3(1, 0, 0)),
	Vertex(vec3(-32, 32,-32), vec3(1, 0, 0)),
	Vertex(vec3(-32, 32, 32), vec3(1, 0, 0)),
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
	import std.stdio;

    // Create Device
	auto device = NioDevice.systemDevices[0];
	auto queue = device.createQueue(NioCommandQueueDescriptor(
		maxCommandBuffers: 8
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
			vertexFunction: shader.getFunction("vertex_main"),
			fragmentFunction: shader.getFunction("fragment_main"),
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
			)],
			depthFormat: NioPixelFormat.depth24Stencil8
		)
	);

    // Vertex Data
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

	// Uniform data
	Uniform* uniformData;
	NioBuffer uniforms = device.createBuffer(NioBufferDescriptor(
        usage: NioBufferUsage.uniformBuffer,
		storage: NioStorageMode.sharedStorage,
		size: cast(uint)(Uniform.sizeof)
	));
	uniformData = cast(Uniform*)uniforms.map().ptr;

	// Depth buffer
	NioDepthStencilState depthState = device.createDepthStencilState(NioDepthStencilStateDescriptor(
		depthTestEnabled: true,
		depthState: NioDepthStateDescriptor(
			depthWriteEnabled: true,
			compareFunction: NioCompareOp.greater
		)
	));
	NioTexture depthBuffer = device.createTexture(NioTextureDescriptor(
		type: NioTextureType.type2D,
		format: NioPixelFormat.depth24Stencil8,
		storage: NioStorageMode.privateStorage,
		usage: NioTextureUsage.attachment,
		width: 640,
		height: 480
	));

	bool closeRequested;
	SDL_Event ev;
	
	ulong currentFrame;
	ulong lastFrame;
	float t = 0;
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
					depthBuffer.release();
					depthBuffer = device.createTexture(NioTextureDescriptor(
						type: NioTextureType.type2D,
						format: NioPixelFormat.depth24Stencil8,
						storage: NioStorageMode.privateStorage,
						usage: NioTextureUsage.attachment,
						width: ev.window.data1,
						height: ev.window.data2
					));
					break;
			}
		}

		lastFrame = currentFrame;
		currentFrame = SDL_GetTicks();
		t += cast(float)(currentFrame-lastFrame) * 0.001;

		if (NioDrawable drawable = surface.next()) {
			auto cmdbuffer = queue.fetch();
			NioColorAttachmentDescriptor[] colorAttachments = [
				NioColorAttachmentDescriptor(
					texture: drawable.texture,
					loadAction: NioLoadAction.clear,
					storeAction: NioStoreAction.store,
					clearColor: NioColor(0, 0, 0, 1)
				)
			];
			auto depthAttachment = NioDepthAttachmentDescriptor(
				texture: depthBuffer,
				loadAction: NioLoadAction.clear,
				storeAction: NioStoreAction.store,
				clearDepth: 0,
			);

			uniformData.mvp = (
				mat4.orthographic01(0, drawable.texture.width, drawable.texture.height, 0, 0, ushort.max) *
				mat4.translation((drawable.texture.width/2), (drawable.texture.height/2), ushort.max/2) * 
				mat4.scaling(3, 3, 3) *
				mat4.xRotation(radians(24)) *
				mat4.yRotation(t)
			).transposed;
			
			auto renderPass = cmdbuffer.beginRenderPass(NioRenderPassDescriptor(colorAttachments[], depthAttachment));
				renderPass.setPipeline(renderPipeline);
				renderPass.setDepthStencilState(depthState);
				renderPass.setVertexBuffer(vtxbuffer, 0, 0);
				renderPass.setVertexBuffer(uniforms, 0, 0);
				renderPass.drawIndexed(NioPrimitive.triangles, idxbuffer, NioIndexType.u32, cast(uint)indices.length);
			renderPass.endEncoding();

			cmdbuffer.present(drawable);
			queue.commit(cmdbuffer);
			cmdbuffer.await();
			cmdbuffer.release();
		}
	}

	renderPipeline.release();
	shader.release();
	uniforms.release();
    vtxbuffer.release();
    idxbuffer.release();
	queue.release();
	surface.release();
	SDL_DestroyWindow(window);
}