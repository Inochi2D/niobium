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
import niobium.mtl.utils;
import niobium.types;
import metal.datatype;
import metal.functiondescriptor;
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
        .autorelease(() {
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
                functions_[i] = nogc_new!NioMTLShaderFunction(device, this, handle_.newFunctionWithName(name), null);
            }
            funcNames.release();
        });
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
        Creates a new specialized function instance from the given descriptor.

        Params:
            desc = The descriptor.
        
        Returns:
            A $(D NioShaderFunction) on success,
            $(D null) otherwise.
    */
    override NioShaderFunction makeFunction(NioShaderFunctionDescriptor desc) {
        NioMTLShaderFunction result;
        .autorelease(() {
            auto mtlDevice = cast(NioMTLDevice)device;

            MTLFunctionDescriptor mtldesc = MTLFunctionDescriptor.functionDescriptor;
            mtldesc.name = NSString.create(desc.name);

            foreach(constant; desc.constants) {
                mtldesc.constantValues.setConstantValue(
                    constant.data.ptr, 
                    constant.type.toMTLDataType(), 
                    constant.id
                );
            }

            NSError error;
            auto mtlFunction = handle_.newFunctionWithDescriptor(mtldesc, error);
            if (error) {
                string errText = error.toString();
                error.release();
                throw nogc_new!NuException(errText);
            }

            result = nogc_new!NioMTLShaderFunction(device, this, mtlFunction, desc.constants);
        });
        return result;
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
    this(NioDevice device, NioMTLShader parent, MTLFunction func, NioShaderConstant[] constants) {
        super(device, constants);
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

/**
    Converts a $(D NioDataType) format to its $(D MTLDataType) equivalent.

    Params:
        type = The $(D NioDataType)
    
    Returns:
        The $(D MTLDataType) equivalent.
*/
pragma(inline, true)
MTLDataType toMTLDataType(NioDataType type) @nogc nothrow pure {
    final switch(type) with(NioDataType) {
        case unknown:           return MTLDataType.None;
        case bool1:             return MTLDataType.Bool;
        case bool2:             return MTLDataType.Bool2;
        case bool3:             return MTLDataType.Bool3;
        case bool4:             return MTLDataType.Bool4;
        case ubyte1:            return MTLDataType.UChar;
        case ubyte2:            return MTLDataType.UChar2;
        case ubyte3:            return MTLDataType.UChar3;
        case ubyte4:            return MTLDataType.UChar4;
        case byte1:             return MTLDataType.Char;
        case byte2:             return MTLDataType.Char2;
        case byte3:             return MTLDataType.Char3;
        case byte4:             return MTLDataType.Char4;
        case ushort1:           return MTLDataType.UShort;
        case ushort2:           return MTLDataType.UShort2;
        case ushort3:           return MTLDataType.UShort3;
        case ushort4:           return MTLDataType.UShort4;
        case short1:            return MTLDataType.Short;
        case short2:            return MTLDataType.Short2;
        case short3:            return MTLDataType.Short3;
        case short4:            return MTLDataType.Short4;
        case half1:             return MTLDataType.Half;
        case half2:             return MTLDataType.Half2;
        case half3:             return MTLDataType.Half3;
        case half4:             return MTLDataType.Half4;
        case half2x2:           return MTLDataType.Half2x2;
        case half2x3:           return MTLDataType.Half2x3;
        case half2x4:           return MTLDataType.Half2x4;
        case half3x2:           return MTLDataType.Half3x2;
        case half3x3:           return MTLDataType.Half3x3;
        case half3x4:           return MTLDataType.Half3x4;
        case half4x2:           return MTLDataType.Half4x2;
        case half4x3:           return MTLDataType.Half4x3;
        case half4x4:           return MTLDataType.Half4x4;
        case uint1:             return MTLDataType.UInt;
        case uint2:             return MTLDataType.UInt2;
        case uint3:             return MTLDataType.UInt3;
        case uint4:             return MTLDataType.UInt4;
        case int1:              return MTLDataType.Int;
        case int2:              return MTLDataType.Int2;
        case int3:              return MTLDataType.Int3;
        case int4:              return MTLDataType.Int4;
        case float1:            return MTLDataType.Float;
        case float2:            return MTLDataType.Float2;
        case float3:            return MTLDataType.Float3;
        case float4:            return MTLDataType.Float4;
        case float2x2:          return MTLDataType.Float2x2;
        case float2x3:          return MTLDataType.Float2x3;
        case float2x4:          return MTLDataType.Float2x4;
        case float3x2:          return MTLDataType.Float3x2;
        case float3x3:          return MTLDataType.Float3x3;
        case float3x4:          return MTLDataType.Float3x4;
        case float4x2:          return MTLDataType.Float4x2;
        case float4x3:          return MTLDataType.Float4x3;
        case float4x4:          return MTLDataType.Float4x4;
        case ulong1:            return MTLDataType.ULong;
        case ulong2:            return MTLDataType.ULong2;
        case ulong3:            return MTLDataType.ULong3;
        case ulong4:            return MTLDataType.ULong4;
        case long1:             return MTLDataType.Long;
        case long2:             return MTLDataType.Long2;
        case long3:             return MTLDataType.Long3;
        case long4:             return MTLDataType.Long4;
        case r8Unorm:           return MTLDataType.R8Unorm;
        case r8Snorm:           return MTLDataType.R8Snorm;
        case rg8Unorm:          return MTLDataType.RG8Unorm;
        case rg8UnormSRGB:      return MTLDataType.RG8Unorm;
        case rg8Snorm:          return MTLDataType.RG8Snorm;
        case rg16Unorm:         return MTLDataType.RG16Unorm;
        case rg16Snorm:         return MTLDataType.RG16Snorm;
        case rgba8Snorm:        return MTLDataType.RGBA8Snorm;
        case rgba8Unorm:        return MTLDataType.RGBA8Unorm;
        case rgba16Unorm:       return MTLDataType.RGBA16Unorm;
        case rgba16Snorm:       return MTLDataType.RGBA16Snorm;
        case texture:           return MTLDataType.Texture;     
        case sampler:           return MTLDataType.Sampler;     
        case structure:         return MTLDataType.Struct;     
        case array:             return MTLDataType.Array; 
        case pointer:           return MTLDataType.Pointer;     
    }
}