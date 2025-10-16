/**
    Niobium Vulkan Render Encoders
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module niobium.mtl.cmd.renderencoder;
import niobium.mtl.cmd.buffer;
import niobium.mtl.depthstencil;
import niobium.mtl.resource;
import niobium.mtl.sampler;
import niobium.mtl.memory;
import niobium.mtl.render;
import niobium.mtl.sync;
import niobium.types;
import niobium.cmd;
import numem;

import metal.commandbuffer;
import metal.renderpass;
import metal.rendercommandencoder;
import metal.renderpipeline;
import metal.resource;
import metal.texture;
import metal.buffer;

/**
    A short-lived object which encodes rendering commands 
    into a $(D NioCommandBuffer).
    Only one $(D NioCommandEncoder) can be active at a time 
    for a $(D NioCommandBuffer).

    To end encoding call $(D endEncoding).
*/
class NioMTLRenderCommandEncoder : NioRenderCommandEncoder {
private:
@nogc:

    void setup(NioRenderPassDescriptor desc) {
        MTLRenderPassDescriptor mtldesc = MTLRenderPassDescriptor.alloc.init;
        NioViewport vp;

        // Color Attachments
        foreach(i, attachment; desc.colorAttachments) {
            MTLRenderPassColorAttachmentDescriptor colordesc = mtldesc.colorAttachments.get(i);
            colordesc.texture = attachment.texture ? cast(MTLTexture)attachment.texture.handle : null;
            colordesc.level = attachment.level;
            colordesc.slice = attachment.slice;
            colordesc.depthPlane = attachment.depth;
            colordesc.resolveTexture = attachment.resolveTexture ? cast(MTLTexture)attachment.resolveTexture.handle : null;
            colordesc.resolveLevel = attachment.resolveLevel;
            colordesc.resolveSlice = attachment.resolveSlice;
            colordesc.resolveDepthPlane = attachment.resolveDepth;
            colordesc.loadAction = attachment.loadAction.toMTLLoadAction();
            colordesc.storeAction = attachment.storeAction.toMTLStoreAction();
            colordesc.clearColor = MTLClearColor(attachment.clearColor.r, attachment.clearColor.g, attachment.clearColor.b, attachment.clearColor.a);

            if (colordesc.texture.width > vp.width)
                vp.width = colordesc.texture.width;

            if (colordesc.texture.height > vp.height)
                vp.height = colordesc.texture.height;
        }

        // Depth Attachment
        MTLRenderPassDepthAttachmentDescriptor depthdesc = mtldesc.depthAttachment;
        depthdesc.texture = desc.depthAttachment.texture ? cast(MTLTexture)desc.depthAttachment.texture.handle : null;
        depthdesc.level = desc.depthAttachment.level;
        depthdesc.slice = desc.depthAttachment.slice;
        depthdesc.depthPlane = desc.depthAttachment.depth;
        depthdesc.resolveTexture = desc.depthAttachment.resolveTexture ? cast(MTLTexture)desc.depthAttachment.resolveTexture.handle : null;
        depthdesc.resolveLevel = desc.depthAttachment.resolveLevel;
        depthdesc.resolveSlice = desc.depthAttachment.resolveSlice;
        depthdesc.resolveDepthPlane = desc.depthAttachment.resolveDepth;
        depthdesc.loadAction = desc.depthAttachment.loadAction.toMTLLoadAction();
        depthdesc.storeAction = desc.depthAttachment.storeAction.toMTLStoreAction();
        depthdesc.clearDepth = desc.depthAttachment.clearDepth;

        // Stencil Attachment
        MTLRenderPassStencilAttachmentDescriptor stencildesc = mtldesc.stencilAttachment;
        stencildesc.texture = desc.stencilAttachment.texture ? cast(MTLTexture)desc.stencilAttachment.texture.handle : null;
        stencildesc.level = desc.stencilAttachment.level;
        stencildesc.slice = desc.stencilAttachment.slice;
        stencildesc.depthPlane = desc.stencilAttachment.depth;
        stencildesc.resolveTexture = desc.stencilAttachment.resolveTexture ? cast(MTLTexture)desc.stencilAttachment.resolveTexture.handle : null;
        stencildesc.resolveLevel = desc.stencilAttachment.resolveLevel;
        stencildesc.resolveSlice = desc.stencilAttachment.resolveSlice;
        stencildesc.resolveDepthPlane = desc.stencilAttachment.resolveDepth;
        stencildesc.loadAction = desc.stencilAttachment.loadAction.toMTLLoadAction();
        stencildesc.storeAction = desc.stencilAttachment.storeAction.toMTLStoreAction();
        stencildesc.clearStencil = desc.stencilAttachment.clearStencil;

        .autorelease(() {
            this.handle = mtlcmdbuffer.renderCommandEncoder(mtldesc);
            this.handle.retain();
        });
        mtldesc.release();
    }

public:

