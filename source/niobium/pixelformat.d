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
    depth24Stencil8 =       0x00000100U,
    depth32Stencil8 =       0x00000101U,
    x24Stencil8 =           0x00000102U,
    x32Stencil8 =           0x00000103U,
}