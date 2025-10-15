/**
    Niobium Metal Format Conversions
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module niobium.mtl.formats;
import metal.vertexdescriptor;
import metal.pixelformat;
import metal.argument;

public import niobium.vertexformat;
public import niobium.pixelformat;
public import niobium.buffer : NioIndexType;

/**
    Converts a $(D NioPixelFormat) format to its $(D MTLPixelFormat) equivalent.

    Params:
        format = The $(D NioPixelFormat)
    
    Returns:
        The $(D MTLPixelFormat) equivalent.
*/
pragma(inline, true)
MTLPixelFormat toMTLPixelFormat(NioPixelFormat format) @nogc {
    final switch(format) with(NioPixelFormat) {
        case unknown:               return MTLPixelFormat.Invalid;
        case a8Unorm:               return MTLPixelFormat.A8Unorm;
        case r8Unorm:               return MTLPixelFormat.R8Unorm;
        case r8UnormSRGB:           return MTLPixelFormat.R8Unorm_sRGB;
        case r8Snorm:               return MTLPixelFormat.R8Snorm;
        case r8Uint:                return MTLPixelFormat.R8Uint;
        case r8Sint:                return MTLPixelFormat.R8Sint;
        case r16Unorm:              return MTLPixelFormat.R16Unorm;
        case r16Uint:               return MTLPixelFormat.R16Uint;
        case r16Sint:               return MTLPixelFormat.R16Sint;
        case r16Float:              return MTLPixelFormat.R16Float;
        case r32Uint:               return MTLPixelFormat.R32Uint;
        case r32Sint:               return MTLPixelFormat.R32Sint;
        case r32Float:              return MTLPixelFormat.R32Float;
        case rg8Unorm:              return MTLPixelFormat.RG8Unorm;
        case rg8UnormSRGB:          return MTLPixelFormat.RG8Unorm_sRGB;
        case rg8Snorm:              return MTLPixelFormat.RG8Snorm;
        case rg8Uint:               return MTLPixelFormat.RG8Uint;
        case rg8Sint:               return MTLPixelFormat.RG8Sint;
        case rg16Unorm:             return MTLPixelFormat.RG16Unorm;
        case rg16Snorm:             return MTLPixelFormat.RG16Snorm;
        case rg16Uint:              return MTLPixelFormat.RG16Uint;
        case rg16Sint:              return MTLPixelFormat.RG16Sint;
        case rg16Float:             return MTLPixelFormat.RG16Float;
        case rg32Uint:              return MTLPixelFormat.RG32Uint;
        case rg32Sint:              return MTLPixelFormat.RG32Sint;
        case rg32Float:             return MTLPixelFormat.RG32Float;
        case rgba8Unorm:            return MTLPixelFormat.RGBA8Unorm;
        case rgba8UnormSRGB:        return MTLPixelFormat.RGBA8Unorm_sRGB;
        case rgba8Snorm:            return MTLPixelFormat.RGBA8Snorm;
        case rgba8Uint:             return MTLPixelFormat.RGBA8Uint;
        case rgba8Sint:             return MTLPixelFormat.RGBA8Sint;
        case rgba16Unorm:           return MTLPixelFormat.RGBA16Unorm;
        case rgba16Snorm:           return MTLPixelFormat.RGBA16Snorm;
        case rgba16Uint:            return MTLPixelFormat.RGBA16Uint;
        case rgba16Sint:            return MTLPixelFormat.RGBA16Sint;
        case rgba32Uint:            return MTLPixelFormat.RGBA32Uint;
        case rgba32Sint:            return MTLPixelFormat.RGBA32Sint;
        case rgba32Float:           return MTLPixelFormat.RGBA32Float;
        case bgra8Unorm:            return MTLPixelFormat.BGRA8Unorm;
        case bgra8UnormSRGB:        return MTLPixelFormat.BGRA8Unorm_sRGB;
        case rgbaUnorm_BC1:         return MTLPixelFormat.BC1_RGBA;
        case rgbaUnormSRGB_BC1:     return MTLPixelFormat.BC1_RGBA_sRGB;
        case rgbaUnorm_BC2:         return MTLPixelFormat.BC2_RGBA;
        case rgbaUnormSRGB_BC2:     return MTLPixelFormat.BC2_RGBA_sRGB;
        case rgbaUnorm_BC3:         return MTLPixelFormat.BC3_RGBA;
        case rgbaUnormSRGB_BC3:     return MTLPixelFormat.BC3_RGBA_sRGB;
        case rgbaUnorm_BC7:         return MTLPixelFormat.BC7_RGBAUnorm;
        case rgbaUnormSRGB_BC7:     return MTLPixelFormat.BC7_RGBAUnorm_sRGB;
        case stencil8:              return MTLPixelFormat.Stencil8;
        case depth16Unorm:          return MTLPixelFormat.Depth16Unorm;
        case depth32Float:          return MTLPixelFormat.Depth32Float;
        case depth24Stencil8:       return MTLPixelFormat.Depth24Unorm_Stencil8;
        case depth32Stencil8:       return MTLPixelFormat.Depth32Float_Stencil8;
        case x24Stencil8:           return MTLPixelFormat.X24_Stencil8;
        case x32Stencil8:           return MTLPixelFormat.X32_Stencil8;
    }
}

