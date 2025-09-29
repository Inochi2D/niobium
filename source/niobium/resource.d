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
import numem;

enum NioStorageMode : uint {
    
    /**
        The resource is shared between CPU and GPU.
    */
    sharedStorage = 0x01,

    /**
        The resource is stored seperated on the CPU and GPU,
        changes must be synchronized between them.
    */
    managedStorage = 0x02,

    /**
        The resource is stored on the GPU and can't be
        directly interacted with from the CPU.
    */
    privateStorage = 0x03
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
        Storage mode of the resource.
    */
    abstract @property NioStorageMode storageMode();

    /**
        Size of the resource in bytes.
    */
    abstract @property uint size();

    /**
        Alignment of the resource in bytes.
    */
    abstract @property uint alignment();
}