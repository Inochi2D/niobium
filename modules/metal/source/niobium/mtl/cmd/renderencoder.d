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
import niobium.mtl.sampler;
import niobium.mtl.resource;
import niobium.mtl.sync;
import niobium.types;
import niobium.cmd;
import numem;

// TODO: remove this
import niobium.pipeline;

// /**
//     A short-lived object which encodes rendering commands 
//     into a $(D NioCommandBuffer).
//     Only one $(D NioCommandEncoder) can be active at a time 
//     for a $(D NioCommandBuffer).

//     To end encoding call $(D endEncoding).
// */
// class NioMTLRenderCommandEncoder : NioRenderCommandEncoder {
// private:
// @nogc:


// /**
//     A short-lived object which encodes rendering commands 
//     into a $(D NioCommandBuffer).
//     Only one $(D NioCommandEncoder) can be active at a time 
//     for a $(D NioCommandBuffer).

//     To end encoding call $(D endEncoding).
// */
// class NioMTLRenderCommandEncoder : NioRenderCommandEncoder {
// private:
// @nogc:


// public:

//     /// Destructor
//     ~this() {
//         vkCmdEndRendering(vkcmdbuffer);
//     }

//     /**
//         Constructs a new command encoder.
//     */
//     this(NioCommandBuffer buffer, NioRenderPassDescriptor desc) {
//         super(buffer);
//         this.setup(desc);
//     }

//     /// Command Encoder Functions
//     mixin VkCommandEncoderFunctions;

//     /**
//         Encodes a command which instructs the GPU
//         to wait for the fence to be signalled before
//         proceeding.

//         Params:
//             fence =         The fence to wait for.
//             afterStages =   Which stages will be waiting.
//     */
//     override void waitForFence(NioFence fence, NioRenderStage beforeStages) {
//         auto vkevent = (cast(NioVkFence)fence).handle;
//         auto barrierInfo = VkMemoryBarrier2(
//             srcStageMask: VK_PIPELINE_STAGE_2_TOP_OF_PIPE_BIT,
//             srcAccessMask: VK_ACCESS_2_MEMORY_READ_BIT,
//             dstStageMask: beforeStages.toVkPipelineStageFlags2(),
//             dstAccessMask: VK_ACCESS_2_MEMORY_READ_BIT | VK_ACCESS_2_MEMORY_WRITE_BIT
//         );
//         auto depInfo = VkDependencyInfo(
//             memoryBarrierCount: 1,
//             pMemoryBarriers: &barrierInfo
//         );
//         vkCmdWaitEvents2(
//             vkcmdbuffer, 
//             1, &vkevent,
//             &depInfo
//         );
//     }

//     /**
//         Encodes a command which instructs the GPU
//         to signal the fence.

//         Params:
//             fence =         The fence to signal.
//             afterStages =   When in the pipeline to signal.
//     */
//     override void signalFence(NioFence fence, NioRenderStage afterStages) {
//         auto vkevent = (cast(NioVkFence)fence).handle;
//         auto barrierInfo = VkMemoryBarrier2(
//             srcStageMask: VK_PIPELINE_STAGE_2_TOP_OF_PIPE_BIT,
//             srcAccessMask: VK_ACCESS_2_MEMORY_READ_BIT,
//             dstStageMask: afterStages.toVkPipelineStageFlags2(),
//             dstAccessMask: VK_ACCESS_2_MEMORY_READ_BIT | VK_ACCESS_2_MEMORY_WRITE_BIT
//         );
//         auto depInfo = VkDependencyInfo(
//             memoryBarrierCount: 1,
//             pMemoryBarriers: &barrierInfo
//         );
//         vkCmdSetEvent2(
//             vkcmdbuffer, 
//             vkevent,
//             &depInfo
//         );
//     }

//     /**
//         Inserts a memory barrier into the command stream.

