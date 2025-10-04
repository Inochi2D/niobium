/**
    Niobium Vertex Formats
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module niobium.vertexformat;

/**
    The different valid formats for vertex attributes.
*/
enum NioVertexFormat : uint {
    unknown =       0x00000000U,

    /// 8-bit
    ubyte1 =        0x00000001U,
    ubyte2 =        0x00000002U,
    ubyte3 =        0x00000003U,
    ubyte4 =        0x00000004U,
    byte1 =         0x00000005U,
    byte2 =         0x00000006U,
    byte3 =         0x00000007U,
    byte4 =         0x00000008U,
    ubyte1Norm =    0x00000009U,
    ubyte2Norm =    0x0000000AU,
    ubyte3Norm =    0x0000000BU,
    ubyte4Norm =    0x0000000CU,
    byte1Norm =     0x0000000DU,
    byte2Norm =     0x0000000EU,
    byte3Norm =     0x0000000FU,
    byte4Norm =     0x00000010U,

    /// 16-bit
    ushort1 =       0x00000011U,
    ushort2 =       0x00000012U,
    ushort3 =       0x00000013U,
    ushort4 =       0x00000014U,
    short1 =        0x00000015U,
    short2 =        0x00000016U,
    short3 =        0x00000017U,
    short4 =        0x00000018U,
    ushort1Norm =   0x00000019U,
    ushort2Norm =   0x0000001AU,
    ushort3Norm =   0x0000001BU,
    ushort4Norm =   0x0000001CU,
    short1Norm =    0x0000001DU,
    short2Norm =    0x0000001EU,
    short3Norm =    0x0000001FU,
    short4Norm =    0x00000020U,

    /// 32-bit
    uint1 =         0x00000021U,
    uint2 =         0x00000022U,
    uint3 =         0x00000023U,
    uint4 =         0x00000024U,
    int1 =          0x00000025U,
    int2 =          0x00000026U,
    int3 =          0x00000027U,
    int4 =          0x00000028U,
    float1 =        0x00000029U,
    float2 =        0x0000002AU,
    float3 =        0x0000002BU,
    float4 =        0x0000002CU, 
}