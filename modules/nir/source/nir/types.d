/**
    NIR Common Types
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module nir.types;
import nir.ir.atom;
import vulkan.core;

/**
    The different kinds of shader stages that a shader
    can apply to.
*/
enum NirShaderStage : uint {
    
    /**
        Vertex shader stage
    */
    vertex =            0x00000000U,
    
    /**
        Fragment shader stage
    */
    fragment =          0x00000001U,

    /**
        Mesh task shader stage
    */
    task =              0x00000002U,

    /**
        Mesh shader stage
    */
    mesh =              0x00000004U,
    
    /**
        Compute kernel shader stage
    */
    kernel =            0x00000008U,
}

/**
    Converts a $(D NirShaderStage) format to its $(D ExecutionModel) equivalent.

    Params:
        stage = The $(D NirShaderStage)
    
    Returns:
        The $(D ExecutionModel) equivalent.
*/
pragma(inline, true)
ExecutionModel toExecutionModel(NirShaderStage stage) @nogc {
    final switch(stage) with(NirShaderStage) {
        case vertex:    return ExecutionModel.Vertex;
        case fragment:  return ExecutionModel.Fragment;
        case task:      return ExecutionModel.TaskEXT;
        case mesh:      return ExecutionModel.MeshEXT;
        case kernel:    return ExecutionModel.Kernel;
    }
}

/**
    Converts a $(D ExecutionModel) format to its $(D NirShaderStage) equivalent.

    Params:
        stage = The $(D ExecutionModel)
    
    Returns:
        The $(D NirShaderStage) equivalent.
*/
pragma(inline, true)
NirShaderStage toNirShaderStage(ExecutionModel stage) @nogc {
    switch(stage) with(ExecutionModel) {
        default:        return cast(NirShaderStage)0;
        case Vertex:    return NirShaderStage.vertex;
        case Fragment:  return NirShaderStage.fragment;
        case TaskEXT:   return NirShaderStage.task;
        case MeshEXT:   return NirShaderStage.mesh;
        case Kernel:    return NirShaderStage.kernel;
    }
}

/**
    Converts a $(D NirShaderStage) format to its $(D VkShaderStageFlags) equivalent.

    Params:
        stage = The $(D NirShaderStage)
    
    Returns:
        The $(D VkShaderStageFlags) equivalent.
*/
pragma(inline, true)
VkShaderStageFlags toVkShaderStage(NirShaderStage stage) @nogc {
    VkShaderStageFlags result = 0;
    
    if (stage & NirShaderStage.vertex)
        result |= VK_SHADER_STAGE_VERTEX_BIT;
    
    if (stage & NirShaderStage.task)
        result |= VK_SHADER_STAGE_TASK_BIT_EXT;
    
    if (stage & NirShaderStage.mesh)
        result |= VK_SHADER_STAGE_MESH_BIT_EXT;
    
    if (stage & NirShaderStage.fragment)
        result |= VK_SHADER_STAGE_FRAGMENT_BIT;
    
    if (stage & NirShaderStage.kernel)
        result |= VK_SHADER_STAGE_COMPUTE_BIT;

    return result;
}