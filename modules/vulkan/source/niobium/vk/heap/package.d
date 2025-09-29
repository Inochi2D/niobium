/**
    Niobium Vulkan Heaps
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module niobium.vk.heap;
import niobium.vk.device;
import niobium.vk.texture;
import niobium.resource;
import niobium.texture;
import niobium.heap;
import niobium.buffer;
import niobium.device;
import vulkan.core;
import vulkan.eh;
import numem;

public import niobium.vk.heap.allocator;
public import niobium.vk.heap.memory;

/**
    A heap which can suballocate resources from itself.
*/
class NioVkHeap : NioHeap {
private:
@nogc:
    NioHeapDescriptor desc_;
    NioAllocator allocator;

public:

    /**
        Size of the resource in bytes.
    */
    override @property uint size() => cast(uint)allocator.size;

    /**
        Storage mode of the resource.
    */
    override @property NioStorageMode storageMode() => desc_.storageMode;

    /// Destructor
    ~this() {
        nogc_delete(allocator);
    }

    /**
        Constructs a new heap.

        Params:
            device =    The device that "owns" this heap.
            desc =      Descriptor used to make the heap.
    */
    this(NioDevice device, NioHeapDescriptor desc) {
        super(device);
        auto nvkDevice = cast(NioVkDevice)device;

        this.desc_ = desc;
        this.allocator = nogc_new!NioPoolAllocator(
            nvkDevice.vkPhysicalDevice, 
            nvkDevice.vkDevice, 
            NioPoolAllocatorDescriptor(
                size: desc.size,
                pageSize: desc.pageSize
            )
        );
    }

    /**
        Creates a new texture.

        Params:
            descriptor = Descriptor for the texture.
        
        Returns:
            A new $(D NioTexture) or $(D null) on failure.
    */
    override NioTexture createTexture(NioTextureDescriptor descriptor) {
        descriptor.storage = desc_.storageMode;
        return nogc_new!NioVkTexture(device, descriptor, allocator);
    }

    /**
        Creates a new texture at a specified byte offset in the heap.

        Params:
            descriptor =    Descriptor for the texture.
            offset =        The offset into the heap in bytes
        
        Returns:
            A new $(D NioTexture) or $(D null) on failure.
    */
    override NioTexture createTextureAtOffset(NioTextureDescriptor descriptor, size_t offset) {
        return null;
    }

    /**
        Creates a new buffer.

        Params:
            descriptor = Descriptor for the buffer.
        
        Returns:
            A new $(D NioBuffer) or $(D null) on failure.
    */
    override NioBuffer createBuffer(NioBufferDescriptor descriptor) {
        return null;
    }

    /**
        Creates a new buffer at a specified byte offset in the heap.

        Params:
            descriptor =    Descriptor for the buffer.
            offset =        The offset into the heap in bytes
        
        Returns:
            A new $(D NioBuffer) or $(D null) on failure.
    */
    override NioBuffer createBufferAtOffset(NioBufferDescriptor descriptor, size_t offset) {
        return null;
    }
}