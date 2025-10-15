/**
    Niobium Command Buffers.
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module niobium.cmd;
import niobium.queue;
import niobium.device;
import niobium.surface;
import niobium.texture;
import niobium.resource;
import niobium.pipeline;
import niobium.depthstencil;
import niobium.sampler;
import niobium.buffer;
import niobium.sync;
import niobium.types;
import numem;

/**
    A buffer of commands which can be sent to the GPU
    for processing.

    Note:
        Submitting a command buffer will invalidate it,
        this means that you cannot modify its state any
        longer. Once submitted it's safe to $(D release)
        the command buffer.
*/
abstract
class NioCommandBuffer : NioDeviceObject {
private:
@nogc:
    NioCommandQueue queue_;

protected:

    /**
        The currently active command encoder.
    */
    NioCommandEncoder activeEncoder;

    /**
        Constructs a new command buffer.

        Params:
            queue =     The queue that "owns" this command buffer.
    */
    this(NioCommandQueue queue) {
        super(queue.device);
        this.queue_ = queue;
    }

    /**
        Called by command encoders when encoding ends.
    */
    void onEncodingEnd() { }

public:

    /**
        The queue the buffer belongs to.
    */
    final @property NioCommandQueue queue() => queue_;

    /**
        Begins a new render pass.

        Note:
            Only one pass can be active at a time,
            attempting to create new passes will fail.
        
        Params:
            desc = Descriptor used to start the render pass

        Returns:
            A short lived $(D NioRenderCommandEncoder) on success,
            $(D null) on failure.
    */
    abstract NioRenderCommandEncoder beginRenderPass(NioRenderPassDescriptor desc);

    /**
        Begins a new transfer pass.

        Note:
            Only one pass can be active at a time,
            attempting to create new passes will fail.
        
        Returns:
            A short lived $(D NioTransferCommandEncoder) on success,
            $(D null) on failure.
    */
    abstract NioTransferCommandEncoder beginTransferPass();

    /**
        Enqueues a presentation to happen after this
        command buffer finishes execution.

        You may only make one presentation request
        per command buffer. Any extra present requests
        will be ignored.

        Params:
            drawable = The drawable to present.
    */
    abstract void present(NioDrawable drawable);

    /**
        Awaits the completion of the command buffer
        execution.
    */
    abstract void await();
}

/**
    A short-lived object which encodes commands into a
    $(D NioCommandBuffer). Only one $(D NioCommandEncoder)
    can be active at a time for a $(D NioCommandBuffer).

    To end encoding call $(D endEncoding).
*/
abstract
class NioCommandEncoder : NuObject {
private:
@nogc:
    NioCommandBuffer cmdbuffer_;

protected:

    /**
        Constructs a new command encoder.
    */
    this(NioCommandBuffer buffer) {
        this.cmdbuffer_ = buffer;
    }

    /**
        Helper internal function to allow ending the command
        encoder.
    */
    final void finishEncoding() {
        auto cmdbuffer = cmdbuffer_;
        if (cmdbuffer.activeEncoder) {

            nogc_delete(cmdbuffer.activeEncoder);
            cmdbuffer.activeEncoder = null;
            cmdbuffer.onEncodingEnd();
        }
    }

public:

    /**
        The command buffer the encoder is recording to.
    */
    final @property NioCommandBuffer commandBuffer() => cmdbuffer_;

    /**
        Pushes a debug group.

        Params:
            name = The name of the debug group
            color = The color of the debug group (optional)
    */
    abstract void pushDebugGroup(string name, float[4] color = [0, 0, 0, 1]);

    /**
        Pops the top debug group from the debug
        group stack.
    */
    abstract void popDebugGroup();

    /**
        Ends the encoding pass, allowing a new pass to be
        begun from the parent command buffer.
    */
    abstract void endEncoding();

