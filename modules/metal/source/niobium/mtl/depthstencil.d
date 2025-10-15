module niobium.mtl.depthstencil;
import niobium.mtl.device;
import metal.depthstencil;
import metal.device;
import numem;
import nulib;

public import niobium.depthstencil;

/**
    A depth-stencil state object.

    Once a depth-stencil object is created its state
    is immutable.
*/
class NioMTLDepthStencilState : NioDepthStencilState {
private:
@nogc:

    // Handles
    MTLDepthStencilState handle_;

    void setup(NioDepthStencilStateDescriptor desc) {
        auto mtlDevice = cast(NioMTLDevice)device;
        MTLDepthStencilDescriptor mtldesc = MTLDepthStencilDescriptor.alloc.init;
        
        // Depth enable.
        mtldesc.depthCompareFunction = desc.depthTestEnabled ? desc.depthState.compareFunction.toMTLCompareFunction() : MTLCompareFunction.Always;
        mtldesc.depthWriteEnabled = desc.depthTestEnabled ? desc.depthState.depthWriteEnabled : false;

        if (desc.stencilTestEnabled) {
            
            // Front-face stencil
            auto frontFaceStencil = MTLStencilDescriptor.alloc.init;
            frontFaceStencil.stencilCompareFunction =       desc.frontStencilState.compareFunction.toMTLCompareFunction();
            frontFaceStencil.stencilFailureOperation =      desc.frontStencilState.failureOp.toMTLStencilOperation();
            frontFaceStencil.depthFailureOperation =        desc.frontStencilState.depthFailureOp.toMTLStencilOperation();
            frontFaceStencil.depthStencilPassOperation =    desc.frontStencilState.passOp.toMTLStencilOperation();
            frontFaceStencil.readMask =                     desc.frontStencilState.readMask;
            frontFaceStencil.writeMask =                    desc.frontStencilState.writeMask;

            // Back-face stencil
            auto backFaceStencil = MTLStencilDescriptor.alloc.init;
            backFaceStencil.stencilCompareFunction =        desc.backStencilState.compareFunction.toMTLCompareFunction();
            backFaceStencil.stencilFailureOperation =       desc.backStencilState.failureOp.toMTLStencilOperation();
            backFaceStencil.depthFailureOperation =         desc.backStencilState.depthFailureOp.toMTLStencilOperation();
            backFaceStencil.depthStencilPassOperation =     desc.backStencilState.passOp.toMTLStencilOperation();
            backFaceStencil.readMask =                      desc.backStencilState.readMask;
            backFaceStencil.writeMask =                     desc.backStencilState.writeMask;
            
            mtldesc.frontFaceStencil = frontFaceStencil;
            mtldesc.backFaceStencil = backFaceStencil;
        }

        this.handle_ = mtlDevice.handle.newDepthStencilState(mtldesc);
        mtldesc.release();
    }

public:

    /**
        The underlying Metal handle
    */
    final @property MTLDepthStencilState handle() => handle_;

    /// Destructor
    ~this() {
        handle_.release();
    }

    /**
        Constructs a new depth stencil state.

        Params:
            device =    The device that "owns" this depth stencil state.
            desc =      The descriptor for this depth stencil state.
    */
    this(NioDevice device, NioDepthStencilStateDescriptor desc) {
        super(device, desc);
        this.setup(desc);
    }
}

/**
    Converts a $(D NioCompareOp) type to its $(D MTLCompareFunction) equivalent.

    Params:
        value = The $(D NioCompareOp)
    
    Returns:
        The $(D MTLCompareFunction) equivalent.
*/
pragma(inline, true)
MTLCompareFunction toMTLCompareFunction(NioCompareOp value) @nogc {
    final switch(value) with(NioCompareOp) {
        case never:         return MTLCompareFunction.Never;
        case less:          return MTLCompareFunction.Less;
        case equal:         return MTLCompareFunction.Equal;
        case lessEqual:     return MTLCompareFunction.LessEqual;
        case greater:       return MTLCompareFunction.Greater;
        case notEqual:      return MTLCompareFunction.NotEqual;
        case greaterEqual:  return MTLCompareFunction.GreaterEqual;
        case always:        return MTLCompareFunction.Always;
    }
}

/**
    Converts a $(D NioStencilOp) type to its $(D MTLStencilOperation) equivalent.

    Params:
        value = The $(D NioStencilOp)
    
    Returns:
        The $(D MTLStencilOperation) equivalent.
*/
pragma(inline, true)
MTLStencilOperation toMTLStencilOperation(NioStencilOp value) @nogc {
    final switch(value) with(NioStencilOp) {
        case keep:              return MTLStencilOperation.Keep;
        case zero:              return MTLStencilOperation.Zero;
        case replace:           return MTLStencilOperation.Replace;
        case incrementClamp:    return MTLStencilOperation.IncrementClamp;
        case decrementClamp:    return MTLStencilOperation.DecrementClamp;
        case invert:            return MTLStencilOperation.Invert;
        case incrementWrap:     return MTLStencilOperation.IncrementClamp;
        case decrementWrap:     return MTLStencilOperation.DecrementClamp;
    }
}