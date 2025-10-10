/**
    Niobium Vulkan Render Encoders
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module niobium.vk.cmd.renderencoder;
import niobium.vk.cmd.buffer;
import niobium.vk.resource;
import niobium.vk.sampler;
import niobium.vk.device;
import niobium.vk.render;
import niobium.vk.sync;
import niobium.types;
import niobium.cmd;
import vulkan.loader;
import vulkan.core;
import vulkan.eh;
import nulib.math : min, max;
import numem;

/**
    A short-lived object which encodes rendering commands 
    into a $(D NioCommandBuffer).
    Only one $(D NioCommandEncoder) can be active at a time 
    for a $(D NioCommandBuffer).

    To end encoding call $(D endEncoding).
*/
class NioVkRenderCommandEncoder : NioRenderCommandEncoder {
private:
@nogc:
    VK_EXT_extended_dynamic_state3 dyn3;
    VkRect2D renderArea;

    void transitionIfNotLayout(T)(T attachment, VkImageLayout layout) {
        auto nvkTexture = cast(NioVkTexture)attachment.texture;
        if (nvkTexture && nvkTexture.layout != layout)
            this.transitionTextureTo(nvkTexture, layout);
        
        auto nvkResolveTexture = cast(NioVkTexture)attachment.resolveTexture;
        if (nvkResolveTexture && nvkResolveTexture.layout != layout)
            this.transitionTextureTo(nvkResolveTexture, layout);
    }

    void setup(NioRenderPassDescriptor desc) {
        VkRenderingInfo renderInfo = VkRenderingInfo(
            colorAttachmentCount: cast(uint)desc.colorAttachments.length,
            layerCount: 1,
            viewMask: 0,
        );

        // Color attachments.
        renderInfo.pColorAttachments = cast(VkRenderingAttachmentInfo*)nu_malloc(renderInfo.colorAttachmentCount * VkRenderingAttachmentInfo.sizeof);
        foreach(i, attachment; desc.colorAttachments) {
            this.transitionIfNotLayout(attachment, VK_IMAGE_LAYOUT_ATTACHMENT_OPTIMAL);

            auto pAttachment = (cast(VkRenderingAttachmentInfo*)renderInfo.pColorAttachments);
            pAttachment[i] = attachment.toVkRenderingAttachmentInfo();
            
            auto nvkTexture = cast(NioVkTexture)attachment.texture;
            renderInfo.renderArea.extent.width = max(renderInfo.renderArea.extent.width, nvkTexture.width);
            renderInfo.renderArea.extent.height = max(renderInfo.renderArea.extent.height, nvkTexture.height);
        }
        renderArea = renderInfo.renderArea;

        // Depth attachment.
        if (desc.depthAttachment.texture || desc.depthAttachment.resolveTexture) {
            this.transitionIfNotLayout(desc.depthAttachment, VK_IMAGE_LAYOUT_ATTACHMENT_OPTIMAL);

            auto depthAttachment = cast(VkRenderingAttachmentInfo*)nu_malloc(VkRenderingAttachmentInfo.sizeof);
            *depthAttachment = desc.depthAttachment.toVkRenderingAttachmentInfo();

            renderInfo.pDepthAttachment = depthAttachment;
        }

        // Stencil attachment.
        if (desc.stencilAttachment.texture || desc.stencilAttachment.resolveTexture) {
            this.transitionIfNotLayout(desc.stencilAttachment, VK_IMAGE_LAYOUT_ATTACHMENT_OPTIMAL);

            auto stencilAttachment = cast(VkRenderingAttachmentInfo*)nu_malloc(VkRenderingAttachmentInfo.sizeof);
            *stencilAttachment = desc.stencilAttachment.toVkRenderingAttachmentInfo();
            renderInfo.pStencilAttachment = stencilAttachment;
        }

        vkCmdBeginRendering(vkcmdbuffer, &renderInfo);

        // Free temporaries.
        nu_free(cast(void*)renderInfo.pColorAttachments);
        nu_free(cast(void*)renderInfo.pDepthAttachment);
        nu_free(cast(void*)renderInfo.pStencilAttachment);

        auto nvkDevice = cast(NioVkDevice)cmdbuffer.device;
        nvkDevice.handle.loadProcs(dyn3);
    }

