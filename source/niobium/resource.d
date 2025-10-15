/**
    Niobium Resources
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module niobium.resource;
import niobium.device;

/**
    Storage mode for the resource
*/
enum NioStorageMode : uint {
    
    /**
        The resource is shared between CPU and GPU.
    */
    sharedStorage   = 0x01,

    /**
        The resource is stored seperated on the CPU and GPU,
        changes must be synchronized between them.
    */
    managedStorage  = 0x02,

    /**
        The resource is stored on the GPU and can't be
        directly interacted with from the CPU.
    */
    privateStorage  = 0x03
}

/**
    Base class of all high level resources.
*/
abstract
class NioResource : NioDeviceObject {
protected:
@nogc:

    /**
        Constructs a new device object.

        Params:
            device = The device that "owns" this object.
    */
    this(NioDevice device) {
        super(device);
    }

public:

    /**
        Native backend handle of the resource
    */
    abstract @property void* handle();

    /**
        Storage mode of the resource.
    */
    abstract @property NioStorageMode storageMode();

    /**
        Size of the resource in bytes.
    */
    abstract @property uint size();
}

/**
    A handle to a shared resource, abstracting away the low level
    details of shared resources.
*/
abstract
class NioSharedResourceHandle : NioDeviceObject {
protected:
@nogc:

    /**
        Constructs a new resource handle.

        Params:
            device = The device that "owns" this object.
    */
    this(NioDevice device) {
        super(device);
    }

public:

    /**
        Creates a new shared resource handle from a system handle.

        Params:
            device =    The device which will be importing the handle.
            handle =    The underlying system handle to create a shared 
                        resource handle for.
    */
    static NioSharedResourceHandle createForHandle(NioDevice device, void* handle) @nogc {
        return nio_shared_resource_handle_create(device, handle);
    }

    /**
        The backend-specific handle for the foreign texture.
    */
    abstract @property void* handle();
}

//
//              IMPLEMENTATION DETAILS.
//
private extern(C):

/**
    Creates a new shared resource handle from a system handle.

    Params:
        device =    The device which will be importing the handle.
        handle =    The underlying system handle to create a shared 
                    resource handle for.
*/
extern extern(C) NioSharedResourceHandle nio_shared_resource_handle_create(NioDevice device, void* handle) @nogc;