/**
    Niobium Vulkan Command Queues
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module niobium.vk.queue;
import niobium.device;
import niobium.queue;
import niobium.cmd;
import vulkan.core;
import numem;
import nulib;

/**
    Represents an individual queue for command submission on the device.
*/
class NioVkCommandQueue : NioCommandQueue {
private:
@nogc:
    VkQueue handle_;

public:

    /**
        Constructs a new queue.

        Params:
            device = The device that "owns" this queue.
            handle = Vulkan handle 
    */
    this(NioDevice device, VkQueue handle) {
        super(device);
        this.handle_ = handle;
    }

    /**
        Fetches a $(D NioCommandBuffer) from the queue,
        the queue may contain an internal pool of command buffers.
    */
    override NioCommandBuffer fetch() {
        return null;
    }

    /**
        Commits a single command buffer onto the queue.
        
        Params:
            buffer = The buffer to enqueue.
    */
    override void commit(NioCommandBuffer buffer) {

    }

    /**
        Commits a slice of command buffers into the queue.

        Params:
            buffers = The buffers to enqueue.
    */
    override void commit(NioCommandBuffer[] buffers) {

    }
}

/**
    A queue for encoding video.
*/
class NioVkVideoEncodeQueue : NioVideoEncodeQueue {
private:
@nogc:
    VkQueue handle_;

public:

    /**
        Constructs a new queue.

        Params:
            device = The device that "owns" this queue.
            handle = Vulkan handle 
    */
    this(NioDevice device, VkQueue handle) {
        super(device);
        this.handle_ = handle;
    }

}

/**
    A queue for decoding video.
*/
class NioVkVideoDecodeQueue : NioVideoDecodeQueue {
private:
@nogc:
    VkQueue handle_;

public:

    /**
        Constructs a new queue.

        Params:
            device = The device that "owns" this queue.
            handle = Vulkan handle 
    */
    this(NioDevice device, VkQueue handle) {
        super(device);
        this.handle_ = handle;
    }
    
}