/**
    Niobium Buffers
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module niobium.vk.buffer;
import niobium.vk.device;
import niobium.vk.heap;
import niobium.buffer;
import niobium.resource;
import niobium.device;
import vulkan.core;
import vulkan.eh;
import numem;

/**
    Vulkan Buffer
*/
class NioVkBuffer : NioBuffer {
private:
@nogc:
    NioAllocator allocator_;
    NioAllocation allocation_;
    VkBuffer handle_;

    NioBufferDescriptor desc_;
    VkBufferCreateInfo vkdesc_;

    void createBuffer(NioBufferDescriptor desc) {
        auto nvkDevice = (cast(NioVkDevice)device);
        
        this.desc_ = desc;
        this.vkdesc_ = VkBufferCreateInfo(
            size: desc.length,
            usage: desc.usage.toVkBufferUsage(),
            sharingMode: VK_SHARING_MODE_EXCLUSIVE
        );
        vkEnforce(vkCreateBuffer(nvkDevice.vkDevice, &vkdesc_, null, &handle_));

        // Allocate memory for our texture.
        VkMemoryRequirements vkmemreq_;
        vkGetBufferMemoryRequirements(nvkDevice.vkDevice, handle_, &vkmemreq_);

        VkMemoryAllocateFlags flags = desc.storage.toVkMemoryProperties();
        ptrdiff_t type = allocator_.getTypeForMasked(flags, vkmemreq_.memoryTypeBits);
        if (type >= 0) {
            allocation_ = allocator_.malloc(vkmemreq_.size, cast(uint)type);
            if (allocation_.memory) {
                vkBindBufferMemory(
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
        vkDevice.setDebugName(VK_OBJECT_TYPE_BUFFER, handle_, label);
    }

public:

    /// Destructor
    ~this() {
        auto vkDevice = (cast(NioVkDevice)device).vkDevice;
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
        if (allocation_.memory)
            return allocation_.memory.map(allocation_.size, allocation_.offset);
        return null;
    }

    
    /**
        Unmaps the buffer, decreasing the internal mapping
        reference count.
    */
    override void unmap() {
        if (allocation_.memory)
            return allocation_.memory.unmap();
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
    override void upload(void[] data, size_t offset) {
        import nulib.math : min;

        if (allocation_.memory && allocation_.memory.isMappable) {
            void[] mapped = this.map();
                size_t start = min(offset, mapped.length);
                size_t end = min(offset+data.length, mapped.length);
                size_t srcEnd = mapped.length-end;
                mapped[start..end] = data[0..srcEnd];
            this.unmap();
        }
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