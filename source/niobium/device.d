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
import niobium.texture;
import niobium.buffer;
import niobium.heap;
import numem;
import nulib;
import niobium.queue;

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
        The amount of command queues that you can 
        fetch from the device.
    */
    abstract @property uint queueCount();

    /**
        The video encode queue for the device, $(D null) if video
        encoding is not supported.
    */
    abstract @property NioVideoEncodeQueue videoEncodeQueue();

    /**
        The video decode queue for the device, $(D null) if video
        decoding is not supported.
    */
    abstract @property NioVideoDecodeQueue videoDecodeQueue();

    /**
        Gets a command queue from the device..

        Params:
            index = The index of the queue to get.
        
        Returns:
            A $(D NioCommandQueue) or $(D null) on failure.
    */
    abstract NioCommandQueue getCommandQueue(uint index);

    /**
        Creates a new heap.

        Params:
            desc = Descriptor for the heap.
        
        Returns:
            A new $(D NioHeap) or $(D null) on failure.
    */
    abstract NioHeap createHeap(NioHeapDescriptor desc);

    /**
        Creates a new texture.

        The texture is created on the internal device heap, managed
        by Niobium itself.

        Params:
            desc = Descriptor for the texture.
        
        Returns:
            A new $(D NioTexture) or $(D null) on failure.
    */
    abstract NioTexture createTexture(NioTextureDescriptor desc);

    /**
        Creates a new texture which reinterprets the data of another
        texture.

        Params:
            texture =   Texture to create a view of.
            desc =      Descriptor for the texture.
        
        Returns:
            A new $(D NioTexture) or $(D null) on failure.
    */
    abstract NioTexture createTextureView(NioTexture texture, NioTextureDescriptor desc);

    /**
        Creates a new buffer.

        The buffer is created on the internal device heap, managed
        by Niobium itself.

        Params:
            desc = Descriptor for the buffer.
        
        Returns:
            A new $(D NioBuffer) or $(D null) on failure.
    */
    abstract NioBuffer createBuffer(NioBufferDescriptor desc);
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