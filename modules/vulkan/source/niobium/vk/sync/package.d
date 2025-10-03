/**
    Niobium Vulkan Synchronisation
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module niobium.vk.sync;
import niobium.texture;
import niobium.device;
import niobium.buffer;
import niobium.heap;
import vulkan.core;

public import niobium.sync;
public import niobium.vk.sync.fence;
public import niobium.vk.sync.semaphore;

/**
    Converts a $(D NioRenderStage) format to its $(D VkPipelineStageFlags2) equivalent.

    Params:
        stage = The $(D NioRenderStage)
    
    Returns:
        The $(D VkPipelineStageFlags2) equivalent.
*/
VkPipelineStageFlags2 toVkPipelineStageFlags2(NioRenderStage stage) @nogc {
    VkPipelineStageFlags2 result = 0;

    if (stage & NioRenderStage.task)
        result |= VK_PIPELINE_STAGE_2_TASK_SHADER_BIT_EXT;

    if (stage & NioRenderStage.mesh)
        result |= VK_PIPELINE_STAGE_2_MESH_SHADER_BIT_EXT;

    if (stage & NioRenderStage.vertex)
        result |= VK_PIPELINE_STAGE_2_VERTEX_INPUT_BIT | VK_PIPELINE_STAGE_2_VERTEX_SHADER_BIT;

    if (stage & NioRenderStage.fragment)
        result |= VK_PIPELINE_STAGE_2_EARLY_FRAGMENT_TESTS_BIT | VK_PIPELINE_STAGE_2_FRAGMENT_SHADER_BIT | VK_PIPELINE_STAGE_2_LATE_FRAGMENT_TESTS_BIT;

    return result;
}
/**
    Converts a $(D NioPipelineStage) format to its $(D VkPipelineStageFlags2) equivalent.

    Params:
        stage = The $(D NioPipelineStage)
    
    Returns:
        The $(D VkPipelineStageFlags2) equivalent.
*/
VkPipelineStageFlags2 toVkPipelineStageFlags2(NioPipelineStage stage) @nogc {
    VkPipelineStageFlags2 result = 0;

    if (stage & NioPipelineStage.transfer)
        result |= VK_PIPELINE_STAGE_2_ALL_TRANSFER_BIT;

    if (stage & NioPipelineStage.compute)
        result |= VK_PIPELINE_STAGE_2_COMPUTE_SHADER_BIT;

    if (stage & NioPipelineStage.vertex)
        result |= VK_PIPELINE_STAGE_2_VERTEX_INPUT_BIT | VK_PIPELINE_STAGE_2_VERTEX_SHADER_BIT;

    if (stage & NioPipelineStage.fragment)
        result |= VK_PIPELINE_STAGE_2_EARLY_FRAGMENT_TESTS_BIT | VK_PIPELINE_STAGE_2_FRAGMENT_SHADER_BIT | VK_PIPELINE_STAGE_2_LATE_FRAGMENT_TESTS_BIT;

    if (stage & NioPipelineStage.task)
        result |= VK_PIPELINE_STAGE_2_TASK_SHADER_BIT_EXT;

    if (stage & NioPipelineStage.mesh)
        result |= VK_PIPELINE_STAGE_2_MESH_SHADER_BIT_EXT;

    if (stage & NioPipelineStage.raytracing)
        result |= VK_PIPELINE_STAGE_2_RAY_TRACING_SHADER_BIT_KHR;

    return result;
}