    /// Destructor
    ~this() {
        handle.release();
    }

    /**
        Constructs a new command encoder.
    */
    this(NioCommandBuffer buffer, NioRenderPassDescriptor desc) {
        super(buffer);
        this.setup(desc);
    }

    /// Command Encoder Functions
    mixin MTLCommandEncoderFunctions!MTLRenderCommandEncoder;

    /**
        Encodes a command which instructs the GPU
        to wait for the fence to be signalled before
        proceeding.

        Params:
            fence =         The fence to wait for.
            beforeStages =  Which stages will be waiting.
    */
    override void waitForFence(NioFence fence, NioRenderStage beforeStages) {
        handle.waitForFence((cast(NioMTLFence)fence).handle, beforeStages.toMTLRenderStages());
    }

    /**
        Encodes a command which instructs the GPU
        to signal the fence.

        Params:
            fence =         The fence to signal.
            afterStages =   When in the pipeline to signal.
    */
    override void signalFence(NioFence fence, NioRenderStage afterStages) {
        handle.updateFence((cast(NioMTLFence)fence).handle, afterStages.toMTLRenderStages());
    }

    /**
        Inserts a memory barrier into the command stream.

        Params:
            resource =  The resource to set a barrier for.
            after =     The render stages of previous commands that modify the resource.
            before =    The render stages of subsequent commands that modify the resource.
    */
    override void memoryBarrier(NioResource resource, NioRenderStage after, NioRenderStage before) {
        auto res = cast(MTLResource)resource.handle;
        handle.memoryBarrier(&res, 1, after.toMTLRenderStages(), before.toMTLRenderStages());
    }

    /**
        Sets the primary viewport of the render pass.

        Params:
            viewport = The viewport.
    */
    override void setViewport(NioViewport viewport) {
        handle.setViewport(
            MTLViewport(viewport.originX, viewport.originY, viewport.width, viewport.height, viewport.near, viewport.far)
        );
    }

    /**
        Sets the primary scissor rectangle of the render pass.

        Params:
            scissor = The scissor rectangle.
    */
    override void setScissor(NioScissorRect scissor) {
        handle.setScissorRect(MTLScissorRect(cast(ulong)scissor.x, cast(ulong)scissor.y, cast(ulong)scissor.width, cast(ulong)scissor.height));
    }

    /**
        Sets the active culling mode for the render pass.

        Params:
            culling = The culling mode.
    */
    override void setCulling(NioCulling culling) {
        handle.setCullMode(culling.toMTLCullMode());
    }

    /**
        Sets the active front-face winding for the render pass.

        Params:
            winding = The front-face winding.
    */
    override void setFaceWinding(NioFaceWinding winding) {
        handle.setFrontFacingWinding(winding.toMTLWinding());
    }

    /**
        Sets the active constant blending color for the render pass.

        Params:
            color = The constant blending color.
    */
    override void setBlendColor(NioColor color) {
        handle.setBlendColor(color.r, color.g, color.b, color.a);
    }

    /**
        Sets the active depth stencil state for the render pass.

        Params:
            state = The depth stencil state to apply.
    */
    override void setDepthStencilState(NioDepthStencilState state) {
        handle.setDepthStencilState((cast(NioMTLDepthStencilState)state).handle);
    }

    /**
        Sets the active render pipeline for the render pass.

        Params:
            pipeline =  The pipeline.
    */
    override void setPipeline(NioRenderPipeline pipeline) {
        handle.setRenderPipelineState((cast(NioMTLRenderPipeline)pipeline).handle);
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
        handle.setVertexBuffer(cast(MTLBuffer)buffer.handle, offset, slot);
    }

    /**
        Sets the given texture as the active texture at the given
        slot in the vertex shader argument table.

        Params:
            texture =   The texture to set.
            slot =      The slot in the argument table to set.
    */
    override void setVertexTexture(NioTexture texture, uint slot) {
        handle.setVertexTexture(cast(MTLTexture)texture.handle, slot);
    }

    /**
        Sets the given sampler as the active sampler at the given
        slot in the vertex shader argument table.

        Params:
            sampler =   The sampler to set.
            slot =      The slot in the argument table to set.
    */
    override void setVertexSampler(NioSampler sampler, uint slot) {
        handle.setVertexSamplerState((cast(NioMTLSampler)sampler).handle, slot);
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
        handle.setFragmentBuffer(cast(MTLBuffer)buffer.handle, offset, slot);
    }

    /**
        Sets the given texture as the active texture at the given
        slot in the fragment shader argument table.

        Params:
            texture =   The texture to set.
            slot =      The slot in the argument table to set.
    */
    override void setFragmentTexture(NioTexture texture, uint slot) {
        handle.setFragmentTexture(cast(MTLTexture)texture.handle, slot);
    }

