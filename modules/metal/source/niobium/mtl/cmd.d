/**
    Niobium Metal Command Buffers
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module niobium.mtl.cmd;
import niobium.mtl.queue;
import niobium.cmd;
import niobium.queue;
import niobium.device;
import niobium.surface;
import metal.commandbuffer;
import foundation;
import numem;
import nulib;
import niobium.mtl.surface;

/**
    A buffer of commands which can be sent to the GPU
    for processing.

    Note:
        Submitting a command buffer will invalidate it,
        this means that you cannot modify its state any
        longer. Once submitted it's safe to $(D release)
        the command buffer.
*/
class NioMTLCommandBuffer : NioCommandBuffer {
private:
@nogc:
    // State
    bool isRecording_ = true;

    // Handles
    MTLCommandBuffer handle_;

    void setup(NioMTLCommandQueue queue) {
        this.handle_ = queue.handle.commandBuffer();
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
        The underlying metal handle.
    */
    final @property MTLCommandBuffer handle() => handle_;

    /// Destructor
    ~this() {
        handle_.release();
    }

    /**
        Constructs a new command buffer.

        Params:
            device = The device that "owns" this command buffer.
    */
    this(NioDevice device, NioCommandQueue queue) {
        super(device, queue);
        this.setup(cast(NioMTLCommandQueue)queue);
    }

    /**
        Enqueues a presentation to happen after this
        command buffer finishes execution.

        Params:
            drawable = The drawable to present.
    */
    override void present(NioDrawable drawable) {
        if (!isRecording_)
            return;
        
        if (auto mtldrawable = cast(NioMTLDrawable)drawable) {
            if (mtldrawable.queue)
                return;
            
            mtldrawable.queue = this.queue;
            handle_.present(mtldrawable.handle);
        }
    }

    /**
        Submits the command buffer to its queue.

        After submitting a command buffer you cannot
        modify it any further, not upload it to any other
        queues.
    */
    override void submit() {
        if (!isRecording_) {
            this.isRecording_ = false;
            queue.submit(this);
        }
    }

    /**
        Awaits the completion of the command buffer
        execution.
    */
    override void await() {
        handle_.waitUntilCompleted();
    }
}