    NioPrimitive prim_;
    void setTopology(NioPrimitive prim) {
        if (prim == prim_)
            return;

        vkCmdSetPrimitiveTopology(vkcmdbuffer, prim.toVkPrimitive());
        this.prim_ = prim;
    }

    NioVkBuffer index_;
    NioIndexType indexType_;
    void setIndexBuffer(NioVkBuffer index, NioIndexType indexType) {
        if (index is index_ && indexType_ == indexType)
            return;
        
        vkCmdBindIndexBuffer(vkcmdbuffer, index.handle, 0, indexType.toVkIndexType);
        this.indexType_ = indexType;
        this.index_ = index;
    }

public:

    /// Destructor
    ~this() {
        vkCmdEndRendering(vkcmdbuffer);
    }

    /**
        Constructs a new command encoder.
    */
    this(NioCommandBuffer buffer, NioRenderPassDescriptor desc) {
        super(buffer);
        this.setup(desc);
    }

    /// Command Encoder Functions
    mixin VkCommandEncoderFunctions;

    /**
        Encodes a command which instructs the GPU
        to wait for the fence to be signalled before
        proceeding.

        Params:
            fence =         The fence to wait for.
            beforeStages =  Which stages will be waiting.
    */
    override void waitForFence(NioFence fence, NioRenderStage beforeStages) {
        auto vkevent = (cast(NioVkFence)fence).handle;
        auto barrierInfo = VkMemoryBarrier2(
            srcStageMask: VK_PIPELINE_STAGE_2_TOP_OF_PIPE_BIT,
            srcAccessMask: VK_ACCESS_2_MEMORY_READ_BIT,
            dstStageMask: beforeStages.toVkPipelineStageFlags2(),
            dstAccessMask: VK_ACCESS_2_MEMORY_READ_BIT | VK_ACCESS_2_MEMORY_WRITE_BIT
        );
        auto depInfo = VkDependencyInfo(
            memoryBarrierCount: 1,
            pMemoryBarriers: &barrierInfo
        );
        vkCmdWaitEvents2(
            vkcmdbuffer, 
            1, &vkevent,
            &depInfo
        );
    }

    /**
        Encodes a command which instructs the GPU
        to signal the fence.

        Params:
            fence =         The fence to signal.
            afterStages =   When in the pipeline to signal.
    */
    override void signalFence(NioFence fence, NioRenderStage afterStages) {
        auto vkevent = (cast(NioVkFence)fence).handle;
        auto barrierInfo = VkMemoryBarrier2(
            srcStageMask: VK_PIPELINE_STAGE_2_TOP_OF_PIPE_BIT,
            srcAccessMask: VK_ACCESS_2_MEMORY_READ_BIT,
            dstStageMask: afterStages.toVkPipelineStageFlags2(),
            dstAccessMask: VK_ACCESS_2_MEMORY_READ_BIT | VK_ACCESS_2_MEMORY_WRITE_BIT
        );
        auto depInfo = VkDependencyInfo(
            memoryBarrierCount: 1,
            pMemoryBarriers: &barrierInfo
        );
        vkCmdSetEvent2(
            vkcmdbuffer, 
            vkevent,
            &depInfo
        );
    }

    /**
        Inserts a memory barrier into the command stream.

        Params:
            resource =  The resource to set a barrier for.
            after =     The render stages of previous commands that modify the resource.
            after =     The render stages of subsequent commands that modify the resource.
    */
    override void memoryBarrier(NioResource resource, NioRenderStage after, NioRenderStage before) {
        auto barrierInfo = VkMemoryBarrier2(
            srcStageMask: after.toVkPipelineStageFlags2(),
            srcAccessMask: VK_ACCESS_2_MEMORY_READ_BIT,
            dstStageMask: before.toVkPipelineStageFlags2(),
            dstAccessMask: VK_ACCESS_2_MEMORY_READ_BIT | VK_ACCESS_2_MEMORY_WRITE_BIT
        );
        auto depInfo = VkDependencyInfo(
            memoryBarrierCount: 1,
            pMemoryBarriers: &barrierInfo
        );
        vkCmdPipelineBarrier2(
            vkcmdbuffer,
            &depInfo
        );
    }