    /**
        Inserts a barrier that ensures that subsequent commands 
        of type $(D afterStages) submitted to the command queue does 
        not proceed until the work in $(D beforeStages) completes.

        Params:
            afterStages =   A mask that defines the stages of work to wait for.
            beforeStages =  A mask that defines the work that must wait.
    */
    abstract void insertBarrier(NioPipelineStage afterStages, NioPipelineStage beforeStages);
}

/**
    The different face culling modes.
*/
enum NioCulling : uint {

    /**
        Disables face culling.
    */
    none =      0x00000000U,

    /**
        Enables front face culling.
    */
    front =     0x00000001U,

    /**
        Enables back face culling.
    */
    back =      0x00000002U,
}

/**
    The different face windings.
*/
enum NioFaceWinding : uint {

    /**
        Front faces are wound clockwise.
    */
    clockwise =         0x00000001U,

    /**
        Front faces are wound counter-clockwise.
    */
    counterClockwise =  0x00000002U,
}

/**
    Types of primitives.
*/
enum NioPrimitive : uint {

    /**
        Vertex primitives are a series of points.
    */
    points =        0x00000001U,

    /**
        Vertex primitives are a series of lines.
    */
    lines =         0x00000002U,

    /**
        Vertex primitives are strip of lines,
        with each line connecting to the previous one.
    */
    lineStrip =     0x00000003U,

    /**
        Vertex primitives are a series of triangles.
    */
    triangles =     0x00000004U,

    /**
        Vertex primitives strip of triangles,
        with each vertex creating a new triangle from
        the previous 2 vertices.
    */
    triangleStrip = 0x00000005U,
}

/**
    Action top perform when an attachment is loaded
    in a render pass.
*/
enum NioLoadAction : uint {

    /**
        Let the implementation decide.
    */
    dontCare =  0x00000001U,

    /**
        Load the contents of the texture attachment.
    */
    load =      0x00000002U,

    /**
        Clear the contents of the texture attachment.
    */
    clear =     0x00000003U,
}

/**
    Action top perform when an attachment is loaded
    in a render pass.
*/
enum NioStoreAction : uint {

    /**
        Let the implementation decide.
    */
    dontCare =          0x00000001U,

    /**
        Store the result of the pass into the attachment.
    */
    store =             0x00000002U,

    /**
        Perform a multisample resolution pass.
    */
    resolve =           0x00000003U,

    /**
        Perform a multisample resolution pass.
    */
    resolveAndStore =   0x00000004U,
}

/**
    Describes a single color texture attachment for a render pass.
*/
struct NioColorAttachmentDescriptor {

    /**
        The attached texture.
    */
    NioTexture texture;

    /**
        Texture mipmap level to render to.
    */
    uint level = 0;

    /**
        Texture array slice to render to.
    */
    uint slice = 0;

    /**
        Texture depth plane to render to.
    */
    uint depth = 0;

    /**
        Action to perform on attachment load.
    */
    NioLoadAction loadAction;

    /**
        Action to perform on attachment store.
    */
    NioStoreAction storeAction;
    
    /**
        The clear color to use for the attachment.
    */
    NioColor clearColor;

    /**
        Texture to use for multisample resolve.
    */
    NioTexture resolveTexture = null;

    /**
        Mipmap level to use for multisample resolve.
    */
    uint resolveLevel = 0;

    /**
        Array slice to use for multisample resolve.
    */
    uint resolveSlice = 0;

    /**
        Texture depth to use for multisample resolve.
    */
    uint resolveDepth = 0;
}

/**
    Describes a single depth texture attachment for a render pass.
*/
struct NioDepthAttachmentDescriptor {

    /**
        The attached texture.
    */
    NioTexture texture;

    /**
        Texture mipmap level to render to.
    */
    uint level = 0;

    /**
        Texture array slice to render to.
    */
    uint slice = 0;

    /**
        Texture depth plane to render to.
    */
    uint depth = 0;

    /**
        Action to perform on attachment load.
    */
    NioLoadAction loadAction;

