/**
    Niobium Device Interface
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module niobium.device;
import niobium.depthstencil;
import niobium.pipeline;
import niobium.sampler;
import niobium.texture;
import niobium.buffer;
import niobium.queue;
import niobium.shader;
import niobium.heap;
import niobium.sync;
import nir.library;
import numem;
import nulib;

/**
    A feature list for a device.
*/
struct NioDeviceFeatures {

    /**
        Whether the device supports presentation to a surface.
    */
    bool presentation;

    /**
        Whether the device supports mesh shaders.
    */
    bool meshShaders;

    /**
        Whether the device supports geometry shaders.
    */
    bool geometryShaders;

    /**
        Whether the device supports tesselation shaders.
    */
    bool tesselationShaders;

    /**
        Whether the device supports video encoding.
    */
    bool videoEncode;

    /**
        Whether the device supports video decoding.
    */
    bool videoDecode;

    /**
        Whether the device supports blending with multiple sources.
    */
    bool dualSourceBlend;

    /**
        Whether the device supports anisotropic filtering.
    */
    bool anisotropicFiltering;

    /**
        Whether alpha-to-coverage is supported.
    */
    bool alphaToCoverage;

    /**
        Whether sharing memory between processes is supported.
    */
    bool externalMemory;

    /**
        Whether the framebuffer may be read from, then written to.
    */
    bool framebufferFetch;
}

/**
    Limits of the niobium device.
*/
struct NioDeviceLimits {
    
    /**
        Maximum amount of samples when using multisampling.
    */
    int maxSamples;

    /**
        Maximum size of buffers in bytes.
    */
    ulong maxBufferSize;

    /**
        Total amount of memory available to the device.

        0 indicates that this is unknown.
    */
    ulong totalMemory;
}

/**
    A device which is capable of doing 3D rendering and/or
    GPGPU computations.

    Note:
        You should not implement this class yourself, but use
        the provided enumerator to get system-provided devices.
*/
abstract
class NioDevice : NuRefCounted {
public:
@nogc:

    /**
        Gets the devices in the system

        Returns:
            An array owned by niobium containing all
            of the devices supported by the API.
    */
    static @property NioDevice[] systemDevices() {
        return __nio_enumerate_devices();
    }

    /**
        Name of the device.
    */
    abstract @property string name();

    /**
        Features supported by the device.
    */
    abstract @property NioDeviceFeatures features();

    /**
        Limits of the device.
    */
    abstract @property NioDeviceLimits limits();

    /**
        Type of the device.
    */
    abstract @property NioDeviceType type();

    /**
        Creates a new video encode queue from the device.

        Queues created this way may only be used by a single thread
        at a time.
        
        Returns:
            A new $(D NioVideoEncodeQueue) on success,
            $(D null) otherwise.
    */
    abstract NioVideoEncodeQueue createVideoEncodeQueue();

    /**
        Creates a new video decode queue from the device.

        Queues created this way may only be used by a single thread
        at a time.
        
        Returns:
            A new $(D NioVideoDecodeQueue) on success,
            $(D null) otherwise.
    */
    abstract NioVideoDecodeQueue createVideoDecodeQueue();

    /**
        Creates a new command queue from the device.

        Queues created this way may only be used by a single thread
        at a time.

        Params:
            desc = Descriptor for the queue.
        
        Returns:
            A new $(D NioCommandQueue) on success,
            $(D null) otherwise.
    */
    abstract NioCommandQueue createQueue(NioCommandQueueDescriptor desc);

    /**
        Creates a new fence.
        
        Returns:
            A new $(D NioFence) on success,
            $(D null) otherwise.
    */
    abstract NioFence createFence();

    /**
        Creates a new semaphore.
        
        Returns:
            A new $(D NioSemaphore) on success,
            $(D null) otherwise.
    */
    abstract NioSemaphore createSemaphore();

    /**
        Creates a new heap.

        Params:
            desc = Descriptor for the heap.
        
        Returns:
            A new $(D NioHeap) on success,
            $(D null) otherwise.
    */
    abstract NioHeap createHeap(NioHeapDescriptor desc);

    /**
        Creates a new texture.

        The texture is created on the internal device heap, managed
        by Niobium itself.

        Params:
            desc = Descriptor for the texture.
        
        Returns:
            A new $(D NioTexture) on success,
            $(D null) otherwise.
    */
    abstract NioTexture createTexture(NioTextureDescriptor desc);