    /**
        Sets the given sampler as the active sampler at the given
        slot in the fragment shader argument table.

        Params:
            sampler =   The sampler to set.
            slot =      The slot in the argument table to set.
    */
    override void setFragmentSampler(NioSampler sampler, uint slot) {
        handle.setFragmentSamplerState((cast(NioMTLSampler)sampler).handle, slot);
    }

    /**
        Enocodes a draw command using the bound vertex buffers.

        Params:
            prim =          The primitive topology to draw with.
            firstVertex =   Offset to the first vertex.
            vertexCount =   The amount of vertices to draw.
    */
    override void draw(NioPrimitive prim, uint firstVertex, uint vertexCount) {
        handle.draw(prim.toMTLPrimitiveType(), firstVertex, vertexCount);
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
        handle.draw(prim.toMTLPrimitiveType(), firstVertex, vertexCount, instanceCount);
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
        handle.draw(prim.toMTLPrimitiveType(), firstVertex, vertexCount, instanceCount, firstInstance);
        
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
        handle.drawIndexed(
            prim.toMTLPrimitiveType(), 
            indexCount, 
            indexType.toMTLIndexType(),
            cast(MTLBuffer)indexBuffer.handle,
            indexOffset
        );
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
        handle.drawIndexed(
            prim.toMTLPrimitiveType(), 
            indexCount, 
            indexType.toMTLIndexType(),
            cast(MTLBuffer)indexBuffer.handle,
            indexOffset,
            instanceCount
        );
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
        handle.drawIndexed(
            prim.toMTLPrimitiveType(), 
            indexCount, 
            indexType.toMTLIndexType(),
            cast(MTLBuffer)indexBuffer.handle,
            indexOffset,
            instanceCount,
            baseVertex,
            0
        );
    }
}

/**
    Converts a $(D NioPrimitive) format to its $(D MTLPrimitiveType) equivalent.

    Params:
        primitive = The $(D NioPrimitive)
    
    Returns:
        The $(D MTLPrimitiveType) equivalent.
*/
pragma(inline, true)
MTLPrimitiveType toMTLPrimitiveType(NioPrimitive primitive) @nogc {
    final switch(primitive) with(NioPrimitive) {
        case points:            return MTLPrimitiveType.Point;
        case lines:             return MTLPrimitiveType.Line;
        case lineStrip:         return MTLPrimitiveType.LineStrip;
        case triangles:         return MTLPrimitiveType.Triangle;
        case triangleStrip:     return MTLPrimitiveType.TriangleStrip;
    }
}

/**
    Converts a $(D NioCulling) format to its $(D MTLCullMode) equivalent.

    Params:
        culling = The $(D NioCulling)
    
    Returns:
        The $(D MTLCullMode) equivalent.
*/
pragma(inline, true)
MTLCullMode toMTLCullMode(NioCulling culling) @nogc {
    final switch(culling) with(NioCulling) {
        case none:          return MTLCullMode.None;
        case front:         return MTLCullMode.Front;
        case back:          return MTLCullMode.Back;
    }
}

/**
    Converts a $(D NioFaceWinding) format to its $(D MTLWinding) equivalent.

    Params:
        winding = The $(D NioFaceWinding)
    
    Returns:
        The $(D MTLWinding) equivalent.
*/
pragma(inline, true)
MTLWinding toMTLWinding(NioFaceWinding winding) @nogc {
    final switch(winding) with(NioFaceWinding) {
        case clockwise:         return MTLWinding.Clockwise;
        case counterClockwise:  return MTLWinding.CounterClockwise;
    }
}

/**
    Converts a $(D NioLoadAction) format to its $(D MTLLoadAction) equivalent.

    Params:
        action = The $(D NioLoadAction)
    
    Returns:
        The $(D MTLLoadAction) equivalent.
*/
pragma(inline, true)
MTLLoadAction toMTLLoadAction(NioLoadAction action) @nogc {
    final switch(action) with(NioLoadAction) {
        case dontCare:      return MTLLoadAction.DontCare;
        case load:          return MTLLoadAction.Load;
        case clear:         return MTLLoadAction.Clear;
    }
}

/**
    Converts a $(D NioStoreAction) format to its $(D MTLStoreAction) equivalent.

    Params:
        action = The $(D NioStoreAction)
    
    Returns:
        The $(D MTLStoreAction) equivalent.
*/
pragma(inline, true)
MTLStoreAction toMTLStoreAction(NioStoreAction action) @nogc {
    final switch(action) with(NioStoreAction) {
        case dontCare:          return MTLStoreAction.DontCare;
        case store:             return MTLStoreAction.Store;
        case resolve:           return MTLStoreAction.MultisampleResolve;
        case resolveAndStore:   return MTLStoreAction.StoreAndMultisampleResolve;
    }
}