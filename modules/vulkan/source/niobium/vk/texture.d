/**
    Niobium Textures
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module niobium.vk.texture;
import niobium.vk.device;
import niobium.vk.heap;
import niobium.texture;
import niobium.resource;
import niobium.device;
import vulkan.core;
import vulkan.eh;
import numem;

/**
    Vulkan Texture
*/
class NioVkTexture : NioTexture {
private:
@nogc:
    NioAllocator allocator_;
    NioAllocation allocation_;
    VkImage handle_;
    
    VkImageCreateInfo vkdesc_;
    NioTextureDescriptor desc_;
    VkImageLayout layout_;

    void createImage(NioTextureDescriptor desc) {
        auto nvkDevice = (cast(NioVkDevice)device);
        
        this.desc_ = desc;
        this.vkdesc_ = VkImageCreateInfo(
            imageType: desc_.type.toVkImageType(),
            format: desc_.format.toVkFormat(),
            extent: VkExtent3D(desc.width, desc.height, desc.depth),
            mipLevels: desc.levels,
            arrayLayers: desc.layers,
            samples: VK_SAMPLE_COUNT_1_BIT,
            tiling: VK_IMAGE_TILING_OPTIMAL,
            usage: desc.usage.toVkImageUsage(),
            sharingMode: VK_SHARING_MODE_EXCLUSIVE,
            initialLayout: VK_IMAGE_LAYOUT_UNDEFINED
        );
        vkEnforce(vkCreateImage(nvkDevice.vkDevice, &vkdesc_, null, &handle_));
        this.layout_ = vkdesc_.initialLayout;

        // Allocate memory for our texture.
        VkMemoryRequirements vkmemreq_;
        vkGetImageMemoryRequirements(nvkDevice.vkDevice, handle_, &vkmemreq_);

        VkMemoryAllocateFlags flags = desc.storage.toVkMemoryProperties();
        ptrdiff_t type = allocator_.getTypeForMasked(flags, vkmemreq_.memoryTypeBits);
        if (type >= 0) {
            allocation_ = allocator_.malloc(vkmemreq_.size, cast(uint)type);
            if (allocation_.memory) {
                vkBindImageMemory(
                    nvkDevice.vkDevice, 
                    handle_, 
                    allocation_.memory.handle,
                    allocation_.offset 
                );
            }
        }
    }

protected:

    /**
        Called when the label has been changed.

        Params:
            label = The new label of the device.
    */
    override
    void onLabelChanged(string label) {
        auto vkDevice = (cast(NioVkDevice)device).vkDevice;

        import niobium.vk.device : setDebugName;
        vkDevice.setDebugName(VK_OBJECT_TYPE_IMAGE, handle_, label);
    }
public:

    /// Destructor
    ~this() {
        auto vkDevice = (cast(NioVkDevice)device).vkDevice;
        if (allocation_.memory) {
            allocator_.free(allocation_);
        }

        vkDestroyImage(vkDevice, handle_, null);
    }

    /**
        Constructs a new $(D NioVkTexture) from a descriptor.

        Params:
            device =    The device to create the texture on.
            desc =      Descriptor used to create the texture.
            allocator = Allocator to use $(D null) for device allocator.
    */
    this(NioDevice device, NioTextureDescriptor desc, NioAllocator allocator = null) {
        super(device);
        this.allocator_ = allocator ? allocator : (cast(NioVkDevice)device).allocator;
        this.createImage(desc);
    }

    /**
        Size of the resource in bytes.
    */
    override @property uint size() => cast(uint)allocation_.size;

    /**
        The pixel format of the texture.
    */
    override @property NioPixelFormat format() => desc_.format;

    /**
        The type of the texture.
    */
    override @property NioTextureType type() => desc_.type;

    /**
        The usage flags of the texture.
    */
    override @property NioTextureUsage usage() => desc_.usage;

    /**
        Storage mode of the resource.
    */
    override @property NioStorageMode storageMode() => desc_.storage;

    /**
        Width of the texture in pixels.
    */
    override @property uint width() => desc_.width;

    /**
        Height of the texture in pixels.
    */
    override @property uint height() => desc_.height;

    /**
        Depth of the texture in pixels.
    */
    override @property uint depth() => desc_.depth;

    /**
        Array layer count of the texture.
    */
    override @property uint layers() => desc_.layers;

    /**
        Mip level count of the texture.
    */
    override @property uint levels() => desc_.levels;
}

