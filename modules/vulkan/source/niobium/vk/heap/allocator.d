/**
    Niobium Memory Managment for Vulkan
    
    Inspired by work from this article:
    https://kylehalladay.com/blog/tutorial/2017/12/13/Custom-Allocators-Vulkan.html

    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module niobium.vk.heap.allocator;
import niobium.vk.heap.memory;
import niobium.resource;
import niobium.texture;
import niobium.heap;
import niobium.buffer;
import niobium.device;
import vulkan.core;
import vulkan.eh;
import numem;
import nulib;
import nulib.threading.mutex;
import nulib.math : min, max;

/**
    Memory allocator.
*/
abstract
class NioAllocator : NuObject {
private:
@nogc:
    VkPhysicalDevice physicalDevice;
    VkDevice device;

protected:

    /**
        Memory properties.
    */
    VkPhysicalDeviceMemoryProperties memoryProperties;

    /**
        Device properties.
    */
    VkPhysicalDeviceProperties deviceProperties;

    /**
        Constructs a new allocator.
    */
    this(VkPhysicalDevice physicalDevice, VkDevice device) {
        this.physicalDevice = physicalDevice;
        this.device = device;

        vkGetPhysicalDeviceMemoryProperties(physicalDevice, &memoryProperties);
        vkGetPhysicalDeviceProperties(physicalDevice, &deviceProperties);
    }

    /**
        Gets the type index for the givan vulkan 
        memory property flags.

        Params:
            flags = The vulkan property flags
        
        Returns:
            A positive index on success,
            $(D -1) on failure.
    */
    ptrdiff_t getMemoryTypeIndexFor(VkMemoryPropertyFlags flags) {
        foreach(i; 0..memoryProperties.memoryTypeCount) {
            auto devProps = memoryProperties.memoryTypes[i];
            if ((flags & devProps.propertyFlags) == flags)
                return i;
        }
        return -1;
    }

    /**
        Gets the type index for the givan vulkan 
        memory property flags.

        Params:
            flags = The vulkan property flags
        
        Returns:
            A positive index on success,
            $(D -1) on failure.
    */
    ptrdiff_t getMemoryHeapIndexFor(VkMemoryPropertyFlags flags) {
        foreach(i; 0..memoryProperties.memoryTypeCount) {
            auto devProps = memoryProperties.memoryTypes[i];
            if ((flags & devProps.propertyFlags) == flags)
                return devProps.heapIndex;
        }
        return -1;
    }

public:

    /**
        Number of active allocations.
    */
    abstract @property uint count();

    /**
        The total amount of bytes currently held by the allocator.
    */
    abstract @property VkDeviceSize size();

    /**
        Gets the first memory type available which supports the
        given allocation flags.

        Params:
            flags = The vulkan memory allocation flags
        
        Returns:
            A positive integer on success,
            $(D -1) on failure.
    */
    final ptrdiff_t getTypeFor(VkMemoryAllocateFlags flags) {
        return this.getMemoryTypeIndexFor(flags);
    }

    /**
        Searches through all of the memory to find a type that
        fits the given flags and returns it.

        Params:
            flags = The vulkan memory allocation flags
            mask =  The VkMemoryRequirements type mask.
    */
    final ptrdiff_t getTypeForMasked(VkMemoryAllocateFlags flags, uint mask) {
        foreach(i; 0..memoryProperties.memoryTypeCount) {
            if (((mask >> i) & 1) && memoryProperties.memoryTypes[i].propertyFlags & flags) {
                return i;
            }
        }
        return -1;
    }

    /**
        Creates a new allocation of the specified size.

        Params:
            size = The size of the allocation.
            type = The type of the allocation.
        
        Returns:
            A new allocation, or a empty allocation on failure.
    */
    abstract NioAllocation malloc(VkDeviceSize size, uint type);

    /**
        Frees the given allocation.

        Params:
            obj = The NioAllocation object to free.
    */
    abstract void free(ref NioAllocation obj);
}

