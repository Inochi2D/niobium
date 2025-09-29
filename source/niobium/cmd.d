/**
    Niobium Command Buffers.
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module niobium.cmd;
import niobium.queue;
import niobium.device;

/**
    An ephemeral command buffer that commands get recorded into.
*/
abstract
class NioCommandBuffer : NioDeviceObject {
protected:
@nogc:

    /**
        Constructs a new command buffer.

        Params:
            device = The device that "owns" this command buffer.
    */
    this(NioDevice device) {
        super(device);
    }

public:

}