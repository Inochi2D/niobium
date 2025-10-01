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
import niobium.device;
import niobium.cmd;

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

    /**
        Called when the label has been changed.

        Params:
            label = The new label of the device.
    */
    override void onLabelChanged(string label) {
        
    }

public:

    /**
        Fetches a $(D NioCommandBuffer) from the queue,
        the queue may contain an internal pool of command buffers.
    */
    abstract NioCommandBuffer fetch();

    /**
        Commits a single command buffer onto the queue.
        
        Params:
            buffer = The buffer to enqueue.
    */
    abstract void commit(NioCommandBuffer buffer);

    /**
        Commits a slice of command buffers into the queue.

        Params:
            buffers = The buffers to enqueue.
    */
    abstract void commit(NioCommandBuffer[] buffers);
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