/**
    Niobium Memory Objects

    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module niobium.vk.heap.memory;
import niobium.vk.heap.allocator;
import vulkan.core;
import vulkan.eh;
import numem;
import nulib;
import nulib.math : min, max;

struct NioDeviceMemoryDescriptor {
    VkDeviceSize size;
    uint type;
    VkMemoryPropertyFlags flags;
}

/**
    Device memory created from an allocator.
*/
final
class NioDeviceMemory : NuRefCounted {
private:
@nogc:
    VkDevice                    device_;
    VkDeviceMemory              handle_;
    NioDeviceMemoryDescriptor   desc_;

    // Mapping.
    void[]                      mapped_;
    uint                        mapCount_;

public:

    /// Destructor
    ~this() {
        vkFreeMemory(device_, handle_, null);
        this.handle_ = null;
    }

    /**
        Creates a new memory object.

        Params:
            device =    The device to create the memory for.
            desc =      Descriptor used to crate the memory.
    */
    this(VkDevice device, NioDeviceMemoryDescriptor desc) {
        this.device_ = device;
        this.desc_ = desc;

        auto createInfo = VkMemoryAllocateInfo(
            allocationSize: desc.size,
            memoryTypeIndex: desc.type
        );
        vkEnforce(vkAllocateMemory(device_, &createInfo, null, &handle_));
    }

    /**
        Creates a new memory object.

        Params:
            device =    The device to create the memory for.
            desc =      Descriptor used to crate the memory.
    */
    this(VkDevice device, VkMemoryAllocateInfo allocInfo) {
        this.device_ = device;
        this.desc_ = NioDeviceMemoryDescriptor(
            size: allocInfo.allocationSize,
            type: allocInfo.memoryTypeIndex
        );

        auto createInfo = allocInfo;
        vkEnforce(vkAllocateMemory(device_, &createInfo, null, &handle_));
    }

    /**
        Vulkan Handle to the memory.
    */
    @property VkDeviceMemory handle() => handle_;

    /**
        Size of the memory allocation.
    */
    @property VkDeviceSize size() => desc_.size;

    /**
        Type index of the memory.
    */
    @property uint type() => desc_.type;

    /**
        Usage flags of the memory.
    */
    @property VkMemoryPropertyFlags flags() => desc_.flags;

    /**
        Whether the memory can be mapped.
    */
    @property bool isMappable() => (desc_.flags & VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT) != 0;

    /**
        Whether the memory allocated is coherent.
    */
    @property bool isCoherent() => (desc_.flags & VK_MEMORY_PROPERTY_HOST_COHERENT_BIT) != 0;

    /**
        Maps the device memory.

        Params:
            offset =    Offset into the device memory to map.
            length =    Length into the memory to map.
        
        Returns:
            The mapped region or $(D null) if the memory can't
            be mapped.
    */
    void[] map(size_t offset, size_t length) {
        if (!this.isMappable)
            return null;

        if (++mapCount_ == 1) {
            void* map_;
            vkMapMemory(device_, handle_, 0, desc_.size, 0, &map_);
            mapped_ = map_[0..desc_.size];
        }
        return mapped_[offset..offset+length];
    }

    /**
        Unmaps the device memory.
    */
    void unmap() {
        if (!this.isMappable)
            return;
        
        if (--mapCount_ == 0) {
            vkUnmapMemory(device_, handle_);
            mapped_ = null;
        }
    }

    /**
        Flushes the memory.
    */
    void flush() {
        
        // No need to flush coherent memory.
        if (this.isCoherent)
            return;

        if (mapCount_ > 0) {
            auto mapInfo = VkMappedMemoryRange(
                memory: handle_,
                offset: 0,
                size: desc_.size
            );
            vkEnforce(vkFlushMappedMemoryRanges(device_, 1, &mapInfo));
        }
    }
}