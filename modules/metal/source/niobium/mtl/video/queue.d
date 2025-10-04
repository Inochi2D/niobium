/**
    Niobium Metal Video Queues
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module niobium.mtl.video.queue;
import niobium.device;
import niobium.queue;
import numem;
import nulib;

/**
    A queue for encoding video.
*/
class NioVTKVideoEncodeQueue : NioVideoEncodeQueue {
private:
@nogc:

public:

    /**
        Constructs a new queue.

        Params:
            device = The device that "owns" this queue.
            handle = Vulkan handle 
    */
    this(NioDevice device) {
        super(device);
    }

}

/**
    A queue for decoding video.
*/
class NioVTKVideoDecodeQueue : NioVideoDecodeQueue {
private:
@nogc:

public:

    /**
        Constructs a new queue.

        Params:
            device = The device that "owns" this queue.
            handle = Vulkan handle 
    */
    this(NioDevice device) {
        super(device);
    }
    
}