    /**
        Sets the primary viewport of the render pass.

        Params:
            viewport = The viewport.
    */
    override void setViewport(NioViewport viewport) {
        vkCmdSetViewportWithCount(vkcmdbuffer, 1, cast(VkViewport*)&viewport);
    }

    /**
        Sets the primary scissor rectangle of the render pass.

        Params:
            scissor = The scissor rectangle.
    */
    override void setScissor(NioScissorRect scissor) {
        vkCmdSetScissorWithCount(vkcmdbuffer, 1, cast(VkRect2D*)&scissor);
    }

    /**
        Sets the active culling mode for the render pass.

        Params:
            culling = The culling mode.
    */
    override void setCulling(NioCulling culling) {
        vkCmdSetCullMode(vkcmdbuffer, culling.toVkCullMode());
    }

    /**
        Sets the active front-face winding for the render pass.

        Params:
            winding = The front-face winding.
    */
    override void setFaceWinding(NioFaceWinding winding) {
        vkCmdSetFrontFace(vkcmdbuffer, winding.toVkFrontFace());
    }

    /**
        Sets the active constant blending color for the render pass.

        Params:
            color = The constant blending color.
    */
    override void setBlendColor(NioColor color) {
        float[4] values = *(cast(float[4]*)&color);
        vkCmdSetBlendConstants(vkcmdbuffer, values);
    }

    /**
        Sets the active render pipeline for the render pass.

        Params:
            pipeline =  The pipeline.
    */
    override void setPipeline(NioRenderPipeline pipeline) {
        auto nvkRenderPipeline = cast(NioVkRenderPipeline)pipeline;
        vkCmdBindPipeline(vkcmdbuffer, VK_PIPELINE_BIND_POINT_GRAPHICS, nvkRenderPipeline.handle);
        this.setCulling(NioCulling.none);
        this.setViewport(NioViewport(renderArea.offset.x, renderArea.offset.y, renderArea.extent.width, renderArea.extent.height, 0, 1));
        this.setScissor(NioScissorRect(renderArea.offset.x, renderArea.offset.y, renderArea.extent.width, renderArea.extent.height));
        
        vkCmdSetDepthBiasEnable(vkcmdbuffer, VK_TRUE);
        vkCmdSetDepthBias(vkcmdbuffer, 0, 0, 0);
        vkCmdSetDepthBoundsTestEnable(vkcmdbuffer, VK_TRUE);
        vkCmdSetDepthBounds(vkcmdbuffer, 0, 1);
        vkCmdSetFrontFace(vkcmdbuffer, VK_FRONT_FACE_COUNTER_CLOCKWISE);
        vkCmdSetPrimitiveRestartEnable(vkcmdbuffer, VK_FALSE);
        dyn3.vkCmdSetDepthClampEnableEXT(vkcmdbuffer, VK_FALSE);
        dyn3.vkCmdSetPolygonModeEXT(vkcmdbuffer, VK_POLYGON_MODE_FILL);
    }

    /**
        Sets the given buffer as the active buffer at the given
        slot in the vertex shader argument table.

        Params:
            buffer =    The buffer to set.
            offset =    The offset into the buffer, in bytes.
            slot =      The slot in the argument table to set.
    */
    override void setVertexBuffer(NioBuffer buffer, ulong offset, uint slot) {
        auto nvkBuffer = cast(NioVkBuffer)buffer;
        auto handle = nvkBuffer.handle;

        vkCmdBindVertexBuffers(vkcmdbuffer, slot, 1, &handle, &offset);
    }

    /**
        Sets the given texture as the active texture at the given
        slot in the vertex shader argument table.

        Params:
            texture =   The texture to set.
            slot =      The slot in the argument table to set.
    */
    override void setVertexTexture(NioTexture texture, uint slot) {
        
    }

    /**
        Sets the given sampler as the active sampler at the given
        slot in the vertex shader argument table.

        Params:
            sampler =   The sampler to set.
            slot =      The slot in the argument table to set.
    */
    override void setVertexSampler(NioSampler sampler, uint slot) {

    }

    /**
        Sets the given buffer as the active buffer at the given
        slot in the fragment shader argument table.

        Params:
            buffer =    The buffer to set.
            offset =    The offset into the buffer, in bytes.
            slot =      The slot in the argument table to set.
    */
    override void setFragmentBuffer(NioBuffer buffer, ulong offset, uint slot) {
        
    }

