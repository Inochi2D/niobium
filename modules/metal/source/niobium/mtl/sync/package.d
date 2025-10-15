/**
    Niobium Metal Synchronisation
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module niobium.mtl.sync;
import metal.commandencoder;
import metal.rendercommandencoder;

public import niobium.sync;
public import niobium.mtl.sync.fence;
public import niobium.mtl.sync.semaphore;

/**
    Converts a $(D NioPipelineStage) type to its $(D MTLStages) equivalent.

    Params:
        stages = The $(D NioPipelineStage)
    
    Returns:
        The $(D MTLStages) equivalent.
*/
pragma(inline, true)
MTLStages toMTLStages(NioPipelineStage stages) @nogc {
    uint result;

    if (stages & NioPipelineStage.transfer)
        result |= MTLStages.Blit;

    if (stages & NioPipelineStage.compute)
        result |= MTLStages.Dispatch;

    if (stages & NioPipelineStage.vertex)
        result |= MTLStages.Vertex;

    if (stages & NioPipelineStage.fragment)
        result |= MTLStages.Fragment;

    if (stages & NioPipelineStage.task)
        result |= MTLStages.Object;

    if (stages & NioPipelineStage.mesh)
        result |= MTLStages.Mesh;

    if (stages & NioPipelineStage.raytracing)
        result |= MTLStages.AccelerationStructure;

    return cast(MTLStages) result;
}

/**
    Converts a $(D NioRenderStage) type to its $(D MTLRenderStages) equivalent.

    Params:
        stages = The $(D NioRenderStage)
    
    Returns:
        The $(D MTLRenderStages) equivalent.
*/
pragma(inline, true)
MTLRenderStages toMTLRenderStages(NioRenderStage stages) @nogc {
    uint result;

    if (stages & NioRenderStage.vertex)
        result |= MTLStages.Vertex;

    if (stages & NioRenderStage.fragment)
        result |= MTLStages.Fragment;

    if (stages & NioRenderStage.task)
        result |= MTLStages.Object;

    if (stages & NioRenderStage.mesh)
        result |= MTLStages.Mesh;

    return cast(MTLRenderStages) result;
}