    /**
        Action to perform on attachment store.
    */
    NioStoreAction storeAction;

    /**
        Value to clear the depth buffer to
    */
    float clearDepth = 1;

    /**
        Texture to use for multisample resolve.
    */
    NioTexture resolveTexture = null;

    /**
        Mipmap level to use for multisample resolve.
    */
    uint resolveLevel = 0;

    /**
        Array slice to use for multisample resolve.
    */
    uint resolveSlice = 0;

    /**
        Texture depth to use for multisample resolve.
    */
    uint resolveDepth = 0;
}

/**
    Describes a single depth texture attachment for a render pass.
*/
struct NioStencilAttachmentDescriptor {

    /**
        The attached texture.
    */
    NioTexture texture;

    /**
        Texture mipmap level to render to.
    */
    uint level = 0;

    /**
        Texture array slice to render to.
    */
    uint slice = 0;

    /**
        Texture depth plane to render to.
    */
    uint depth = 0;

    /**
        Action to perform on attachment load.
    */
    NioLoadAction loadAction;

    /**
        Action to perform on attachment store.
    */
    NioStoreAction storeAction;

    /**
        Value to clear the stencil buffer to
    */
    uint clearStencil;

    /**
        Texture to use for multisample resolve.
    */
    NioTexture resolveTexture = null;

    /**
        Mipmap level to use for multisample resolve.
    */
    uint resolveLevel = 0;

    /**
        Array slice to use for multisample resolve.
    */
    uint resolveSlice = 0;

    /**
        Texture depth to use for multisample resolve.
    */
    uint resolveDepth = 0;
}

/**
    Describes the settings needed for a render pass.
*/
struct NioRenderPassDescriptor {

    /**
        Color attachments.
    */
    NioColorAttachmentDescriptor[] colorAttachments;

    /**
        Depth attachment, optional.
    */
    NioDepthAttachmentDescriptor depthAttachment;

    /**
        Stencil attachment, optional.
    */
    NioDepthAttachmentDescriptor stencilAttachment;
}

/**
    A short-lived object which encodes rendering commands 
    into a $(D NioCommandBuffer).
    Only one $(D NioCommandEncoder) can be active at a time 
    for a $(D NioCommandBuffer).

    To end encoding call $(D endEncoding).
*/
abstract
class NioRenderCommandEncoder : NioCommandEncoder {
protected:
@nogc:

    /**
        Constructs a new command encoder.
    */
    this(NioCommandBuffer buffer) {
        super(buffer);
    }

public:

    /**
        Encodes a command which instructs the GPU
        to wait for the fence to be signalled before
        proceeding.

        Params:
            fence =         The fence to wait for.
            beforeStages =  Which stages will be waiting.
    */
    abstract void waitForFence(NioFence fence, NioRenderStage beforeStages);

    /**
        Encodes a command which instructs the GPU
        to signal the fence.

        Params:
            fence =         The fence to signal.
            afterStages =   When in the pipeline to signal.
    */
    abstract void signalFence(NioFence fence, NioRenderStage afterStages);

    /**
        Inserts a memory barrier into the command stream.

        Params:
            resource =  The resource to set a barrier for.
            after =     The render stages of previous commands that modify the resource.
            before =    The render stages of subsequent commands that modify the resource.
    */
    abstract void memoryBarrier(NioResource resource, NioRenderStage after, NioRenderStage before);

    /**
        Sets the primary viewport of the render pass.

        Params:
            viewport = The viewport.
    */
    abstract void setViewport(NioViewport viewport);

    /**
        Sets the primary scissor rectangle of the render pass.

        Params:
            scissor = The scissor rectangle.
    */
    abstract void setScissor(NioScissorRect scissor);

    /**
        Sets the active culling mode for the render pass.

        Params:
            culling = The culling mode.
    */
    abstract void setCulling(NioCulling culling);

    /**
        Sets the active front-face winding for the render pass.

        Params:
            winding = The front-face winding.
    */
    abstract void setFaceWinding(NioFaceWinding winding);

