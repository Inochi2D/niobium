#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float3 position [[attribute(0)]];
    float2 uv       [[attribute(1)]];
};

struct Uniform {
    float4x4 mvp;
};

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

vertex VertexOut vertex_main(VertexIn in [[stage_in]], constant Uniform& uniformIn [[buffer(1)]]) {
    VertexOut out;
    out.position = uniformIn.mvp * float4(in.position, 1);
    out.uv = in.uv;
    return out;
}

fragment float4 fragment_main(VertexOut in [[stage_in]], sampler samplerIn [[sampler(0)]], texture2d<float> textureIn [[texture(0)]]) {
    return textureIn.sample(samplerIn, in.uv);
}