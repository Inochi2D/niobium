/**
    Niobium Pixel Formats.
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module niobium.pixelformat;

/**
    Supported pixel formats of Niobium.
*/
enum NioPixelFormat : uint {

    /**
        Unknown format.
    */
    unknown =               0x00000000U,

    // R
    a8Unorm =               0x00000001U,
    r8Unorm =               0x00000002U,
    r8UnormSRGB =           0x00000003U,
    r8Snorm =               0x00000004U,
    r8Uint =                0x00000005U,
    r8Sint =                0x00000006U,
    r16Unorm =              0x00000007U,
    r16Uint =               0x00000008U,
    r16Sint =               0x00000009U,
    r16Float =              0x0000000AU,
    r32Uint =               0x0000000BU,
    r32Sint =               0x0000000CU,
    r32Float =              0x0000000DU,

    // RG
    rg8Unorm =              0x00000010U,
    rg8UnormSRGB =          0x00000011U,
    rg8Snorm =              0x00000012U,
    rg8Uint =               0x00000013U,
    rg8Sint =               0x00000014U,
    rg16Unorm =             0x00000015U,
    rg16Snorm =             0x00000016U,
    rg16Uint =              0x00000017U,
    rg16Sint =              0x00000018U,
    rg16Float =             0x00000019U,
    rg32Uint =              0x0000001AU,
    rg32Sint =              0x0000001BU,
    rg32Float =             0x0000001CU,

    // RGBA
    rgba8Unorm =            0x00000020U,
    rgba8UnormSRGB =        0x00000021U,
    rgba8Snorm =            0x00000022U,
    rgba8Uint =             0x00000023U,
    rgba8Sint =             0x00000024U,
    rgba16Unorm =           0x00000025U,
    rgba16Snorm =           0x00000026U,
    rgba16Uint =            0x00000027U,
    rgba16Sint =            0x00000028U,
    rgba32Uint =            0x0000002AU,
    rgba32Sint =            0x0000002BU,
    rgba32Float =           0x0000002CU,

    // BGRA
    bgra8Unorm =            0x00000030U,
    bgra8UnormSRGB =        0x00000031U,

    // BC
    rgbaUnorm_BC1 =         0x00000050U,
    rgbaUnormSRGB_BC1 =     0x00000051U,
    rgbaUnorm_BC2 =         0x00000052U,
    rgbaUnormSRGB_BC2 =     0x00000053U,
    rgbaUnorm_BC3 =         0x00000054U,
    rgbaUnormSRGB_BC3 =     0x00000055U,
    rgbaUnorm_BC7 =         0x00000056U,
    rgbaUnormSRGB_BC7 =     0x00000057U,

    // Depth-Stencil
    depth16Unorm =          0x00000100U,
    depth32Float =          0x00000101U,
    stencil8 =              0x00000102U,
    depth24Stencil8 =       0x00000103U,
    depth32Stencil8 =       0x00000104U,
    x24Stencil8 =           0x00000105U,
    x32Stencil8 =           0x00000106U,
}



/**
    Gets the byte-stride for a given pixel format.

    Params:
        format = The $(D NioPixelFormat)
    
    Returns:
        The stride in bytes.
*/
pragma(inline, true)
uint toStride(NioPixelFormat format) @nogc {
    final switch(format) with(NioPixelFormat) {
        case rgbaUnorm_BC1:
        case rgbaUnormSRGB_BC1:
        case rgbaUnorm_BC2:
        case rgbaUnormSRGB_BC2:
        case rgbaUnorm_BC3:
        case rgbaUnormSRGB_BC3:
        case rgbaUnorm_BC7:
        case rgbaUnormSRGB_BC7:
        case unknown:               return 0;

        // 8-bit
        case stencil8:
        case a8Unorm:
        case r8Unorm:
        case r8UnormSRGB:
        case r8Snorm:
        case r8Uint:
        case r8Sint:                return 1;
        
        // 16-bit
        case depth16Unorm:
        case r16Unorm:
        case r16Uint:
        case r16Sint:
        case r16Float:
        case rg8Unorm:
        case rg8UnormSRGB:
        case rg8Snorm:
        case rg8Uint:
        case rg8Sint:               return 2;

        // 32-bit
        case depth32Float:
        case rgba8Unorm:
        case rgba8UnormSRGB:
        case rgba8Snorm:
        case rgba8Uint:
        case rgba8Sint:
        case r32Uint:
        case r32Sint:
        case r32Float:
        case rg16Unorm:
        case rg16Snorm:
        case rg16Uint:
        case rg16Sint:
        case rg16Float:
        case bgra8Unorm:
        case bgra8UnormSRGB:
        case depth24Stencil8:
        case x24Stencil8:           return 4;

        // 40-bit
        case depth32Stencil8:
        case x32Stencil8:           return 5;

        // 64-bit
        case rg32Uint:
        case rg32Sint:
        case rg32Float:
        case rgba16Unorm:
        case rgba16Snorm:
        case rgba16Uint:
        case rgba16Sint:            return 8;

        // 128-bit
        case rgba32Uint:
        case rgba32Sint:
        case rgba32Float:           return 16;
    }
}