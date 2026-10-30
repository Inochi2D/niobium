/**
    Niobium Types
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module niobium.types;

/**
    Types of data supported by shaders.
*/
enum NioDataType : uint {
    unknown =       0x00000000U,

    /// Boolean
    bool1 =         0x00000001U,
    bool2 =         0x00000002U,
    bool3 =         0x00000003U,
    bool4 =         0x00000004U,

    /// 8-bit
    ubyte1 =        0x00000010U,
    ubyte2 =        0x00000011U,
    ubyte3 =        0x00000012U,
    ubyte4 =        0x00000013U,
    byte1 =         0x00000014U,
    byte2 =         0x00000015U,
    byte3 =         0x00000016U,
    byte4 =         0x00000017U,

    /// 16-bit
    ushort1 =       0x00000020U,
    ushort2 =       0x00000021U,
    ushort3 =       0x00000022U,
    ushort4 =       0x00000023U,
    short1 =        0x00000024U,
    short2 =        0x00000025U,
    short3 =        0x00000026U,
    short4 =        0x00000027U,

    /// 16-bit floating
    half1 =         0x00000030U,
    half2 =         0x00000031U,
    half3 =         0x00000032U,
    half4 =         0x00000033U,
    half2x2 =       0x00000034U,
    half2x3 =       0x00000035U,
    half2x4 =       0x00000036U,
    half3x2 =       0x00000037U,
    half3x3 =       0x00000038U,
    half3x4 =       0x00000039U,
    half4x2 =       0x0000003AU,
    half4x3 =       0x0000003BU,
    half4x4 =       0x0000003CU,

    /// 32-bit
    uint1 =         0x00000040U,
    uint2 =         0x00000041U,
    uint3 =         0x00000042U,
    uint4 =         0x00000043U,
    int1 =          0x00000044U,
    int2 =          0x00000045U,
    int3 =          0x00000046U,
    int4 =          0x00000047U,

    /// 32-bit floating
    float1 =        0x00000050U,
    float2 =        0x00000051U,
    float3 =        0x00000052U,
    float4 =        0x00000053U,
    float2x2 =      0x00000054U,
    float2x3 =      0x00000055U,
    float2x4 =      0x00000056U,
    float3x2 =      0x00000057U,
    float3x3 =      0x00000058U,
    float3x4 =      0x00000059U,
    float4x2 =      0x0000005AU,
    float4x3 =      0x0000005BU,
    float4x4 =      0x0000005CU,

    /// 64-bit
    ulong1 =        0x00000060U,
    ulong2 =        0x00000061U,
    ulong3 =        0x00000062U,
    ulong4 =        0x00000063U,
    long1 =         0x00000064U,
    long2 =         0x00000065U,
    long3 =         0x00000066U,
    long4 =         0x00000067U,

    /// Pixel formats
    r8Unorm =       0x00000070U,
    r8Snorm =       0x00000071U,
    rg8Unorm =      0x00000072U,
    rg8UnormSRGB =  0x00000073U,
    rg8Snorm =      0x00000074U,
    rg16Unorm =     0x00000075U,
    rg16Snorm =     0x00000076U,
    rgba8Snorm =    0x00000077U,
    rgba8Unorm =    0x00000078U,
    rgba16Unorm =   0x00000079U,
    rgba16Snorm =   0x0000007AU,

    /// Resource Types
    texture =       0x00000080U,
    sampler =       0x00000081U,
    structure =     0x00000082U,
    array =         0x00000083U,
    pointer =       0x00000084U,
}

/**
    2D Extents
*/
struct NioExtent2D {
    uint width;
    uint height;
}

/**
    2D Origin
*/
struct NioOrigin2D {
    uint x;
    uint y;
}

/**
    3D Extents
*/
struct NioExtent3D {
    uint width;
    uint height;
    uint depth;
}

/**
    3D Origin
*/
struct NioOrigin3D {
    uint x;
    uint y;
    uint z;
}

/**
    3D Region
*/
union NioRegion3D {
    struct {
        uint x;
        uint y;
        uint z;
        uint width;
        uint height;
        uint depth;
    }
    struct {
        NioOrigin3D origin;
        NioExtent3D extent;
    }
}

/**
    An RGBA color value.
*/
struct NioColor {
    float r;
    float g;
    float b;
    float a;
}

/**
    A viewport
*/
struct NioViewport {

    /**
        The X coordinate of upper-left corner of the viewport.
    */
    float originX;

    /**
        The Y coordinate of upper-left corner of the viewport.
    */
    float originY;

    /**
        The width of the viewport, in pixels.
    */
    float width;

    /**
        The height of the viewport, in pixels.
    */
    float height;

    /**
        The near-plane of the viewport.
    */
    float near;

    /**
        The far-plane of the viewport.
    */
    float far;
}

/**
    A scissor rectangle
*/
struct NioScissorRect {

    /**
        The X coordinate of upper-left corner of the 
        scissor rectangle.
    */
    float x;

    /**
        The Y coordinate of upper-left corner of the 
        scissor rectangle.
    */
    float y;

    /**
        The width of the viewport, in pixels.
    */
    float width;

    /**
        The height of the viewport, in pixels.
    */
    float height;
}