    /**
        Creates a new texture which can be shared between process
        boundaries.

        Params:
            desc = Descriptor for the texture.
        
        Returns:
            A new $(D NioTexture) on success,
            $(D null) otherwise.
    */
    abstract NioTexture createSharedTexture(NioTextureDescriptor desc);

    /**
        Creates a new buffer.

        The buffer is created on the internal device heap, managed
        by Niobium itself.

        Params:
            desc = Descriptor for the buffer.
        
        Returns:
            A new $(D NioBuffer) on success,
            $(D null) otherwise.
    */
    abstract NioBuffer createBuffer(NioBufferDescriptor desc);

    /**
        Creates a new shader from a library.

        Params:
            library = The NIR Library.
        
        Returns:
            A new $(D NioShader) on success,
            $(D null) otherwise.
    */
    abstract NioShader createShader(NirLibrary library);

    /**
        Creates a new shader from source, the type of the source
        depends on the backend and platform.

        Params:
            name =      Name of the implicit library to create
            source =    Source code to compile.
        
        Notes:
            On most platforms source will be in the form of SPIR-V
            bytecode, on macOS and derivatives, the source will be
            in the form of metal shader language.

        Returns:
            A new $(D NioShader) on success,
            $(D null) otherwise.
    */
    abstract NioShader createShaderFromNativeSource(string name, ubyte[] source);

    /**
        Creates a new render pipeline object.

        Params:
            desc = Descriptor for the pipeline.
        
        Returns:
            A new $(D NioRenderPipeline) on success,
            $(D null) otherwise.
    */
    abstract NioRenderPipeline createRenderPipeline(NioRenderPipelineDescriptor desc);

    /**
        Creates a new sampler.

        Params:
            desc = Descriptor for the sampler.
        
        Returns:
            A new $(D NioSampler) on success,
            $(D null) otherwise.
    */
    abstract NioSampler createSampler(NioSamplerDescriptor desc);

    /**
        Creates a new depth-stencil state object.

        Params:
            desc = Descriptor for the depth-stencil state object.
        
        Returns:
            A new $(D NioDepthStencilState) on success,
            $(D null) otherwise.
    */
    abstract NioDepthStencilState createDepthStencilState(NioDepthStencilStateDescriptor desc);
}

/**
    An object which belongs to a device.
*/
abstract
class NioDeviceObject : NuRefCounted {
private:
@nogc:
    NioDevice device_;
    string label_;

protected:

    /**
        The device that created this object.
    */
    final @property void device(NioDevice value) {
        this.device_ = value;
    }

    /**
        Constructs a new device object.

        Params:
            device = The device that "owns" this object.
    */
    this(NioDevice device) {
        this.device_ = device;
    }

    /**
        Called when the label has been changed.

        Params:
            label = The new label of the device.
    */
    void onLabelChanged(string label) { }

public:

    /**
        The device that created this object.
    */
    final @property NioDevice device() => device_;

    /**
        Label of the object when debugging.
    */
    final @property string label() => label_;
    final @property void label(string value) {
        if (label_)
            nu_freea(label_);
        
        this.label_ = nstring(value).take();
        this.onLabelChanged(label_);
    }
}

/**
    A Niobium Device Type
*/
enum NioDeviceType : uint {
    
    /**
        Device type is unknown.
    */
    unknown,

    /**
        Integrated GPU.
    */
    iGPU,
    
    /**
        Dedicated GPU.
    */
    dGPU,
    
    /**
        Virtual GPU.
    */
    vGPU,
    
    /**
        CPU
    */
    cpu
}

/**
    Converts a $(D NioDeviceType) to a $(D string).

    Params:
        type = The device type.

    Returns:
        $(D string) representation of $(D NioDeviceType)
*/
pragma(inline, true)
string toString(NioDeviceType type) @nogc {
    final switch(type) {
        case NioDeviceType.unknown:
            return "Unknown";
        case NioDeviceType.iGPU:
            return "Integrated GPU";
        case NioDeviceType.dGPU:
            return "Dedicated GPU";
        case NioDeviceType.vGPU:
            return "Virtual GPU";
        case NioDeviceType.cpu:
            return "CPU";
    }
}

//
//          IMPLEMENTATION DETAILS
//
private extern(C):
    
/**
    The devices available on the system.
*/
extern extern(C) @property NioDevice[] __nio_enumerate_devices() @nogc;