    /**
        Sets the given texture as the active texture at the given
        slot in the fragment shader argument table.

        Params:
            texture =   The texture to set.
            slot =      The slot in the argument table to set.
    */
    override void setFragmentTexture(NioTexture texture, uint slot) {

    }

    /**
        Sets the given sampler as the active sampler at the given
        slot in the fragment shader argument table.

        Params:
            sampler =   The sampler to set.
            slot =      The slot in the argument table to set.
    */
    override void setFragmentSampler(NioSampler sampler, uint slot) {
        
    }

    /**
        Enocodes a draw command using the bound vertex buffers.

        Params:
            prim =          The primitive topology to draw with.
            firstVertex =   Offset to the first vertex.
            vertexCount =   The amount of vertices to draw.
    */
    override void draw(NioPrimitive prim, uint firstVertex, uint vertexCount) {
        this.setTopology(prim);
        vkCmdDraw(vkcmdbuffer, vertexCount, 1, firstVertex, 0);
    }

    /**
        Enocodes a draw command using the bound vertex buffers.

        Params:
            prim =          The primitive topology to draw with.
            firstVertex =   Offset to the first vertex.
            vertexCount =   The amount of vertices to draw.
            instanceCount = The amount of instances to draw.
    */
    override void draw(NioPrimitive prim, uint firstVertex, uint vertexCount, uint instanceCount) {
        this.setTopology(prim);
        vkCmdDraw(vkcmdbuffer, vertexCount, instanceCount, firstVertex, 0);
    }

    /**
        Enocodes a draw command using the bound vertex buffers.

        Params:
            prim =          The primitive topology to draw with.
            firstVertex =   Offset to the first vertex.
            vertexCount =   The amount of vertices to draw.
            firstInstance = Index of the first instance to draw.
            instanceCount = The amount of instances to draw.
    */
    override void draw(NioPrimitive prim, uint firstVertex, uint vertexCount, uint firstInstance, uint instanceCount) {
        this.setTopology(prim);
        vkCmdDraw(vkcmdbuffer, vertexCount, instanceCount, firstVertex, firstInstance);
    }

    /**
        Enocodes a draw command using the bound vertex buffers and
        the given index buffer.

        Params:
            prim =          The primitive topology to draw with.
            indexBuffer =   The index buffer to use.
            indexType =     The type of the index values.
            indexCount =    The amount of indices to draw.
            indexOffset =   Offset into the index buffer to begin at.
    */
    override void drawIndexed(NioPrimitive prim, NioBuffer indexBuffer, NioIndexType indexType, uint indexCount, uint indexOffset = 0) {
        this.setTopology(prim);
        this.setIndexBuffer(cast(NioVkBuffer)indexBuffer, indexType);
        vkCmdDrawIndexed(vkcmdbuffer, indexCount, 1, indexOffset, 0, 0);
    }

    /**
        Enocodes a draw command using the bound vertex buffers and
        the given index buffer.

        Params:
            prim =          The primitive topology to draw with.
            indexBuffer =   The index buffer to use.
            indexType =     The type of the index values.
            indexCount =    The amount of indices to draw.
            indexOffset =   Offset into the index buffer to begin at.
            instanceCount = The amount of instances to draw.
    */
    override void drawIndexed(NioPrimitive prim, NioBuffer indexBuffer, NioIndexType indexType, uint indexCount, uint indexOffset, uint instanceCount) {
        this.setTopology(prim);
        this.setIndexBuffer(cast(NioVkBuffer)indexBuffer, indexType);
        vkCmdDrawIndexed(vkcmdbuffer, indexCount, instanceCount, indexOffset, 0, 0);
    }

    /**
        Enocodes a draw command using the bound vertex buffers and
        the given index buffer.

        Params:
            prim =          The primitive topology to draw with.
            indexBuffer =   The index buffer to use.
            indexType =     The type of the index values.
            indexCount =    The amount of indices to draw.
            indexOffset =   Offset into the index buffer to begin at.
            baseVertex =    Constant value to add to all of the indices.
            instanceCount = The amount of instances to draw.
    */
    override void drawIndexed(NioPrimitive prim, NioBuffer indexBuffer, NioIndexType indexType, uint indexCount, uint indexOffset, int baseVertex, uint instanceCount) {
        this.setTopology(prim);
        this.setIndexBuffer(cast(NioVkBuffer)indexBuffer, indexType);
        vkCmdDrawIndexed(vkcmdbuffer, indexCount, instanceCount, indexOffset, baseVertex, 0);
    }
}

