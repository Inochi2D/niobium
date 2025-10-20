/**
    Niobium Textures
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module niobium.vk.resource.texture;
import niobium.vk.device;
import niobium.vk.heap;
import niobium.resource;
import vulkan.khr.external_memory;
import vulkan.core;
import vulkan.eh;
import numem;
import nulib;

public import niobium.texture;
public import niobium.vk.formats;
import niobium.vk.resource.external;

/**
    Vulkan Texture
*/
class NioVkTexture : NioTexture {
private:
@nogc:
    // Backing Memory
    NioAllocator    allocator_;
    NioAllocation   allocation_;
    
    // Handles
    VkImage         image_;
    VkImageView     view_;
    NioSharedResourceHandle sharedHandle_;
    
    // State
    bool                    isView_;
    NioTextureDescriptor    desc_;
    VkExternalMemoryImageCreateInfo externInfo_;
    VkImageCreateInfo       vkdesc_;
    VkImageViewCreateInfo   vkviewdesc_;

    void createImage(NioTextureDescriptor desc, bool makeShared) {
        auto nvkDevice = (cast(NioVkDevice)device);
        if (makeShared) {
        
            this.desc_ = desc;
            this.isView_ = false;
            this.externInfo_ = VkExternalMemoryImageCreateInfo(
                handleTypes: NIO_VK_SHARED_HANDLE_TYPE
            );
            this.vkdesc_ = VkImageCreateInfo(
                pNext: &externInfo_,
                imageType: desc_.type.toVkImageType(),
                format: desc_.format.toVkFormat(),
                extent: VkExtent3D(desc.width, desc.height, desc.depth),
                mipLevels: desc.levels,
                arrayLayers: desc.slices,
                samples: VK_SAMPLE_COUNT_1_BIT,
                tiling: VK_IMAGE_TILING_OPTIMAL,
                usage: desc.usage.toVkImageUsage(desc_.format),
                sharingMode: VK_SHARING_MODE_EXCLUSIVE,
                initialLayout: VK_IMAGE_LAYOUT_UNDEFINED
            );
            vkEnforce(vkCreateImage(nvkDevice.handle, &vkdesc_, null, image_));
            this.layout = vkdesc_.initialLayout;

            // Allocate memory for our texture.
            VkMemoryRequirements vkmemreq_;
            vkGetImageMemoryRequirements(nvkDevice.handle, image_, &vkmemreq_);

            VkMemoryAllocateFlags flags = desc.storage.toVkMemoryProperties();
            ptrdiff_t type = allocator_.getTypeForMasked(flags, vkmemreq_.memoryTypeBits);

            // Allocate shared texture
            auto exportInfo = VkExportMemoryAllocateInfo(handleTypes: NIO_VK_SHARED_HANDLE_TYPE);
            allocation_ = allocator_.malloc_unique(VkMemoryAllocateInfo(
                pNext: &exportInfo,
                allocationSize: vkmemreq_.size,
                memoryTypeIndex: cast(uint)type,
            ));
            if (allocation_.memory) {
                this.sharedHandle_ = nogc_new!NioVkSharedResourceHandle(device, allocation_.memory.handle);
                vkBindImageMemory(
                    nvkDevice.handle, 
                    image_, 
                    allocation_.memory.handle,
                    allocation_.offset
                );
            }
        } else if (type >= 0) {
        
            this.desc_ = desc;
            this.isView_ = false;
            this.vkdesc_ = VkImageCreateInfo(
                imageType: desc_.type.toVkImageType(),
                format: desc_.format.toVkFormat(),
                extent: VkExtent3D(desc.width, desc.height, desc.depth),
                mipLevels: desc.levels,
                arrayLayers: desc.slices,
                samples: VK_SAMPLE_COUNT_1_BIT,
                tiling: VK_IMAGE_TILING_OPTIMAL,
                usage: desc.usage.toVkImageUsage(desc_.format),
                sharingMode: VK_SHARING_MODE_EXCLUSIVE,
                initialLayout: VK_IMAGE_LAYOUT_UNDEFINED
            );
            vkEnforce(vkCreateImage(nvkDevice.handle, &vkdesc_, null, image_));

            // Allocate memory for our texture.
            VkMemoryRequirements vkmemreq_;
            vkGetImageMemoryRequirements(nvkDevice.handle, image_, &vkmemreq_);

            VkMemoryAllocateFlags flags = desc.storage.toVkMemoryProperties();
            ptrdiff_t type = allocator_.getTypeForMasked(flags, vkmemreq_.memoryTypeBits);
            
            allocation_ = allocator_.malloc(vkmemreq_.size, cast(uint)type, vkmemreq_.alignment);
            if (allocation_.memory) {
                vkBindImageMemory(
                    nvkDevice.handle, 
                    image_, 
                    allocation_.memory.handle,
                    allocation_.offset 
                );
            }
        }

        // Create View
        this.vkviewdesc_ = VkImageViewCreateInfo(
            image: image_,
            viewType: desc.type.toVkImageViewType(),
            format: desc.format.toVkFormat(),
            components: VkComponentMapping(VK_COMPONENT_SWIZZLE_IDENTITY, VK_COMPONENT_SWIZZLE_IDENTITY, VK_COMPONENT_SWIZZLE_IDENTITY, VK_COMPONENT_SWIZZLE_IDENTITY),
            subresourceRange: VkImageSubresourceRange(desc.format.toVkAspect(), 0, VK_REMAINING_MIP_LEVELS, 0, VK_REMAINING_ARRAY_LAYERS)
        );
        vkEnforce(vkCreateImageView(nvkDevice.handle, &vkviewdesc_, null, view_));
    }