/**
    A memory allocation.
*/
struct NioAllocation {
@nogc:
    
    /**
        Underlying memory object.
    */
    NioDeviceMemory memory;

    /**
        Offset of the allocation
    */
    VkDeviceSize offset;

    /**
        Size of the allocation
    */
    VkDeviceSize size;

    /**
        Memory-pool internal ID.
    */
    uint poolId;
}

/**
    Descriptor used to make a pool allocator.
*/
struct NioPoolAllocatorDescriptor {

    /**
        Size of the heap in bytes.

        Note:
            The size of the heap will be aligned up to the closest
            page.
    */
    uint size;

    /**
        The size of a page in the heap.
        
        Default:
            Defaults to 16 kilobytes.
    */
    uint pageSize = 16_384;
}

/**
    An allocator that uses bigger memory pools to allocate from.
*/
class NioPoolAllocator : NioAllocator {
private:
@nogc:
    Mutex                       mutex_;
    NioPoolAllocatorDescriptor  desc_;
    MemoryPool[]                pools;
    VkDeviceSize[]              allocated;
    VkDeviceSize                allocatedTotal;
    uint                        allocCount;

    VkDeviceSize                pageSize;
    VkDeviceSize                blockMinSize;

    // Index within block
    struct SpanIndex { ptrdiff_t blockIdx = -1; ptrdiff_t spanIdx = -1; }
    struct Span { size_t offset; size_t length; }

    // A memory block
    struct MemoryBlock {
        NioDeviceMemory memory;
        Span[] layout;
    }

    // A memory pool
    struct MemoryPool {
        MemoryBlock[] blocks;
    }

    // Tries to find a free memory chunk.
    SpanIndex findFreeChunk(uint type, VkDeviceSize size, bool requireAligned) {
        if (type >= pools.length)
            return SpanIndex(-1, -1);
        
        auto pool = pools[type];
        foreach(i, ref block; pool.blocks) {
            foreach(j, ref span; block.layout) {
                bool isValidOffset = requireAligned ? span.offset == 0 : true;
                if (span.length >= size && isValidOffset) {
                    return SpanIndex(i, j);
                }
            }
        }
        return SpanIndex(-1, -1);
    }

    // Takes ownership of a chunk by reducing its allocated size.
    void claimChunk(SpanIndex index, uint type, VkDeviceSize size) {

        if (type >= pools.length)
            return;
        
        pools[type].blocks[index.blockIdx].layout[index.spanIdx].offset += size;
        pools[type].blocks[index.blockIdx].layout[index.spanIdx].length -= size;
    }

    // Adds a new block to the pool.
    ptrdiff_t addBlock(VkDeviceSize size, uint type) {
        if (type >= pools.length)
            return -1;

        import std.stdio : writeln;


        // Allocate new block.
        auto newBlock = MemoryBlock(
            memory: nogc_new!NioDeviceMemory(device, NioDeviceMemoryDescriptor(
                max(size * 2, blockMinSize),
                type,
                memoryProperties.memoryTypes[type].propertyFlags
            )),
            layout: nu_malloca!Span(1)
        );
        newBlock.layout[0] = Span(0, newBlock.memory.size);

        auto front = pools[type].blocks.length;
        pools[type].blocks = pools[type].blocks.nu_resize(front+1);
        pools[type].blocks[$-1] = newBlock;
        allocCount++;

        debug writeln("addBlock: ", size, " ", type, " front=", front);
        return front;
    }

public:

    /// Destructor
    ~this() {
        foreach(ref pool; pools) {
            foreach_reverse(ref block; pool.blocks) {
                block.memory.release();
                nu_freea(block.layout);
            }
            nu_freea(pool.blocks);
        }
        nu_freea(pools);
    }

