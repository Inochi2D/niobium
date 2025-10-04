/**
    Niobium Vulkan Semaphores
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module niobium.mtl.sync.semaphore;
import niobium.mtl.device;
import metal.event;
import foundation;
import numem;

public import niobium.sync : NioSemaphore;

/**
    A GPU-local memory fence for tracking resource dependencies.
*/
class NioMTLSemaphore : NioSemaphore {
private:
@nogc:
    // Handles
    MTLSharedEvent handle_;

    void setup() {
        auto mtlDevice = cast(NioMTLDevice)device;
        this.handle_ = mtlDevice.handle.newSharedEvent();
    }

protected:

    /**
        Called when the label has been changed.

        Params:
            label = The new label of the device.
    */
    override
    void onLabelChanged(string label) {
        if (handle_.label)
            handle_.label.release();
        
        handle_.label = NSString.create(label);
    }

public:

    /**
        The current value of the semaphore.
    */
    override @property ulong value() => handle_.signaledValue;

    /**
        The native metal handle.
    */
    @property MTLSharedEvent handle() => handle_;

    /// Destructor
    ~this() {
        handle_.release();
    }

    /**
        Creates a new $(D NioVkFence)
    */
    this(NioDevice device) {
        super(device);
        this.setup();
    }

    /**
        Signals the semaphore with the given value.

        Params:
            value = The value to signal with, must be greater 
                    than the current value.
        
        Returns:
            $(D true) if the operation succeeded,
            $(D false) otherwise.
    */
    override bool signal(ulong value) {
        if (value <= handle_.signaledValue)
            return false;
        
        handle_.signaledValue = value;
        return true;
    }

    /**
        Awaits the semaphore getting signalled.

        Params:
            value =     The value to wait for
            timeout =   The timeout for the wait in miliseconds.
        
        Returns:
            $(D true) if the semaphore reached the given value,
            $(D false) otherwise (eg. it timed out.)
    */
    override
    bool await(ulong value, ulong timeout) {
        return handle_.await(value, timeout);
    }
}