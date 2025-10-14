#version 450

layout(location = 0) in vec3 inPosition;
layout(location = 1) in vec3 inColor;

layout(set = 0, binding = 0) uniform inUniform {
    mat4 mvp;
};

layout(location = 0) out vec3 outColor;

void main() {
    outColor = inColor;
    gl_Position = mvp * vec4(inPosition, 1.0);
}