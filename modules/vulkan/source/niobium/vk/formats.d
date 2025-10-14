/**
    Niobium Vulkan Format Conversions
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module niobium.vk.formats;
import vulkan.core;

public import niobium.vertexformat;
public import niobium.pixelformat;

/**
    Converts a $(D NioPixelFormat) format to its $(D VkFormat) equivalent.

    Params:
        format = The $(D NioPixelFormat)
    
    Returns:
        The $(D VkFormat) equivalent.
*/
pragma(inline, true)
VkFormat toVkFormat(NioPixelFormat format) @nogc {
    final switch(format) with(NioPixelFormat) {
        case unknown:               return VK_FORMAT_UNDEFINED;
        case a8Unorm:               return VK_FORMAT_A8_UNORM;
        case r8Unorm:               return VK_FORMAT_R8_UNORM;
        case r8UnormSRGB:           return VK_FORMAT_R8_SRGB;
        case r8Snorm:               return VK_FORMAT_R8_SNORM;
        case r8Uint:                return VK_FORMAT_R8_UINT;
        case r8Sint:                return VK_FORMAT_R8_SINT;
        case r16Unorm:              return VK_FORMAT_R16_UNORM;
        case r16Uint:               return VK_FORMAT_R16_UINT;
        case r16Sint:               return VK_FORMAT_R16_SINT;
        case r16Float:              return VK_FORMAT_R16_SFLOAT;
        case r32Uint:               return VK_FORMAT_R32_UINT;
        case r32Sint:               return VK_FORMAT_R32_SINT;
        case r32Float:              return VK_FORMAT_R32_SFLOAT;
        case rg8Unorm:              return VK_FORMAT_R8G8_UNORM;
        case rg8UnormSRGB:          return VK_FORMAT_R8G8_SRGB;
        case rg8Snorm:              return VK_FORMAT_R8G8_SNORM;
        case rg8Uint:               return VK_FORMAT_R8G8_UINT;
        case rg8Sint:               return VK_FORMAT_R8G8_SINT;
        case rg16Unorm:             return VK_FORMAT_R16G16_UNORM;
        case rg16Snorm:             return VK_FORMAT_R16G16_SNORM;
        case rg16Uint:              return VK_FORMAT_R16G16_UINT;
        case rg16Sint:              return VK_FORMAT_R16G16_SINT;
        case rg16Float:             return VK_FORMAT_R16G16_SFLOAT;
        case rg32Uint:              return VK_FORMAT_R32G32_UINT;
        case rg32Sint:              return VK_FORMAT_R32G32_SINT;
        case rg32Float:             return VK_FORMAT_R32G32_SFLOAT;
        case rgba8Unorm:            return VK_FORMAT_R8G8B8A8_UNORM;
        case rgba8UnormSRGB:        return VK_FORMAT_R8G8B8A8_SRGB;
        case rgba8Snorm:            return VK_FORMAT_R8G8B8A8_SNORM;
        case rgba8Uint:             return VK_FORMAT_R8G8B8A8_UINT;
        case rgba8Sint:             return VK_FORMAT_R8G8B8A8_SINT;
        case rgba16Unorm:           return VK_FORMAT_R16G16B16A16_UNORM;
        case rgba16Snorm:           return VK_FORMAT_R16G16B16A16_SNORM;
        case rgba16Uint:            return VK_FORMAT_R16G16B16A16_UINT;
        case rgba16Sint:            return VK_FORMAT_R16G16B16A16_SINT;
        case rgba32Uint:            return VK_FORMAT_R32G32B32A32_UINT;
        case rgba32Sint:            return VK_FORMAT_R32G32B32A32_SINT;
        case rgba32Float:           return VK_FORMAT_R32G32B32A32_SFLOAT;
        case bgra8Unorm:            return VK_FORMAT_B8G8R8A8_UNORM;
        case bgra8UnormSRGB:        return VK_FORMAT_B8G8R8A8_SRGB;
        case rgbaUnorm_BC1:         return VK_FORMAT_BC1_RGBA_UNORM_BLOCK;
        case rgbaUnormSRGB_BC1:     return VK_FORMAT_BC1_RGBA_SRGB_BLOCK;
        case rgbaUnorm_BC2:         return VK_FORMAT_BC2_UNORM_BLOCK;
        case rgbaUnormSRGB_BC2:     return VK_FORMAT_BC2_SRGB_BLOCK;
        case rgbaUnorm_BC3:         return VK_FORMAT_BC3_UNORM_BLOCK;
        case rgbaUnormSRGB_BC3:     return VK_FORMAT_BC3_SRGB_BLOCK;
        case rgbaUnorm_BC7:         return VK_FORMAT_BC7_UNORM_BLOCK;
        case rgbaUnormSRGB_BC7:     return VK_FORMAT_BC7_SRGB_BLOCK;
        case depth16Unorm:          return VK_FORMAT_D16_UNORM;
        case depth32Float:          return VK_FORMAT_D32_SFLOAT;
        case stencil8:              return VK_FORMAT_S8_UINT;
        case depth24Stencil8:       return VK_FORMAT_D24_UNORM_S8_UINT;
        case depth32Stencil8:       return VK_FORMAT_D32_SFLOAT_S8_UINT;
        case x24Stencil8:           return VK_FORMAT_D24_UNORM_S8_UINT;
        case x32Stencil8:           return VK_FORMAT_D32_SFLOAT_S8_UINT;
    }
}

