/**
    Niobium Device Interface
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module niobium.mtl.device;
import niobium.mtl.resource;
import niobium.mtl.sampler;
import niobium.mtl.video;
import niobium.mtl.cmd;
import niobium.mtl.sync;
import niobium.mtl.heap;
import foundation;
import metal.device;
import numem;
import nulib;

import niobium.pipeline;

public import niobium.device;
public import niobium.types;

class NioMTLDevice : NioDevice {
private:
@nogc:
    // Device related data
    string              deviceName_;
    NioDeviceType       deviceType_;
    NioDeviceFeatures   deviceFeatures_;
    NioDeviceLimits     deviceLimits_;

    // Handles
    MTLDevice handle_;

    void setup(MTLDevice device) {
        this.handle_ = device;
        this.deviceName_ = device.name.toString().nu_dup();
        this.deviceType_ = device.location.toNioDeviceType();
        this.deviceFeatures_ = NioDeviceFeatures(
            presentation: true,
            meshShaders: true,
            geometryShaders: false,
            tesselationShaders: false,
            videoEncode: false,         // TODO: Add support for Video Toolkit
            videoDecode: false,
            dualSourceBlend: true,
            anisotropicFiltering: true,
            alphaToCoverage: true
        );
        this.deviceLimits_ = NioDeviceLimits(
            maxBufferSize: device.maxBufferLength,
        );

        foreach_reverse(i; 0..16) {
            if (device.supportsTextureSampleCount(1 << i)) {
                this.deviceLimits_.maxSamples = 1 << i;
                break;
            }
        }
    }

public:

    /**
        Low level handle for the device.
    */
    final @property MTLDevice handle() => handle_;

    /**
        Name of the device.
    */
    override @property string name() => deviceName_;

    /**
        Features supported by the device.
    */
    override @property NioDeviceFeatures features() => deviceFeatures_;

    /**
        Limits of the device.
    */
    override @property NioDeviceLimits limits() => deviceLimits_;

    /**
        Type of the device.
    */
    override @property NioDeviceType type() => deviceType_;

    ~this() {
        nu_freea(deviceName_);
    }

    /**
        Creates a Metal Device from its device handle.
    */
    this(MTLDevice device) {
        this.setup(device);
    }

    /**
        Creates a new video encode queue from the device.

        Queues created this way may only be used by a single thread
        at a time.
        
        Returns:
            A $(D NioVideoEncodeQueue) or $(D null) on failure.
    */
    override NioVideoEncodeQueue createVideoEncodeQueue() {
        return null;
    }

    /**
        Creates a new video decode queue from the device.

        Queues created this way may only be used by a single thread
        at a time.
        
        Returns:
            A $(D NioVideoDecodeQueue) or $(D null) on failure.
    */
    override NioVideoDecodeQueue createVideoDecodeQueue() {
        return null;
    }

    /**
        Creates a new command queue from the device submitting to
        the given logical device queue.

        Queues created this way may only be used by a single thread
        at a time.

        Params:
            index = The index of the queue to get.
        
        Returns:
            A $(D NioCommandQueue) or $(D null) on failure.
    */
    override NioCommandQueue createQueue(NioCommandQueueDescriptor desc) {
        return nogc_new!NioMTLCommandQueue(this, desc);
    }

    /**
        Creates a new fence.
        
        Returns:
            A new $(D NioFence) on success,
            $(D null) otherwise.
    */
    override NioFence createFence() {
        return nogc_new!NioMTLFence(this);
    }

    /**
        Creates a new semaphore.
        
        Returns:
            A new $(D NioSemaphore) on success,
            $(D null) otherwise.
    */
    override NioSemaphore createSemaphore() {
        return nogc_new!NioMTLSemaphore(this);
    }

    /**
        Creates a new heap.

        Params:
            desc = Descriptor for the heap.
        
        Returns:
            A new $(D NioHeap) or $(D null) on failure.
    */
    override NioHeap createHeap(NioHeapDescriptor desc) {
        return nogc_new!NioMTLHeap(this, desc);
    }

    /**
        Creates a new texture.

        The texture is created on the internal device heap, managed
        by Niobium itself.

        Params:
            desc = Descriptor for the texture.
        
        Returns:
            A new $(D NioTexture) or $(D null) on failure.
    */
    override NioTexture createTexture(NioTextureDescriptor desc) {
        return nogc_new!NioMTLTexture(this, desc);
    }

    /**
        Creates a new texture which reinterprets the data of another
        texture.

        Params:
            texture =   Texture to create a view of.
            desc =      Descriptor for the texture.
        
        Returns:
            A new $(D NioTexture) or $(D null) on failure.
    */
    override NioTexture createTextureView(NioTexture texture, NioTextureDescriptor desc) {
        return nogc_new!NioMTLTexture(this, texture, desc);
    }

    /**
        Creates a new buffer.

        The buffer is created on the internal device heap, managed
        by Niobium itself.

        Params:
            desc = Descriptor for the buffer.
        
        Returns:
            A new $(D NioBuffer) or $(D null) on failure.
    */
    override NioBuffer createBuffer(NioBufferDescriptor desc) {
        return nogc_new!NioMTLBuffer(this, desc);
    }

    /**
        Creates a new render pipeline object.

        Params:
            desc = Descriptor for the pipeline.
        
        Returns:
            A new $(D NioRenderPipeline) on success,
            $(D null) otherwise.
    */
    override NioRenderPipeline createRenderPipeline(NioRenderPipelineDescriptor desc) {
        return null;
    }

    /**
        Creates a new sampler.

        Params:
            desc = Descriptor for the sampler.
        
        Returns:
            A new $(D NioSampler) on success,
            $(D null) otherwise.
    */
    override NioSampler createSampler(NioSamplerDescriptor desc) {
        return nogc_new!NioMTLSampler(this, desc);
    }

    /// Stringification override
    override string toString() => name; // @suppress(dscanner.suspicious.object_const)
}

/**
    Converts a $(D MTLDeviceLocation) bitmask to its $(D NioDeviceType) equivalent.

    Params:
        usage = The $(D MTLDeviceLocation)
    
    Returns:
        The $(D NioDeviceType) equivalent.
*/
pragma(inline, true)
NioDeviceType toNioDeviceType(MTLDeviceLocation location) @nogc {
    switch(location) with(MTLDeviceLocation) {
        case BuiltIn:           return NioDeviceType.iGPU;
        case Slot, External:    return NioDeviceType.dGPU;
        default:                return NioDeviceType.unknown;
    }
}

//
//          IMPLEMENTATION DETAILS
//
private:




//
//          DEVICE ITERATION IMPLEMENTATION DETAILS
//

__gshared extern(C) NioDevice[] __nio_mtl_devices;

export extern(C) @property NioDevice[] __nio_enumerate_devices() @nogc {
    return __nio_mtl_devices;
}

pragma(crt_constructor)
export extern(C) void __nio_crt_init() @nogc {
    auto mtlDevices = MTLCopyAllDevices();

    vector!NioDevice devices;
    foreach(i, device; mtlDevices) {

        // < Metal 3 is not supported.
        if (!device.supportsFamily(MTLGPUFamily.Metal3))
            continue;
        
        devices ~= nogc_new!NioMTLDevice(device);
    }
    __nio_mtl_devices = devices.take();
    mtlDevices.release();
}

pragma(crt_destructor)
export extern(C) void __nio_crt_fini() @nogc {
    foreach(device; __nio_mtl_devices) 
        device.release();
    
    nu_freea(__nio_mtl_devices);
}