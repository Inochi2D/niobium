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
import imagefmt;

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
		import sdl.metal : SDL_Metal_CreateView, SDL_Metal_GetLayer;

		auto view = SDL_Metal_CreateView(window);
		return NioSurface.createForLayer(SDL_Metal_GetLayer(view));
	}
}

// Uniform data
struct Uniform {
	mat4 mvp;
}

// Vertex data
struct Vertex {
    vec3 vtx;
    vec2 uv;
}

const Vertex[] vertices = [

	// Front face
	Vertex(vec3(-32,-32, 32), vec2(0, 0)),
	Vertex(vec3(-32, 32, 32), vec2(0, 1)),
	Vertex(vec3( 32,-32, 32), vec2(1, 0)),
	Vertex(vec3( 32, 32, 32), vec2(1, 1)),

	// Back face
	Vertex(vec3(-32,-32,-32), vec2(1, 0)),
	Vertex(vec3( 32,-32,-32), vec2(0, 0)),
	Vertex(vec3(-32, 32,-32), vec2(1, 1)),
	Vertex(vec3( 32, 32,-32), vec2(0, 1)),

	// Top face
	Vertex(vec3(-32,-32,-32), vec2(0, 0)),
	Vertex(vec3(-32,-32, 32), vec2(0, 1)),
	Vertex(vec3( 32,-32,-32), vec2(1, 0)),
	Vertex(vec3( 32,-32, 32), vec2(1, 1)),

	// Bottom face
	Vertex(vec3(-32, 32,-32), vec2(1, 0)),
	Vertex(vec3( 32, 32,-32), vec2(0, 0)),
	Vertex(vec3(-32, 32, 32), vec2(1, 1)),
	Vertex(vec3( 32, 32, 32), vec2(0, 1)),

	// Right face
	Vertex(vec3( 32,-32,-32), vec2(1, 0)),
	Vertex(vec3( 32,-32, 32), vec2(0, 0)),
	Vertex(vec3( 32, 32,-32), vec2(1, 1)),
	Vertex(vec3( 32, 32, 32), vec2(0, 1)),

	// Left face
	Vertex(vec3(-32,-32,-32), vec2(0, 0)),
	Vertex(vec3(-32, 32,-32), vec2(0, 1)),
	Vertex(vec3(-32,-32, 32), vec2(1, 0)),
	Vertex(vec3(-32, 32, 32), vec2(1, 1)),
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
		maxCommandBuffers: 6
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
					NioVertexAttributeDescriptor(NioVertexFormat.float2, 0, Vertex.uv.offsetof)
				],
			),
			colorAttachments: [NioRenderPipelineAttachmentDescriptor(
				format: surface.format,
				blending: true,
			)],
			depthFormat: NioPixelFormat.depth32Stencil8
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
		depthTestEnabled: true
	));
	NioTexture depthBuffer = device.createTexture(NioTextureDescriptor(
		type: NioTextureType.type2D,
		format: NioPixelFormat.depth32Stencil8,
		storage: NioStorageMode.privateStorage,
		usage: NioTextureUsage.attachment,
		width: 640,
		height: 480
	));

	// Cube Image
	IFImage logoimg = read_image(cast(ubyte[])import("niobium-logo.png"), 4);
	NioSampler niosampler = device.createSampler(NioSamplerDescriptor());
	NioTexture niologo = device.createTexture(NioTextureDescriptor(
		type: NioTextureType.type2D,
		format: NioPixelFormat.rgba8UnormSRGB,
		storage: NioStorageMode.privateStorage,
		usage: NioTextureUsage.transfer | NioTextureUsage.sampled,
		width: logoimg.w,
		height: logoimg.h,
	)).upload(NioRegion3D(0, 0, 0, logoimg.w, logoimg.h, 1), 0, 0, logoimg.buf8, 0);
	logoimg.free();

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
						format: NioPixelFormat.depth32Stencil8,
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
			);

			vec3 cameraPos = (vec4(0, 0, -128, 1) * mat4.xRotation(radians(45)) * mat4.yRotation(t*2.5)).xyz;
			uniformData.mvp = (
				mat4.perspective01(drawable.texture.width, drawable.texture.height, 60.0, 0.01, 1000) *
				mat4.lookAt(cameraPos, vec3(0, 0, 0), vec3(0, 1, 0))
			).transposed;

			if (auto cmdbuffer = queue.fetch()) {
				auto renderPass = cmdbuffer.beginRenderPass(NioRenderPassDescriptor(colorAttachments[], depthAttachment));
					renderPass.setPipeline(renderPipeline);
					renderPass.setDepthStencilState(depthState);
					renderPass.setFragmentSampler(niosampler, 0);
					renderPass.setFragmentTexture(niologo, 0);
					renderPass.setVertexBuffer(vtxbuffer, 0, 0);
					renderPass.setVertexBuffer(uniforms, 0, 1);
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
	uniforms.release();
    vtxbuffer.release();
    idxbuffer.release();
	queue.release();
	surface.release();
	SDL_DestroyWindow(window);
}