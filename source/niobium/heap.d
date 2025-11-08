/**
    Niobium Heaps
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module niobium.heap;
import niobium.resource;
import niobium.texture;
import niobium.buffer;
import niobium.device;

/**
    Describes the creation parameters of a $(D NioHeap).
*/
struct NioHeapDescriptor {
@nogc:
    
    /**
        Storage mode of the heap, inherited by all objects
        created from it.
    */
    NioStorageMode storageMode;

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
    A heap which can suballocate resources from itself.
*/
abstract
class NioHeap : NioResource {
protected:
@nogc:

    /**
        Constructs a new heap.

        Params:
            device = The device that "owns" this heap.
    */
    this(NioDevice device) {
        super(device);
    }

public:

    /**
        Creates a new texture.

        Params:
            descriptor = Descriptor for the texture.
        
        Returns:
            A new $(D NioTexture) or $(D null) on failure.
    */
    abstract NioTexture createTexture(NioTextureDescriptor descriptor);

    /**
        Creates a new texture at a specified byte offset in the heap.

        Params:
            descriptor =    Descriptor for the texture.
            offset =        The offset into the heap in bytes
        
        Returns:
            A new $(D NioTexture) or $(D null) on failure.
    */
    abstract NioTexture createTextureAtOffset(NioTextureDescriptor descriptor, size_t offset);

    /**
        Creates a new buffer.

        Params:
            descriptor = Descriptor for the buffer.
        
        Returns:
            A new $(D NioBuffer) or $(D null) on failure.
    */
    abstract NioBuffer createBuffer(NioBufferDescriptor descriptor);

    /**
        Creates a new buffer at a specified byte offset in the heap.

        Params:
            descriptor =    Descriptor for the buffer.
            offset =        The offset into the heap in bytes
        
        Returns:
            A new $(D NioBuffer) or $(D null) on failure.
    */
    abstract NioBuffer createBufferAtOffset(NioBufferDescriptor descriptor, size_t offset);
}