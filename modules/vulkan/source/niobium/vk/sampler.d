/**
    Niobium Vulkan Samplers
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module niobium.vk.sampler;
import niobium.vk.device;
import niobium.vk.heap;
import vulkan.core;
import vulkan.eh;
import numem;
import nulib;

public import niobium.sampler;

class NioVkSampler : NioSampler {
private:
@nogc:
    VkSampler handle_;

    void setup(NioSamplerDescriptor desc) {
        auto nvkDevice = (cast(NioVkDevice)device);

        bool mipEnable = desc.mipFilter != NioMipFilter.none;
        auto createInfo = VkSamplerCreateInfo(
            minFilter: desc.minFilter.toVkFilter(),
            magFilter: desc.magFilter.toVkFilter(),
            mipmapMode: desc.mipFilter.toVkSamplerMipmapMode(),
            mipLodBias: desc.mipLodBias,
            minLod: mipEnable ? desc.minLod : 0,
            maxLod: mipEnable ? desc.maxLod : 0.25,
            anisotropyEnable: desc.maxAnisotropy > 1,
            maxAnisotropy: desc.maxAnisotropy,
            unnormalizedCoordinates: cast(VkBool32)!desc.normalizedCoordinates
        );
        vkCreateSampler(nvkDevice.handle, &createInfo, null, &handle_);
    }

protected:

    /**
        Called when the label has been changed.

        Params:
            label = The new label of the device.
    */
    override
    void onLabelChanged(string label) {
        auto vkDevice = (cast(NioVkDevice)device).handle;
        vkDevice.setDebugName(VK_OBJECT_TYPE_SAMPLER, handle_, label);
    }

public:

    // Destructor
    ~this() {
        auto nvkDevice = (cast(NioVkDevice)device);
        vkDestroySampler(nvkDevice.handle, handle_, null);
    }

    /**
        Constructs a new sampler.

        Params:
            device =    The device that "owns" this sampler.
            desc =      The descriptor for this sampler.
    */
    this(NioDevice device, NioSamplerDescriptor desc) {
        super(device, desc);
        this.setup(desc);
    }
}

/**
    Converts a $(D NioSamplerWrap) type to its $(D VkSamplerAddressMode) equivalent.

    Params:
        type = The $(D NioSamplerWrap)
    
    Returns:
        The $(D VkSamplerAddressMode) equivalent.
*/
pragma(inline, true)
VkSamplerAddressMode toVkSamplerAddressMode(NioSamplerWrap value) @nogc {
    final switch(value) with(NioSamplerWrap) {
        case clampToEdge:           return VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
        case repeat:                return VK_SAMPLER_ADDRESS_MODE_REPEAT;
        case mirroredClampToEdge:   return VK_SAMPLER_ADDRESS_MODE_MIRROR_CLAMP_TO_EDGE;
        case mirroredRepeat:        return VK_SAMPLER_ADDRESS_MODE_MIRRORED_REPEAT;
        case clampToBorderColor:    return VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_BORDER;
    }
}

/**
    Converts a $(D NioMinMagFilter) type to its $(D VkFilter) equivalent.

    Params:
        value = The $(D NioMinMagFilter)
    
    Returns:
        The $(D VkFilter) equivalent.
*/
pragma(inline, true)
VkFilter toVkFilter(NioMinMagFilter value) @nogc {
    final switch(value) with(NioMinMagFilter) {
        case nearest:   return VK_FILTER_NEAREST;
        case linear:    return VK_FILTER_LINEAR;
    }
}

/**
    Converts a $(D NioMipFilter) type to its $(D VkSamplerMipmapMode) equivalent.

    Params:
        value = The $(D NioMipFilter)
    
    Returns:
        The $(D VkSamplerMipmapMode) equivalent.
*/
pragma(inline, true)
VkSamplerMipmapMode toVkSamplerMipmapMode(NioMipFilter value) @nogc {
    final switch(value) with(NioMipFilter) {
        case none:      return VK_SAMPLER_MIPMAP_MODE_NEAREST;
        case nearest:   return VK_SAMPLER_MIPMAP_MODE_NEAREST;
        case linear:    return VK_SAMPLER_MIPMAP_MODE_LINEAR;
    }
}