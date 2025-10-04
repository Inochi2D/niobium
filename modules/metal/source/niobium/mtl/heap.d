/**
    Niobium Metal Heaps
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module niobium.mtl.heap;
import niobium.mtl.device;
import niobium.mtl.resource;
import metal.resource;
import metal.device;
import metal.heap;
import foundation;

public import niobium.heap;

/**
    A heap which can suballocate resources from itself.
*/
class NioMTLHeap : NioHeap {
private:
@nogc:
    NioHeapDescriptor desc_;
    MTLHeap handle_;

    void setup(NioHeapDescriptor desc) {
        auto nmtlDevice = cast(NioMTLDevice)device;

        this.desc_ = desc;
        MTLHeapDescriptor createInfo = MTLHeapDescriptor.alloc.init();
        createInfo.size = cast(NSUInteger)desc.size;
        createInfo.storageMode = desc.storageMode.toMTLStorageMode();
        this.handle_ = nmtlDevice.handle.newHeap(createInfo);
        createInfo.release();
    }

public:

    /**
        Size of the resource in bytes.
    */
    override @property uint size() => cast(uint)desc_.size;

    /**
        Storage mode of the resource.
    */
    override @property NioStorageMode storageMode() => desc_.storageMode;

    /// Destructor
    ~this() {
        handle_.release();
    }

    /**
        Constructs a new heap.

        Params:
            device =    The device that "owns" this heap.
            desc =      Descriptor used to make the heap.
    */
    this(NioDevice device, NioHeapDescriptor desc) {
        super(device);
        this.setup(desc);
    }

    /**
        Creates a new texture.

        Params:
            descriptor = Descriptor for the texture.
        
        Returns:
            A new $(D NioTexture) or $(D null) on failure.
    */
    override NioTexture createTexture(NioTextureDescriptor descriptor) {
        return null;
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

/**
    Converts a $(D MTLDeviceLocation) bitmask to its $(D NioDeviceType) equivalent.

    Params:
        usage = The $(D MTLDeviceLocation)
    
    Returns:
        The $(D NioDeviceType) equivalent.
*/
pragma(inline, true)
MTLStorageMode toMTLStorageMode(NioStorageMode mode) @nogc {
    final switch(mode) with(NioStorageMode) {
        case sharedStorage:     return MTLStorageMode.Shared;
        case managedStorage:    return MTLStorageMode.Managed;
        case privateStorage:    return MTLStorageMode.Private;
    }
}

/**
    Converts a $(D MTLDeviceLocation) bitmask to its $(D NioDeviceType) equivalent.

    Params:
        usage = The $(D MTLDeviceLocation)
    
    Returns:
        The $(D NioDeviceType) equivalent.
*/
pragma(inline, true)
NioStorageMode toNioStorageMode(MTLStorageMode mode) @nogc {
    switch(mode) with(MTLStorageMode) {
        default:         return NioStorageMode.privateStorage;
        case Shared:     return NioStorageMode.sharedStorage;
        case Managed:    return NioStorageMode.managedStorage;
        case Private:    return NioStorageMode.privateStorage;
    }
}