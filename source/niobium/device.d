/**
    Niobium Device Interface
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module niobium.device;
import numem;

/**
    A device which is capable of doing 3D rendering and/or
    GPGPU computations.
*/
abstract
class NioDevice : NuRefCounted {
public:
@nogc:

    /**
        Gets the devices in the system

        Returns:
            An array owned by niobium containing all
            of the devices supported by the API.
    */
    static @property NioDevice[] systemDevices() {
        return __nio_enumerate_devices();
    }

    /**
        Name of the device.
    */
    abstract @property string name();

    /**
        Type of the device.
    */
    abstract @property NioDeviceType type();

    /**
        The native underlying handle of the object.
    */
    abstract @property void* handle();
}

/**
    An object which belongs to a device.
*/
abstract
class NioDeviceObject : NuRefCounted {
private:
@nogc:
    NioDevice device_;

protected:

    /**
        Constructs a new device object.

        Params:
            device = The device that "owns" this object.
    */
    this(NioDevice device) {
        this.device_ = device;
    }

public:

    /**
        The device that created this object.
    */
    final @property NioDevice device() => device_;
}

/**
    A Niobium Device Type
*/
enum NioDeviceType : uint {
    
    /**
        Device type is unknown.
    */
    unknown,

    /**
        Integrated GPU.
    */
    iGPU,
    
    /**
        Dedicated GPU.
    */
    dGPU,
    
    /**
        Virtual GPU.
    */
    vGPU,
    
    /**
        CPU
    */
    cpu
}

/**
    Converts a $(D NioDeviceType) to a $(D string).

    Params:
        type = The device type.

    Returns:
        $(D string) representation of $(D NioDeviceType)
*/
pragma(inline, true)
string toString(NioDeviceType type) @nogc {
    final switch(type) {
        case NioDeviceType.unknown:
            return "Unknown";
        case NioDeviceType.iGPU:
            return "Integrated GPU";
        case NioDeviceType.dGPU:
            return "Dedicated GPU";
        case NioDeviceType.vGPU:
            return "Virtual GPU";
        case NioDeviceType.cpu:
            return "CPU";
    }
}

//
//          IMPLEMENTATION DETAILS
//
private extern(C):
    
/**
    The devices available on the system.
*/
extern extern(C) @property NioDevice[] __nio_enumerate_devices() @nogc;