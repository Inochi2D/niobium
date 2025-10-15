/**
    Niobium Vulkan Samplers
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module niobium.mtl.sampler;
import niobium.mtl.device;
import niobium.mtl.heap;
import metal.sampler;
import foundation;
import numem;
import nulib;

public import niobium.sampler;

class NioMTLSampler : NioSampler {
private:
@nogc:
    MTLSamplerState handle_;

    void setup(NioSamplerDescriptor desc) {
        auto mtlDevice = cast(NioMTLDevice)device;

        MTLSamplerDescriptor mtldesc = MTLSamplerDescriptor.alloc.init;
        mtldesc.sAddressMode = desc.wrapU.toMTLSamplerAddressMode();
        mtldesc.tAddressMode = desc.wrapV.toMTLSamplerAddressMode();
        mtldesc.rAddressMode = desc.wrapW.toMTLSamplerAddressMode();
        mtldesc.lodMinClamp = desc.minLod;
        mtldesc.lodMaxClamp = desc.maxLod;
        mtldesc.lodBias = desc.mipLodBias;
        mtldesc.maxAnisotropy = cast(NSUInteger)desc.maxAnisotropy;
        mtldesc.normalizedCoordinates = desc.normalizedCoordinates;
        mtldesc.minFilter = desc.minFilter.toMTLSamplerMinMagFilter();
        mtldesc.magFilter = desc.magFilter.toMTLSamplerMinMagFilter();
        mtldesc.mipFilter = desc.mipFilter.toMTLSamplerMipFilter();
        this.handle_ = mtlDevice.handle.newSamplerState(mtldesc);
        
        mtldesc.release();
    }

public:

    /**
        The underlying Metal handle
    */
    final @property MTLSamplerState handle() => handle_;

    /// Destructor
    ~this() {
        handle_.release();
    }

    /**
        Constructs a new $(D NioMTLSampler) from a descriptor.

        Params:
            device =    The device to create the sampler on.
            desc =      Descriptor used to create the sampler.
    */
    this(NioDevice device, NioSamplerDescriptor desc) {
        super(device, desc);
        this.setup(desc);
    }
}

/**
    Converts a $(D NioSamplerWrap) type to its $(D MTLSamplerAddressMode) equivalent.

    Params:
        type = The $(D NioSamplerWrap)
    
    Returns:
        The $(D MTLSamplerAddressMode) equivalent.
*/
pragma(inline, true)
MTLSamplerAddressMode toMTLSamplerAddressMode(NioSamplerWrap wrap) @nogc {
    final switch(wrap) with(NioSamplerWrap) {
        case clampToEdge:           return MTLSamplerAddressMode.ClampToEdge;
        case repeat:                return MTLSamplerAddressMode.Repeat;
        case mirroredClampToEdge:   return MTLSamplerAddressMode.MirrorClampToEdge;
        case mirroredRepeat:        return MTLSamplerAddressMode.MirrorRepeat;
        case clampToBorderColor:    return MTLSamplerAddressMode.ClampToBorderColor;
    }
}

/**
    Converts a $(D NioMinMagFilter) type to its $(D MTLSamplerMinMagFilter) equivalent.

    Params:
        type = The $(D NioMinMagFilter)
    
    Returns:
        The $(D MTLSamplerMinMagFilter) equivalent.
*/
pragma(inline, true)
MTLSamplerMinMagFilter toMTLSamplerMinMagFilter(NioMinMagFilter filter) @nogc {
    final switch(filter) with(NioMinMagFilter) {
        case nearest:   return MTLSamplerMinMagFilter.Nearest;
        case linear:    return MTLSamplerMinMagFilter.Linear;
    }
}

/**
    Converts a $(D NioMipFilter) type to its $(D MTLSamplerMipFilter) equivalent.

    Params:
        type = The $(D NioMipFilter)
    
    Returns:
        The $(D MTLSamplerMipFilter) equivalent.
*/
pragma(inline, true)
MTLSamplerMipFilter toMTLSamplerMipFilter(NioMipFilter filter) @nogc {
    final switch(filter) with(NioMipFilter) {
        case none:      return MTLSamplerMipFilter.NotMipmapped;
        case nearest:   return MTLSamplerMipFilter.Nearest;
        case linear:    return MTLSamplerMipFilter.Linear;
    }
}