/**
    Converts a $(D MTLPixelFormat) format to its $(D NioPixelFormat) equivalent.

    Params:
        format = The $(D MTLPixelFormat)
    
    Returns:
        The $(D NioPixelFormat) equivalent.
*/
pragma(inline, true)
NioPixelFormat toNioPixelFormat(MTLPixelFormat format) @nogc {
    switch(format) with(MTLPixelFormat) {
        default:                        return NioPixelFormat.unknown;
        case A8Unorm:                   return NioPixelFormat.a8Unorm;
        case R8Unorm:                   return NioPixelFormat.r8Unorm;
        case R8Unorm_sRGB:              return NioPixelFormat.r8UnormSRGB;
        case R8Snorm:                   return NioPixelFormat.r8Snorm;
        case R8Uint:                    return NioPixelFormat.r8Uint;
        case R8Sint:                    return NioPixelFormat.r8Sint;
        case R16Unorm:                  return NioPixelFormat.r16Unorm;
        case R16Uint:                   return NioPixelFormat.r16Uint;
        case R16Sint:                   return NioPixelFormat.r16Sint;
        case R16Float:                  return NioPixelFormat.r16Float;
        case R32Uint:                   return NioPixelFormat.r32Uint;
        case R32Sint:                   return NioPixelFormat.r32Sint;
        case R32Float:                  return NioPixelFormat.r32Float;
        case RG8Unorm:                  return NioPixelFormat.rg8Unorm;
        case RG8Unorm_sRGB:             return NioPixelFormat.rg8UnormSRGB;
        case RG8Snorm:                  return NioPixelFormat.rg8Snorm;
        case RG8Uint:                   return NioPixelFormat.rg8Uint;
        case RG8Sint:                   return NioPixelFormat.rg8Sint;
        case RG16Unorm:                 return NioPixelFormat.rg16Unorm;
        case RG16Snorm:                 return NioPixelFormat.rg16Snorm;
        case RG16Uint:                  return NioPixelFormat.rg16Uint;
        case RG16Sint:                  return NioPixelFormat.rg16Sint;
        case RG16Float:                 return NioPixelFormat.rg16Float;
        case RG32Uint:                  return NioPixelFormat.rg32Uint;
        case RG32Sint:                  return NioPixelFormat.rg32Sint;
        case RG32Float:                 return NioPixelFormat.rg32Float;
        case RGBA8Unorm:                return NioPixelFormat.rgba8Unorm;
        case RGBA8Unorm_sRGB:           return NioPixelFormat.rgba8UnormSRGB;
        case RGBA8Snorm:                return NioPixelFormat.rgba8Snorm;
        case RGBA8Uint:                 return NioPixelFormat.rgba8Uint;
        case RGBA8Sint:                 return NioPixelFormat.rgba8Sint;
        case RGBA16Unorm:               return NioPixelFormat.rgba16Unorm;
        case RGBA16Snorm:               return NioPixelFormat.rgba16Snorm;
        case RGBA16Uint:                return NioPixelFormat.rgba16Uint;
        case RGBA16Sint:                return NioPixelFormat.rgba16Sint;
        case RGBA32Uint:                return NioPixelFormat.rgba32Uint;
        case RGBA32Sint:                return NioPixelFormat.rgba32Sint;
        case RGBA32Float:               return NioPixelFormat.rgba32Float;
        case BGRA8Unorm:                return NioPixelFormat.bgra8Unorm;
        case BGRA8Unorm_sRGB:           return NioPixelFormat.bgra8UnormSRGB;
        case BC1_RGBA:                  return NioPixelFormat.rgbaUnorm_BC1;
        case BC1_RGBA_sRGB:             return NioPixelFormat.rgbaUnormSRGB_BC1;
        case BC2_RGBA:                  return NioPixelFormat.rgbaUnorm_BC2;
        case BC2_RGBA_sRGB:             return NioPixelFormat.rgbaUnormSRGB_BC2;
        case BC3_RGBA:                  return NioPixelFormat.rgbaUnorm_BC3;
        case BC3_RGBA_sRGB:             return NioPixelFormat.rgbaUnormSRGB_BC3;
        case BC7_RGBAUnorm:             return NioPixelFormat.rgbaUnorm_BC7;
        case BC7_RGBAUnorm_sRGB:        return NioPixelFormat.rgbaUnormSRGB_BC7;
        case Stencil8:                  return NioPixelFormat.stencil8;
        case Depth16Unorm:              return NioPixelFormat.depth16Unorm;
        case Depth32Float:              return NioPixelFormat.depth32Float;
        case Depth24Unorm_Stencil8:     return NioPixelFormat.depth24Stencil8;
        case Depth32Float_Stencil8:     return NioPixelFormat.depth32Stencil8;
        case X24_Stencil8:              return NioPixelFormat.x24Stencil8;
        case X32_Stencil8:              return NioPixelFormat.x32Stencil8;
    }
}

