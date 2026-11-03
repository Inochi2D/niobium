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

    NioVertexAttribute[] attribs_;
    void calcAttribs(MTLFunction func) {
        auto attribArray = func.vertexAttributes;
        if (attribArray && attribArray.length > 0) {
            this.attribs_ = nu_malloca!NioVertexAttribute(attribArray.length);

            foreach(i, attrib; attribArray) {
                attribs_[i].index = cast(uint)attrib.index;
                attribs_[i].type = attrib.type.toNioDataType();
                attribs_[i].size = cast(uint)attribs_[i].type.sizeOf;
            }
        }
    }

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

    /**
        Vertex attributes of the function, if present.
    */
    override @property NioVertexAttribute[] attributes() => attribs_;

    /// Destructor
    ~this() {
        nu_freea(name_);
        nu_freea(attribs_);
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
        this.calcAttribs(func);
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

/**
    Converts a $(D MTLDataType) format to its $(D NioDataType) equivalent.

    Params:
        type = The $(D MTLDataType)
    
    Returns:
        The $(D NioDataType) equivalent.
*/
pragma(inline, true)
NioDataType toNioDataType(MTLDataType type) @nogc nothrow pure {
    switch(type) with(MTLDataType) {
        default:                return NioDataType.unknown;
        case Bool:              return NioDataType.bool1;
        case Bool2:             return NioDataType.bool2;
        case Bool3:             return NioDataType.bool3;
        case Bool4:             return NioDataType.bool4;
        case UChar:             return NioDataType.ubyte1;
        case UChar2:            return NioDataType.ubyte2;
        case UChar3:            return NioDataType.ubyte3;
        case UChar4:            return NioDataType.ubyte4;
        case Char:              return NioDataType.byte1;
        case Char2:             return NioDataType.byte2;
        case Char3:             return NioDataType.byte3;
        case Char4:             return NioDataType.byte4;
        case UShort:            return NioDataType.ushort1;
        case UShort2:           return NioDataType.ushort2;
        case UShort3:           return NioDataType.ushort3;
        case UShort4:           return NioDataType.ushort4;
        case Short:             return NioDataType.short1;
        case Short2:            return NioDataType.short2;
        case Short3:            return NioDataType.short3;
        case Short4:            return NioDataType.short4;
        case Half:              return NioDataType.half1;
        case Half2:             return NioDataType.half2;
        case Half3:             return NioDataType.half3;
        case Half4:             return NioDataType.half4;
        case Half2x2:           return NioDataType.half2x2;
        case Half2x3:           return NioDataType.half2x3;
        case Half2x4:           return NioDataType.half2x4;
        case Half3x2:           return NioDataType.half3x2;
        case Half3x3:           return NioDataType.half3x3;
        case Half3x4:           return NioDataType.half3x4;
        case Half4x2:           return NioDataType.half4x2;
        case Half4x3:           return NioDataType.half4x3;
        case Half4x4:           return NioDataType.half4x4;
        case UInt:              return NioDataType.uint1;
        case UInt2:             return NioDataType.uint2;
        case UInt3:             return NioDataType.uint3;
        case UInt4:             return NioDataType.uint4;
        case Int:               return NioDataType.int1;
        case Int2:              return NioDataType.int2;
        case Int3:              return NioDataType.int3;
        case Int4:              return NioDataType.int4;
        case Float:             return NioDataType.float1;
        case Float2:            return NioDataType.float2;
        case Float3:            return NioDataType.float3;
        case Float4:            return NioDataType.float4;
        case Float2x2:          return NioDataType.float2x2;
        case Float2x3:          return NioDataType.float2x3;
        case Float2x4:          return NioDataType.float2x4;
        case Float3x2:          return NioDataType.float3x2;
        case Float3x3:          return NioDataType.float3x3;
        case Float3x4:          return NioDataType.float3x4;
        case Float4x2:          return NioDataType.float4x2;
        case Float4x3:          return NioDataType.float4x3;
        case Float4x4:          return NioDataType.float4x4;
        case ULong:             return NioDataType.ulong1;
        case ULong2:            return NioDataType.ulong2;
        case ULong3:            return NioDataType.ulong3;
        case ULong4:            return NioDataType.ulong4;
        case Long:              return NioDataType.long1;
        case Long2:             return NioDataType.long2;
        case Long3:             return NioDataType.long3;
        case Long4:             return NioDataType.long4;
        case R8Unorm:           return NioDataType.r8Unorm;
        case R8Snorm:           return NioDataType.r8Snorm;
        case RG8Unorm:          return NioDataType.rg8Unorm;
        case RG8Snorm:          return NioDataType.rg8Snorm;
        case RG16Unorm:         return NioDataType.rg16Unorm;
        case RG16Snorm:         return NioDataType.rg16Snorm;
        case RGBA8Snorm:        return NioDataType.rgba8Snorm;
        case RGBA8Unorm:        return NioDataType.rgba8Unorm;
        case RGBA16Unorm:       return NioDataType.rgba16Unorm;
        case RGBA16Snorm:       return NioDataType.rgba16Snorm;
        case Texture:           return NioDataType.texture;     
        case Sampler:           return NioDataType.sampler;     
        case Struct:            return NioDataType.structure;     
        case Array:             return NioDataType.array; 
        case Pointer:           return NioDataType.pointer;     
    }
}