/**
    Niobium Vulkan Depth Stencil State Objects
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module niobium.vk.depthstencil;
import niobium.vk.device;
import vulkan.core;
import vulkan.eh;
import numem;
import nulib;

public import niobium.depthstencil;

/**
    A depth-stencil state object.

    Once a depth-stencil object is created its state
    is immutable.
*/
class NioVkDepthStencilState : NioDepthStencilState {
public:
@nogc:

    /**
        Constructs a new depth stencil state.

        Params:
            device =    The device that "owns" this depth stencil state.
            desc =      The descriptor for this depth stencil state.
    */
    this(NioDevice device, NioDepthStencilStateDescriptor desc) {
        super(device, desc);
    }

    /**
        Applies the depth-stencil state.

        Params:
            buffer = The command buffer to write the state to.
    */
    void apply(VkCommandBuffer buffer) {

        // Depth state.
        vkCmdSetDepthTestEnable(buffer, cast(VkBool32)desc.depthTestEnabled);
        if (desc.depthTestEnabled) {
            vkCmdSetDepthWriteEnable(buffer, cast(VkBool32)desc.depthState.depthWriteEnabled);
            vkCmdSetDepthCompareOp(buffer, desc.depthState.compareFunction.toVkCompareOp());
        }

        vkCmdSetStencilTestEnable(buffer, cast(VkBool32)desc.stencilTestEnabled);
        if (desc.stencilTestEnabled) {

            // Front face
            vkCmdSetStencilCompareMask(buffer, VK_STENCIL_FACE_FRONT_BIT, desc.frontStencilState.readMask);
            vkCmdSetStencilWriteMask(buffer, VK_STENCIL_FACE_FRONT_BIT, desc.frontStencilState.writeMask);
            vkCmdSetStencilOp(
                buffer, 
                VK_STENCIL_FACE_FRONT_BIT,
                desc.frontStencilState.failureOp.toVkStencilOp(),
                desc.frontStencilState.passOp.toVkStencilOp(),
                desc.frontStencilState.depthFailureOp.toVkStencilOp(),
                desc.frontStencilState.compareFunction.toVkCompareOp()
            );

            // Back face
            vkCmdSetStencilCompareMask(buffer, VK_STENCIL_FACE_BACK_BIT, desc.backStencilState.readMask);
            vkCmdSetStencilWriteMask(buffer, VK_STENCIL_FACE_BACK_BIT, desc.backStencilState.writeMask);
            vkCmdSetStencilOp(
                buffer, 
                VK_STENCIL_FACE_BACK_BIT,
                desc.backStencilState.failureOp.toVkStencilOp(),
                desc.backStencilState.passOp.toVkStencilOp(),
                desc.backStencilState.depthFailureOp.toVkStencilOp(),
                desc.backStencilState.compareFunction.toVkCompareOp()
            );
        }
    }
}

/**
    Converts a $(D NioCompareOp) type to its $(D VkCompareOp) equivalent.

    Params:
        value = The $(D NioCompareOp)
    
    Returns:
        The $(D VkCompareOp) equivalent.
*/
pragma(inline, true)
VkCompareOp toVkCompareOp(NioCompareOp value) @nogc {
    final switch(value) with(NioCompareOp) {
        case never:         return VK_COMPARE_OP_NEVER;
        case less:          return VK_COMPARE_OP_LESS;
        case equal:         return VK_COMPARE_OP_EQUAL;
        case lessEqual:     return VK_COMPARE_OP_LESS_OR_EQUAL;
        case greater:       return VK_COMPARE_OP_GREATER;
        case notEqual:      return VK_COMPARE_OP_NOT_EQUAL;
        case greaterEqual:  return VK_COMPARE_OP_GREATER_OR_EQUAL;
        case always:        return VK_COMPARE_OP_ALWAYS;
    }
}

/**
    Converts a $(D NioStencilOp) type to its $(D VkStencilOp) equivalent.

    Params:
        value = The $(D NioStencilOp)
    
    Returns:
        The $(D VkStencilOp) equivalent.
*/
pragma(inline, true)
VkStencilOp toVkStencilOp(NioStencilOp value) @nogc {
    final switch(value) with(NioStencilOp) {
        case keep:              return VK_STENCIL_OP_KEEP;
        case zero:              return VK_STENCIL_OP_ZERO;
        case replace:           return VK_STENCIL_OP_REPLACE;
        case incrementClamp:    return VK_STENCIL_OP_INCREMENT_AND_CLAMP;
        case decrementClamp:    return VK_STENCIL_OP_DECREMENT_AND_CLAMP;
        case invert:            return VK_STENCIL_OP_INVERT;
        case incrementWrap:     return VK_STENCIL_OP_INCREMENT_AND_WRAP;
        case decrementWrap:     return VK_STENCIL_OP_DECREMENT_AND_WRAP;
    }
}