/**
    Converts a $(D NioVertexFormat) format to its $(D MTLVertexFormat) equivalent.

    Params:
        format = The $(D NioVertexFormat)
    
    Returns:
        The $(D MTLVertexFormat) equivalent.
*/
pragma(inline, true)
MTLVertexFormat toMTLVertexFormat(NioVertexFormat format) @nogc {
    final switch(format) with(NioVertexFormat) {
        case unknown:               return MTLVertexFormat.Invalid;

        /// 8-bit
        case ubyte1:                return MTLVertexFormat.UChar;
        case ubyte2:                return MTLVertexFormat.UChar2;
        case ubyte3:                return MTLVertexFormat.UChar3;
        case ubyte4:                return MTLVertexFormat.UChar4;
        case byte1:                 return MTLVertexFormat.Char;
        case byte2:                 return MTLVertexFormat.Char2;
        case byte3:                 return MTLVertexFormat.Char3;
        case byte4:                 return MTLVertexFormat.Char4;
        case ubyte1Norm:            return MTLVertexFormat.UCharNormalized;
        case ubyte2Norm:            return MTLVertexFormat.UChar2Normalized;
        case ubyte3Norm:            return MTLVertexFormat.UChar3Normalized;
        case ubyte4Norm:            return MTLVertexFormat.UChar4Normalized;
        case byte1Norm:             return MTLVertexFormat.CharNormalized;
        case byte2Norm:             return MTLVertexFormat.Char2Normalized;
        case byte3Norm:             return MTLVertexFormat.Char3Normalized;
        case byte4Norm:             return MTLVertexFormat.Char4Normalized;

        /// 16-bit
        case ushort1:               return MTLVertexFormat.UShort;
        case ushort2:               return MTLVertexFormat.UShort2;
        case ushort3:               return MTLVertexFormat.UShort3;
        case ushort4:               return MTLVertexFormat.UShort4;
        case short1:                return MTLVertexFormat.Short;
        case short2:                return MTLVertexFormat.Short2;
        case short3:                return MTLVertexFormat.Short3;
        case short4:                return MTLVertexFormat.Short4;
        case ushort1Norm:           return MTLVertexFormat.UShortNormalized;
        case ushort2Norm:           return MTLVertexFormat.UShort2Normalized;
        case ushort3Norm:           return MTLVertexFormat.UShort3Normalized;
        case ushort4Norm:           return MTLVertexFormat.UShort4Normalized;
        case short1Norm:            return MTLVertexFormat.ShortNormalized;
        case short2Norm:            return MTLVertexFormat.Short2Normalized;
        case short3Norm:            return MTLVertexFormat.Short3Normalized;
        case short4Norm:            return MTLVertexFormat.Short4Normalized;

        /// 32-bit
        case uint1:                 return MTLVertexFormat.UInt;
        case uint2:                 return MTLVertexFormat.UInt2;
        case uint3:                 return MTLVertexFormat.UInt3;
        case uint4:                 return MTLVertexFormat.UInt4;
        case int1:                  return MTLVertexFormat.Int;
        case int2:                  return MTLVertexFormat.Int2;
        case int3:                  return MTLVertexFormat.Int3;
        case int4:                  return MTLVertexFormat.Int4;
        case float1:                return MTLVertexFormat.Float;
        case float2:                return MTLVertexFormat.Float2;
        case float3:                return MTLVertexFormat.Float3;
        case float4:                return MTLVertexFormat.Float4;
    }
}

/**
    Converts a $(D NioIndexType) format to its $(D MTLIndexType) equivalent.

    Params:
        indexType = The $(D NioIndexType)
    
    Returns:
        The $(D MTLIndexType) equivalent.
*/
pragma(inline, true)
MTLIndexType toMTLIndexType(NioIndexType indexType) @nogc {
    final switch(indexType) with(NioIndexType) {
        case u16:       return MTLIndexType.UInt16;
        case u32:       return MTLIndexType.UInt32;
    }
}