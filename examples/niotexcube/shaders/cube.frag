#version 450

layout(location = 0) in vec2 inUV;
layout(location = 0) out vec4 outColor;

layout(set = 1, binding = 0) uniform texture2D inTexture;
layout(set = 2, binding = 0) uniform sampler inSampler;

void main() {
    outColor = texture(sampler2D(inTexture, inSampler), inUV);
}