//         Params:
//             resource =  The resource to set a barrier for.
//             after =     The render stages of previous commands that modify the resource.
//             after =     The render stages of subsequent commands that modify the resource.
//     */
//     override void memoryBarrier(NioResource resource, NioRenderStage after, NioRenderStage before) {
//         auto barrierInfo = VkMemoryBarrier2(
//             srcStageMask: after.toVkPipelineStageFlags2(),
//             srcAccessMask: VK_ACCESS_2_MEMORY_READ_BIT,
//             dstStageMask: before.toVkPipelineStageFlags2(),
//             dstAccessMask: VK_ACCESS_2_MEMORY_READ_BIT | VK_ACCESS_2_MEMORY_WRITE_BIT
//         );
//         auto depInfo = VkDependencyInfo(
//             memoryBarrierCount: 1,
//             pMemoryBarriers: &barrierInfo
//         );
//         vkCmdPipelineBarrier2(
//             vkcmdbuffer,
//             &depInfo
//         );
//     }

//     /**
//         Sets the primary viewport of the render pass.

//         Params:
//             viewport = The viewport.
//     */
//     override void setViewport(NioViewport viewport) {
//         vkCmdSetViewport(vkcmdbuffer, 0, 1, cast(VkViewport*)&viewport);
//     }

//     /**
//         Sets the primary scissor rectangle of the render pass.

//         Params:
//             scissor = The scissor rectangle.
//     */
//     override void setScissor(NioScissorRect scissor) {
//         vkCmdSetScissor(vkcmdbuffer, 0, 1, cast(VkRect2D*)&scissor);
//     }

//     /**
//         Sets the active culling mode for the render pass.

//         Params:
//             culling = The culling mode.
//     */
//     override void setCulling(NioCulling culling) {
//         vkCmdSetCullMode(vkcmdbuffer, culling.toVkCullMode());
//     }

//     /**
//         Sets the active front-face winding for the render pass.

//         Params:
//             winding = The front-face winding.
//     */
//     override void setFaceWinding(NioFaceWinding winding) {
//         vkCmdSetFrontFace(vkcmdbuffer, winding.toVkFrontFace());
//     }

//     /**
//         Sets the active constant blending color for the render pass.

//         Params:
//             color = The constant blending color.
//     */
//     override void setBlendColor(NioColor color) {
//         float[4] values = *(cast(float[4]*)&color);
//         vkCmdSetBlendConstants(vkcmdbuffer, values);
//     }

//     /**
//         Sets the active render pipeline for the render pass.

//         Params:
//             pipeline =  The pipeline.
//     */
//     override void setPipeline(NioRenderPipeline pipeline) {

//     }

//     /**
//         Sets the given buffer as the active buffer at the given
//         slot in the vertex shader argument table.

//         Params:
//             buffer =    The buffer to set.
//             offset =    The offset into the buffer, in bytes.
//             slot =      The slot in the argument table to set.
//     */
//     override void setVertexBuffer(NioBuffer buffer, ulong offset, uint slot) {

//     }

//     /**
//         Sets the given texture as the active texture at the given
//         slot in the vertex shader argument table.

//         Params:
//             texture =   The texture to set.
//             slot =      The slot in the argument table to set.
//     */
//     override void setVertexTexture(NioTexture texture, uint slot) {

//     }

//     /**
//         Sets the given sampler as the active sampler at the given
//         slot in the vertex shader argument table.

//         Params:
//             sampler =   The sampler to set.
//             slot =      The slot in the argument table to set.
//     */
//     override void setVertexSampler(NioSampler sampler, uint slot) {

//     }

//     /**
//         Sets the given buffer as the active buffer at the given
//         slot in the fragment shader argument table.

//         Params:
//             buffer =    The buffer to set.
//             offset =    The offset into the buffer, in bytes.
//             slot =      The slot in the argument table to set.
//     */
//     override void setFragmentBuffer(NioBuffer buffer, ulong offset, uint slot) {

//     }

//     /**
//         Sets the given texture as the active texture at the given
//         slot in the fragment shader argument table.

//         Params:
//             texture =   The texture to set.
//             slot =      The slot in the argument table to set.
//     */
//     override void setFragmentTexture(NioTexture texture, uint slot) {

//     }

//     /**
//         Sets the given sampler as the active sampler at the given
//         slot in the fragment shader argument table.

//         Params:
//             sampler =   The sampler to set.
//             slot =      The slot in the argument table to set.
//     */
//     override void setFragmentSampler(NioSampler sampler, uint slot) {
        
//     }

//     /**
//         Enocodes a draw command using the bound vertex buffers.

