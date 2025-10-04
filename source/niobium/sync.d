/**
    Niobium Synchronisation Primitives
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module niobium.sync;
import niobium.device;

/**
    The different pipeline stages that can be used for memory barriers.
*/
enum NioPipelineStage : uint {

    /**
        Transfer pipeline stage.
    */
    transfer =          0x00000001U,
    
    /**
        Compute dispatch pipeline stage.
    */
    compute =           0x00000002U,

    /**
        Vertex pipeline stage.
    */
    vertex =            0x00000010U,

    /**
        Fragment pipeline stage.
    */
    fragment =          0x00000020U,
    
    /**
        Task pipeline stage.
    */
    task =              0x00000100U,
    
    /**
        Mesh pipeline stage.
    */
    mesh =              0x00000200U,

    /**
        Raytracing acceleration structure stage.
    */
    raytracing =        0x00001000U,

    /**
        All basic dispatch stages.
    */
    allDispatch =       transfer | compute,

    /**
        All rendering related stages.
    */
    allMesh =         task | mesh,

    /**
        All rendering related stages.
    */
    allRender =         vertex | fragment | raytracing | allMesh,

    /**
        All stages.
    */
    all =               allDispatch | allRender
}

/**
    The different pipeline stages render operations go through.
*/
enum NioRenderStage : uint {

    /**
        Mesh Task Stage
    */
    task =      0x00000001U,

    /**
        Mesh Stage
    */
    mesh =      0x00000002U,

    /**
        Vertex Stage
    */
    vertex =    0x00000004U,

    /**
        Fragment Stage
    */
    fragment =  0x00000008U,

    /**
        All stages
    */
    all =       task | mesh| vertex |fragment
}

/**
    A GPU-local memory fence for tracking resource dependencies.
*/
abstract
class NioFence : NioDeviceObject {
protected:
@nogc:

    /**
        Constructs a new texture.

        Params:
            device = The device that "owns" this texture.
    */
    this(NioDevice device) {
        super(device);
    }
}

/**
    A GPU-local timeline semaphore for tracking resource dependencies.
*/
abstract
class NioSemaphore : NioDeviceObject {
protected:
@nogc:

    /**
        Constructs a new texture.

        Params:
            device = The device that "owns" this texture.
    */
    this(NioDevice device) {
        super(device);
    }

public:

    /**
        The current value of the semaphore.
    */
    abstract @property ulong value();

    /**
        Signals the semaphore with the given value.

        Params:
            value = The value to signal with, must be greater 
                    than the current value.
        
        Returns:
            $(D true) if the operation succeeded,
            $(D false) otherwise.
    */
    abstract bool signal(ulong value);

    /**
        Awaits the semaphore getting signalled.

        Params:
            value =     The value to wait for
            timeout =   The timeout for the wait in miliseconds.
        
        Returns:
            $(D true) if the semaphore reached the given value,
            $(D false) otherwise (eg. it timed out.)
    */
    abstract bool await(ulong value, ulong timeout);
}