    /**
        Sets the active constant blending color for the render pass.

        Params:
            color = The constant blending color.
    */
    abstract void setBlendColor(NioColor color);

    /**
        Sets the active depth stencil state for the render pass.

        Params:
            state = The depth stencil state to apply.
    */
    abstract void setDepthStencilState(NioDepthStencilState state);

    /**
        Sets the active render pipeline for the render pass.

        Params:
            pipeline =  The pipeline.
    */
    abstract void setPipeline(NioRenderPipeline pipeline);

    /**
        Sets the given buffer as the active buffer at the given
        slot in the vertex shader argument table.

        Params:
            buffer =    The buffer to set.
            offset =    The offset into the buffer, in bytes.
            slot =      The slot in the argument table to set.
    */
    abstract void setVertexBuffer(NioBuffer buffer, ulong offset, uint slot);

    /**
        Sets the given texture as the active texture at the given
        slot in the vertex shader argument table.

        Params:
            texture =   The texture to set.
            slot =      The slot in the argument table to set.
    */
    abstract void setVertexTexture(NioTexture texture, uint slot);

    /**
        Sets the given sampler as the active sampler at the given
        slot in the vertex shader argument table.

        Params:
            sampler =   The sampler to set.
            slot =      The slot in the argument table to set.
    */
    abstract void setVertexSampler(NioSampler sampler, uint slot);

    /**
        Sets the given buffer as the active buffer at the given
        slot in the fragment shader argument table.

        Params:
            buffer =    The buffer to set.
            offset =    The offset into the buffer, in bytes.
            slot =      The slot in the argument table to set.
    */
    abstract void setFragmentBuffer(NioBuffer buffer, ulong offset, uint slot);

    /**
        Sets the given texture as the active texture at the given
        slot in the fragment shader argument table.

        Params:
            texture =   The texture to set.
            slot =      The slot in the argument table to set.
    */
    abstract void setFragmentTexture(NioTexture texture, uint slot);

    /**
        Sets the given sampler as the active sampler at the given
        slot in the fragment shader argument table.

        Params:
            sampler =   The sampler to set.
            slot =      The slot in the argument table to set.
    */
    abstract void setFragmentSampler(NioSampler sampler, uint slot);

    /**
        Enocodes a draw command using the bound vertex buffers.

        Params:
            prim =          The primitive topology to draw with.
            firstVertex =   Offset to the first vertex.
            vertexCount =   The amount of vertices to draw.
    */
    abstract void draw(NioPrimitive prim, uint firstVertex, uint vertexCount);

    /**
        Enocodes a draw command using the bound vertex buffers.

        Params:
            prim =          The primitive topology to draw with.
            firstVertex =   Offset to the first vertex.
            vertexCount =   The amount of vertices to draw.
            instanceCount = The amount of instances to draw.
    */
    abstract void draw(NioPrimitive prim, uint firstVertex, uint vertexCount, uint instanceCount);

    /**
        Enocodes a draw command using the bound vertex buffers.

        Params:
            prim =          The primitive topology to draw with.
            firstVertex =   Offset to the first vertex.
            vertexCount =   The amount of vertices to draw.
            firstInstance = Index of the first instance to draw.
            instanceCount = The amount of instances to draw.
    */
    abstract void draw(NioPrimitive prim, uint firstVertex, uint vertexCount, uint firstInstance, uint instanceCount);

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
    abstract void drawIndexed(NioPrimitive prim, NioBuffer indexBuffer, NioIndexType indexType, uint indexCount, uint indexOffset = 0);

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
    abstract void drawIndexed(NioPrimitive prim, NioBuffer indexBuffer, NioIndexType indexType, uint indexCount, uint indexOffset, uint instanceCount);

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
    abstract void drawIndexed(NioPrimitive prim, NioBuffer indexBuffer, NioIndexType indexType, uint indexCount, uint indexOffset, int baseVertex, uint instanceCount);
}