//         Params:
//             prim =          The primitive topology to draw with.
//             firstVertex =   Offset to the first vertex.
//             vertexCount =   The amount of vertices to draw.
//     */
//     override void draw(NioPrimitive prim, uint firstVertex, uint vertexCount) {
//         this.setTopology(prim);
//         vkCmdDraw(vkcmdbuffer, vertexCount, 1, firstVertex, 0);
//     }

//     /**
//         Enocodes a draw command using the bound vertex buffers.

//         Params:
//             prim =          The primitive topology to draw with.
//             firstVertex =   Offset to the first vertex.
//             vertexCount =   The amount of vertices to draw.
//             instanceCount = The amount of instances to draw.
//     */
//     override void draw(NioPrimitive prim, uint firstVertex, uint vertexCount, uint instanceCount) {
//         this.setTopology(prim);
//         vkCmdDraw(vkcmdbuffer, vertexCount, instanceCount, firstVertex, 0);
//     }

//     /**
//         Enocodes a draw command using the bound vertex buffers.

//         Params:
//             prim =          The primitive topology to draw with.
//             firstVertex =   Offset to the first vertex.
//             vertexCount =   The amount of vertices to draw.
//             firstInstance = Index of the first instance to draw.
//             instanceCount = The amount of instances to draw.
//     */
//     override void draw(NioPrimitive prim, uint firstVertex, uint vertexCount, uint firstInstance, uint instanceCount) {
//         this.setTopology(prim);
//         vkCmdDraw(vkcmdbuffer, vertexCount, instanceCount, firstVertex, firstInstance);
//     }

//     /**
//         Enocodes a draw command using the bound vertex buffers and
//         the given index buffer.

//         Params:
//             prim =          The primitive topology to draw with.
//             indexBuffer =   The index buffer to use.
//             indexCount =    The amount of indices to draw.
//             indexType =     The type of the index values.
//             indexCount =    The amount of indices to draw.
//             indexOffset =   Offset into the index buffer to begin at.
//     */
//     override void drawIndexed(NioPrimitive prim, NioBuffer indexBuffer, NioIndexType indexType, uint indexCount, uint indexOffset = 0) {
//         this.setTopology(prim);
//         this.setIndexBuffer(cast(NioVkBuffer)indexBuffer, indexType);
//         vkCmdDrawIndexed(vkcmdbuffer, indexCount, 1, indexOffset, 0, 0);
//     }

//     /**
//         Enocodes a draw command using the bound vertex buffers and
//         the given index buffer.

//         Params:
//             prim =          The primitive topology to draw with.
//             indexBuffer =   The index buffer to use.
//             indexCount =    The amount of indices to draw.
//             indexType =     The type of the index values.
//             indexCount =    The amount of indices to draw.
//             indexOffset =   Offset into the index buffer to begin at.
//             instanceCount = The amount of instances to draw.
//     */
//     override void drawIndexed(NioPrimitive prim, NioBuffer indexBuffer, NioIndexType indexType, uint indexCount, uint indexOffset, uint instanceCount) {
//         this.setTopology(prim);
//         this.setIndexBuffer(cast(NioVkBuffer)indexBuffer, indexType);
//         vkCmdDrawIndexed(vkcmdbuffer, indexCount, instanceCount, indexOffset, 0, 0);
//     }

//     /**
//         Enocodes a draw command using the bound vertex buffers and
//         the given index buffer.

//         Params:
//             prim =          The primitive topology to draw with.
//             indexBuffer =   The index buffer to use.
//             indexCount =    The amount of indices to draw.
//             indexType =     The type of the index values.
//             indexCount =    The amount of indices to draw.
//             indexOffset =   Offset into the index buffer to begin at.
//             baseVertex =    Constant value to add to all of the indices.
//             instanceCount = The amount of instances to draw.
//     */
//     override void drawIndexed(NioPrimitive prim, NioBuffer indexBuffer, NioIndexType indexType, uint indexCount, uint indexOffset, int baseVertex, uint instanceCount) {
//         this.setTopology(prim);
//         this.setIndexBuffer(cast(NioVkBuffer)indexBuffer, indexType);
//         vkCmdDrawIndexed(vkcmdbuffer, indexCount, instanceCount, indexOffset, baseVertex, 0);
//     }
// }
