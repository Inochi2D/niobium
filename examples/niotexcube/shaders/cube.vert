#version 450

layout(location = 0) in vec3 inPosition;
layout(location = 1) in vec2 inUV;

layout(set = 0, binding = 1) uniform inUniform {
    mat4 mvp;
};

layout(location = 0) out vec2 outUV;

void main() {
    outUV = inUV;
    gl_Position = mvp * vec4(inPosition, 1.0);
}