/**
    Descriptor for a buffer-to-image copy operation.
*/
struct NioBufferSrcInfo {
    NioBuffer buffer;
    ulong offset = 0;
    ulong length;
    ulong rowLength;
    NioExtent3D extent = NioExtent3D(0, 0, 0);
}

/**
    Descriptor for a image-to-buffer copy operation.
*/
struct NioBufferDstInfo {
    NioBuffer buffer;
    ulong offset = 0;
    ulong rowLength;
}

/**
    Descriptor for a texture copy operation.
*/
struct NioTextureSrcInfo {
    NioTexture texture;
    uint slice = 0;
    uint level = 0;
    NioOrigin3D origin = NioOrigin3D(0, 0, 0);
    NioExtent3D extent;
}

/**
    Descriptor for a texture copy operation.
*/
struct NioTextureDstInfo {
    NioTexture texture;
    uint slice = 0;
    uint level = 0;
    NioOrigin3D origin = NioOrigin3D(0, 0, 0);
}

/**
    A short-lived object which encodes transfer commands 
    into a $(D NioCommandBuffer).
    Only one $(D NioCommandEncoder) can be active at a time 
    for a $(D NioCommandBuffer).

    To end encoding call $(D endEncoding).
*/
abstract
class NioTransferCommandEncoder : NioCommandEncoder {
protected:
@nogc:

    /**
        Constructs a new command encoder.
    */
    this(NioCommandBuffer buffer) {
        super(buffer);
    }

public:

    /**
        Encodes a command which instructs the GPU
        to wait for the fence to be signalled before
        proceeding.

        Params:
            fence = The fence to wait for.
    */
    abstract void waitForFence(NioFence fence);

    /**
        Encodes a command which instructs the GPU
        to signal the fence.

        Params:
            fence = The fence to signal.
    */
    abstract void signalFence(NioFence fence);

    /**
        Generates mipmaps for the destination texture,
        given that it's a color texture with mipmaps allocated.
    */
    abstract void generateMipmapsFor(NioTexture dst);

    /**
        Fills the given buffer with the given value.

        Params:
            dst =       The desination buffer.
            value =     The value to write to the buffer.
    */
    abstract void fillBuffer(NioBuffer dst, uint value);

    /**
        Fills the given buffer with the given value.

        Notes:
            The region defined will be clamped to the memory
            region of the buffer.

        Params:
            dst =       The desination buffer.
            offset =    The offset to start filling at, in bytes.
            length =    The length of the region to fill, in bytes.
            value =     The value to write to the buffer.
    */
    abstract void fillBuffer(NioBuffer dst, ulong offset, ulong length, uint value);

    /**
        Copies data from one buffer to another.

        Params:
            src =       The source buffer descriptor.
            dst =       The destination buffer descriptor.
    */
    abstract void copy(NioBufferSrcInfo src, NioBufferDstInfo dst);

    /**
        Copies the data from a buffer to a texture.

        Params:
            src =       The source buffer descriptor.
            dst =       The destination texture descriptor.
    */
    abstract void copy(NioBufferSrcInfo src, NioTextureDstInfo dst);

    /**
        Copies the data from a texture to a buffer.

        Params:
            src =       The source texture descriptor.
            dst =       The destination buffer descriptor.
    */
    abstract void copy(NioTextureSrcInfo src, NioBufferDstInfo dst);

    /**
        Copies the contents of the source texture
        into the destination texture.

        Params:
            src =       The source texture descriptor.
            dst =       The destination texture descriptor.
    */
    abstract void copy(NioTextureSrcInfo src, NioTextureDstInfo dst);

    /**
        Copies the contents of the source texture
        into the destination texture.

        Note:
            The smallest intersection between the 2 textures
            will be written to.

        Params:
            src = The source texture descriptor.
            dst = The desination descriptor.
    */
    abstract void copy(NioTexture src, NioTexture dst);
}