    void createImageView(NioVkTexture parent, NioTextureDescriptor desc, uint baseLevel, uint baseSlice) {
        auto nvkDevice = (cast(NioVkDevice)device);

        // Create View
        this.isView_ = true;
        this.desc_ = desc;
        this.vkdesc_ = parent.vkdesc_;
        this.image_ = cast(VkImage)parent.handle;
        this.vkviewdesc_ = VkImageViewCreateInfo(
            image: cast(VkImage)parent.handle,
            viewType: desc.type.toVkImageViewType(),
            format: desc.format.toVkFormat(),
            components: VkComponentMapping(VK_COMPONENT_SWIZZLE_IDENTITY, VK_COMPONENT_SWIZZLE_IDENTITY, VK_COMPONENT_SWIZZLE_IDENTITY, VK_COMPONENT_SWIZZLE_IDENTITY),
            subresourceRange: VkImageSubresourceRange(desc.format.toVkAspect(), baseLevel, desc_.levels, baseSlice, desc_.slices)
        );
        vkEnforce(vkCreateImageView(nvkDevice.handle, &vkviewdesc_, null, view_));
    }

    void createImageView(VkImage image, NioTextureDescriptor desc) {
        auto nvkDevice = (cast(NioVkDevice)device);

        // Create View
        this.isView_ = true;
        this.desc_ = desc;
        this.vkdesc_ = VkImageCreateInfo(
            imageType: desc_.type.toVkImageType(),
            format: desc_.format.toVkFormat(),
            extent: VkExtent3D(desc.width, desc.height, desc.depth),
            mipLevels: desc.levels,
            arrayLayers: desc.slices,
            samples: VK_SAMPLE_COUNT_1_BIT,
            tiling: VK_IMAGE_TILING_OPTIMAL,
            usage: desc.usage.toVkImageUsage(desc.format),
            sharingMode: VK_SHARING_MODE_EXCLUSIVE,
            initialLayout: VK_IMAGE_LAYOUT_UNDEFINED
        );
        this.image_ = image;
        this.vkviewdesc_ = VkImageViewCreateInfo(
            image: image,
            viewType: desc.type.toVkImageViewType(),
            format: desc.format.toVkFormat(),
            components: VkComponentMapping(VK_COMPONENT_SWIZZLE_IDENTITY, VK_COMPONENT_SWIZZLE_IDENTITY, VK_COMPONENT_SWIZZLE_IDENTITY, VK_COMPONENT_SWIZZLE_IDENTITY),
            subresourceRange: VkImageSubresourceRange(desc.format.toVkAspect(), 0, VK_REMAINING_MIP_LEVELS, 0, VK_REMAINING_ARRAY_LAYERS)
        );
        vkEnforce(vkCreateImageView(nvkDevice.handle, &vkviewdesc_, null, view_));
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

        // Differentiate view and image view.
        vkDevice.setDebugName(VK_OBJECT_TYPE_IMAGE, image_, label);
        vkDevice.setDebugName(VK_OBJECT_TYPE_IMAGE_VIEW, view_, (nstring(label) ~ " (View)"));
    }
public:

    /**
        Underlying Vulkan Image Layout.
    */
    final @property VkImageLayout layout() => vkdesc_.initialLayout;
    final @property void layout(VkImageLayout value) {
        vkdesc_.initialLayout = value;
    }

