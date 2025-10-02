/**
    Niobium Command Queues
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module niobium.queue;
import niobium.surface;
import niobium.device;
import niobium.cmd;

/**
    Information needed to create a command queue.
*/
struct NioCommandQueueDescriptor {
    
    /**
        The maximum amount of command buffers that can be "alive"
        at a time.
    */
    uint maxCommandBuffers = 64;
}

/**
    Represents an individual queue for command submission on the device.
*/
abstract
class NioCommandQueue : NioDeviceObject {
protected:
@nogc:

    /**
        Constructs a new queue.

        Params:
            device = The device that "owns" this queue.
    */
    this(NioDevice device) {
        super(device);
    }

public:

    /**
        Fetches a $(D NioCommandBuffer) from the queue,
        the queue may contain an internal pool of command buffers.
    */
    abstract NioCommandBuffer fetch();

    /**
        Submit a single command buffer onto the queue.
        
        Params:
            buffer = The buffer to enqueue.
    */
    abstract void submit(NioCommandBuffer buffer);

    /**
        Submits a slice of command buffers into the queue.

        Params:
            buffers = The buffers to enqueue.
    */
    abstract void submit(NioCommandBuffer[] buffers);
}

/**
    A queue for encoding video.
*/
abstract
class NioVideoEncodeQueue : NioDeviceObject {
protected:
@nogc:

    /**
        Constructs a new queue.

        Params:
            device = The device that "owns" this queue.
    */
    this(NioDevice device) {
        super(device);
    }

public:

}

/**
    A queue for decoding video.
*/
abstract
class NioVideoDecodeQueue : NioDeviceObject {
protected:
@nogc:

    /**
        Constructs a new queue.

        Params:
            device = The device that "owns" this queue.
    */
    this(NioDevice device) {
        super(device);
    }

public:

}