/**
    Niobium Metal Shader Infrastructure
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module niobium.mtl.shader;
import niobium.mtl.device;
import metal.library;
import metal.device;
import foundation;
import numem;
import nulib;
import objc;

public import niobium.shader;
public import nir.library; 

class NioMTLShader : NioShader {
private:
@nogc:

    // Handles
    MTLLibrary handle_;
    NioMTLShaderFunction[] functions_;
    
    void setup(NirLibrary library) {
        foreach(ref shader; library.shaders) {
            if (shader.type == NirShaderType.msl) {
                this.setup(shader.name, shader.code);
                return;
            }
        }
    }
    
    void setup(string name, ubyte[] source) {
        auto mtlDevice = cast(NioMTLDevice)device;

        NSError error;
        auto nssource = NSString.create(cast(string)source);
        auto compileOptions = MTLCompileOptions.alloc.init;
        
        handle_ = mtlDevice.handle.newLibrary(nssource, compileOptions, error);
        
        nssource.release();
        compileOptions.release();
        if (error) {
            string errText = error.toString();
            error.release();
            throw nogc_new!NuException(errText);
        }

        auto funcNames = handle_.functionNames;
        functions_ = nu_malloca!NioMTLShaderFunction(funcNames.length);
        foreach(i, name; funcNames) {
            functions_[i] = nogc_new!NioMTLShaderFunction(device, this, handle_.newFunctionWithName(name));
        }
        funcNames.release();
    }

public:

    /**
        The underlying Metal handle
    */
    final @property MTLLibrary handle() => handle_;

    /// Destructor
    ~this() {
        handle_.release();
    }

    /**
        Constructs a new shader from a Nir library.
    */
    this(NioDevice device, NirLibrary library) {
        super(device, library);
        this.setup(library);
    }

    /**
        Constructs a new shader from source.
    */
    this(NioDevice device, string name, ubyte[] source) {
        super(device, null);
        this.setup(name, source);
    }

    /**
        Gets a named function from the shader.

        Params:
            name = The name of the function.
        
        Returns:
            A $(D NioShaderFunction) on success,
            $(D null) otherwise.
    */
    override NioShaderFunction getFunction(string name) {
        foreach(func; functions_) {
            if (func.name == name)
                return func;
        }
        return null;
    }
}

/**
    A vulkan shader function.
*/
class NioMTLShaderFunction : NioShaderFunction {
private:
@nogc:
    NioMTLShader parent_;
    MTLFunction handle_;
    string name_;
    NirShaderStage stage_;

public:

    /**
        The underlying Metal handle
    */
    final @property MTLFunction handle() => handle_;

    /**
        Name of the function
    */
    override @property string name() => name_;

    /**
        The shader stage this shader conforms to.
    */
    override @property NirShaderStage stage() => stage_;

    /// Destructor
    ~this() {
        nu_freea(name_);
        handle_.release();
        parent_.release();
    }

    /**
        Constructs a new shader function.
    */
    this(NioDevice device, NioMTLShader parent, MTLFunction func) {
        super(device);
        this.parent_ = parent.retained();
        this.handle_ = func;
        this.name_ = func.name.toString();
        this.stage_ = func.functionType.toNirShaderStage();
    }
}

/**
    Converts a $(D MTLFunctionType) format to its $(D NirShaderStage) equivalent.

    Params:
        type = The $(D MTLFunctionType)
    
    Returns:
        The $(D NirShaderStage) equivalent.
*/
pragma(inline, true)
NirShaderStage toNirShaderStage(MTLFunctionType type) @nogc {
    switch(type) with(MTLFunctionType) {
        default:                return NirShaderStage.none;
        case Vertex:            return NirShaderStage.vertex;
        case Fragment:          return NirShaderStage.fragment;
        case Kernel:            return NirShaderStage.kernel;
        case Object:            return NirShaderStage.task;
        case Mesh:              return NirShaderStage.mesh;
    }
}