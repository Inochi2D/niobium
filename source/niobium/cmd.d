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
import niobium.surface;

/**
    A buffer of commands which can be sent to the GPU
    for processing.

    Note:
        Submitting a command buffer will invalidate it,
        this means that you cannot modify its state any
        longer. Once submitted it's safe to $(D release)
        the command buffer.
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

    /**
        Enqueues a presentation to happen after this
        command buffer finishes execution.

        Params:
            drawable = The drawable to present.
    */
    abstract void present(NioDrawable drawable);

    /**
        Submits the command buffer to its queue.

        After submitting a command buffer you cannot
        modify it any further, not upload it to any other
        queues.
    */
    abstract void submit();
}