    /**
        Constructs a new allocator.
    */
    this(VkPhysicalDevice physicalDevice, VkDevice device, NioPoolAllocatorDescriptor desc) {
        super(physicalDevice, device);
        this.desc_ = desc;

        // Allocate a pool for every memory type.
        this.pools = nu_malloca!MemoryPool(this.memoryProperties.memoryTypeCount);
        this.allocated = nu_malloca!VkDeviceSize(this.memoryProperties.memoryTypeCount);

        // Page size must be a multiple of the bufferImageGranularity.
        auto granularity = deviceProperties.limits.bufferImageGranularity;
        this.pageSize = max(desc.pageSize, granularity).alignTo(granularity);
        this.blockMinSize = desc.size.alignTo(pageSize);
        this.mutex_ = nogc_new!Mutex();
    }

    /**
        Number of active allocations.
    */
    override @property uint count() => allocCount;

    /**
        The total amount of bytes currently held by the allocator.
    */
    override @property VkDeviceSize size() => allocatedTotal;

    /**
        Creates a new allocation of the specified size.

        Params:
            size = The size of the allocation.
            type = The type of the allocation.
        
        Returns:
            A new allocation, or a empty allocation on failure.
    */
    override NioAllocation malloc(VkDeviceSize size, uint type) {
        if (type >= memoryProperties.memoryTypeCount)
            return NioAllocation.init;

        // Ensure the pool doesn't get changed from multiple threads at once.
        mutex_.lock();
        scope(exit) mutex_.unlock();

        auto flags = memoryProperties.memoryTypes[type].propertyFlags;

        // Get allocation size
        VkDeviceSize reqSize = size + (size % pageSize);
        auto idx = this.findFreeChunk(type, size, !(flags & VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT));
        if (idx.blockIdx < 0) {
            
            idx.spanIdx = 0;
            idx.blockIdx = this.addBlock(size, type);
            if (idx.blockIdx < 0)
                return NioAllocation.init;
        }
        
        this.allocated[type] += reqSize;
        this.claimChunk(idx, type, reqSize);
        return NioAllocation(
            memory: pools[type].blocks[idx.blockIdx].memory,
            offset: pools[type].blocks[idx.blockIdx].layout[idx.spanIdx].offset,
            size: size,
            poolId: cast(uint)idx.blockIdx
        );
    }

    /**
        Frees the given allocation.

        Params:
            obj = The NioAllocation object to free.
    */
    override void free(ref NioAllocation obj) {
        assert(obj.memory.type < memoryProperties.memoryTypeCount, "Invalid memory type!");

        if (obj.memory.type >= memoryProperties.memoryTypeCount)
            return;

        // Ensure the pool doesn't get changed from multiple threads at once.
        mutex_.lock();
        scope(exit) mutex_.unlock();

        auto pool = pools[obj.memory.type];
        VkDeviceSize reqSize = size + (size % pageSize);

        Span span = Span(obj.offset, reqSize);

        // try to find the memory if possible.
        bool found;
        foreach(i, ref layout; pool.blocks[obj.poolId].layout) {
            if (layout.offset == reqSize + obj.offset) {
                layout.offset = obj.offset;
                layout.length += reqSize;
                found = true;
                break;
            }
        }

        if (!found) {
            auto layoutSize = pool.blocks[obj.poolId].layout.length;
            pool.blocks[obj.poolId].layout = pool.blocks[obj.poolId].layout.nu_resize(layoutSize+1);
            pool.blocks[obj.poolId].layout[$-1] = span;
            this.allocated[obj.memory.type] -= reqSize;
        }
    }
}

/**
    Converts a $(D NioStorageMode) to its $(D VkMemoryPropertyFlags)
    equvialent.

    Params:
        mode = The $(D NioStorageMode)
    
    Returns:
        The $(D VkMemoryPropertyFlags) equvialent.
*/
pragma(inline, true)
VkMemoryPropertyFlags toVkMemoryProperties(NioStorageMode mode) @nogc {
    final switch(mode) with(NioStorageMode) {
        case sharedStorage:     return VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT;
        case managedStorage:    return VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_CACHED_BIT;
        case privateStorage:    return VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT;
    }
}