    /**
        Underlying Vulkan handle.
    */
    override @property void* handle() => cast(void*)image_;

    /**
        Underlying Vulkan Image View.
    */
    final @property VkImageView view() => view_;

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
    override @property uint slices() => desc_.slices;

    /**
        Mip level count of the texture.
    */
    override @property uint levels() => desc_.levels;

    /**
        Whether the texture can be shared between process boundaries.
    */
    override @property bool isShareable() => sharedHandle_ !is null;

    /**
        Exported handle for the texture.
    */
    override @property NioSharedResourceHandle sharedHandle() => sharedHandle_;

    /// Destructor
    ~this() {
        auto vkDevice = (cast(NioVkDevice)device).handle;
        
        // Image-view Mode
        if (isView_) {
            vkDestroyImageView(vkDevice, view_, null);
            return;
        }

        // Owning image.
        vkDestroyImageView(vkDevice, view_, null);
        vkDestroyImage(vkDevice, image_, null);
        if (allocator_ && allocation_.memory)
            allocator_.free(allocation_);
    }

    /**
        Constructs a new $(D NioVkTexture) from a descriptor.

        Params:
            device =        The device to create the texture on.
            desc =          Descriptor used to create the texture.
            makeShared =    Whether to allocate the texture as shared.
            allocator =     Allocator to use $(D null) for device allocator.
    */
    this(NioDevice device, NioTextureDescriptor desc, bool makeShared, NioAllocator allocator = null) {
        super(device);

        enforce(desc.usage != NioTextureUsage.none, "Invalid texture usage 'none'!");
        this.allocator_ = allocator ? allocator : (cast(NioVkDevice)device).allocator;
        this.createImage(desc, makeShared);
    }

    /**
        Constructs a new $(D NioVkTexture) as a view of another texture.

        Params:
            device =    The device to create the texture on.
            texture =   Texture to create a view of.
            desc =      Descriptor used to create the texture.
    */
    this(NioDevice device, NioTexture texture, NioTextureDescriptor desc) {
        super(device);
        this.createImageView(cast(NioVkTexture)texture, desc, 0, 0);
    }

    /**
        Constructs a new $(D NioVkTexture) as a view of another texture.

        Params:
            device =    The device to create the texture on.
            texture =   Texture to create a view of.
            desc =      Descriptor used to create the texture.
            baseLevel = Base mip level
            baseSlice = Base slice
    */
    this(NioDevice device, NioTexture texture, NioTextureDescriptor desc, uint baseLevel, uint baseSlice) {
        super(device);
        this.createImageView(cast(NioVkTexture)texture, desc, baseLevel, baseSlice);
    }

    /**
        Constructs a new $(D NioVkTexture) as a view of a vulkan handle.

        Params:
            device =    The device to create the texture on.
            handle =    Vulkan handle to create a view of.
            desc =      Descriptor used to create the texture.
    */
    this(NioDevice device, VkImage handle, NioTextureDescriptor desc) {
        super(device);

        this.createImageView(handle, desc);
    }

    /**
        Uploads data to the texture using a device-internal
        transfer queue.

        This is overall a slow operation, uploading via
        a $(D NioTransferCommandEncoder) is recommended.

        Params:
            region =    The region of the texture to upload to.
            level =     The mipmap level of the texture to upload to.
            slice =     The array slice of the texture to upload to, for non-array textures, set to 0.
            data =      The data to upload.
            rowStride = The stride of a single row of pixels.
    */
    override
    NioTexture upload(NioRegion3D region, uint level, uint slice, void[] data, uint rowStride) {
        (cast(NioVkDevice)device).uploadDataToTexture(this, region, level, slice, data, rowStride);
        return this;
    }

    /**
        Downloads data from a texture using a device-internal
        transfer queue.

        This is overall a slow operation, downloading via
        a $(D NioTransferCommandEncoder) is recommended.
        
        Params:
            region =    Region to download
            level =     Mip level to download
            slice =     Array slice to download
            rowStride = The stride of a single row of pixels.
        
        Returns:
            A nogc slice of data on success,
            $(D null) otherwise.
    */
    override
    void[] download(NioRegion3D region, uint level, uint slice, uint rowStride) {
        return (cast(NioVkDevice)device).downloadDataFromTexture(this, region, level, slice, rowStride);
    }

