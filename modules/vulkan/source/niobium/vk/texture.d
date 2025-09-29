/**
    Niobium Textures
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module niobium.vk.texture;
import niobium.texture;
import niobium.resource;
import niobium.device;
import vulkan.core;
import numem;

// /**
//     Vulkan Texture
// */
// class NioVkTexture : NioTexture {
// private:
// @nogc:
//     VkImageLayout layout_;
//     VkImage handle_;
// public:
// }

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
        case depth24Stencil8:       return VK_FORMAT_D24_UNORM_S8_UINT;
        case depth32Stencil8:       return VK_FORMAT_D32_SFLOAT_S8_UINT;
        case x24Stencil8:           return VK_FORMAT_D24_UNORM_S8_UINT;
        case x32Stencil8:           return VK_FORMAT_D32_SFLOAT_S8_UINT;
    }
}