/**
    Niobium Vulkan Video Queues
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module niobium.vk.video.queue;
import niobium.device;
import niobium.queue;
import vulkan.loader;
import vulkan.core;
import vulkan.eh;
import numem;
import nulib;

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