/**
    Converts a $(D NioPixelFormat) format to its $(D VkFormat) equivalent.

    Params:
        format = The $(D NioPixelFormat)
    
    Returns:
        The $(D VkFormat) equivalent.
*/
pragma(inline, true)
VkFormat toVkFormat(NioPixelFormat format) @nogc {
    final switch(format) with(NioPixelFormat) {
        case unknown:               return VK_FORMAT_UNDEFINED;
        case a8Unorm:               return VK_FORMAT_A8_UNORM;
        case r8Unorm:               return VK_FORMAT_R8_UNORM;
        case r8UnormSRGB:           return VK_FORMAT_R8_SRGB;
        case r8Snorm:               return VK_FORMAT_R8_SNORM;
        case r8Uint:                return VK_FORMAT_R8_UINT;
        case r8Sint:                return VK_FORMAT_R8_SINT;
        case r16Unorm:              return VK_FORMAT_R16_UNORM;
        case r16Uint:               return VK_FORMAT_R16_UINT;
        case r16Sint:               return VK_FORMAT_R16_SINT;
        case r16Float:              return VK_FORMAT_R16_SFLOAT;
        case r32Uint:               return VK_FORMAT_R32_UINT;
        case r32Sint:               return VK_FORMAT_R32_SINT;
        case r32Float:              return VK_FORMAT_R32_SFLOAT;
        case rg8Unorm:              return VK_FORMAT_R8G8_UNORM;
        case rg8UnormSRGB:          return VK_FORMAT_R8G8_SRGB;
        case rg8Snorm:              return VK_FORMAT_R8G8_SNORM;
        case rg8Uint:               return VK_FORMAT_R8G8_UINT;
        case rg8Sint:               return VK_FORMAT_R8G8_SINT;
        case rg16Unorm:             return VK_FORMAT_R16G16_UNORM;
        case rg16Snorm:             return VK_FORMAT_R16G16_SNORM;
        case rg16Uint:              return VK_FORMAT_R16G16_UINT;
        case rg16Sint:              return VK_FORMAT_R16G16_SINT;
        case rg16Float:             return VK_FORMAT_R16G16_SFLOAT;
        case rg32Uint:              return VK_FORMAT_R32G32_UINT;
        case rg32Sint:              return VK_FORMAT_R32G32_SINT;
        case rg32Float:             return VK_FORMAT_R32G32_SFLOAT;
        case rgba8Unorm:            return VK_FORMAT_R8G8B8A8_UNORM;
        case rgba8UnormSRGB:        return VK_FORMAT_R8G8B8A8_SRGB;
        case rgba8Snorm:            return VK_FORMAT_R8G8B8A8_SNORM;
        case rgba8Uint:             return VK_FORMAT_R8G8B8A8_UINT;
        case rgba8Sint:             return VK_FORMAT_R8G8B8A8_SINT;
        case rgba16Unorm:           return VK_FORMAT_R16G16B16A16_UNORM;
        case rgba16Snorm:           return VK_FORMAT_R16G16B16A16_SNORM;
        case rgba16Uint:            return VK_FORMAT_R16G16B16A16_UINT;
        case rgba16Sint:            return VK_FORMAT_R16G16B16A16_SINT;
        case rgba32Uint:            return VK_FORMAT_R32G32B32A32_UINT;
        case rgba32Sint:            return VK_FORMAT_R32G32B32A32_SINT;
        case rgba32Float:           return VK_FORMAT_R32G32B32A32_SFLOAT;
        case bgra8Unorm:            return VK_FORMAT_B8G8R8A8_UNORM;
        case bgra8UnormSRGB:        return VK_FORMAT_B8G8R8A8_SRGB;
        case rgbaUnorm_BC1:         return VK_FORMAT_BC1_RGBA_UNORM_BLOCK;
        case rgbaUnormSRGB_BC1:     return VK_FORMAT_BC1_RGBA_SRGB_BLOCK;
        case rgbaUnorm_BC2:         return VK_FORMAT_BC2_UNORM_BLOCK;
        case rgbaUnormSRGB_BC2:     return VK_FORMAT_BC2_SRGB_BLOCK;
        case rgbaUnorm_BC3:         return VK_FORMAT_BC3_UNORM_BLOCK;
        case rgbaUnormSRGB_BC3:     return VK_FORMAT_BC3_SRGB_BLOCK;
        case rgbaUnorm_BC7:         return VK_FORMAT_BC7_UNORM_BLOCK;
        case rgbaUnormSRGB_BC7:     return VK_FORMAT_BC7_SRGB_BLOCK;
        case depth24Stencil8:       return VK_FORMAT_D24_UNORM_S8_UINT;
        case depth32Stencil8:       return VK_FORMAT_D32_SFLOAT_S8_UINT;
        case x24Stencil8:           return VK_FORMAT_D24_UNORM_S8_UINT;
        case x32Stencil8:           return VK_FORMAT_D32_SFLOAT_S8_UINT;
    }
}

/**
    Converts a $(D NioTextureType) type to its $(D VkImageType) equivalent.

    Params:
        type = The $(D NioTextureType)
    
    Returns:
        The $(D VkImageType) equivalent.
*/
pragma(inline, true)
VkImageType toVkImageType(NioTextureType type) @nogc {
    final switch(type) with(NioTextureType) {
        case texture1d: return VK_IMAGE_TYPE_1D;
        case texture2d: return VK_IMAGE_TYPE_2D;
        case texture3d: return VK_IMAGE_TYPE_3D;
    }
}

/**
    Converts a $(D NioTextureUsage) bitmask to its $(D VkImageUsageFlags) equivalent.

    Params:
        usage = The $(D NioTextureUsage)
    
    Returns:
        The $(D VkImageUsageFlags) equivalent.
*/
pragma(inline, true)
VkImageUsageFlags toVkImageUsage(NioTextureUsage usage) @nogc {
    VkImageUsageFlags result = 0;
    if (usage & NioTextureUsage.transfer)
        result |= VK_IMAGE_USAGE_TRANSFER_SRC_BIT | VK_IMAGE_USAGE_TRANSFER_DST_BIT;

    if (usage & NioTextureUsage.sampled)
        result |= VK_IMAGE_USAGE_SAMPLED_BIT;

    if (usage & NioTextureUsage.attachment)
        result |= VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT | VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT;

    if (usage & NioTextureUsage.videoEncode)
        result |= VK_IMAGE_USAGE_VIDEO_ENCODE_SRC_BIT_KHR | VK_IMAGE_USAGE_VIDEO_ENCODE_DST_BIT_KHR;

    if (usage & NioTextureUsage.videoDecode)
        result |= VK_IMAGE_USAGE_VIDEO_DECODE_SRC_BIT_KHR | VK_IMAGE_USAGE_VIDEO_DECODE_DST_BIT_KHR;

    return result;
}