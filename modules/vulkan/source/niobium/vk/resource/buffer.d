/**
    Niobium Vulkan Buffers
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module niobium.vk.resource.buffer;
import niobium.vk.device;
import niobium.vk.heap;
import niobium.resource;
import vulkan.core;
import vulkan.eh;
import numem;

public import niobium.buffer;
public import niobium.vertexformat;

/**
    Vulkan Buffer
*/
class NioVkBuffer : NioBuffer {
private:
@nogc:
    // Backing Memory
    NioAllocator    allocator_;
    NioAllocation   allocation_;

    // Handles
    VkBuffer handle_;

    // State
    NioBufferDescriptor desc_;
    VkBufferCreateInfo vkdesc_;

    void createBuffer(NioBufferDescriptor desc) {
        auto nvkDevice = (cast(NioVkDevice)device);
        
        this.desc_ = desc;
        this.vkdesc_ = VkBufferCreateInfo(
            size: desc.size,
            usage: desc.usage.toVkBufferUsage(),
            sharingMode: VK_SHARING_MODE_EXCLUSIVE
        );
        vkEnforce(vkCreateBuffer(nvkDevice.handle, &vkdesc_, null, &handle_));

        // Allocate memory for our texture.
        VkMemoryRequirements vkmemreq_;
        vkGetBufferMemoryRequirements(nvkDevice.handle, handle_, &vkmemreq_);

        VkMemoryAllocateFlags flags = desc.storage.toVkMemoryProperties();
        ptrdiff_t type = allocator_.getTypeForMasked(flags, vkmemreq_.memoryTypeBits);
        if (type >= 0) {
            allocation_ = allocator_.malloc(vkmemreq_.size, cast(uint)type);
            if (allocation_.memory) {
                vkBindBufferMemory(
                    nvkDevice.handle, 
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
        auto vkDevice = (cast(NioVkDevice)device).handle;
        vkDevice.setDebugName(VK_OBJECT_TYPE_BUFFER, handle_, label);
    }

public:

    /**
        Underlying Vulkan handle.
    */
    override @property void* handle() => cast(void*)handle_;

    /// Destructor
    ~this() {
        auto vkDevice = (cast(NioVkDevice)device).handle;
        if (allocation_.memory)
            allocator_.free(allocation_);
        
        vkDestroyBuffer(vkDevice, handle_, null);
    }

    /**
        Constructs a new $(D NioVkBuffer) from a descriptor.

        Params:
            device =    The device to create the buffer on.
            desc =      Descriptor used to create the buffer.
            allocator = Allocator to use $(D null) for device allocator.
    */
    this(NioDevice device, NioBufferDescriptor desc, NioAllocator allocator = null) {
        super(device);

        enforce(desc.usage != NioBufferUsage.none, "Invalid buffer usage 'none'!");
        this.allocator_ = allocator ? allocator : (cast(NioVkDevice)device).allocator;
        this.createBuffer(desc);
    }

    /**
        Size of the resource in bytes.
    */
    override @property uint size() => cast(uint)allocation_.size;

    /**
        The usage flags of the buffer.
    */
    override @property NioBufferUsage usage() => desc_.usage;

    /**
        Storage mode of the resource.
    */
    override @property NioStorageMode storageMode() => desc_.storage;
    
    /**
        Maps the buffer, increasing the internal mapping
        reference count.

        Returns:
            The mapped buffer or $(D null) on failure.
    */
    override void[] map() {
        if (!allocation_.memory || !allocation_.memory.isMappable)
            return null;

        return allocation_.memory.map(allocation_.offset, allocation_.size);
    }

    
    /**
        Unmaps the buffer, decreasing the internal mapping
        reference count.
    */
    override void unmap() {
        if (!allocation_.memory)
            return;
        
        if (!allocation_.memory.isCoherent)
            allocation_.memory.flush();

        if (allocation_.memory.isMappable)
            allocation_.memory.unmap();
    }

    /**
        Uploads data to the buffer.
        
        Note:
            Depending on the implementation this may be done during 
            the next frame in an internal staging buffer.

        Params:
            data =      The data to upload.
            offset =    Offset into the buffer to upload the data.
    */
    override NioBuffer upload(void[] data, size_t offset) {
        import nulib.math : min;

        if (allocation_.memory && allocation_.memory.isMappable) {
            if (void[] mapped = this.map()) {
                size_t start = min(offset, mapped.length);
                size_t end = min(offset+data.length, mapped.length);
                size_t srcEnd = min(data.length, end-start);
                
                mapped[start..end] = data[0..srcEnd];

                this.unmap();
            }
        } else {
            (cast(NioVkDevice)device).uploadDataToBuffer(this, offset, data);
        }
        return this;
    }

    /**
        Downloads data from a buffer.
        
        Params:
            offset =    Offset into the buffer to download from.
            length =    Length of data to download, in bytes.
        
        Returns:
            A nogc slice of data on success,
            $(D null) otherwise.
    */
    override void[] download(size_t offset, size_t length) {
        import nulib.math : min;
        
        if (allocation_.memory && allocation_.memory.isMappable) {
            if (void[] mapped = this.map()) {
                size_t start = min(offset, mapped.length);
                size_t end = min(offset+length, mapped.length);

                auto result = mapped[start..end].nu_dup();
                this.unmap();
                return result;
            }
        } else {
            return (cast(NioVkDevice)device).downloadDataFromBuffer(this, offset, length);
        }
        return null;
    }
}

/**
    Converts a $(D NioIndexType) type to its $(D VkIndexType) equivalent.

    Params:
        value = The $(D NioIndexType)
    
    Returns:
        The $(D VkIndexType) equivalent.
*/
pragma(inline, true)
VkIndexType toVkIndexType(NioIndexType value) @nogc {
    final switch(value) with(NioIndexType) {
        case u16:  return VK_INDEX_TYPE_UINT16;
        case u32:  return VK_INDEX_TYPE_UINT32;
    }
}

/**
    Converts a $(D NioBufferUsage) bitmask to its $(D VkBufferUsageFlags) equivalent.

    Params:
        usage = The $(D NioBufferUsage)
    
    Returns:
        The $(D VkBufferUsageFlags) equivalent.
*/
pragma(inline, true)
VkBufferUsageFlags toVkBufferUsage(NioBufferUsage usage) @nogc {
    VkBufferUsageFlags result = 0;
    if (usage & NioBufferUsage.transfer)
        result |= VK_BUFFER_USAGE_TRANSFER_SRC_BIT | VK_BUFFER_USAGE_TRANSFER_DST_BIT;
        
    if (usage & NioBufferUsage.uniformBuffer)
        result |= VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT;

    if (usage & NioBufferUsage.storageBuffer)
        result |= VK_BUFFER_USAGE_STORAGE_BUFFER_BIT;

    if (usage & NioBufferUsage.indexBuffer)
        result |= VK_BUFFER_USAGE_INDEX_BUFFER_BIT;

    if (usage & NioBufferUsage.vertexBuffer)
        result |= VK_BUFFER_USAGE_VERTEX_BUFFER_BIT;

    if (usage & NioBufferUsage.videoDecode)
        result |= VK_BUFFER_USAGE_VIDEO_DECODE_SRC_BIT_KHR | VK_BUFFER_USAGE_VIDEO_DECODE_DST_BIT_KHR;

    if (usage & NioBufferUsage.videoEncode)
        result |= VK_BUFFER_USAGE_VIDEO_ENCODE_SRC_BIT_KHR | VK_BUFFER_USAGE_VIDEO_ENCODE_DST_BIT_KHR;

    return result;
}