/**
    Converts a $(D NioLoadAction) type to its $(D VkAttachmentLoadOp) equivalent.

    Params:
        action = The $(D NioLoadAction)
    
    Returns:
        The $(D VkAttachmentLoadOp) equivalent.
*/
pragma(inline, true)
VkAttachmentLoadOp toVkLoadOp(NioLoadAction action) @nogc {
    final switch(action) with(NioLoadAction) {
        case dontCare:  return VK_ATTACHMENT_LOAD_OP_DONT_CARE;
        case load:      return VK_ATTACHMENT_LOAD_OP_LOAD;
        case clear:     return VK_ATTACHMENT_LOAD_OP_CLEAR;
    }
}

/**
    Converts a $(D NioStoreAction) type to its $(D VkAttachmentStoreOp) equivalent.

    Params:
        action = The $(D NioStoreAction)
    
    Returns:
        The $(D VkAttachmentStoreOp) equivalent.
*/
pragma(inline, true)
VkAttachmentStoreOp toVkStoreOp(NioStoreAction action) @nogc {
    final switch(action) with(NioStoreAction) {
        case dontCare:          return VK_ATTACHMENT_STORE_OP_DONT_CARE;
        case store:             return VK_ATTACHMENT_STORE_OP_STORE;
        case resolve:           return VK_ATTACHMENT_STORE_OP_NONE;
        case resolveAndStore:   return VK_ATTACHMENT_STORE_OP_STORE;
    }
}

/**
    Converts a $(D NioStoreAction) type to its $(D VkAttachmentStoreOp) equivalent.

    Params:
        action = The $(D NioStoreAction)
    
    Returns:
        The $(D VkAttachmentStoreOp) equivalent.
*/
pragma(inline, true)
VkAttachmentStoreOp toVkResolveMode(NioStoreAction action) @nogc {
    final switch(action) with(NioStoreAction) {
        case dontCare:          return VK_RESOLVE_MODE_NONE;
        case store:             return VK_RESOLVE_MODE_NONE;
        case resolve:           return VK_RESOLVE_MODE_AVERAGE_BIT;
        case resolveAndStore:   return VK_RESOLVE_MODE_AVERAGE_BIT;
    }
}

/**
    Converts a $(D NioCulling) type to its $(D VkCullModeFlags) equivalent.

    Params:
        value = The $(D NioCulling)
    
    Returns:
        The $(D VkCullModeFlags) equivalent.
*/
pragma(inline, true)
VkCullModeFlags toVkCullMode(NioCulling value) @nogc {
    final switch(value) with(NioCulling) {
        case none:  return VK_CULL_MODE_NONE;
        case front: return VK_CULL_MODE_FRONT_BIT;
        case back:  return VK_CULL_MODE_BACK_BIT;
    }
}

/**
    Converts a $(D NioFaceWinding) type to its $(D VkFrontFace) equivalent.

    Params:
        value = The $(D NioFaceWinding)
    
    Returns:
        The $(D VkFrontFace) equivalent.
*/
pragma(inline, true)
VkFrontFace toVkFrontFace(NioFaceWinding value) @nogc {
    final switch(value) with(NioFaceWinding) {
        case clockwise:         return VK_FRONT_FACE_CLOCKWISE;
        case counterClockwise:  return VK_FRONT_FACE_COUNTER_CLOCKWISE;
    }
}

/**
    Converts a $(D NioPrimitive) type to its $(D VkPrimitiveTopology) equivalent.

    Params:
        value = The $(D NioPrimitive)
    
    Returns:
        The $(D VkPrimitiveTopology) equivalent.
*/
pragma(inline, true)
VkPrimitiveTopology toVkPrimitive(NioPrimitive value) @nogc {
    final switch(value) with(NioPrimitive) {
        case points:        return VK_PRIMITIVE_TOPOLOGY_POINT_LIST;
        case lines:         return VK_PRIMITIVE_TOPOLOGY_LINE_LIST;
        case lineStrip:     return VK_PRIMITIVE_TOPOLOGY_LINE_STRIP;
        case triangles:     return VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST;
        case triangleStrip: return VK_PRIMITIVE_TOPOLOGY_TRIANGLE_STRIP;
    }
}

