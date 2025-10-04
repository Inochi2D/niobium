/**
    Niobium Metal Fences
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module niobium.mtl.sync.fence;
import niobium.mtl.device;
import metal.fence;
import foundation;
import numem;

public import niobium.sync : NioFence;

/**
    A GPU-local memory fence for tracking resource dependencies.
*/
class NioMTLFence : NioFence {
private:
@nogc:
    // Handles
    MTLFence handle_;

    void setup() {
        auto mtlDevice = cast(NioMTLDevice)device;
        this.handle_ = mtlDevice.handle.newFence();
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
        The native metal handle.
    */
    @property MTLFence handle() => handle_;

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
}