/**
    Niobium Depth-Stencil State Objects
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module niobium.depthstencil;
import niobium.device;

/**
    Comparison functions for depth-stencil.
*/
enum NioCompareOp : uint {
    never =         0x00000000U,
    less =          0x00000001U,
    equal =         0x00000002U,
    lessEqual =     0x00000003U,
    greater =       0x00000004U,
    notEqual =      0x00000005U,
    greaterEqual =  0x00000006U,
    always =        0x00000007U,
}

/**
    A stencil operation to perform.
*/
enum NioStencilOp : uint {
    keep =              0x00000000U,
    zero =              0x00000001U,
    replace =           0x00000002U,
    incrementClamp =    0x00000003U,
    decrementClamp =    0x00000004U,
    invert =            0x00000005U,
    incrementWrap =     0x00000006U,
    decrementWrap =     0x00000007U,
}

/**
    Descriptor used to create a $(D NioDepthStencilState).
*/
struct NioDepthStencilStateDescriptor {

    /**
        Whether depth testing is enabled.
    */
    bool depthTestEnabled;

    /**
        Depth state.
    */
    NioDepthStateDescriptor depthState;

    /**
        Whether stencil testing is enabled.
    */
    bool stencilTestEnabled;
    
    /**
        Front-face stencil state.
    */
    NioStencilStateDescriptor frontStencilState;
    
    /**
        Back-face stencil state.
    */
    NioStencilStateDescriptor backStencilState;
}

/**
    Depth state for a $(D NioDepthStencilStateDescriptor)
*/
struct NioDepthStateDescriptor {

    /**
        Whether depth writing is enabled.
    */
    bool depthWriteEnabled;

    /**
        The comparison function to use.
    */
    NioCompareOp compareFunction;
}

/**
    Stencil state for a $(D NioDepthStencilStateDescriptor)
*/
struct NioStencilStateDescriptor {

    /**
        Operation to perform on stencil testing failure.
    */
    NioStencilOp failureOp;

    /**
        Operation to perform on depth testing failure.
    */
    NioStencilOp depthFailureOp;

    /**
        Operation to perform on test pass.
    */
    NioStencilOp passOp;

    /**
        The comparison function to use.
    */
    NioCompareOp compareFunction;

    /**
        Stencil read mask.
    */
    uint readMask;

    /**
        Stencil write mask.
    */
    uint writeMask;
}

/**
    A depth-stencil state object.

    Once a depth-stencil object is created its state
    is immutable.
*/
abstract
class NioDepthStencilState : NioDeviceObject {
private:
@nogc:
    NioDepthStencilStateDescriptor desc_;

protected:

    /**
        The descriptor used to create this state.
    */
    final @property NioDepthStencilStateDescriptor desc() => desc_;

    /**
        Constructs a new depth stencil state.

        Params:
            device =    The device that "owns" this depth stencil state.
            desc =      The descriptor for this depth stencil state.
    */
    this(NioDevice device, NioDepthStencilStateDescriptor desc) {
        super(device);
        this.desc_ = desc;
    }
}