/**
    Niobium Metal Command Queues
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module niobium.mtl.queue;
import niobium.mtl.surface;
import niobium.mtl.device;
import niobium.mtl.cmd;
import niobium.surface;
import niobium.device;
import niobium.queue;
import niobium.cmd;
import metal.commandqueue;
import metal.commandbuffer;
import foundation;
import numem;
import nulib;


/**
    Represents an individual queue for command submission on the device.
*/
class NioMTLCommandQueue : NioCommandQueue {
private:
@nogc:

    // Handles
    MTLCommandQueue handle_;

    void setup(NioMTLDevice device) {
        this.handle_ = device.handle.newCommandQueue();
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
    final @property MTLCommandQueue handle() => handle_;

    /// Destructor
    ~this() {
        handle_.release();
    }

    /**
        Creates a new command queue.
    */
    this(NioMTLDevice device) {
        super(device);
        this.setup(device);
    }

    /**
        Fetches a $(D NioCommandBuffer) from the queue,
        the queue may contain an internal pool of command buffers.
    */
    override NioCommandBuffer fetch() {
        return nogc_new!NioMTLCommandBuffer(device, this);
    }

    /**
        Submit a single command buffer onto the queue.
        
        Params:
            buffer = The buffer to enqueue.
    */
    override void submit(NioCommandBuffer buffer) {
        if (auto mtlcmdbuffer = cast(NioMTLCommandBuffer)buffer) {
            if (mtlcmdbuffer.handle.status != MTLCommandBufferStatus.NotEnqueued)
                return;
            
            mtlcmdbuffer.handle.commit();
        }
    }

    /**
        Submits a slice of command buffers into the queue.

        Params:
            buffers = The buffers to enqueue.
    */
    override void submit(NioCommandBuffer[] buffers) {
        foreach(buffer; buffers) {
            if (auto mtlcmdbuffer = cast(NioMTLCommandBuffer)buffer) {
                if (mtlcmdbuffer.handle.status != MTLCommandBufferStatus.NotEnqueued)
                    return;
                
                mtlcmdbuffer.handle.commit();
            }
        }
    }
}