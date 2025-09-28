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
        Size of the resource in bytes.
    */
    abstract @property uint size();

    /**
        Alignment of the resource in bytes.
    */
    abstract @property uint alignment();
}