/**
    Converts a $(D NioColorAttachmentDescriptor) type to its $(D VkRenderingAttachmentInfo) equivalent.

    Params:
        desc = The $(D NioColorAttachmentDescriptor)
    
    Returns:
        The $(D VkRenderingAttachmentInfo) equivalent.
*/
VkRenderingAttachmentInfo toVkRenderingAttachmentInfo(NioColorAttachmentDescriptor desc) @nogc {
    auto nvkTexture = cast(NioVkTexture)desc.texture;
    auto nvkResolveTexture = cast(NioVkTexture)desc.resolveTexture;

    auto clearColorValue = *(cast(VkClearColorValue*)&desc.clearColor); 
    return VkRenderingAttachmentInfo(
        imageView: nvkTexture.view,
        imageLayout: nvkTexture.layout,
        resolveMode: desc.storeAction.toVkResolveMode(),
        resolveImageView: nvkResolveTexture ? nvkResolveTexture.view : null,
        resolveImageLayout: nvkResolveTexture ? nvkResolveTexture.layout : VK_IMAGE_LAYOUT_UNDEFINED,
        loadOp: desc.loadAction.toVkLoadOp(),
        storeOp: desc.storeAction.toVkStoreOp(),
        clearValue: VkClearValue(color: clearColorValue)
    );
}

/**
    Converts a $(D NioColorAttachmentDescriptor) type to its $(D VkRenderingAttachmentInfo) equivalent.

    Params:
        desc = The $(D NioColorAttachmentDescriptor)
    
    Returns:
        The $(D VkRenderingAttachmentInfo) equivalent.
*/
VkRenderingAttachmentInfo toVkRenderingAttachmentInfo(NioDepthAttachmentDescriptor desc) @nogc {
    auto nvkTexture = cast(NioVkTexture)desc.texture;
    auto nvkResolveTexture = cast(NioVkTexture)desc.resolveTexture;
    return VkRenderingAttachmentInfo(
        imageView: nvkTexture.view,
        imageLayout: nvkTexture.layout,
        resolveMode: desc.storeAction.toVkResolveMode(),
        resolveImageView: nvkResolveTexture ? nvkResolveTexture.view : null,
        resolveImageLayout: nvkResolveTexture ? nvkResolveTexture.layout : VK_IMAGE_LAYOUT_UNDEFINED,
        loadOp: desc.loadAction.toVkLoadOp(),
        storeOp: desc.storeAction.toVkStoreOp(),
        clearValue: VkClearValue(depthStencil: VkClearDepthStencilValue(depth: desc.clearDepth))
    );
}

/**
    Converts a $(D NioColorAttachmentDescriptor) type to its $(D VkRenderingAttachmentInfo) equivalent.

    Params:
        desc = The $(D NioColorAttachmentDescriptor)
    
    Returns:
        The $(D VkRenderingAttachmentInfo) equivalent.
*/
VkRenderingAttachmentInfo toVkRenderingAttachmentInfo(NioStencilAttachmentDescriptor desc) @nogc {
    auto nvkTexture = cast(NioVkTexture)desc.texture;
    auto nvkResolveTexture = cast(NioVkTexture)desc.resolveTexture;
    return VkRenderingAttachmentInfo(
        imageView: nvkTexture.view,
        imageLayout: nvkTexture.layout,
        resolveMode: desc.storeAction.toVkResolveMode(),
        resolveImageView: nvkResolveTexture ? nvkResolveTexture.view : null,
        resolveImageLayout: nvkResolveTexture ? nvkResolveTexture.layout : VK_IMAGE_LAYOUT_UNDEFINED,
        loadOp: desc.loadAction.toVkLoadOp(),
        storeOp: desc.storeAction.toVkStoreOp(),
        clearValue: VkClearValue(depthStencil: VkClearDepthStencilValue(stencil: desc.clearStencil))
    );
}