    /**
        Creates a new texture which reinterprets the data of this
        texture.

        Params:
            format =    Pixel format to interpret the texture as.
        
        Returns:
            A new $(D NioTexture) on success,
            $(D null) otherwise.
    */
    override
    NioTexture createView(NioPixelFormat format) {
        return nogc_new!NioVkTexture(device, this, NioTextureDescriptor(
            type: desc_.type,
            format: format,
            storage: desc_.storage,
            usage: desc_.usage,
            width: desc_.width,
            height: desc_.height,
            depth: desc_.depth,
            levels: desc_.levels,
            slices: desc_.slices
        ));
    }

    /**
        Creates a new texture which reinterprets the data of this
        texture.

        Params:
            format =        Pixel format to interpret the texture as.
            type =          The texture type to interpret the texture as.
            baseLevel =     The base mip level to interpret
            baseSlice =     The base array slice to interpret
            levels =        The levels to interpret.
            slices =        The slices to interpret.
        
        Returns:
            A new $(D NioTexture) on success,
            $(D null) otherwise.
    */
    override
    NioTexture createView(NioPixelFormat format, NioTextureType type, uint baseLevel = 0, uint baseSlice = 0, uint levels = 1, uint slices = 1) {
        return nogc_new!NioVkTexture(device, this, NioTextureDescriptor(
            type: desc_.type,
            format: format,
            storage: desc_.storage,
            usage: desc_.usage,
            width: desc_.width,
            height: desc_.height,
            depth: desc_.depth,
            levels: desc_.levels,
            slices: desc_.slices
        ), baseLevel, baseSlice);

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
        case type1D, type1DArray:                       return VK_IMAGE_TYPE_1D;
        case type2D, type2DArray, 
             type2DMultisample, type2DMultisampleArray, 
             typeCube, typeCubeArray:                   return VK_IMAGE_TYPE_2D;
        case type3D:                                    return VK_IMAGE_TYPE_3D;
    }
}

/**
    Converts a $(D NioTextureType) type to its $(D VkImageViewType) equivalent.

    Params:
        type = The $(D NioTextureType)
    
    Returns:
        The $(D VkImageViewType) equivalent.
*/
pragma(inline, true)
VkImageViewType toVkImageViewType(NioTextureType type) @nogc {
    final switch(type) with(NioTextureType) {
        case type1D:                                return VK_IMAGE_VIEW_TYPE_1D;
        case type1DArray:                           return VK_IMAGE_VIEW_TYPE_1D_ARRAY;
        case type2D, type2DMultisample:             return VK_IMAGE_VIEW_TYPE_2D;
        case type2DArray, type2DMultisampleArray:   return VK_IMAGE_VIEW_TYPE_2D_ARRAY;
        case type3D:                                return VK_IMAGE_VIEW_TYPE_3D;
        case typeCube:                              return VK_IMAGE_VIEW_TYPE_CUBE;
        case typeCubeArray:                         return VK_IMAGE_VIEW_TYPE_CUBE_ARRAY;
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
VkImageUsageFlags toVkImageUsage(NioTextureUsage usage, NioPixelFormat format) @nogc {
    VkImageUsageFlags result = 0;
    if (usage & NioTextureUsage.transfer)
        result |= VK_IMAGE_USAGE_TRANSFER_SRC_BIT | VK_IMAGE_USAGE_TRANSFER_DST_BIT;

    if (usage & NioTextureUsage.sampled)
        result |= VK_IMAGE_USAGE_SAMPLED_BIT;

    if (usage & NioTextureUsage.attachment) {
        switch(format) with(NioPixelFormat) {
            case depth24Stencil8:       result |= VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT; break;
            case depth32Stencil8:       result |= VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT; break;
            case x24Stencil8:           result |= VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT; break;
            case x32Stencil8:           result |= VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT; break;
            case stencil8:              result |= VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT; break;
            case depth16Unorm:          result |= VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT; break;
            case depth32Float:          result |= VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT; break;
            default:                    result |= VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT; break;
        }
    }

    if (usage & NioTextureUsage.videoEncode)
        result |= VK_IMAGE_USAGE_VIDEO_ENCODE_SRC_BIT_KHR | VK_IMAGE_USAGE_VIDEO_ENCODE_DST_BIT_KHR;

    if (usage & NioTextureUsage.videoDecode)
        result |= VK_IMAGE_USAGE_VIDEO_DECODE_SRC_BIT_KHR | VK_IMAGE_USAGE_VIDEO_DECODE_DST_BIT_KHR;

    return result;
}