/**
    Converts a $(D NioVertexFormat) format to its $(D VkFormat) equivalent.

    Params:
        format = The $(D NioVertexFormat)
    
    Returns:
        The $(D VkFormat) equivalent.
*/
pragma(inline, true)
VkFormat toVkFormat(NioVertexFormat format) @nogc {
    final switch(format) with(NioVertexFormat) {
        case unknown:               return VK_FORMAT_UNDEFINED;
        
        /// 8-bit
        case ubyte1:                return VK_FORMAT_R8_UINT;
        case ubyte2:                return VK_FORMAT_R8G8_UINT;
        case ubyte3:                return VK_FORMAT_R8G8B8_UINT;
        case ubyte4:                return VK_FORMAT_R8G8B8A8_UINT;
        case byte1:                 return VK_FORMAT_R8_SINT;
        case byte2:                 return VK_FORMAT_R8G8_SINT;
        case byte3:                 return VK_FORMAT_R8G8B8_SINT;
        case byte4:                 return VK_FORMAT_R8G8B8A8_SINT;
        case ubyte1Norm:            return VK_FORMAT_R8_UNORM;
        case ubyte2Norm:            return VK_FORMAT_R8G8_UNORM;
        case ubyte3Norm:            return VK_FORMAT_R8G8B8_UNORM;
        case ubyte4Norm:            return VK_FORMAT_R8G8B8A8_UNORM;
        case byte1Norm:             return VK_FORMAT_R8_SNORM;
        case byte2Norm:             return VK_FORMAT_R8G8_SNORM;
        case byte3Norm:             return VK_FORMAT_R8G8B8_SNORM;
        case byte4Norm:             return VK_FORMAT_R8G8B8A8_SNORM;
        
        /// 16-bit
        case ushort1:               return VK_FORMAT_R16_UINT;   
        case ushort2:               return VK_FORMAT_R16G16_UINT;   
        case ushort3:               return VK_FORMAT_R16G16B16_UINT;   
        case ushort4:               return VK_FORMAT_R16G16B16A16_UINT;   
        case short1:                return VK_FORMAT_R16_SINT;   
        case short2:                return VK_FORMAT_R16G16_SINT;   
        case short3:                return VK_FORMAT_R16G16B16_SINT;   
        case short4:                return VK_FORMAT_R16G16B16A16_SINT;   
        case ushort1Norm:           return VK_FORMAT_R16_UNORM;       
        case ushort2Norm:           return VK_FORMAT_R16G16_UNORM;       
        case ushort3Norm:           return VK_FORMAT_R16G16B16_UNORM;       
        case ushort4Norm:           return VK_FORMAT_R16G16B16A16_UNORM;       
        case short1Norm:            return VK_FORMAT_R16_SNORM;       
        case short2Norm:            return VK_FORMAT_R16G16_SNORM;       
        case short3Norm:            return VK_FORMAT_R16G16B16_SNORM;       
        case short4Norm:            return VK_FORMAT_R16G16B16A16_SNORM; 
        
        /// 32-bit
        case uint1:                 return VK_FORMAT_R32_UINT;     
        case uint2:                 return VK_FORMAT_R32G32_UINT;     
        case uint3:                 return VK_FORMAT_R32G32B32_UINT;     
        case uint4:                 return VK_FORMAT_R32G32B32A32_UINT;     
        case int1:                  return VK_FORMAT_R32_SINT;     
        case int2:                  return VK_FORMAT_R32G32_SINT;     
        case int3:                  return VK_FORMAT_R32G32B32_SINT;     
        case int4:                  return VK_FORMAT_R32G32B32A32_SINT;     
        case float1:                return VK_FORMAT_R32_SFLOAT;         
        case float2:                return VK_FORMAT_R32G32_SFLOAT;         
        case float3:                return VK_FORMAT_R32G32B32_SFLOAT;         
        case float4:                return VK_FORMAT_R32G32B32A32_SFLOAT;               
    }
}

/**
    Converts a $(D NioPixelFormat) format to its $(D VkImageAspectFlags) equivalent.

    Params:
        format = The $(D NioPixelFormat)
    
    Returns:
        The $(D VkImageAspectFlags) equivalent.
*/
VkImageAspectFlags toVkAspect(NioPixelFormat format) @nogc {
    switch(format) with(NioPixelFormat) {
        case depth24Stencil8:       return VK_IMAGE_ASPECT_DEPTH_BIT | VK_IMAGE_ASPECT_STENCIL_BIT;
        case depth32Stencil8:       return VK_IMAGE_ASPECT_DEPTH_BIT | VK_IMAGE_ASPECT_STENCIL_BIT;
        case x24Stencil8:           return VK_IMAGE_ASPECT_STENCIL_BIT;
        case x32Stencil8:           return VK_IMAGE_ASPECT_STENCIL_BIT;
        case stencil8:              return VK_IMAGE_ASPECT_STENCIL_BIT;
        case depth16Unorm:          return VK_IMAGE_ASPECT_DEPTH_BIT;
        case depth32Float:          return VK_IMAGE_ASPECT_DEPTH_BIT;
        default:                    return VK_IMAGE_ASPECT_COLOR_BIT;
    }
}